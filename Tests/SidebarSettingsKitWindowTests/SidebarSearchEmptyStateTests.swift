import AppKit
import SidebarSettingsFixtures
import SidebarSettingsKit
import SwiftUI
import Testing

@testable import SidebarSettingsKit

extension WindowTestSuite {
    /// What the sidebar shows when a search finds no page.
    @Suite(.serialized) @MainActor
    struct SidebarSearchEmptyStateTests {
        @Test func aSearchWithoutAMatchShowsTheEmptyStateAndClearingItBringsTheRowsBack()
            async throws
        {
            try await withWindow(pages: FixturePages.three) { window in
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
