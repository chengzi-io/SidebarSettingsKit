import AppKit
import SidebarSettingsFixtures
import SidebarSettingsKit
import SwiftUI
import Testing

@testable import SidebarSettingsKit

extension WindowTestSuite {
    /// The only thing the kit may leave in `UserDefaults`: the window's frame, and only when
    /// `autosaveName` names one.
    @Suite(.serialized) @MainActor
    struct AutosaveTests {
        private static func uniqueName() -> String {
            "WindowTestAutosave-\(UUID().uuidString)"
        }

        private static func makeSettings(name: String?) -> SidebarSettingsWindow<FixturePage> {
            var configuration = SidebarSettingsConfiguration.windowTest
            configuration.autosaveName = name
            return fixtureWindow(configuration: configuration)
        }

        /// A spot away from where `center()` puts `window`, with the whole frame inside the
        /// screen: AppKit moves a restored frame into the visible area, which Stage Manager
        /// narrows on the left and a CI runner's 1024-point screen leaves little room in.
        private static func spotInsideTheScreen(for window: NSWindow) throws -> NSPoint {
            let screen = try require(window.screen ?? NSScreen.main, "a screen").visibleFrame
            return NSPoint(
                x: (screen.maxX - window.frame.width - 20).rounded(.down),
                y: (screen.minY + 20).rounded(.down))
        }

        @Test func namedWindowSavesItsFrameWhenItCloses() async throws {
            let name = Self.uniqueName()
            let key = WindowTest.frameDefaultsPrefix + name
            defer { UserDefaults.standard.removeObject(forKey: key) }

            let settings = Self.makeSettings(name: name)
            defer { settings.close() }
            settings.show()
            let window = try await WindowUnderTest.attach(settings)
            let moved = try Self.spotInsideTheScreen(for: window.window)
            window.window.setFrameOrigin(moved)
            try await WindowTest.wait(for: "the window to move") {
                window.window.frame.origin == moved
            }

            settings.close()
            try await WindowTest.wait(for: "the frame to be saved under \(key)") {
                UserDefaults.standard.string(forKey: key) != nil
            }
            // AppKit saves "x y width height screen…" for the window's frame.
            let saved = try require(UserDefaults.standard.string(forKey: key), "the saved frame")
            let numbers = saved.split(separator: " ").compactMap { Double($0) }
            #expect(numbers.first == Double(moved.x))
            #expect(numbers.dropFirst().first == Double(moved.y))
        }

        @Test func aReopenedWindowUsesTheSavedFrame() async throws {
            let name = Self.uniqueName()
            let key = WindowTest.frameDefaultsPrefix + name
            defer { UserDefaults.standard.removeObject(forKey: key) }
            var moved = NSPoint.zero

            // An app replaces a window object by dropping the old one; AppKit refuses a name
            // while a live window holds it, so the first window must be gone.
            weak var firstWindow: NSWindow?
            do {
                let first = Self.makeSettings(name: name)
                first.show()
                let window = try await WindowUnderTest.attach(first)
                firstWindow = window.window
                moved = try Self.spotInsideTheScreen(for: window.window)
                window.window.setFrameOrigin(moved)
                try await WindowTest.wait(for: "the window to move") {
                    window.window.frame.origin == moved
                }
                first.close()
                try await WindowTest.wait(for: "the frame to be saved under \(key)") {
                    UserDefaults.standard.string(forKey: key) != nil
                }
            }
            try await WindowTest.wait(for: "the first window to be released") { firstWindow == nil }

            let second = Self.makeSettings(name: name)
            defer { second.close() }
            second.show()
            let reopened = try await WindowUnderTest.attach(second)
            let origin = reopened.window.frame.origin

            #expect(reopened.window.frameAutosaveName == name)
            #expect(origin == moved)
        }

        @Test func anUnnamedWindowSavesNoFrame() async throws {
            let before = defaultsKeys()
            let settings = Self.makeSettings(name: nil)
            defer { settings.close() }
            settings.show()
            let window = try await WindowUnderTest.attach(settings)
            window.window.setFrameOrigin(NSPoint(x: 200, y: 220))
            await WindowTest.settle()
            settings.close()
            try await WindowTest.wait(for: "the window to close") { settings.isVisible == false }

            let writtenFrames = defaultsKeys().subtracting(before)
                .filter { $0.hasPrefix(WindowTest.frameDefaultsPrefix) }
            #expect(writtenFrames.isEmpty, "\(writtenFrames)")
        }

        @Test func aWindowWritesNoDefaultsButItsFrame() async throws {
            let before = defaultsKeys()
            try await withWindow { window in
                window.settings.navigator.open(FixturePages.appearance)
                try await WindowTest.wait(for: "the page to change") {
                    window.settings.navigator.selection == FixturePages.appearance
                }
                window.settings.navigator.searchText = "app"
                await WindowTest.settle()
            }

            let added = defaultsKeys().subtracting(before).sorted()
            // AppKit, not the kit, writes this the first time the process builds a text view
            // (the sidebar's search field); it is the one key of its kind seen here.
            let writtenByAppKit: Set<String> = ["NSVisualBidiSelectionEnabled"]
            let unexpected = added.filter {
                !$0.hasPrefix(WindowTest.frameDefaultsPrefix) && !writtenByAppKit.contains($0)
            }
            #expect(
                unexpected.isEmpty,
                "the window wrote defaults keys of its own: \(unexpected)")
        }
    }
}
