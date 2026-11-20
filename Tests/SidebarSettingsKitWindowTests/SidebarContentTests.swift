import AppKit
import SidebarSettingsFixtures
import SidebarSettingsKit
import SwiftUI
import Testing

@testable import SidebarSettingsKit

extension WindowTestSuite {
    /// The sidebar's grouping, its search field, and what it shows when a search finds nothing.
    @Suite(.serialized) @MainActor
    struct SidebarContentTests {
        /// The groups the sidebar shows: every page, and a heading row for each group that kept
        /// a page.
        private static func check(_ sections: [SettingsPageSection<FixturePage>]) async throws {
            let pages = sections.flatMap(\.pages)
            let shownGroups = sections.filter { !$0.pages.isEmpty }.count
            let settings = SidebarSettingsWindow(sections: sections, configuration: .windowTest) {
                FixtureDetail(page: $0)
            }
            try await withWindow(settings) { window in
                #expect(window.sidebarPageRowCount() == pages.count)
                #expect(window.sidebarHeadingRowCount() == shownGroups)
            }
        }

        @Test func groupsShowEveryPage() async throws {
            try await Self.check(FixtureSections.grouped)
        }

        @Test func aGroupWithoutPagesIsLeftOut() async throws {
            try await Self.check(FixtureSections.withEmptySection)
        }

        @Test func disabledSearchHasNoSearchField() async throws {
            var configuration = SidebarSettingsConfiguration.windowTest
            configuration.search = .disabled
            try await withWindow(configuration: configuration) { window in
                #expect(window.searchField() == nil)
            }
        }

        @Test func commandFFocusesTheSearchField() async throws {
            try await withWindow { window in
                let field = try require(window.searchField(), "the sidebar's search field")
                // Somewhere else in the window, so taking focus back is a change.
                window.window.makeFirstResponder(window.window.contentView)
                #expect(
                    window.window.performKeyEquivalent(
                        with: try commandKey("f", keyCode: 3, in: window.window)))
                try await WindowTest.wait(for: "⌘F to focus the search field") {
                    isFocused(field, in: window.window)
                }
            }
        }

        @Test func searchTextFiltersTheSidebar() async throws {
            try await withWindow { window in
                #expect(window.sidebarPageRowCount() == FixturePages.three.count)

                window.settings.navigator.searchText = "appearance"
                try await WindowTest.wait(for: "the sidebar to keep only Appearance") {
                    window.sidebarPageRowCount() == 1
                }

                // A page's search keywords find it too, here Appearance's "dark mode".
                window.settings.navigator.searchText = "dark mode"
                try await WindowTest.wait(for: "the sidebar to find Appearance by its keyword") {
                    window.sidebarPageRowCount() == 1
                }

                window.settings.navigator.searchText = ""
                try await WindowTest.wait(for: "the sidebar to show every page again") {
                    window.sidebarPageRowCount() == FixturePages.three.count
                }
            }
        }

        @Test func aSearchWithoutAMatchShowsTheEmptyStateAndClearingItBringsTheRowsBack()
            async throws
        {
            try await withWindow { window in
                #expect(window.sidebarPageRowCount() == FixturePages.three.count)

                window.settings.navigator.searchText = "nothing in this window matches"
                try await WindowTest.wait(for: "the list to give way to the empty state") {
                    window.sidebarTable() == nil
                }
                // No rows are left to show, and the sidebar still draws something in their place.
                #expect(window.sidebarPageRowCount() == 0)
                #expect(!window.sidebarView.subviews.isEmpty)

                window.settings.navigator.searchText = ""
                try await WindowTest.wait(for: "the rows to come back") {
                    window.sidebarPageRowCount() == FixturePages.three.count
                }
            }
        }
    }
}
