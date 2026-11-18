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
            for style in [SidebarSettingsStyle.native, .branded] {
                try await withWindow(style: style) { window in
                    let table = try require(window.sidebarTable(), "the sidebar's table")
                    // Not the search field, the window's first key view, which AppKit picks.
                    try await WindowTest.wait(for: "the list to take the focus") {
                        window.window.firstResponder === table
                    }
                }
            }
        }

        @Test func typingAPageTitleSelectsItsRow() async throws {
            for style in [SidebarSettingsStyle.native, .branded] {
                try await withWindow(style: style) { window in
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
