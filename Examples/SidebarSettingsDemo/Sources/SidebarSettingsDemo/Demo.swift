import AppKit
import DemoFixtures
import SidebarSettingsKit
import SwiftUI

/// The demo's state, created once at launch: the settings window has to outlive the main
/// window's body, which runs many times.
@MainActor
final class Demo {
    /// What the command line asked for.
    let arguments: DemoArguments

    /// The settings window the menu item and the main window's button open.
    let settingsWindow: SidebarSettingsWindow<FixturePage>

    /// The short page the scenarios that need one open the window on.
    let shortPage: FixturePage

    /// A demo of `arguments`, its settings window on the three fixture pages.
    init(arguments: DemoArguments) {
        self.arguments = arguments
        let pages = FixturePages.three
        shortPage = pages.first { $0.contentKind == .short } ?? pages[0]
        settingsWindow = SidebarSettingsWindow(
            sections: [SettingsPageSection(pages: pages)],
            style: arguments.style.sidebarStyle,
            detail: { FixtureDetail(page: $0) }
        )
    }

    /// Applies the appearance and opens the scenario the command line asked for, once the app
    /// has finished launching.
    func start() {
        if let appearance = arguments.appearance {
            NSApp.appearance = appearance.nsAppearance
        }
        arguments.scenario?.run(in: self)
    }
}

/// The demo's main window, standing in for a host app's own: a button that opens the settings
/// window, as the ⌘, menu item does.
struct DemoRootView: View {
    let demo: Demo

    var body: some View {
        VStack(spacing: 12) {
            Text("Sidebar Settings Kit")
                .font(.largeTitle)
            Text("The settings window opens on its own, as System Settings does.")
                .foregroundStyle(.secondary)
            OpenSidebarSettingsButton(window: demo.settingsWindow) {
                Text("Open Settings")
            }
        }
        .padding(40)
        .frame(minWidth: 460, minHeight: 240)
    }
}
