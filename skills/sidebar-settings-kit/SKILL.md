---
name: sidebar-settings-kit
description: Give a macOS SwiftUI app a settings window like System Settings - a sidebar of pages that never collapses, a search field, back and forward in the toolbar - with SidebarSettingsKit, or move an app's tabbed Settings scene to it. Use when someone wants sidebar-style settings, has outgrown a TabView Settings window, or asks to add or configure SidebarSettingsKit.
allowed-tools: Bash(grep -rEnI *)
---

# Integrate SidebarSettingsKit

SidebarSettingsKit builds the window: the sidebar, search, history, toolbar, the line under
the toolbar, Liquid Glass on macOS 26 and later. The app keeps everything else: its settings data, how it
stores them, and the views of each page. Integrating it is a small change; most of the work is
deciding the pages and moving existing settings views into them.

## 1. Read the project

!`grep -rEnI --include='*.swift' --include='*.pbxproj' --include='*.plist' --include='*.xcconfig' --exclude-dir=.build --exclude-dir=DerivedData --exclude-dir=.git --exclude-dir=.swiftpm --exclude-dir=Pods --exclude-dir=node_modules --exclude-dir=.agents --exclude-dir=.claude -e @main -e "^[[:space:]]*Settings[[:space:]]*[{(]" -e MenuBarExtra -e LSUIElement -e NSApplicationDelegateAdaptor -e SettingsLink -e openSettings -e SidebarSettingsKit -e MACOSX_DEPLOYMENT_TARGET -e "[.]macOS[(]" -e swift-tools-version .`

If the line above was not replaced by search results (an agent other than Claude Code), run
that `grep` command yourself, once, from the project root. It is the only survey command needed.

| A match on | Means |
| --- | --- |
| `@main` | the app's entry: where the window object will usually live |
| `Settings {` at the start of a line | a `Settings` scene to replace |
| `MenuBarExtra`, `LSUIElement` | a menu bar app: the window opens from the menu |
| `NSApplicationDelegateAdaptor` | an app delegate, a good owner for the window |
| `SettingsLink`, `openSettings` | call sites that will not reach the new window |
| `SidebarSettingsKit` | already integrated: change it, do not add it again |
| `MACOSX_DEPLOYMENT_TARGET`, `.macOS(` | the deployment target: must be macOS 14 or later |
| `swift-tools-version` | a SwiftPM manifest |

Then open what the matches point at: the entry, the `Settings` scene's content, and every view
it shows. If the project has its own AGENTS.md, CLAUDE.md or contributing rules, they decide
naming, file layout and where state lives; this skill only suggests.

