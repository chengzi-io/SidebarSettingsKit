import AppKit
import SwiftUI

/// The AppKit window behind ``SidebarSettingsWindow``: a split view whose sidebar cannot
/// collapse, beside the detail, under a toolbar with back and forward buttons.
///
/// SwiftUI's scenes cannot build it: the `Settings` scene keeps the preferences toolbar, and
/// a `NavigationSplitView` sidebar collapses when its divider is dragged in, after which
/// nothing brings it back.
@MainActor
final class SettingsWindowController: NSWindowController, NSToolbarDelegate,
    NSToolbarItemValidation
{
    /// What the window needs from the navigator, so the controller stays free of `Page`.
    struct Navigation {
        let canGoBack: () -> Bool
        let canGoForward: () -> Bool
        let goBack: () -> Void
        let goForward: () -> Void
        let pageTitle: () -> String

        /// The page's title and the buttons' state. Read in a view's body, it makes SwiftUI
        /// update the view when they change.
        var state: State {
            State(title: pageTitle(), canGoBack: canGoBack(), canGoForward: canGoForward())
        }

        struct State: Equatable {
            let title: String
            let canGoBack: Bool
            let canGoForward: Bool
        }
    }

    static let backItem = NSToolbarItem.Identifier("SidebarSettingsKit.back")
    static let forwardItem = NSToolbarItem.Identifier("SidebarSettingsKit.forward")
    static let leadingSpaceItem = NSToolbarItem.Identifier("SidebarSettingsKit.leadingSpace")
    // Probe only: the title as a toolbar item, the window's own title hidden.
    static let probeTitleItem = NSToolbarItem.Identifier("SidebarSettingsKit.probeTitle")
    static let probeTitleAsItem = ProcessInfo.processInfo.environment["SSK_PROBE_TITLE"] == "item"

    let sidebarItem: NSSplitViewItem
    let detailItem: NSSplitViewItem
    private let configuration: SidebarSettingsConfiguration
    private let splitViewController: NSSplitViewController
    private let navigation: Navigation
    /// An adjustable sidebar's ideal width, given to it when the window first shows.
    private var sidebarIdealOnceShown: CGFloat?

    init(
        configuration: SidebarSettingsConfiguration,
        navigation: Navigation,
        sidebar: some View,
        detail: some View
    ) {
        self.configuration = configuration
        self.navigation = navigation

        // Apple's guidelines dim a settings window's minimize and zoom buttons: ⌘, brings it
        // back, and it is sized for its pages. A resizable window still resizes from its edges.
        var styleMask: NSWindow.StyleMask = [.titled, .closable, .fullSizeContentView]
        if case .resizable = configuration.resizing { styleMask.insert(.resizable) }
        let window = SettingsWindow(
            contentRect: .zero,
            styleMask: styleMask,
            backing: .buffered,
            defer: true
        )

        let sidebarController = NSHostingController(rootView: sidebar.softScrollEdgeOnMacOS26())
        let separator = ToolbarSeparator()
        // The title and the buttons change in the SwiftUI update that draws the new page. Set
        // after it, from an observation, the old title stayed over the new page for a frame.
        let detailController = NSHostingController(
            rootView: detail
                .environment(\.pageScrolled, separator.follow(isScrolled:))
                .modifier(
                    FollowsNavigation(navigation: navigation) { [weak window] in
                        Self.showNavigation(in: window, configuration: configuration, navigation: navigation)
                    }
                )
        )
        // The split view and the window size the columns; the content's ideal size must not.
        sidebarController.sizingOptions = []
        detailController.sizingOptions = []

        sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarController)
        sidebarItem.canCollapse = false
        switch configuration.sidebarWidth {
        case .fixed(let width):
            sidebarItem.minimumThickness = width
            sidebarItem.maximumThickness = width
        case .adjustable(let min, let ideal, let max):
            sidebarItem.minimumThickness = min
            sidebarItem.maximumThickness = max
            sidebarIdealOnceShown = ideal
        }
        detailItem = NSSplitViewItem(viewController: detailController)
        separator.item = detailItem
        splitViewController = NSSplitViewController()
        splitViewController.addSplitViewItem(sidebarItem)
        splitViewController.addSplitViewItem(detailItem)

        // The controller owns the window; AppKit must not release it again on close.
        window.isReleasedWhenClosed = false
        // AppKit gives a resizable window full screen and an enabled zoom button.
        window.collectionBehavior.insert(.fullScreenNone)
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        // The split view leaves the list's next key view a view that takes no focus, so Tab
        // from the list went nowhere; System Settings' Tab goes back to the search field.
        window.autorecalculatesKeyViewLoop = true
        // Set after init: `NSWindow(contentViewController:)` leaves the title "Untitled"
        // until something changes it.
        window.contentViewController = splitViewController
        window.setContentSize(configuration.size)
        if case .resizable(let min, let max) = configuration.resizing {
            if let min { window.contentMinSize = min }
            if let max { window.contentMaxSize = max }
        }
        window.center()
        super.init(window: window)
        // On the controller: `init(window:)` clears a name set on the window. A window that
        // cannot be resized gets back only its saved position.
        if let autosaveName = configuration.autosaveName {
            windowFrameAutosaveName = autosaveName
        }

        if configuration.showsNavigationButtons {
            window.onBack = navigation.goBack
            window.onForward = navigation.goForward
        }
        // AppKit items: when SwiftUI's toolbar bridging built the toolbar, the window's
        // first title came out unlocalized.
        let toolbar = NSToolbar(identifier: "SidebarSettingsKit")
        toolbar.delegate = self
        // In an app, the taller toolbar shows "Back" and "Forward" under the arrows; System
        // Settings shows none. A test process gets icons only either way.
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        window.toolbarStyle = configuration.toolbarStyle.appKit
        if configuration.title == .hidden { window.titleVisibility = .hidden }

        Self.showNavigation(in: window, configuration: configuration, navigation: navigation)
        // Probe only: once the window shows, record its title field, then move the title to the item.
        Task { @MainActor [weak window] in
            try? await Task.sleep(for: .milliseconds(1000))
            guard let window else { return }
            probeDumpTitleField(in: window)
            guard Self.probeTitleAsItem, let label = Self.probeTitleLabel(in: window) else { return }
            if let field = probeTitleField(in: window) {
                label.font = field.font
                label.textColor = field.textColor
            }
            label.stringValue = window.title
            window.titleVisibility = .hidden
            probeDumpTitleField(in: window)
        }
    }

    private static func probeTitleLabel(in window: NSWindow) -> NSTextField? {
        guard probeTitleAsItem else { return nil }
        return window.toolbar?.items.first(where: { $0.itemIdentifier == probeTitleItem })?.view as? NSTextField
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        guard let ideal = sidebarIdealOnceShown else { return }
        sidebarIdealOnceShown = nil
        let splitView = splitViewController.splitView
        splitView.setPosition(ideal, ofDividerAt: 0)
        splitView.layoutSubtreeIfNeeded()
        // On macOS 26 that position left the sidebar 8 pt narrower than the ideal, so the
        // divider moves by what the sidebar came out short.
        let shortfall = ideal - sidebarItem.viewController.view.frame.width
        if shortfall != 0 {
            splitView.setPosition(ideal + shortfall, ofDividerAt: 0)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Shows the page's title, or the fixed one, and the back and forward buttons' state.
    private static func showNavigation(
        in window: NSWindow?,
        configuration: SidebarSettingsConfiguration,
        navigation: Navigation
    ) {
        guard let window else { return }
        window.title =
            switch configuration.title {
            case .followsPage, .hidden: navigation.pageTitle()
            case .fixed(let resource): String(localized: resource)
            }
        probeTitleLabel(in: window)?.stringValue = window.title
        window.toolbar?.validateVisibleItems()
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        if configuration.showsNavigationButtons {
            if Self.probeTitleAsItem {
                return [.sidebarTrackingSeparator, Self.backItem, Self.forwardItem, Self.probeTitleItem]
            }
            return [.sidebarTrackingSeparator, Self.backItem, Self.forwardItem]
        }
        // Alone, the title sat 11 pt from the sidebar, left of the page's grouped form (20 pt
        // in). An empty navigational item comes before the title, as the buttons do, and the
        // gap AppKit leaves after it lines the title up with the page. macOS 26 puts toolbar
        // items on glass, where an empty item is unchecked, so its toolbar stays AppKit's.
        if #available(macOS 26, *) { return [.sidebarTrackingSeparator] }
        return [.sidebarTrackingSeparator, Self.leadingSpaceItem]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        if identifier == Self.probeTitleItem {
            let item = NSToolbarItem(itemIdentifier: identifier)
            let label = NSTextField(labelWithString: "")
            label.identifier = NSUserInterfaceItemIdentifier("probeTitleLabel")
            label.font = .titleBarFont(ofSize: 0)
            item.view = label
            item.isBordered = false
            item.isNavigational = true
            return item
        }
        if identifier == Self.leadingSpaceItem {
            let item = NSToolbarItem(itemIdentifier: identifier)
            let space = NSView()
            // The gap AppKit leaves between items is the space.
            space.widthAnchor.constraint(equalToConstant: 0).isActive = true
            item.view = space
            item.isNavigational = true
            return item
        }
        let isBack = identifier == Self.backItem
        guard isBack || identifier == Self.forwardItem else { return nil }
        let label = String(localized: isBack ? configuration.strings.back : configuration.strings.forward)
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = label
        item.toolTip = label
        // Backward and forward, not left and right: in Arabic and Hebrew back points right.
        item.image = NSImage(
            systemSymbolName: isBack ? "chevron.backward" : "chevron.forward",
            accessibilityDescription: label
        )
        item.isBordered = true
        item.isNavigational = true
        item.target = self
        item.action = isBack ? #selector(goBack) : #selector(goForward)
        return item
    }

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        switch item.itemIdentifier {
        case Self.backItem: navigation.canGoBack()
        case Self.forwardItem: navigation.canGoForward()
        default: false
        }
    }

    @objc private func goBack() {
        navigation.goBack()
    }

    @objc private func goForward() {
        navigation.goForward()
    }
}

