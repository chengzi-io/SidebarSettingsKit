import AppKit
import SidebarSettingsFixtures
import SidebarSettingsKit
import SwiftUI
import Testing

@testable import SidebarSettingsKit

extension WindowTestSuite {
    /// The shortcuts the window takes itself, before the app's menus: ⌘[ and ⌘], and ⌘W; and
    /// the keys the sidebar list takes, which work as soon as the window opens.
    @Suite(.serialized) @MainActor
    struct KeyboardTests {
        @Test func theListHasTheFocusWhenTheWindowOpens() async throws {
            for icons in SidebarSettingsConfiguration.Icons.bothKinds {
                try await withWindow(configuration: .windowTest.drawing(icons)) { window in
                    let table = try require(window.sidebarTable(), "the sidebar's table")
                    // Not the search field, the window's first key view, which AppKit picks.
                    try await WindowTest.wait(for: "the list to take the focus") {
                        window.window.firstResponder === table
                    }
                }
            }
        }

        @Test func typingAPageTitleSelectsItsRow() async throws {
            for icons in SidebarSettingsConfiguration.Icons.bothKinds {
                try await withWindow(configuration: .windowTest.drawing(icons)) { window in
                    let table = try require(window.sidebarTable(), "the sidebar's table")
                    try await WindowTest.wait(for: "the list to take the focus") {
                        window.window.firstResponder === table
                    }
                    #expect(window.settings.navigator.selection == FixturePages.general)

                    // "ad", not "a": Appearance and Advanced both start with an A.
                    try typeKeys("adv", in: window.window)
                    try await WindowTest.wait(for: "typing \"adv\" to select Advanced") {
                        window.settings.navigator.selection == FixturePages.advanced
                    }
                }
            }
        }

        /// As in System Settings: ↓ in the search field goes to the first page found, then the
        /// arrows move through the pages found; ↑ on the first stays in the list, and Tab goes
        /// back to the field.
        @Test func downArrowLeavesTheSearchFieldForThePagesFound() async throws {
            try await withWindow(pages: FixturePages.three, initialPage: FixturePages.general) {
                window in
                let field = try require(window.searchField(), "the sidebar's search field")
                let table = try require(window.sidebarTable(), "the sidebar's table")
                let navigator = window.settings.navigator
                // The list takes the focus once the window opens; the field is focused after.
                try await WindowTest.wait(for: "the list to take the focus") {
                    window.window.firstResponder === table
                }
                window.window.makeFirstResponder(field)
                try await WindowTest.wait(for: "the search field to take the focus") {
                    isFocused(field, in: window.window)
                }
                // "ance" finds Appearance and Advanced; General, the page shown, is not found.
                try typeKeys("ance", in: window.window)
                try await WindowTest.wait(for: "the search to find two pages") {
                    window.sidebarPageRowCount() == 2
                }

                try press(.down, in: window.window)
                try await WindowTest.wait(for: "↓ to open the first page found, in the list") {
                    window.window.firstResponder === table
                        && navigator.selection == FixturePages.appearance
                }
                try press(.down, in: window.window)
                try await WindowTest.wait(for: "↓ to open the next page found") {
                    navigator.selection == FixturePages.advanced
                }
                try press(.up, in: window.window)
                try await WindowTest.wait(for: "↑ to go back to the first page found") {
                    navigator.selection == FixturePages.appearance
                }
                try press(.up, in: window.window)
                await WindowTest.settle()
                #expect(window.window.firstResponder === table)
                #expect(navigator.selection == FixturePages.appearance)

                try press(.tab, in: window.window)
                try await WindowTest.wait(for: "Tab to go back to the search field") {
                    isFocused(field, in: window.window)
                }
                #expect(navigator.searchText == "ance")
            }
        }

        /// A search that finds nothing replaces the list; the list that comes back when a letter
        /// is deleted must leave the focus in the field, or the next letter selects a row.
        @Test func theListComingBackLeavesTheFocusInTheSearchField() async throws {
            try await withWindow(pages: FixturePages.three) { window in
                let field = try require(window.searchField(), "the sidebar's search field")
                let table = try require(window.sidebarTable(), "the sidebar's table")
                try await WindowTest.wait(for: "the list to take the focus") {
                    window.window.firstResponder === table
                }
                window.window.makeFirstResponder(field)
                try typeKeys("appz", in: window.window)
                try await WindowTest.wait(for: "the search to find nothing") {
                    window.sidebarTable() == nil
                }

                try press(.delete, in: window.window)
                try await WindowTest.wait(for: "the list to come back with Appearance") {
                    window.sidebarPageRowCount() == 1
                }
                // A list that takes the focus does so a turn of the run loop after it appears.
                await WindowTest.settle(.milliseconds(300))
                #expect(isFocused(field, in: window.window))
            }
        }

        @Test func commandBracketGoesBackAndForward() async throws {
            try await withWindow(pages: FixturePages.three) { window in
                window.settings.navigator.open(FixturePages.appearance)
                try await WindowTest.wait(for: "the page to change") {
                    window.settings.navigator.selection == FixturePages.appearance
                }

                #expect(
                    window.window.performKeyEquivalent(
                        with: try commandKey("[", keyCode: 33, in: window.window)))
                try await WindowTest.wait(for: "⌘[ to go back to General") {
                    window.settings.navigator.selection == FixturePages.general
                }

                #expect(
                    window.window.performKeyEquivalent(
                        with: try commandKey("]", keyCode: 30, in: window.window)))
                try await WindowTest.wait(for: "⌘] to go forward to Appearance") {
                    window.settings.navigator.selection == FixturePages.appearance
                }
            }
        }

        @Test func commandWClosesTheWindow() async throws {
            try await withWindow { window in
                #expect(
                    window.window.performKeyEquivalent(
                        with: try commandKey("w", keyCode: 13, in: window.window)))
                try await WindowTest.wait(for: "⌘W to close the window") {
                    window.settings.isVisible == false
                }
            }
        }
    }
}
