import AppKit
import SidebarSettingsFixtures
import SidebarSettingsKit
import SwiftUI
import Testing

@testable import SidebarSettingsKit

extension WindowTestSuite {
    /// What happens to the window after the app lets go of it.
    @Suite(.serialized) @MainActor
    struct MemoryTests {
        @Test func closingAndDroppingTheWindowReleasesIt() async throws {
            weak var weakController: SettingsWindowController?
            weak var weakWindow: NSWindow?

            do {
                let settings = SidebarSettingsWindow(
                    pages: FixturePages.three, configuration: .windowTest
                ) { page in
                    FixtureDetail(page: page)
                }
                settings.show()
                let window = try await WindowUnderTest.attach(settings)
                weakController = window.controller
                weakWindow = window.window
                settings.close()
                await WindowTest.settle()
            }

            let released = await WindowTest.poll(timeout: .seconds(2)) {
                weakController == nil && weakWindow == nil
            }
            #expect(released, "the closed window and its controller are still alive")
        }
    }
}
