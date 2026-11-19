# Architecture

How the settings window is built, and why each part is what it is. For the public API, read the
doc comments in `Sources/SidebarSettingsKit/Public/`.

## Why an AppKit window

SwiftUI has no scene for this window.

| SwiftUI offers | Why it does not fit |
| --- | --- |
| `Settings` scene | keeps the preferences toolbar: no back and forward, no toolbar items of the app's own |
| `NavigationSplitView` | its sidebar collapses when the divider is dragged in, and nothing brings it back |

So `SidebarSettingsWindow` is a SwiftUI-shaped API in front of an `NSWindow`: an
`NSSplitViewController` with a non-collapsing sidebar item beside the detail, under an `NSToolbar`
the kit fills. No AppKit type appears in a public signature.

The window cannot be minimized, zoomed or made full screen, as Apple's guidelines ask of a
settings window: ⌘, brings it back, and it is sized for its pages. Its style mask leaves out
`.miniaturizable`; `.fullScreenNone` and a dimmed zoom button take back what AppKit gives a
resizable window; and `SettingsWindow.zoom(_:)` does nothing, so nothing that calls it zooms the
window. A resizable window still resizes from its edges.

The kit sets no appearance. The window follows the app's (`NSApp.appearance`), which follows the
Mac unless the app sets one. SwiftUI's `.preferredColorScheme` does not reach it, even from
inside a page.

## The object graph

```
SidebarSettingsWindow<Page>                            public, @MainActor class, created once
├── navigator: SettingsNavigator<Page>                 selection, history, searchText
├── sections: [SettingsPageSection<Page>]              the sidebar's groups
├── configuration                                      value type
└── controller: SettingsWindowController?              built by the first show()
    ├── window: SettingsWindow                         NSWindow subclass: ⌘[ ⌘] ⌘W
    │   ├── toolbar: NSToolbar                         delegate = the controller
    │   │   └── items: .sidebarTrackingSeparator, back, forward
    │   └── contentViewController: NSSplitViewController
    │       ├── sidebarItem: NSSplitViewItem(sidebarWithViewController:)
    │       │   └── NSHostingController<SidebarView>
    │       │       → NSSearchField (fixed) + system sidebar List + header + footer
    │       └── detailItem: NSSplitViewItem(viewController:)
    │           └── NSHostingController<DetailContainer>
    │               → the selected page, which scrolls itself
    └── scrollState: DetailScrollState                 written by the page, read for the separator
```

## Ownership and lifetimes

| Object | Owned by | Lives |
| --- | --- | --- |
| `SidebarSettingsWindow` | the app | as long as the app; create it once, never in a `body` |
| `SettingsNavigator` | the window object | the app: it survives closing the window, so the window reopens on its page |
| `SettingsWindowController` | the window object | from the first `show(page:)` until the window object dies |
| `SettingsWindow` | the controller | with the controller: `isReleasedWhenClosed = false`, so AppKit does not free it on close |
| `DetailScrollState` | the controller | with the controller, shared with the detail's SwiftUI views |

`SidebarSettingsWindow.init` captures `makeController`, but builds nothing: the first
`show(page:)` calls it, stores the controller, activates the app and shows the window. `close()`
closes the window and keeps the controller, so the next `show()` reopens the same one.

The controller stays free of `Page`: `SettingsWindowController.Navigation` holds closures for
`canGoBack`, `canGoForward`, `goBack`, `goForward` and `pageTitle`.

## The sidebar

`SidebarView` is a `VStack` with no spacing:

1. The search field, when `configuration.search` is `.enabled`: AppKit's `NSSearchField` through
   `NSViewRepresentable`, at `.controlSize(.large)` with 8 pt insets, as System Settings has it.
   `.searchable` cannot put a field above the list, which is why the kit uses AppKit here.
2. The list, which scrolls (below). The header is the list's
   first item and scrolls with the pages, as System Settings' account row does.
3. The footer, through `.safeAreaInset(edge: .bottom)`, so it stays at the bottom while the list
   scrolls above it and the list leaves room for it.

