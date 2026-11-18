import AppKit
import SidebarSettingsFixtures
import SidebarSettingsKit
import SwiftUI
import Testing

@testable import SidebarSettingsKit

extension WindowTestSuite {
    /// What the sidebar shows above and below its pages: a header that scrolls with them, a
    /// footer fixed at its bottom, both, or neither.
    @Suite(.serialized) @MainActor
    struct SidebarChromeTests {
        /// The sidebar's shape for one combination of header and footer.
        private struct Chrome {
            /// The rows that draw a page.
            let pageRows: Int
            /// The rows that do not: the group heading, and the header when there is one.
            let headingRows: Int
            /// The height the list itself has, which a footer takes its own from.
            let listHeight: CGFloat
            let headerShown: Bool
            let footerShown: Bool
        }

        /// Opens a window with the given header and footer and measures its sidebar.
        private static func measure(header: Bool, footer: Bool) async throws -> Chrome {
            let headerAnchor = ViewAnchor()
            let footerAnchor = ViewAnchor()
            var chrome: Chrome?

            func read(_ window: WindowUnderTest) throws {
                let sidebar = try window.sidebarScrollView()
                chrome = Chrome(
                    pageRows: window.sidebarPageRowCount(),
                    headingRows: window.sidebarHeadingRowCount(),
                    listHeight: sidebar.contentView.bounds.height,
                    headerShown: headerAnchor.isShown,
                    footerShown: footerAnchor.isShown)
            }

            switch (header, footer) {
            case (false, false):
                try await withWindow { window in try read(window) }
            case (true, false):
                let settings = SidebarSettingsWindow(
                    pages: FixturePages.three, configuration: .windowTest,
                    header: { probed(headerAnchor, FixtureHeader()) }
                ) { page in FixtureDetail(page: page) }
                try await withWindow(settings) { window in try read(window) }
            case (false, true):
                let settings = SidebarSettingsWindow(
                    pages: FixturePages.three, configuration: .windowTest,
                    footer: { probed(footerAnchor, FixtureFooter()) }
                ) { page in FixtureDetail(page: page) }
                try await withWindow(settings) { window in try read(window) }
            case (true, true):
                let settings = SidebarSettingsWindow(
                    pages: FixturePages.three, configuration: .windowTest,
                    header: { probed(headerAnchor, FixtureHeader()) },
                    footer: { probed(footerAnchor, FixtureFooter()) }
                ) { page in FixtureDetail(page: page) }
                try await withWindow(settings) { window in try read(window) }
            }
            return try require(chrome, "the sidebar of the window")
        }

        @Test func windowsShowExactlyTheHeaderAndFooterTheyAreGiven() async throws {
            let plain = try await Self.measure(header: false, footer: false)
            let headerOnly = try await Self.measure(header: true, footer: false)
            let footerOnly = try await Self.measure(header: false, footer: true)
            let both = try await Self.measure(header: true, footer: true)

            // Neither: the list holds the three pages and their group's heading, nothing else.
            #expect(plain.headerShown == false)
            #expect(plain.footerShown == false)
            #expect(plain.pageRows == FixturePages.three.count)
            #expect(plain.headingRows == 1)

            // A header is a row at the top of the list: one more heading row, the same list.
            #expect(headerOnly.headerShown)
            #expect(headerOnly.footerShown == false)
            #expect(headerOnly.pageRows == plain.pageRows)
            #expect(headerOnly.headingRows == plain.headingRows + 1)
            #expect(abs(headerOnly.listHeight - plain.listHeight) <= 1)

            // A footer takes its height away from the list, not from the pages.
            #expect(footerOnly.headerShown == false)
            #expect(footerOnly.footerShown)
            #expect(footerOnly.pageRows == plain.pageRows)
            #expect(footerOnly.headingRows == plain.headingRows)
            #expect(abs(footerOnly.listHeight - (plain.listHeight - FixtureFooter.height)) <= 2)

            // Both, each in its place.
            #expect(both.headerShown)
            #expect(both.footerShown)
            #expect(both.pageRows == plain.pageRows)
            #expect(both.headingRows == plain.headingRows + 1)
            #expect(abs(both.listHeight - (plain.listHeight - FixtureFooter.height)) <= 2)
        }
    }
}
