import AppKit
import SwiftUI

@main
struct SidebarSettingsDemoApp: App {
    @NSApplicationDelegateAdaptor(DemoAppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup("Sidebar Settings Demo") {
            if ProcessInfo.processInfo.environment["SSK_PROBE_REPLICA"] != nil {
                ProbeReplica()
            } else {
                ControlPanelView(demo: delegate.demo)
            }
        }
        .commands {
            DemoCommands(demo: delegate.demo)
        }
    }
}

/// The app menu's Settings… item. The kit's ``SidebarSettingsCommands`` keeps the window it
/// was built with, which the control panel replaces, so the demo asks the panel for the
/// current window instead.
struct DemoCommands: Commands {
    let demo: Demo

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(String(localized: demo.settingsWindow.configuration.strings.settingsMenuItem)) {
                demo.showSettings()
            }
            .keyboardShortcut(",")
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
        if ProcessInfo.processInfo.environment["SSK_PROBE_REPLICA"] == nil { demo.start() }
    }
}
