import SwiftUI

/// The app menu's Settings… item (⌘,), opening a ``SidebarSettingsWindow`` in place of the
/// `Settings` scene's.
///
/// ```swift
/// WindowGroup { ContentView() }
///     .commands { SidebarSettingsCommands(window: settings) }
/// ```
///
/// Remove the app's `Settings` scene, which would add a second item.
public struct SidebarSettingsCommands<Page: SettingsPage>: Commands {
    private let window: SidebarSettingsWindow<Page>

    /// The item for `window`, titled with its configuration's
    /// ``SidebarSettingsConfiguration/Strings/settingsMenuItem``.
    public init(window: SidebarSettingsWindow<Page>) {
        self.window = window
    }

    /// The menu item, replacing the app menu's settings group.
    public var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            OpenSidebarSettingsButton(window: window)
                .keyboardShortcut(",")
        }
    }
}
