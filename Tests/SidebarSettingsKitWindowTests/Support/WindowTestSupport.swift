import AppKit
import Foundation
import SidebarSettingsFixtures
import SidebarSettingsKit
import SwiftUI
import Testing

@testable import SidebarSettingsKit

/// Every window test, in one serialized suite.
///
/// The tests open real windows in one app process and read app-wide state (the first responder,
/// `NSApp.windows`, `UserDefaults`), so they must not run beside each other. Swift Testing
/// serializes a suite's child suites too, which is why each area below is a nested suite.
@Suite(.serialized)
enum WindowTestSuite {}

// MARK: - Failures

/// A test's own failure: a wait that timed out, a part of the window that was not there.
struct WindowTestFailure: Error, CustomStringConvertible {
    let message: String

    var description: String { message }
}

/// Returns `value`, or throws ``WindowTestFailure`` with `message`.
func require<T>(_ value: T?, _ message: @autoclosure () -> String) throws -> T {
    guard let value else { throw WindowTestFailure(message: message()) }
    return value
}

// MARK: - Waiting for AppKit and SwiftUI

@MainActor
enum WindowTest {
    /// How long a wait may take before it fails the test.
    static let timeout: Duration = .seconds(5)

    /// How long each poll lets the run loop work.
    static let step: Duration = .milliseconds(20)

    /// The prefix AppKit saves a window's frame under, the one `UserDefaults` key the kit may
    /// leave behind.
    static let frameDefaultsPrefix = "NSWindow Frame "

    /// Polls `condition` until it holds, and throws after `timeout` naming what it waited for.
    ///
    /// Every wait awaits instead of running the run loop. The kit updates the window's title
    /// and the toolbar separator from `Task { @MainActor in … }`, and a synchronous body that
    /// blocks the main thread in `RunLoop.main.run(until:)` starves that task and the main
    /// queue both (checked on macOS 15.7: neither ran), so a test would read stale state.
    static func wait(
        for condition: String,
        timeout: Duration = timeout,
        _ holds: () -> Bool
    ) async throws {
        if await poll(timeout: timeout, holds) { return }
        throw WindowTestFailure(message: "Timed out after \(timeout) waiting for \(condition)")
    }

    /// Polls without throwing, and returns whether `condition` ever held. For the bodies of
    /// `withKnownIssue`, which must not throw: it rethrows.
    static func poll(timeout: Duration = timeout, _ holds: () -> Bool) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if holds() { return true }
            try? await Task.sleep(for: step)
        }
        return holds()
    }

    /// Lets one more pass of the run loop settle, for effects with no state to poll.
    static func settle(_ duration: Duration = .milliseconds(80)) async {
        try? await Task.sleep(for: duration)
    }

    /// Polls until `value` stops changing for three polls and returns the last value: SwiftUI
    /// scrolls and swaps pages over several frames, so a value read once is a guess.
    static func settled<T: Equatable>(
        _ value: () -> T,
        timeout: Duration = timeout
    ) async throws -> T {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        var last = value()
        var stable = 0
        while clock.now < deadline {
            try? await Task.sleep(for: step)
            let next = value()
            if next == last {
                stable += 1
                if stable >= 3 { return next }
            } else {
                last = next
                stable = 0
            }
        }
        throw WindowTestFailure(message: "the value never settled; it stayed \(last)")
    }
}

// MARK: - Reading a window

/// `view` and every view below it, depth first.
@MainActor
func allViews(in view: NSView) -> [NSView] {
    view.subviews.reduce([view]) { $0 + allViews(in: $1) }
}

/// `view`'s frame in the window's coordinates.
@MainActor
func frameInWindow(_ view: NSView) -> CGRect {
    view.convert(view.bounds, to: nil)
}

/// The first scroll view below `view`. SwiftUI builds each `ScrollView` and each `List` from
/// one, `HostingScrollView` and `ListCoreScrollView` respectively.
@MainActor
func firstScrollView(in view: NSView) -> NSScrollView? {
    allViews(in: view).compactMap { $0 as? NSScrollView }.first
}

/// How far `scrollView`'s content has moved down from the top, in points: 0 at the top.
///
/// SwiftUI insets a page's content by the space the toolbar takes (38 pt in a
/// `fullSizeContentView` window), so the clip view's own origin is negative at the top; adding
/// the inset back makes the value comparable with 0, which is what the kit's scroll tracking
/// compares against.
@MainActor
func scrollOffsetFromTop(_ scrollView: NSScrollView) -> CGFloat {
    scrollView.contentView.bounds.origin.y + scrollView.contentInsets.top
}

/// The furthest `scrollView` can scroll, where it shows the bottom of its content.
@MainActor
func maximumScrollOffset(_ scrollView: NSScrollView) -> CGFloat {
    max(0, (scrollView.documentView?.frame.height ?? 0) - scrollView.contentView.bounds.height)
}