Search filtering is `visibleSections(_:search:searchText:)` in `Internal/SidebarSections.swift`:
with search on, each group keeps the pages whose `matches(searchText:)` is true, and a group left
with no pages is dropped. When no page matches, the list gives way to a small, light "No Results"
line under a magnifying glass (`NoSearchResults`); `ContentUnavailableView.search` sizes itself
for a whole window and cannot be made smaller. Only a
search can empty the list, because a window has at least one page. The matching itself belongs to `SettingsPage`, not to the configuration, because the
configuration is not generic over the page type.

## The sidebar list

The sidebar draws the pages with SwiftUI's `List` and `.listStyle(.sidebar)` (`SidebarList`), with
plain icons or tiled, so selection, arrow keys, type-to-select, VoiceOver's list navigation and the
selection's look on each macOS version are the system's. `configuration.icons` changes what a
row's icon slot holds, never the selection. The system list cannot draw another selection shape; rows the kit
drew itself to get a rounded one lost type-to-select, VoiceOver's list structure and the system's
selection look, so the kit has no such renderer.

A row is as tall as its content plus the list's padding, so the kit has no row height option: the
sidebar list ignores `defaultMinListRowHeight`, and a frame on the row's content adds the padding
on top of it. The list reserves an icon slot of 16, 20 or 24 points, from the user's Sidebar icon
size setting (`\.sidebarRowSize` in the row's environment), 6 points in from the selection's edge.
An icon, plain or on a tile, fills that slot, as System Settings' tiles do, so the rows keep the
system's height and the title starts where a plain row's does. A tile larger than the slot made a
taller row and crowded the title, so tiles have no size of their own. A plain icon takes its tint
through `listItemTint`, which the list turns white on the selected row; on a tile the tint is the
tile's color and the glyph is white.

A group is a `Section` without a header, set apart by space as System Settings' groups are. A
titled `Section` in a sidebar list becomes a group that folds when its heading is clicked, with
SwiftUI's own animation; keeping it open takes `.collapsible(false)`, which SwiftUI marks for
deprecation, so groups have no titles.

A bare icon takes its tint through `listItemTint`, the sidebar's own tint for a row's icon: the
list turns it white with the title on a selected row. A color set on the symbol with
`foregroundStyle` stays, and a blue icon vanished into the blue selection. On a tile, the tint
colors the tile and the symbol is white.

The list ignores the `nil` a command-click writes into its selection, so the current page stays.
It scrolls the selected page into view on appear and on every change. The scroll on appear waits
one turn of the main actor (`Task.yield()` in `.task`): run during the first layout, before the
rows have their heights, it stops short and clips a row below the fold.

## The line under the toolbar

AppKit's automatic separator (`titlebarSeparatorStyle = .automatic`) loses track once SwiftUI
swaps the detail's content: it keeps the line after the new page is shown from the top. So the
detail's scroll position drives it:

1. `DetailContainer` applies `ScrollTracking` around the page; `onScrollGeometryChange` there
   reaches the form, list or scroll view inside it. It adds no scroll view of its own: on macOS
   14 and 15 the toolbar takes its background from the scroll view right under it. A grouped form
   or a list gives it one that matches the page and changes it once the page scrolls; a plain
   SwiftUI `ScrollView` gives none, so the toolbar falls back to its own lighter material, whose
   edge shows like a line without any scrolling. The kit's own `ScrollView` around every page did
   exactly that, so pages now scroll themselves, as System Settings' do.
2. `ScrollTracking` reads `DetailScrollState` from the environment and, on macOS 15 and later,
   writes `isScrolled` from `onScrollGeometryChange`. It also resets it on appear: a new page
   starts at the top and its scroll view reports nothing until it moves. `DetailContainer` puts
   `.id(page)` on the content, so switching pages builds the new page from the top.
3. `SettingsWindowController.followSeparator()` reads `scrollState.isScrolled` inside
   `withObservationTracking` and re-enters itself on change, then sets
   `detailItem.titlebarSeparatorStyle` to `.line` or `.none`.

macOS 14 cannot report a scroll position to SwiftUI, so on 14 `.whenScrolled` shows the line
always. `.always` and `.never` behave the same on every version.

## Title and toolbar items

The window's title and the back and forward buttons follow the page through `FollowsNavigation`,
a modifier around the detail that watches the title and the history with `onChange` and sets the
title and validates the toolbar items in the SwiftUI update that draws the new page, so the title
changes in the same frame as the page. Set from a task after an observation fired, the old title
stayed over the new page for a frame. `.fixed` shows one title everywhere;
`.hidden` hides it with `titleVisibility = .hidden` while the window keeps a title for the Window
menu and VoiceOver.

The toolbar shows icons only: in an app, the taller toolbar that `.automatic` picks on macOS 15
shows "Back" and "Forward" under the arrows, which System Settings does not. A test process gets
icons only whatever the setting, so this is a manual check.

`window.title` is set after `contentViewController`, because `NSWindow(contentViewController:)`
leaves the title "Untitled" until something changes it.

The toolbar is an `NSToolbar` with the controller as delegate, not SwiftUI's toolbar bridging,
which once produced an unlocalized first title. Its items are `.sidebarTrackingSeparator`, back and
forward; each button takes its label and tooltip from `configuration.strings`, its image from
`chevron.backward` or `chevron.forward` (which point right and left in Arabic and Hebrew) with
the same accessibility description, and is marked
navigational so it draws as a toolbar control.

With the buttons off, AppKit alone sets the title 11 points from the sidebar, left of the page's
grouped form, which starts 20 points in. An empty navigational item takes the buttons' place:
navigational items come before the title, and the gap AppKit leaves after one lines the title up
with the page. macOS 26 puts toolbar items on glass, where an empty item has not been checked, so
there the toolbar stays as AppKit lays it out.

The window frame autosave name is set on the controller after `super.init(window:)`, because
`init(window:)` clears a name set on the window. A window that cannot be resized gets back only
its saved position.

## Keyboard shortcuts

| Shortcut | Does | Handled by |
| --- | --- | --- |
| ⌘, | opens the window | `SidebarSettingsCommands` through `OpenSidebarSettingsButton.keyboardShortcut(",")` |
| ⌘[ , ⌘] | back, forward | `SettingsWindow.performKeyEquivalent`, before the main menu, so it works in an app without a File or Go menu; wired only when `showsNavigationButtons` is on |
| ⌘W | closes the window | the same override, through `performClose(nil)` |
| ⌘F | focuses the search field | `FindShortcutSearchField.performKeyEquivalent`, in the sidebar's `NSSearchField`: it takes the key from anywhere in its window, as System Settings' field does |
| Esc | clears the search field | `NSSearchField`'s own behavior |
| ↑ , ↓ | moves the selection | the system `List` |
| ↓ in the search field | moves to the pages found | `SearchField`'s delegate catches the field editor's `moveDown:` and `SidebarView` focuses the list; when the search hides the page shown, the first page found opens |
| Tab | between the search field and the list | AppKit's key view loop, which the window recalculates (`autorecalculatesKeyViewLoop`): the split view left the list's next key view one that takes no focus, so Tab went nowhere |

Keyboard handling lives in the window and the search field, not in the SwiftUI views, because a
window takes key equivalents before the menu does and the kit must not depend on the app having
the usual menus.

The list takes the focus when the window opens, as System Settings' does, from a task on
`SidebarView` rather than on the list: a search that finds nothing replaces the list, and a list
that comes back when a letter is deleted would take the focus from the field mid-word. ↑ on the
first page found stays in the list, as in System Settings; Tab goes back to the field.

## Localization

`Sources/SidebarSettingsKit/Resources/<language>.lproj/Localizable.strings` hold the five strings
the kit owns, Back, Forward, Search, Settings… and No Results, in every language macOS has. The
manifest sets `defaultLocalization: "en"`.

The words are macOS's own for the same controls, read from the system's localization tables
(`plutil -convert json -o - <table>`, macOS 15), not translated by hand:

| Words | Table | Keys |
| --- | --- | --- |
| Back, Forward, Search | `/System/Applications/System Settings.app/Contents/Resources/Localizable.loctable` | `BACK_AXDESCRIPTION`, `FORWARD_AXDESCRIPTION`, `SEARCH_LABEL` |
| Settings… | `/System/Library/Frameworks/AppKit.framework/Resources/MenuCommands.loctable` | `Settings\U2026` |
| No Results | `/System/Library/Frameworks/SwiftUI.framework/Resources/Localizable.loctable` | `ContentUnavailableView_Search_Text` |

36 folders cover macOS's 41 languages. English (Australia, UK), French (Canada), Spanish (US) and
Chinese (Hong Kong) have the same five words as English, French, Spanish (Latin America) and
Chinese (Traditional), and Foundation falls back to those. The folders take Xcode's names (`nb`,
`pt-BR`, `pt-PT`, `zh-Hans`, `zh-Hant`) where the tables say `no`, `pt_BR` or `pt`, `pt_PT`,
`zh_CN` and `zh_TW`. A word the kit adds needs a source in those tables too.

