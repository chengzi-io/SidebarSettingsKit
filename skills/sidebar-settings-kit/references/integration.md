# Integration

## Where the window lives

`SidebarSettingsWindow` is a class you create once and keep for the app's life. It owns the
navigation (page, history, search), so a second instance would be a second, empty history. The
AppKit window inside it is built on the first `show()`.

### In the App

Fine when the app has no app delegate. `App.init` runs once.

```swift
@main
struct MyApp: App {
    @State private var model: AppModel
    private let settings: SidebarSettingsWindow<SettingsPane>

    init() {
        let model = AppModel()
        _model = State(initialValue: model)
        settings = SidebarSettingsWindow(pages: SettingsPane.allCases) { pane in
            SettingsPaneView(pane: pane).environment(model)
        }
    }

    var body: some Scene {
        WindowGroup { ContentView().environment(model) }
            .commands { SidebarSettingsCommands(window: settings) }
    }
}
```

### In the app delegate

Best when the app already has one, and for menu bar apps.

```swift
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    lazy var settings = SidebarSettingsWindow(pages: SettingsPane.allCases) { [model] pane in
        SettingsPaneView(pane: pane).environment(model)
    }
}

@main
struct MyApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        WindowGroup { ContentView().environment(delegate.model) }
            .commands { SidebarSettingsCommands(window: delegate.settings) }
    }
}
```

### In the app's root object

If the app has a root model or coordinator created once, the window can be one of its
properties. Keep it out of the settings data model: the window is UI, the settings are data.

## Menu bar apps

```swift
MenuBarExtra("MyApp", systemImage: "bolt") {
    OpenSidebarSettingsButton(window: delegate.settings)
        .keyboardShortcut(",")
    Divider()
    Button("Quit MyApp") { NSApp.terminate(nil) }
}
```

`show()` activates the app before showing the window, which an app without a Dock icon
(`LSUIElement`) needs to bring it to the front. A `Settings { EmptyView() }` scene kept only so
the app had a scene can go: `MenuBarExtra` is a scene.

## Open on a page

```swift
settings.show(page: .shortcuts)              // from code, such as a deep link or onboarding
OpenSidebarSettingsButton(window: settings, page: .shortcuts) {
    Label("Keyboard Shortcuts…", systemImage: "command")
}
```

The page must be one of the window's pages. The navigator is public for reading state, such as
`settings.navigator.selection`, or for `settings.navigator.open(_:)` while the window is open.

## Migrate a tabbed Settings scene

Before:

```swift
Settings {
    TabView {
        GeneralSettingsView().tabItem { Label("General", systemImage: "gearshape") }
        AdvancedSettingsView().tabItem { Label("Advanced", systemImage: "star") }
    }
    .frame(width: 450, height: 250)
}
```

After:

1. A page type with one case per tab; the tab's label becomes `title` and its image `icon`.
2. The `detail` closure switches over the page and returns the tab's view, unchanged:

   ```swift
   settings = SidebarSettingsWindow(pages: SettingsPane.allCases) { pane in
       switch pane {
       case .general: GeneralSettingsView()
       case .advanced: AdvancedSettingsView()
       }
   }
   ```

3. Delete the `Settings` scene, the `TabView`, the `.tabItem`s and the fixed frame.
4. Add `.commands { SidebarSettingsCommands(window: settings) }` to the main scene.
5. Replace every `SettingsLink` and `openSettings()` with `settings.show()`, passing `settings`
   to the views that call it: the window is in no environment.
6. Add `searchKeywords` from each view's setting labels.

## Previews

The window cannot be previewed; preview each page's view on its own:

```swift
#Preview { GeneralSettingsView().frame(width: 500, height: 600) }
```

## Tests in the app

There is nothing to mock: the window is UI. Test the app's settings model as before. To check
the integration, launch the app and open the window (UI test or by hand).