/// Scrolls `scrollView` to `offset` points below the top of its content.
///
/// `reflectScrolledClipView` is what publishes the move: without it SwiftUI's
/// `.onScrollGeometryChange` never sees the new offset, and the toolbar separator stays put.
@MainActor
func scroll(_ scrollView: NSScrollView, toOffsetFromTop offset: CGFloat) {
    scrollView.contentView.scroll(to: NSPoint(x: 0, y: offset - scrollView.contentInsets.top))
    scrollView.reflectScrolledClipView(scrollView.contentView)
}

/// Fails when `scrollView`'s content is not taller than the space it is shown in: a scroll test
/// whose content fits would pass without ever scrolling.
@MainActor
func requireScrollable(_ scrollView: NSScrollView, atLeast minimumContentHeight: CGFloat) throws {
    let contentHeight = try require(
        scrollView.documentView?.frame.height, "a document view inside the scroll view")
    let visibleHeight = scrollView.contentView.bounds.height
    guard contentHeight > visibleHeight, contentHeight >= minimumContentHeight else {
        throw WindowTestFailure(
            message: """
                the page cannot scroll, so the test would pass without scrolling: content \
                \(contentHeight) pt, visible \(visibleHeight) pt, at least \(minimumContentHeight) \
                pt of content expected
                """)
    }
}

/// A ⌘ key press for `window`, in the form `SettingsWindow` reads them.
@MainActor
func commandKey(_ characters: String, keyCode: UInt16, in window: NSWindow) throws -> NSEvent {
    try require(
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
            windowNumber: window.windowNumber, context: nil, characters: characters,
            charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode),
        "an NSEvent for ⌘\(characters)")
}

/// Types `text` into `window`'s first responder, one key press per character. The events
/// carry the current time: the list's type-to-select joins key presses by their timestamps.
@MainActor
func typeKeys(_ text: String, in window: NSWindow) throws {
    for character in text.map(String.init) {
        let press = try require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, characters: character,
                charactersIgnoringModifiers: character, isARepeat: false, keyCode: 0),
            "an NSEvent for \(character)")
        window.sendEvent(press)
    }
}

/// The defaults keys `UserDefaults.standard` holds, for the tests that assert the kit stores
/// nothing.
func defaultsKeys() -> Set<String> {
    Set(UserDefaults.standard.dictionaryRepresentation().keys)
}

// MARK: - Pointing at a header or a footer

/// Points at the `NSView` SwiftUI builds for the view under it, so a test can tell whether the
/// kit drew a header or a footer and where it sits.
///
/// The probe is placed in an `overlay`, so it takes no room and changes no layout.
@MainActor
final class ViewAnchor {
    private(set) weak var view: NSView?

    /// Whether the view is on screen; `false` when the kit left it out, or scrolled it away.
    var isShown: Bool { view?.window != nil }

    /// The view's frame in window coordinates, or `nil` when it is not in a window.
    var frameInWindow: CGRect? {
        guard let view, view.window != nil else { return nil }
        return view.convert(view.bounds, to: nil)
    }

    func store(_ view: NSView) {
        self.view = view
    }
}

/// Hands its `NSView` to `anchor`.
struct ViewAnchorProbe: NSViewRepresentable {
    let anchor: ViewAnchor

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        anchor.store(view)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        anchor.store(view)
    }
}

/// `content` with a 1 pt probe at its top-left corner, so the probe's frame starts where
/// `content`'s does.
@MainActor
func probed<Content: View>(_ anchor: ViewAnchor, _ content: Content) -> some View {
    content.overlay(alignment: .topLeading) {
        ViewAnchorProbe(anchor: anchor).frame(width: 1, height: 1)
    }
}

// MARK: - A window to drive

extension SidebarSettingsConfiguration {
    /// The configuration the tests use unless the test is about the window's frame: it saves
    /// no frame, so no `UserDefaults` key is written.
    static var windowTest: Self {
        var configuration = Self()
        configuration.autosaveName = nil
        return configuration
    }
}

/// A shown settings window and the parts of it the tests read.
@MainActor
struct WindowUnderTest {
    let settings: SidebarSettingsWindow<FixturePage>
    let controller: SettingsWindowController
    let window: SettingsWindow

    /// The window's left column.
    var sidebarView: NSView { controller.sidebarItem.viewController.view }

    /// The window's right column, which shows the page.
    var detailView: NSView { controller.detailItem.viewController.view }

    /// The line under the toolbar, driven by the detail's scroll state.
    var separator: NSTitlebarSeparatorStyle { controller.detailItem.titlebarSeparatorStyle }

