import AppKit
import SidebarSettingsFixtures
import SidebarSettingsKit
import SwiftUI
import Testing

@testable import SidebarSettingsKit

extension WindowTestSuite {
    /// What the configuration sets before anything draws: the window's content size and
    /// resizing, and the sidebar's width.
    @Suite(.serialized) @MainActor
    struct WindowGeometryTests {
        @Test func defaultContentSize() async throws {
            try await withWindow { window in
                #expect(window.window.contentView?.frame.size == CGSize(width: 715, height: 600))
            }
        }

        @Test func customContentSize() async throws {
            var configuration = SidebarSettingsConfiguration.windowTest
            configuration.size = CGSize(width: 640, height: 520)
            try await withWindow(configuration: configuration) { window in
                #expect(window.window.contentView?.frame.size == CGSize(width: 640, height: 520))
            }
        }

        @Test func fixedWindowCannotResize() async throws {
            try await withWindow { window in
                #expect(window.window.styleMask.contains(.resizable) == false)
            }
        }

        @Test func resizableWindowAppliesItsLimits() async throws {
            var configuration = SidebarSettingsConfiguration.windowTest
            configuration.resizing = .resizable(
                min: CGSize(width: 600, height: 480), max: CGSize(width: 900, height: 700))
            try await withWindow(configuration: configuration) { window in
                #expect(window.window.styleMask.contains(.resizable))
                #expect(window.window.contentMinSize == CGSize(width: 600, height: 480))
                #expect(window.window.contentMaxSize == CGSize(width: 900, height: 700))
            }
        }

        /// Apple's guidelines dim a settings window's minimize and zoom buttons; it cannot go
        /// full screen either. A resizable window still resizes from its edges.
        @Test(arguments: [false, true])
        func theWindowCannotBeMinimizedZoomedOrMadeFullScreen(resizable: Bool) async throws {
            var configuration = SidebarSettingsConfiguration.windowTest
            if resizable { configuration.resizing = .resizable() }
            try await withWindow(configuration: configuration) { window in
                let nsWindow = window.window
                #expect(nsWindow.standardWindowButton(.miniaturizeButton)?.isEnabled == false)
                #expect(nsWindow.standardWindowButton(.zoomButton)?.isEnabled == false)
                // A test process cannot enter full screen whatever the window allows, so the
                // flag AppKit reads is what can be checked.
                #expect(nsWindow.collectionBehavior.contains(.fullScreenNone))

                let frame = nsWindow.frame
                nsWindow.zoom(nil)
                await WindowTest.settle()
                #expect(nsWindow.frame == frame)
            }
        }

        @Test func fixedSidebarWidth() async throws {
            var configuration = SidebarSettingsConfiguration.windowTest
            configuration.sidebarWidth = .fixed(260)
            try await withWindow(configuration: configuration) { window in
                #expect(window.controller.sidebarItem.minimumThickness == 260)
                #expect(window.controller.sidebarItem.maximumThickness == 260)
                #expect(window.sidebarView.frame.width == 260)
            }
        }

        @Test func adjustableSidebarWidthStartsAtItsIdeal() async throws {
            var configuration = SidebarSettingsConfiguration.windowTest
            configuration.sidebarWidth = .adjustable(min: 180, ideal: 240, max: 300)
            try await withWindow(configuration: configuration) { window in
                #expect(window.controller.sidebarItem.minimumThickness == 180)
                #expect(window.controller.sidebarItem.maximumThickness == 300)
                #expect(window.sidebarView.frame.width == 240)
            }
        }

        @Test func sidebarCannotCollapse() async throws {
            try await withWindow { window in
                #expect(window.controller.sidebarItem.canCollapse == false)
                let identifiers = (window.window.toolbar?.items ?? []).map(\.itemIdentifier)
                #expect(!identifiers.contains(.toggleSidebar))
            }
        }
    }
}