They are `.strings` files, not a string catalog (`.xcstrings`): SwiftPM's command line
(`swift build`, `swift test`, `swift run`) copies a catalog into the bundle without compiling
it, so the translations would only exist in Xcode builds, and neither the tests nor the demo
could see them.

`SidebarSettingsConfiguration.Strings` builds each default with

```swift
let language = Bundle.module.preferredLocalizations.first ?? "en"
LocalizedStringResource(
    key, locale: Locale(identifier: language), bundle: .atURL(Bundle.module.bundleURL))
```

A resource created in the kit's module has to name the kit's bundle to resolve; the app's own
tables would be looked in otherwise. The locale picks the language the app runs in, as AppKit's
own words (the Window menu, the search field's Cancel) do: Foundation chooses among the
languages the app declares, and without a locale the resource would follow the system's
language, so an English-only app on a Chinese Mac would show Chinese back and forward beside an
English page. An app shows the kit's words in a language only when it declares that language
itself (`CFBundleLocalizations` or an `.lproj` in its bundle) and runs in it; otherwise they are in
the development language, English, and an app that wants other words passes them through
`configuration.strings`. The kit cannot tell the language of text an app writes without
localizing it, so it does not guess from the system's language.

Page titles, keywords and anything else user-visible come from the app, so the kit never writes
a literal user-visible string.

## Adjustments for macOS 26 and later

| Where | What | Why |
| --- | --- | --- |
| `SidebarView` root | `scrollEdgeEffectStyle(.soft, for: .all)` | rows fade under the toolbar as in System Settings |
| `DetailContainer` | `scrollContentBackground(.hidden)` | the form or list sits on the window's background on macOS 26 and later; on macOS 15 the same call leaves a band under the toolbar, so it applies from 26 on |
| Sidebar rows | no material anywhere | from 26 on the sidebar keeps the system's Liquid Glass; `configuration.icons` only changes the icons |

## Tests, fixtures and the demo

| Target | Path | What it holds |
| --- | --- | --- |
| `SidebarSettingsKit` | `Sources/SidebarSettingsKit/` | the product; `Public/` and `Internal/` |
| `SidebarSettingsFixtures` | `Tests/Fixtures/` | pages, sections, long and short content, header and footer views; in no product, so a dependent app never builds it |
| `SidebarSettingsKitTests` | `Tests/SidebarSettingsKitTests/` | logic tests, no window on screen |
| `SidebarSettingsKitWindowTests` | `Tests/SidebarSettingsKitWindowTests/` | tests that open real windows and drive them |

Both test targets import the kit with `@testable import`, which is how they reach the
`internal` controller, lists and search field.

The demo at `Examples/SidebarSettingsDemo/` is a separate package that depends on `../..`, and
the root package never references it. It compiles the same fixture files a second time as target
`DemoFixtures`, through the symlink `Sources/DemoFixtures → ../../../Tests/Fixtures`, so the demo
shows what the tests test. Fixture code therefore never names its module: the same files compile
as `SidebarSettingsFixtures` and as `DemoFixtures`.

`make test` runs both test targets, `make demo` runs the demo, `make ci` runs what CI runs.

## Public API rules

These come from `AGENTS.md` and apply to every public symbol:

- No AppKit type in a public signature; the window is SwiftUI-shaped from the outside.
- Every option has a default; the shortest use is `pages` plus `detail`.
- Every public symbol has a `///` doc comment.
- UI types are `@MainActor`. No `@unchecked Sendable`, no `nonisolated(unsafe)`.
- The kit stores nothing: no `UserDefaults`, no files. The one exception is AppKit's window frame
  autosave, which `configuration.autosaveName = nil` turns off.
- Semantic versioning; during 0.x a breaking change is allowed but is listed in
  `CHANGELOG.md`.
