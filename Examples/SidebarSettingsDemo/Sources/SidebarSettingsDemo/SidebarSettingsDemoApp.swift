import AppKit
import SidebarSettingsKit
import SwiftUI

@main
struct SidebarSettingsDemoApp: App {
    @NSApplicationDelegateAdaptor(DemoAppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup("Sidebar Settings Demo") {
            DemoRootView(demo: delegate.demo)
        }
        .commands {
            SidebarSettingsCommands(window: delegate.demo.settingsWindow)
        }
    }
}

/// Gives the executable a Dock icon, a menu bar and a key window, which SwiftPM's bare
/// executable has no `Info.plist` to ask for, then applies the command line.
@MainActor
final class DemoAppDelegate: NSObject, NSApplicationDelegate {
    let demo: Demo

    override init() {
        let arguments: DemoArguments
        do {
            arguments = try DemoArguments.parse(CommandLine.arguments)
        } catch {
            DemoArguments.exitWithUsage("\(error)")
        }
        demo = Demo(arguments: arguments)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        demo.start()
    }
}