/// The line under the toolbar, as System Settings has it on macOS 15: none at the top of a page,
/// a line with a shadow once the page scrolls under the toolbar. The page reports its scroll
/// position; left to AppKit, the line lost track of it once SwiftUI swapped the page. macOS 14
/// shows a line always, as SwiftUI reports no scroll position there. macOS 26 and later ignore
/// the style and draw their own scroll edge.
@MainActor
private final class ToolbarSeparator {
    weak var item: NSSplitViewItem? {
        didSet {
            if #available(macOS 15.0, *) {
                follow(isScrolled: false)
            } else {
                item?.titlebarSeparatorStyle = .line
            }
        }
    }

    func follow(isScrolled: Bool) {
        item?.titlebarSeparatorStyle = isScrolled ? .shadow : .none
    }
}

/// Calls `show` in the SwiftUI update that draws a new page or changes the history.
private struct FollowsNavigation: ViewModifier {
    let navigation: SettingsWindowController.Navigation
    let show: @MainActor () -> Void

    func body(content: Content) -> some View {
        content.onChange(of: navigation.state) { show() }
    }
}

/// Takes the window's keyboard shortcuts before the main menu, so they work in an app
/// without a File or Go menu, such as a menu bar app.
final class SettingsWindow: NSWindow {
    var onBack: (() -> Void)?
    var onForward: (() -> Void)?

