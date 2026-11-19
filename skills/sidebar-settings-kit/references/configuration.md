# Configuration

`SidebarSettingsConfiguration` holds the window's behavior. Its defaults are System Settings';
start from them and change a field only for a reason.

```swift
var configuration = SidebarSettingsConfiguration()
configuration.resizing = .resizable(min: CGSize(width: 640, height: 420))
let settings = SidebarSettingsWindow(pages: SettingsPane.allCases, configuration: configuration) { pane in
    SettingsPaneView(pane: pane)
}
```

The configuration is fixed when the window object is created. To try other values at run time,
create a new `SidebarSettingsWindow`, after closing the old one.

| Field | Default | Other values | Change it when |
| --- | --- | --- | --- |
| `size` | 715 × 600 | any `CGSize` | pages are much narrower or wider than System Settings' |
| `resizing` | `.fixed` | `.resizable(min:max:)`, either limit optional | pages hold long lists or text the user wants to see more of |
| `autosaveName` | `"SidebarSettingsWindow"` | any name; `nil` | `nil` if the app must write nothing at all to `UserDefaults` (this is AppKit's window position) |
| `sidebarWidth` | `.fixed(215)` | `.adjustable(min:ideal:max:)` | page titles are long, or translated into longer languages |
| `toolbarStyle` | `.automatic` | `.unifiedCompact`, `.unified` | the app wants a shorter toolbar (`.unifiedCompact`), or the taller one on every version (`.unified`) |
| `showsNavigationButtons` | `true` | `false` | very few pages, where history adds nothing; ⌘[ and ⌘] go with the buttons |
| `title` | `.followsPage` | `.fixed("Settings")`, `.hidden` | the app's style keeps one title, or none |
| `toolbarSeparator` | `.whenScrolled` | `.always`, `.never` | rarely; on macOS 14 `.whenScrolled` shows the line always |
| `search` | `.enabled` | `.disabled` | only a handful of pages |
| `navigationPersistence` | `.session` | `.resetOnShow` | the window should always open on the first page |
| `strings` | the kit's, in every macOS language | `.init(back:forward:searchPrompt:settingsMenuItem:noSearchResults:)` (the type is `SidebarSettingsConfiguration.Strings`) | the app's text is not localized, or its menu says "Preferences…" |
| `icons` | `.plain` | `.tiled`, `.tiled(defaultColor:)` | the app has a brand look; see [styling.md](styling.md) |

## Appearance

The window follows the app's appearance: the Mac's, unless the app sets `NSApp.appearance`.
SwiftUI's `.preferredColorScheme` does not reach it, even from inside a page. An app with its own
Light, Dark and System choice applies it to every window at once:

```swift
NSApp.appearance = switch choice {
case .system: nil
case .light: NSAppearance(named: .aqua)
case .dark: NSAppearance(named: .darkAqua)
}
```

## Strings

The kit localizes its five pieces of text (Back, Forward, Search, Settings…, No Results) in every
language macOS has, in macOS's own wording, and shows them in the language the app runs in: one
the app declares (`CFBundleLocalizations` or a `<language>.lproj` in the app bundle), as AppKit
does for its menus; an app that declares none gets English. For an app whose text is written in
one language without localization, or for other wording, pass your own words; leave out the ones
to keep:

```swift
// An app written in Japanese, not localized: the words show as written.
configuration.strings = .init(
    back: "戻る", forward: "進む", searchPrompt: "検索", settingsMenuItem: "設定…", noSearchResults: "結果なし")

// A localized app: keys its string catalog translates, so they follow the app's language.
// The catalog in the app target is in the main bundle, where a key is looked up by default.
configuration.strings = .init(
    searchPrompt: LocalizedStringResource("Find a setting"),
    settingsMenuItem: LocalizedStringResource("Preferences…")
)

// The catalog in a Swift package module is in the module's own bundle: name it, or the key
// is not found and its default value shows.
configuration.strings = .init(
    searchPrompt: LocalizedStringResource("Find a setting", bundle: .atURL(Bundle.module.bundleURL))
)
```

Add each key, in every language the app ships, to the catalog of the target whose code creates
the configuration.

## Initial page

The window opens on the first page. Pass `initialPage:` to the initializer to start elsewhere.
To open on a page on demand, call `settings.show(page:)`.

## Search

The search keeps pages whose title or `searchKeywords` contain the text, ignoring case,
diacritics and full- or half-width forms. To match differently, such as by synonyms or a
fuzzy score, implement `matches(searchText:)` on the page type:

```swift
func matches(searchText: String) -> Bool {
    let words = searchText.split(separator: " ").map(String.init)
    return words.allSatisfy { word in
        ([String(localized: title)] + searchKeywords).contains { $0.localizedStandardContains(word) }
    }
}
```

## Pages scroll themselves

The kit adds no scroll view around a page: a grouped `Form` or a `List` scrolls by itself, and
the line under the toolbar follows it. A page of other views that can be taller than the window
goes in a `ScrollView`; on macOS 14 and 15 the toolbar then keeps a lighter background of its own
above it, so prefer a grouped `Form` for settings.

```swift
// A settings page, as in System Settings.
Form {
    Section { Toggle("Show in menu bar", isOn: $showsInMenuBar) }
}
.formStyle(.grouped)

// A page that is not a form, with more than fits.
ScrollView {
    VStack(alignment: .leading) { /* ... */ }
        .padding()
}
```
