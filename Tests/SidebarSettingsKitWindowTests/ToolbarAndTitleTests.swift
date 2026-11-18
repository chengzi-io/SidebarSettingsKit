import AppKit
import SidebarSettingsFixtures
import SidebarSettingsKit
import SwiftUI
import Testing

@testable import SidebarSettingsKit

extension WindowTestSuite {
    /// The toolbar: its style, its back and forward buttons and their labels; and the window's
    /// title in its three modes.
    @Suite(.serialized) @MainActor
    struct ToolbarAndTitleTests {
        /// The AppKit style each configuration style must reach, written out here so a change in
        /// the kit's mapping shows up as a test failure.
        private static func appKitStyle(
            _ style: SidebarSettingsConfiguration.ToolbarStyle
        ) -> NSWindow.ToolbarStyle {
            switch style {
            case .unifiedCompact: .unifiedCompact
            case .unified: .unified
            case .automatic: .automatic
            }
        }

        @Test(arguments: SidebarSettingsConfiguration.ToolbarStyle.allCases)
        func toolbarStyleFollowsConfiguration(
            style: SidebarSettingsConfiguration.ToolbarStyle
        ) async throws {
            var configuration = SidebarSettingsConfiguration.windowTest
            configuration.toolbarStyle = style
            try await withWindow(configuration: configuration) { window in
                #expect(window.window.toolbarStyle == Self.appKitStyle(style))
            }
        }

        @Test func navigationButtonsAndTheirShortcutsAreGoneWhenTurnedOff() async throws {
            var configuration = SidebarSettingsConfiguration.windowTest
            configuration.showsNavigationButtons = false
            try await withWindow(configuration: configuration) { window in
                #expect(window.toolbarItem(SettingsWindowController.backItem) == nil)
                #expect(window.toolbarItem(SettingsWindowController.forwardItem) == nil)

                window.settings.navigator.open(FixturePages.appearance)
                try await WindowTest.wait(for: "the page to change") {
                    window.settings.navigator.selection == FixturePages.appearance
                }
                #expect(
                    window.window.performKeyEquivalent(
                        with: try commandKey("[", keyCode: 33, in: window.window)) == false)
                // The keystroke reaches the window's own handling only when the buttons are
                // there; with them off nothing may go back.
                await WindowTest.settle()
                #expect(window.settings.navigator.selection == FixturePages.appearance)
                #expect(
                    window.window.performKeyEquivalent(
                        with: try commandKey("]", keyCode: 30, in: window.window)) == false)
                await WindowTest.settle()
                #expect(window.settings.navigator.selection == FixturePages.appearance)
            }
        }

        @Test func navigationButtonsStartDisabledAndEnableAfterNavigation() async throws {
            try await withWindow { window in
                let back = try require(
                    window.toolbarItem(SettingsWindowController.backItem), "the back button")
                let forward = try require(
                    window.toolbarItem(SettingsWindowController.forwardItem), "the forward button")

                // AppKit validates the items when it updates the toolbar; ask it to, so the
                // state read here is the one a user would see.
                window.window.toolbar?.validateVisibleItems()
                #expect(back.isEnabled == false)
                #expect(forward.isEnabled == false)
                #expect(window.controller.validateToolbarItem(back) == false)

                window.settings.navigator.open(FixturePages.appearance)
                try await WindowTest.wait(for: "the back button to enable") { back.isEnabled }
                #expect(window.controller.validateToolbarItem(back))
                #expect(forward.isEnabled == false)
            }
        }

        @Test func navigationButtonLabelsUseTheDefaultStrings() async throws {
            let strings = SidebarSettingsConfiguration.Strings.default
            try await withWindow { window in
                let back = try require(
                    window.toolbarItem(SettingsWindowController.backItem), "the back button")
                let forward = try require(
                    window.toolbarItem(SettingsWindowController.forwardItem), "the forward button")
                #expect(back.label == String(localized: strings.back))
                #expect(forward.label == String(localized: strings.forward))
                #expect(!back.label.isEmpty)
                #expect(!forward.label.isEmpty)
            }
        }

        @Test func navigationButtonLabelsUseOverriddenStrings() async throws {
            var configuration = SidebarSettingsConfiguration.windowTest
            configuration.strings = .init(back: "Previous", forward: "Next")
            try await withWindow(configuration: configuration) { window in
                #expect(window.toolbarItem(SettingsWindowController.backItem)?.label == "Previous")
                #expect(
                    window.toolbarItem(SettingsWindowController.forwardItem)?.label == "Next")
            }
        }

        @Test func titleFollowsThePage() async throws {
            try await withWindow(pages: FixturePages.three, initialPage: FixturePages.general) {
                window in
                #expect(window.window.title == String(localized: FixturePages.general.title))
                window.settings.navigator.open(FixturePages.appearance)
                try await WindowTest.wait(for: "the title to follow the page to Appearance") {
                    window.window.title == String(localized: FixturePages.appearance.title)
                }
            }
        }

        @Test func fixedTitleStaysThroughPageChanges() async throws {
            var configuration = SidebarSettingsConfiguration.windowTest
            configuration.title = .fixed("Settings")
            try await withWindow(configuration: configuration) { window in
                #expect(window.window.title == "Settings")
                window.settings.navigator.open(FixturePages.appearance)
                await WindowTest.settle()
                #expect(window.window.title == "Settings")
            }
        }

        @Test func hiddenTitleHidesTheToolbarTitleAndStillFollowsThePage() async throws {
            var configuration = SidebarSettingsConfiguration.windowTest
            configuration.title = .hidden
            try await withWindow(
                pages: FixturePages.three, initialPage: FixturePages.general,
                configuration: configuration
            ) { window in
                #expect(window.window.titleVisibility == .hidden)
                #expect(window.window.title == String(localized: FixturePages.general.title))
                window.settings.navigator.open(FixturePages.appearance)
                try await WindowTest.wait(for: "the hidden title to follow the page") {
                    window.window.title == String(localized: FixturePages.appearance.title)
                }
                #expect(window.window.titleVisibility == .hidden)
            }
        }
    }
}