    /// Waits until `settings`' window is on screen with its columns laid out.
    static func attach(_ settings: SidebarSettingsWindow<FixturePage>) async throws -> Self {
        try await WindowTest.wait(for: "the settings window to be on screen") { settings.isVisible }
        let controller = try require(settings.controller, "the settings window's controller")
        let window = try require(controller.window as? SettingsWindow, "a SettingsWindow")
        try await WindowTest.wait(for: "the split view to lay out its columns") {
            window.contentView?.layoutSubtreeIfNeeded()
            return controller.sidebarItem.viewController.view.frame.width > 1
                && controller.detailItem.viewController.view.frame.width > 1
        }
        return Self(settings: settings, controller: controller, window: window)
    }

    func toolbarItem(_ identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
        window.toolbar?.items.first { $0.itemIdentifier == identifier }
    }

    /// The scroll view the kit put the page in, when `detailScrolling` is on, or the page's own.
    func detailScrollView() throws -> NSScrollView {
        try require(firstScrollView(in: detailView), "a scroll view in the detail column")
    }

    func sidebarScrollView() throws -> NSScrollView {
        try require(firstScrollView(in: sidebarView), "a scroll view in the sidebar")
    }

    /// The sidebar's `List`.
    func sidebarTable() -> NSTableView? {
        allViews(in: sidebarView).compactMap { $0 as? NSTableView }.first
    }

    /// The rows that show a page: the rows the list lets the user select. A group's heading
    /// row and the header cannot be selected, so this is the number of pages the sidebar shows,
    /// groups aside.
    func sidebarPageRowCount() -> Int {
        guard let outline = sidebarTable() as? NSOutlineView else { return 0 }
        return (0..<outline.numberOfRows).count { Self.isPageRow($0, in: outline) }
    }

    /// The rows that show no page: group headings, and the header when there is one.
    func sidebarHeadingRowCount() -> Int {
        guard let outline = sidebarTable() as? NSOutlineView else { return 0 }
        return (0..<outline.numberOfRows).count { !Self.isPageRow($0, in: outline) }
    }

    func searchField() -> NSSearchField? {
        allViews(in: sidebarView).compactMap { $0 as? NSSearchField }.first
    }

    /// Asked of the list rather than read from how a row draws, which changes between macOS
    /// versions: a page row carries a selection tag, a heading or the header does not.
    private static func isPageRow(_ row: Int, in outline: NSOutlineView) -> Bool {
        guard let item = outline.item(atRow: row) else { return false }
        return outline.delegate?.outlineView?(outline, shouldSelectItem: item) ?? false
    }
}

// MARK: - Opening and closing a window

/// Shows a window built with `FixtureDetail` pages, and closes it when `body` returns, also
/// when `body` throws.
@MainActor
func withWindow(
    pages: [FixturePage] = FixturePages.three,
    initialPage: FixturePage? = nil,
    configuration: SidebarSettingsConfiguration = .windowTest,
    style: SidebarSettingsStyle = .native,
    page: FixturePage? = nil,
    _ body: (WindowUnderTest) async throws -> Void
) async throws {
    let settings = SidebarSettingsWindow(
        pages: pages, initialPage: initialPage, configuration: configuration, style: style
    ) { page in
        FixtureDetail(page: page)
    }
    try await withWindow(settings, page: page, body)
}

/// Shows a window with pages of the test's own view, for the pages that draw their own scroll
/// view, and closes it when `body` returns.
@MainActor
func withWindow<Detail: View>(
    pages: [FixturePage] = FixturePages.three,
    initialPage: FixturePage? = nil,
    configuration: SidebarSettingsConfiguration = .windowTest,
    style: SidebarSettingsStyle = .native,
    page: FixturePage? = nil,
    @ViewBuilder detail: @escaping (FixturePage) -> Detail,
    _ body: (WindowUnderTest) async throws -> Void
) async throws {
    let settings = SidebarSettingsWindow(
        pages: pages, initialPage: initialPage, configuration: configuration, style: style,
        detail: detail)
    try await withWindow(settings, page: page, body)
}

/// Shows a window built from grouped pages, and closes it when `body` returns.
@MainActor
func withWindow(
    sections: [SettingsPageSection<FixturePage>],
    initialPage: FixturePage? = nil,
    configuration: SidebarSettingsConfiguration = .windowTest,
    style: SidebarSettingsStyle = .native,
    page: FixturePage? = nil,
    _ body: (WindowUnderTest) async throws -> Void
) async throws {
    let settings = SidebarSettingsWindow(
        sections: sections, initialPage: initialPage, configuration: configuration, style: style
    ) { page in
        FixtureDetail(page: page)
    }
    try await withWindow(settings, page: page, body)
}

/// Shows `settings`, waits for its window, and closes it when `body` returns.
@MainActor
func withWindow(
    _ settings: SidebarSettingsWindow<FixturePage>,
    page: FixturePage? = nil,
    _ body: (WindowUnderTest) async throws -> Void
) async throws {
    defer { settings.close() }
    settings.show(page: page)
    let window = try await WindowUnderTest.attach(settings)
    try await body(window)
}
