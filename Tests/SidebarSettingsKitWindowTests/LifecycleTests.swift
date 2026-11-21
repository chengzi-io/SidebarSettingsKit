import AppKit
import SidebarSettingsFixtures
import SidebarSettingsKit
import SwiftUI
import Testing

@testable import SidebarSettingsKit

extension WindowTestSuite {
    /// The window's life: showing it twice, closing and showing it again, and what it keeps
    /// across that.
    @Suite(.serialized) @MainActor
    struct LifecycleTests {
        @Test func showingTwiceOpensOneWindow() async throws {
            let settings = fixtureWindow()
            defer { settings.close() }
            settings.show()
            let first = try await WindowUnderTest.attach(settings)

            let windowCount = NSApp.windows.count
            settings.show()
            await WindowTest.settle()

            #expect(settings.controller?.window === first.window)
            #expect(NSApp.windows.count == windowCount)
        }

        @Test func closingThenShowingReusesTheWindowAndTheNavigator() async throws {
            let settings = fixtureWindow()
            defer { settings.close() }
            settings.show()
            let first = try await WindowUnderTest.attach(settings)
            let navigator = settings.navigator

            settings.close()
            try await WindowTest.wait(for: "the window to close") { settings.isVisible == false }

            settings.show()
            try await WindowTest.wait(for: "the window to come back") { settings.isVisible }
            #expect(settings.controller?.window === first.window)
            #expect(settings.navigator === navigator)
        }

        @Test func sessionPersistenceKeepsThePageAndItsHistory() async throws {
            var configuration = SidebarSettingsConfiguration.windowTest
            configuration.navigationPersistence = .session
            let settings = fixtureWindow(configuration: configuration)
            defer { settings.close() }
            settings.show()
            _ = try await WindowUnderTest.attach(settings)
            settings.navigator.open(FixturePages.appearance)
            try await WindowTest.wait(for: "the page to change") {
                settings.navigator.selection == FixturePages.appearance
            }

            settings.close()
            try await WindowTest.wait(for: "the window to close") { settings.isVisible == false }
            settings.show()
            try await WindowTest.wait(for: "the window to come back") { settings.isVisible }

            #expect(settings.navigator.selection == FixturePages.appearance)
            #expect(settings.navigator.canGoBack)
        }

        @Test func resetOnShowReturnsToTheInitialPage() async throws {
            var configuration = SidebarSettingsConfiguration.windowTest
            configuration.navigationPersistence = .resetOnShow
            let settings = fixtureWindow(configuration: configuration)
            defer { settings.close() }
            settings.show()
            _ = try await WindowUnderTest.attach(settings)
            settings.navigator.open(FixturePages.advanced)
            try await WindowTest.wait(for: "the page to change") {
                settings.navigator.selection == FixturePages.advanced
            }

            settings.close()
            try await WindowTest.wait(for: "the window to close") { settings.isVisible == false }
            settings.show()
            try await WindowTest.wait(for: "the window to come back") { settings.isVisible }

            #expect(settings.navigator.selection == FixturePages.general)
            #expect(settings.navigator.canGoBack == false)
        }

        @Test func showSelectsThePageItIsGiven() async throws {
            try await withWindow(page: FixturePages.advanced) { window in
                #expect(window.settings.navigator.selection == FixturePages.advanced)
                // The title is set once the page change has reached the window.
                try await WindowTest.wait(for: "the title of the page show(page:) selected") {
                    window.window.title == String(localized: FixturePages.advanced.title)
                }
            }
        }
    }
}
