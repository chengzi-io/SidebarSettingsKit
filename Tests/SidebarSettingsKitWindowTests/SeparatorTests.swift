import AppKit
import SidebarSettingsFixtures
import SidebarSettingsKit
import SwiftUI
import Testing

@testable import SidebarSettingsKit

extension WindowTestSuite {
    /// The line under the toolbar: it follows the page's scroll position, and a new page starts
    /// at the top.
    @Suite(.serialized) @MainActor
    struct SeparatorTests {
        @Test func separatorFollowsTheDetailScroll() async throws {
            try await withWindow(initialPage: FixturePages.appearance) { window in
                let detail = try window.detailScrollView()
                // The false-pass rule: the page must be taller than the space it is shown in.
                try requireScrollable(detail, atLeast: LongContentView.minimumHeight)

                if #available(macOS 15.0, *) {
                    try await WindowTest.wait(for: "the line to be hidden at the top") {
                        window.separator == .none
                    }
                    scroll(detail, toOffsetFromTop: 200)
                    try await WindowTest.wait(for: "the line to show past the top") {
                        window.separator == .line
                    }
                    #expect(window.controller.scrollState.isScrolled)

                    scroll(detail, toOffsetFromTop: 0)
                    try await WindowTest.wait(for: "the line to hide again at the top") {
                        window.separator == .none
                    }
                    #expect(window.controller.scrollState.isScrolled == false)
                } else {
                    // macOS 14 cannot report a scroll offset to SwiftUI, so
                    // `.whenScrolled` shows the line always; see SeparatorMode.whenScrolled.
                    #expect(window.separator == .line)
                }
            }
        }

        @Test func switchingToAShortPageHidesTheLine() async throws {
            try await withWindow(initialPage: FixturePages.appearance) { window in
                let detail = try window.detailScrollView()
                try requireScrollable(detail, atLeast: LongContentView.minimumHeight)
                scroll(detail, toOffsetFromTop: 300)
                if #available(macOS 15.0, *) {
                    try await WindowTest.wait(for: "the line to show while scrolled") {
                        window.separator == .line
                    }
                }

                window.settings.navigator.open(FixturePages.advanced)
                try await WindowTest.wait(for: "the short page to replace the long one") {
                    guard let short = firstScrollView(in: window.detailView),
                        let height = short.documentView?.frame.height
                    else { return false }
                    return height <= ShortContentView.maximumHeight
                }
                if #available(macOS 15.0, *) {
                    try await WindowTest.wait(for: "the line to hide on the short page") {
                        window.separator == .none
                    }
                }
            }
        }

        @Test func alwaysShowsTheLineEvenWhenScrolled() async throws {
            var configuration = SidebarSettingsConfiguration.windowTest
            configuration.toolbarSeparator = .always
            try await withWindow(initialPage: FixturePages.appearance, configuration: configuration)
            { window in
                #expect(window.separator == .line)
                let detail = try window.detailScrollView()
                try requireScrollable(detail, atLeast: LongContentView.minimumHeight)
                scroll(detail, toOffsetFromTop: 300)
                await WindowTest.settle()
                #expect(window.separator == .line)
            }
        }

        @Test func neverShowsTheLineEvenWhenScrolled() async throws {
            var configuration = SidebarSettingsConfiguration.windowTest
            configuration.toolbarSeparator = .never
            try await withWindow(initialPage: FixturePages.appearance, configuration: configuration)
            { window in
                #expect(window.separator == .none)
                let detail = try window.detailScrollView()
                try requireScrollable(detail, atLeast: LongContentView.minimumHeight)
                scroll(detail, toOffsetFromTop: 300)
                await WindowTest.settle()
                #expect(window.separator == .none)
            }
        }

        @Test func separatorFollowsThePagesOwnScrollView() async throws {
            var configuration = SidebarSettingsConfiguration.windowTest
            configuration.detailScrolling = false
            try await withWindow(
                initialPage: FixturePages.appearance, configuration: configuration,
                detail: { page in OwnScrollingDetail(page: page) }
            ) { window in
                // Without `detailScrolling` the page's scroll view is the only one in the column.
                let detail = try window.detailScrollView()
                try requireScrollable(detail, atLeast: LongContentView.minimumHeight)

                if #available(macOS 15.0, *) {
                    try await WindowTest.wait(for: "the line to be hidden at the top") {
                        window.separator == .none
                    }
                    scroll(detail, toOffsetFromTop: 250)
                    try await WindowTest.wait(for: "the line to show past the top") {
                        window.separator == .line
                    }
                    scroll(detail, toOffsetFromTop: 0)
                    try await WindowTest.wait(for: "the line to hide again at the top") {
                        window.separator == .none
                    }
                } else {
                    #expect(window.separator == .line)
                }
            }
        }

        @Test func newPageStartsAtTheTop() async throws {
            try await withWindow(initialPage: FixturePages.appearance) { window in
                let long = try window.detailScrollView()
                try requireScrollable(long, atLeast: LongContentView.minimumHeight)
                scroll(long, toOffsetFromTop: 400)
                if #available(macOS 15.0, *) {
                    try await WindowTest.wait(for: "the line to show while scrolled") {
                        window.separator == .line
                    }
                }

                window.settings.navigator.open(FixturePages.general)
                try await WindowTest.wait(for: "the new page to start at its top") {
                    guard let detail = firstScrollView(in: window.detailView),
                        let height = detail.documentView?.frame.height,
                        height <= ShortContentView.maximumHeight
                    else { return false }
                    return scrollOffsetFromTop(detail) == 0
                }
                if #available(macOS 15.0, *) {
                    try await WindowTest.wait(for: "the line to hide on the new page") {
                        window.separator == .none
                    }
                }
            }
        }
    }
}

/// A page that scrolls itself, as a `Form` or `List` does, and tells the window about it.
private struct OwnScrollingDetail: View {
    let page: FixturePage

    var body: some View {
        ScrollView {
            switch page.contentKind {
            case .short: ShortContentView()
            case .long: LongContentView()
            }
        }
        .sidebarSettingsScrollTracking()
    }
}
