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
| `toolbarStyle` | `.unifiedCompact` | `.unified`, `.automatic` | the app wants the taller toolbar of its main windows |
| `showsNavigationButtons` | `true` | `false` | very few pages, where history adds nothing; ⌘[ and ⌘] go with the buttons |
| `title` | `.followsPage` | `.fixed("Settings")`, `.hidden` | the app's style keeps one title, or none |
| `toolbarSeparator` | `.whenScrolled` | `.always`, `.never` | rarely; on macOS 14 `.whenScrolled` shows the line always |
| `search` | `.enabled` | `.disabled` | only a handful of pages |
| `navigationPersistence` | `.session` | `.resetOnShow` | the window should always open on the first page |
| `detailScrolling` | `true` | `false` | a page scrolls by itself, such as a `List` (see below) |
| `strings` | the kit's (English, Simplified Chinese) | `Strings(back:forward:searchPrompt:settingsMenuItem:)` | the app's language is not English or Simplified Chinese, its text is not localized, or its menu says "Preferences…" |

## Strings

The kit localizes its four words in English and Simplified Chinese, and shows them in the
language the app runs in: one the app declares (`CFBundleLocalizations` or a `<language>.lproj`
in the app bundle), as AppKit does for its menus; any other language gets English. For another
language, for an app whose text is written in one language without localization, or for other
wording, pass your own words; leave out the ones to keep:

```swift
// An app written in Japanese, not localized: the words show as written.
configuration.strings = .init(back: "戻る", forward: "進む", searchPrompt: "検索", settingsMenuItem: "設定…")

// A localized app: keys its string catalog translates, so they follow the app's language.
configuration.strings = .init(
    searchPrompt: LocalizedStringResource("Find a setting"),
    settingsMenuItem: LocalizedStringResource("Preferences…")
)
```

Add each key to the app's string catalog in every language it ships.

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

## Pages that scroll by themselves

With `detailScrolling` on, the kit puts each page in a `ScrollView`. A grouped `Form` sizes to
its content there and works as it is. A `List`, a `Table`, or a page with its own `ScrollView`
does not belong inside another scroll view. For those, turn `detailScrolling` off. It applies
to every page, so each page then scrolls itself; mark each page's scrolling view so the line
under the toolbar still follows it:

```swift
configuration.detailScrolling = false

// in each page:
ScrollView {
    VStack(alignment: .leading) { /* ... */ }
}
.sidebarSettingsScrollTracking()

List(items) { item in Text(item.name) }
    .sidebarSettingsScrollTracking()
```
