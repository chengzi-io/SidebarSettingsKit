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
        /// the kit's mapping shows up as a test failure. macOS 26 gets no compact toolbar.
        private static func appKitStyle(
            _ style: SidebarSettingsConfiguration.ToolbarStyle
        ) -> NSWindow.ToolbarStyle {
            switch style {
            case .unifiedCompact:
                ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 26
                    ? .automatic : .unifiedCompact
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

        /// The sidebar runs up under the toolbar, as System Settings' does, whatever the style and
        /// with or without the title. On macOS 26 a compact toolbar started it below the title
        /// bar, with the window buttons on a bare strip, and on macOS 15 the automatic style turned
        /// compact while the title was hidden. Its gap to the window's top must match its gap to
        /// the bottom: none on macOS 14, 15 and 27, the floating sidebar's inset on macOS 26.
        @Test(
            arguments: SidebarSettingsConfiguration.ToolbarStyle.allCases,
            [SidebarSettingsConfiguration.TitleMode.followsPage, .hidden])
        func sidebarRunsUnderTheToolbar(
            style: SidebarSettingsConfiguration.ToolbarStyle,
            title: SidebarSettingsConfiguration.TitleMode
        ) async throws {
            var configuration = SidebarSettingsConfiguration.windowTest
            configuration.toolbarStyle = style
            configuration.title = title
            try await withWindow(configuration: configuration) { window in
                let content = try require(window.window.contentView, "the window's content view")
                let sidebar = frameInWindow(window.sidebarView)
                let gapToTop = content.frame.maxY - sidebar.maxY
                #expect(gapToTop == sidebar.minY, "sidebar \(sidebar) in \(content.frame)")
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

        /// With the buttons off, AppKit alone set the title 11 pt from the sidebar, left of the
        /// page's grouped form (20 pt in); the title must line up with the page instead.
        @Test(
            .disabled(
                if: ProcessInfo.processInfo.isOperatingSystemAtLeast(
                    OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)),
                "macOS 26's toolbar is left as AppKit lays it out"))
        func theTitleLinesUpWithThePageWithoutTheButtons() async throws {
            var configuration = SidebarSettingsConfiguration.windowTest
            configuration.showsNavigationButtons = false
            try await withWindow(configuration: configuration) { window in
                let frameView = try require(
                    window.window.contentView?.superview, "the window's frame view")
                let title = try require(
                    allViews(in: frameView).compactMap { $0 as? NSTextField }
                        .first { !$0.isEditable && $0.stringValue == window.window.title },
                    "the toolbar's title")
                // The title's text starts 2 pt inside its box.
                let gap = frameInWindow(title).minX - frameInWindow(window.sidebarView).maxX
                #expect((17...21).contains(gap), "the title starts \(gap) pt from the sidebar")
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
            try await withWindow(initialPage: FixturePages.general) { window in
                #expect(window.window.title == String(localized: FixturePages.general.title))
                window.settings.navigator.open(FixturePages.appearance)
                try await WindowTest.wait(for: "the title to follow the page to Appearance") {
                    window.window.title == String(localized: FixturePages.appearance.title)
                }
            }
        }

        /// The title and the back button change in the update that draws the new page: set after
        /// it, the old title stayed over the new page for a frame.
        @Test func titleAndButtonsChangeInTheUpdateThatShowsThePage() async throws {
            try await withWindow(initialPage: FixturePages.general) { window in
                let back = try require(
                    window.toolbarItem(SettingsWindowController.backItem), "the back button")
                window.window.toolbar?.validateVisibleItems()
                #expect(back.isEnabled == false)

                window.settings.navigator.open(FixturePages.appearance)
                // SwiftUI updates the page from the run loop. Running it from this task lets
                // that update happen and no task or main-queue block run, so anything set later
                // than the update is not set yet.
                runTheRunLoop(for: 0.2)
                #expect(window.window.title == String(localized: FixturePages.appearance.title))
                #expect(back.isEnabled)
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
            try await withWindow(initialPage: FixturePages.general, configuration: configuration) {
                window in
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

/// Runs the main run loop from the calling task: SwiftUI's updates happen, and no other task or
/// main-queue block runs until it returns.
@MainActor
private func runTheRunLoop(for seconds: TimeInterval) {
    RunLoop.main.run(until: .now.addingTimeInterval(seconds))
}