Stop and tell the user before changing anything when the deployment target is below macOS 14,
or the project builds with an Xcode older than 26 (the kit's manifest needs Swift 6.2).

## 2. Decide

Infer what you can; ask the user only what the code cannot tell you, in one message.

- **Style.** A tool, utility or developer app gets `.native`, the system sidebar untouched. A
  consumer app that sells itself (brand colors, onboarding, upgrades) gets `.branded`: icons on
  colored tiles, taller rows, larger text. Unsure: ask, describing each in one line.
- **Pages.** One page per existing tab or settings section, in the same order. Each page needs a
  title, an SF Symbol (with a tint for `.branded`, which colors its tile), and search keywords:
  the labels of the settings on it, so a search for "launch at login" finds "General".
- **Groups.** Many pages read better in groups: titled (`SettingsPageSection("Account", pages:)`)
  or set apart by space only (`SettingsPageSection(pages:)`, as System Settings does).
- **Owner.** An object created once for the app's life: the `App`'s initializer, the app
  delegate, or the app's own root object. Never a `View` body or a computed property: they run
  many times, and each run would build a new window with a new history.
- **Header and footer.** Only for UI the app already has that belongs beside the pages: an
  account row on top, a version line or upgrade button at the bottom.
- **Language.** The kit's four words (Back, Forward, Search, Settings…) ship in English and
  Simplified Chinese. An app in any other language, or whose text is written in one language
  without localization, passes its words through `configuration.strings`
  ([references/configuration.md](references/configuration.md)). Judge the language from the
  app's text and string catalogs, not from the Mac's language.

## 3. Add the dependency

SwiftPM manifest:

```swift
.package(url: "https://github.com/chengzi-io/SidebarSettingsKit.git", .upToNextMinor(from: "0.1.0")),
// in the app target's dependencies:
.product(name: "SidebarSettingsKit", package: "SidebarSettingsKit"),
```

While the kit is 0.x a minor release may break the API, hence `upToNextMinor`.

Xcode project: do not edit `project.pbxproj` by hand. Ask the user to choose File > Add Package
Dependencies…, paste `https://github.com/chengzi-io/SidebarSettingsKit.git`, pick "Up to Next
Minor Version" from 0.1.0, and add the `SidebarSettingsKit` library to the app target. If the
project is generated (XcodeGen, Tuist), add the package to the generator's spec instead.

## 4. Define the pages

```swift
import SidebarSettingsKit

enum SettingsPane: String, SettingsPage, CaseIterable {
    case general, appearance, advanced

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .advanced: "Advanced"
        }
    }

    var icon: SettingsIcon {
        switch self {
        case .general: .system("gearshape", tint: .gray)
        case .appearance: .system("paintpalette", tint: .blue)
        case .advanced: .system("wrench.and.screwdriver", tint: .orange)
        }
    }

    var searchKeywords: [String] {
        switch self {
        case .general: [String(localized: "Launch at login"), String(localized: "Updates")]
        case .appearance: [String(localized: "Theme"), String(localized: "Accent color")]
        case .advanced: [String(localized: "Logs")]
        }
    }
}
```

Pages known only at run time (plug-ins, pages behind a permission) can be a struct instead.
`LocalizedStringResource` is not `Hashable`, so such a struct implements `==` and
`hash(into:)` by its `id`, and computes `icon` rather than storing it (`SettingsIcon` is not
`Sendable`).

Move each tab's view into its page as it is. Delete what only the tabbed window needed: the
`TabView`, `.tabItem`, and fixed `.frame(width:height:)` sizes. A grouped `Form`
(`.formStyle(.grouped)`) gives pages System Settings' look; the kit scrolls every page itself.

## 5. Create the window once and open it

The smallest version, in the `App`:

```swift
@main
struct MyApp: App {
    @State private var model: AppModel
    private let settings: SidebarSettingsWindow<SettingsPane>

    init() {
        let model = AppModel()
        _model = State(initialValue: model)
        settings = SidebarSettingsWindow(pages: SettingsPane.allCases) { pane in
            SettingsPaneView(pane: pane)
                .environment(model)
        }
    }

    var body: some Scene {
        WindowGroup { ContentView().environment(model) }
            .commands { SidebarSettingsCommands(window: settings) }
    }
}
```

- Delete the `Settings` scene: `SidebarSettingsCommands` replaces its "Settings…" item and ⌘,.
  Keeping both gives two items.
- The scene's environment does not reach the window. Hand the pages their models in the
  `detail` closure, as above (`.environment(_:)` for `@Observable`, `.environmentObject(_:)` for
  `ObservableObject`). `@AppStorage` inside pages works unchanged.
- `SettingsLink` and `openSettings` do not open this window. Replace them with
  `settings.show()` or `settings.show(page: .advanced)`, or `OpenSidebarSettingsButton`.
- Menu bar app: put `OpenSidebarSettingsButton(window: settings)` in the `MenuBarExtra`'s menu.
  `show()` activates the app, so the window comes to the front even without a Dock icon. If a
  `Settings` scene was only a placeholder next to `MenuBarExtra`, delete it too.

Owners other than the `App`, deep links and migrating a `TabView` step by step:
[references/integration.md](references/integration.md).

## 6. Change only what differs

Every option defaults to System Settings' behavior. Change one only for a reason the user gave
or the app clearly has, such as long pages that need a resizable window. All options and when to
use them: [references/configuration.md](references/configuration.md). Styles, icons and tiles:
[references/styling.md](references/styling.md).

## Do not

- Do not store the selected page: no `@AppStorage`, `UserDefaults` or `SceneStorage` key for it,
  and no field for it in the app's settings model. The kit keeps the page and history while the
  app runs and starts on the first page at launch, like System Settings; that is deliberate.
- Do not wrap a page in another `ScrollView`, `NavigationStack` or `NavigationSplitView`.
- Do not size the window from a page; set `configuration.size`.
- Do not reach into the window with AppKit; if something cannot be configured, tell the user.

## Check the result

1. The app builds.
2. Run it: ⌘, (or the menu bar item) opens the window in front; every page shows; searching a
   keyword finds its page; back and forward work; closing and reopening keeps the page; quitting
   and relaunching starts on the first page.
3. The app menu has exactly one "Settings…" item.
4. A localized app declares its languages in the app bundle: `CFBundleLocalizations` in its
   Info.plist, or a `<language>.lproj` folder. The kit's words (Back, Forward, Search,
   Settings…) follow those languages, as AppKit's menus do, so an app with Chinese pages that
   declares only English shows them in English. Add the missing entry and tell the user.