    /// The zoom button is dimmed; a double-click on the title bar or a menu item that calls
    /// this directly must not zoom the window either.
    override func zoom(_ sender: Any?) {}

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command else {
            return super.performKeyEquivalent(with: event)
        }
        switch event.charactersIgnoringModifiers {
        case "[" where onBack != nil:
            onBack?()
            return true
        case "]" where onForward != nil:
            onForward?()
            return true
        case "w":
            performClose(nil)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}

extension SidebarSettingsConfiguration.ToolbarStyle {
    var appKit: NSWindow.ToolbarStyle {
        switch self {
        case .unifiedCompact:
            // On macOS 26 a compact toolbar starts the sidebar below the title bar and leaves
            // the window buttons on a bare strip; macOS 27 runs it to the top again.
            if #available(macOS 27, *) {
                .unifiedCompact
            } else if #available(macOS 26, *) {
                .automatic
            } else {
                .unifiedCompact
            }
        case .unified: .unified
        case .automatic: .automatic
        }
    }
}

extension View {
    /// Rows fade out under the toolbar on macOS 26 and later.
    @ViewBuilder
    fileprivate func softScrollEdgeOnMacOS26() -> some View {
        if #available(macOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            self
        }
    }
}

// Probe only: the window's own title field and what it draws with.
@MainActor
private func probeTitleField(in window: NSWindow) -> NSTextField? {
    @MainActor func walk(_ view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.stringValue == window.title, !field.stringValue.isEmpty,
            field.identifier?.rawValue != "probeTitleLabel"
        {
            return field
        }
        for sub in view.subviews { if let found = walk(sub) { return found } }
        return nil
    }
    return window.contentView?.superview.flatMap(walk)
}

@MainActor
private func probeDumpTitleField(in window: NSWindow) {
    guard let path = ProcessInfo.processInfo.environment["SSK_PROBE_DUMP"] else { return }
    var line = "title \(window.title.debugDescription) visibility \(window.titleVisibility.rawValue)"
    if let field = probeTitleField(in: window) {
        line += " field \(type(of: field)) font \(field.font.map { "\($0.fontName) \($0.pointSize)" } ?? "nil") color \(field.textColor.map { "\($0)" } ?? "nil") frame \(field.frame)"
        var chain: [String] = []
        var v: NSView? = field.superview
        while let view = v { chain.append("\(type(of: view))"); v = view.superview }
        line += " in \(chain.joined(separator: " < "))"
    } else {
        line += " field none"
    }
    probeAppend(line, to: path)
}

func probeAppend(_ line: String, to path: String) {
    let data = Data((line + "\n").utf8)
    if let handle = FileHandle(forWritingAtPath: path) {
        handle.seekToEndOfFile(); handle.write(data); handle.closeFile()
    } else {
        FileManager.default.createFile(atPath: path, contents: data)
    }
}
