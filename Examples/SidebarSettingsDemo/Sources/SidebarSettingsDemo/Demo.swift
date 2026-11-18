import AppKit
import DemoFixtures
import Observation
import SidebarSettingsKit

/// The demo's state, created once at launch: the control panel's options and the settings
/// window they built, which has to outlive the main window's body.
@MainActor
@Observable
final class Demo {
    /// What the command line asked for.
    let arguments: DemoArguments

    /// The options the settings window on screen was built from.
    private(set) var options: DemoOptions

    /// The settings window, replaced rather than reconfigured when the options change.
    private(set) var settingsWindow: SidebarSettingsWindow<FixturePage>

    /// A demo of `arguments`, its settings window on the default options.
    init(arguments: DemoArguments) {
        self.arguments = arguments
        var options = DemoOptions()
        options.style = arguments.style
        self.options = options
        settingsWindow = SettingsWindowFactory.make(options: options)
    }

    /// Applies the appearance and opens the scenario the command line asked for, once the app
    /// has finished launching.
    func start() {
        if let appearance = arguments.appearance {
            NSApp.appearance = appearance.nsAppearance
        }
        arguments.scenario?.run(in: self)
    }

    /// Closes the settings window and opens a new one for `options`, on `page` and with
    /// `searchText` typed into the search field.
    func apply(
        _ options: DemoOptions,
        startScrolled: Bool = false,
        selecting page: FixturePage? = nil,
        searchText: String? = nil
    ) {
        self.options = options
        settingsWindow.close()
        let window = SettingsWindowFactory.make(options: options, startScrolled: startScrolled)
        if let searchText {
            window.navigator.searchText = searchText
        }
        settingsWindow = window
        window.show(page: page)
    }

    /// Brings the settings window on screen, as the ⌘, item does.
    func showSettings() {
        settingsWindow.show()
    }
}
