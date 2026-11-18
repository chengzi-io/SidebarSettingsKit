import AppKit
import SidebarSettingsFixtures
import SidebarSettingsKit
import SwiftUI
import Testing

@testable import SidebarSettingsKit

extension WindowTestSuite {
    /// A sidebar with more pages than fit: it scrolls, its header scrolls away with the pages,
    /// the footer stays at the sidebar's bottom, and a page below the fold comes into sight.
    @Suite(.serialized) @MainActor
    struct SidebarScrollingTests {
        /// The last of the forty pages, below the fold at the default window height.
        private static let lastPage = FixturePages.many[FixturePages.many.count - 1]

        /// Opens the forty-page sidebar with a header and a tall footer, checks that it really is
        /// taller than the space it has, and hands it to `body`.
        private static func withTallSidebar(
            style: SidebarSettingsStyle,
            _ body: (WindowUnderTest, NSScrollView, ViewAnchor, ViewAnchor) async throws -> Void
        ) async throws {
            let header = ViewAnchor()
            let footer = ViewAnchor()
            let settings = SidebarSettingsWindow(
                pages: FixturePages.many, configuration: .windowTest, style: style,
                header: { probed(header, FixtureHeader()) },
                footer: { probed(footer, TallFooter()) },
                detail: { page in FixtureDetail(page: page) }
            )
            try await withWindow(settings) { window in
                let sidebar = try window.sidebarScrollView()
                try requireTallerThanShown(sidebar)
                try await body(window, sidebar, header, footer)
            }
        }

        /// The sidebar must have more content than it can show, or a scroll test would pass
        /// without scrolling.
        private static func requireTallerThanShown(_ sidebar: NSScrollView) throws {
            let contentHeight = try require(
                sidebar.documentView?.frame.height, "the sidebar's content")
            let visibleHeight = sidebar.contentView.bounds.height
            guard contentHeight > visibleHeight + 100 else {
                throw WindowTestFailure(
                    message: """
                        the sidebar fits, so the test would pass without scrolling: content \
                        \(contentHeight) pt, visible \(visibleHeight) pt
                        """)
            }
        }

        /// What the sidebar shows once the last page is selected.
        private struct LastPageSighting {
            let style: SidebarSettingsStyle
            let footer: Bool
            let shownOnOpen: Bool
            /// The last page's row, and the part of the list the sidebar shows.
            let lastRow: CGRect
            let visible: CGRect

            /// Whether the last page is fully inside what the sidebar shows.
            var isInSight: Bool {
                lastRow.minY >= visible.minY - 1 && lastRow.maxY <= visible.maxY + 2
            }

            var shortfall: String {
                "the last row runs \(Int(lastRow.minY))…\(Int(lastRow.maxY)) pt while the list "
                    + "shows \(Int(visible.minY))…\(Int(visible.maxY)) pt"
            }
        }

        /// Opens the forty-page sidebar on the last page, by `navigator.open` or by
        /// `show(page:)`, and measures whether that page came into sight.
        private static func lastPageSighting(
            style: SidebarSettingsStyle,
            footer: Bool,
            shownOnOpen: Bool
        ) async throws -> LastPageSighting {
            let headerAnchor = ViewAnchor()
            let footerAnchor = ViewAnchor()
            let settings =
                footer
                ? SidebarSettingsWindow(
                    pages: FixturePages.many, configuration: .windowTest, style: style,
                    header: { probed(headerAnchor, FixtureHeader()) },
                    footer: { probed(footerAnchor, TallFooter()) },
                    detail: { page in FixtureDetail(page: page) })
                : SidebarSettingsWindow(
                    pages: FixturePages.many, configuration: .windowTest, style: style,
                    header: { probed(headerAnchor, FixtureHeader()) },
                    detail: { page in FixtureDetail(page: page) })

            var sighting: LastPageSighting?
            try await withWindow(settings, page: shownOnOpen ? lastPage : nil) { window in
                let sidebar = try window.sidebarScrollView()
                try requireTallerThanShown(sidebar)

                if !shownOnOpen {
                    window.settings.navigator.open(lastPage)
                    try await WindowTest.wait(for: "the last page to be selected") {
                        window.settings.navigator.selection == lastPage
                    }
                }
                _ = try await WindowTest.settled { scrollOffsetFromTop(sidebar) }
                let table = try require(window.sidebarTable(), "the sidebar's table")
                sighting = LastPageSighting(
                    style: style,
                    footer: footer,
                    shownOnOpen: shownOnOpen,
                    lastRow: table.rect(ofRow: table.numberOfRows - 1),
                    visible: sidebar.documentVisibleRect)
            }
            return try require(sighting, "the sidebar after the last page was selected")
        }

        @Test func aFullSidebarScrolls() async throws {
            for style in [SidebarSettingsStyle.native, .branded] {
                try await Self.withTallSidebar(style: style) { window, sidebar, _, _ in
                    let rows = try require(window.sidebarTable(), "the sidebar's table")
                        .numberOfRows
                    #expect(rows >= FixturePages.many.count)
                    let before = scrollOffsetFromTop(sidebar)
                    scroll(sidebar, toOffsetFromTop: before + 100)
                    let after = try await WindowTest.settled { scrollOffsetFromTop(sidebar) }
                    #expect(after > before)
                }
            }
        }

        @Test func footerStaysAtTheSidebarsBottomWhileTheListScrolls() async throws {
            for style in [SidebarSettingsStyle.native, .branded] {
                try await Self.withTallSidebar(style: style) { window, sidebar, _, footer in
                    let sidebarBottom = frameInWindow(window.sidebarView).minY
                    let before = try require(footer.frameInWindow, "the footer in the window")
                    // The footer's own bottom edge is the sidebar's.
                    #expect(abs(before.minY - (sidebarBottom + TallFooter.height)) <= 2)

                    scroll(sidebar, toOffsetFromTop: 100)
                    await WindowTest.settle()
                    let after = try require(footer.frameInWindow, "the footer after scrolling")
                    #expect(abs(after.minY - before.minY) <= 1)
                }
            }
        }

        @Test func headerScrollsUpWithTheList() async throws {
            for style in [SidebarSettingsStyle.native, .branded] {
                try await Self.withTallSidebar(style: style) { window, sidebar, header, _ in
                    // The list may open scrolled to the selected page, which hides the header.
                    scroll(sidebar, toOffsetFromTop: 0)
                    try await WindowTest.wait(for: "the header to come into view") { header.isShown }
                    let before = try require(header.frameInWindow, "the header in the window")

                    scroll(sidebar, toOffsetFromTop: 30)
                    try await WindowTest.wait(for: "the header to move up with the list") {
                        (header.frameInWindow?.minY ?? -1) > before.minY + 10
                    }
                    let after = try require(header.frameInWindow, "the header after scrolling")
                    // Window coordinates put y up, so scrolling down lifts the header by as much.
                    #expect(abs((after.minY - before.minY) - 30) <= 2)
                }
            }
        }

        @Test func theSidebarBringsTheLastPageIntoSight() async throws {
            for style in [SidebarSettingsStyle.native, .branded] {
                for footer in [false, true] {
                    for shownOnOpen in [false, true] {
                        let sighting = try await Self.lastPageSighting(
                            style: style, footer: footer, shownOnOpen: shownOnOpen)
                        #expect(
                            sighting.isInSight,
                            """
                            the last page is not in sight for \(style == .native ? "native" : "branded"), \
                            footer: \(footer), shown on open: \(shownOnOpen): \(sighting.shortfall)
                            """)
                    }
                }
            }
        }
    }
}
