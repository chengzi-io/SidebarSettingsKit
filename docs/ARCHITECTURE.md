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

## The object graph

```
SidebarSettingsWindow<Page>                            public, @MainActor class, created once
├── navigator: SettingsNavigator<Page>                 selection, history, searchText
├── sections: [SettingsPageSection<Page>]              the sidebar's groups
├── configuration, style                               value types
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
    │               → the selected page, in a ScrollView when detailScrolling is on
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
with no pages is dropped with its title. When no page matches, the list gives way to the system's
`ContentUnavailableView.search`; only a search can empty it, because a window has at least one
page. The matching itself belongs to `SettingsPage`, not to the configuration, because the
configuration is not generic over the page type.

## The sidebar list

Both presets draw the pages with SwiftUI's `List` and `.listStyle(.sidebar)` (`SidebarList`), so
selection, arrow keys, type-to-select, VoiceOver's list navigation and the selection's look on
each macOS version are the system's. A style changes what a row holds (icon, tile, font) and its
height, never the selection. The system list cannot draw another selection shape; rows the kit
drew itself to get a rounded one lost type-to-select, VoiceOver's list structure and the system's
selection look, so the kit has no such renderer.

A row is as tall as its content plus the list's padding, so a style has no row height token: the
sidebar list ignores `defaultMinListRowHeight`, and a frame on the row's content adds the padding
on top of it. A larger icon tile makes a taller row.

The list ignores the `nil` a command-click writes into its selection, so the current page stays.
It scrolls the selected page into view on appear and on every change. The scroll on appear waits
one turn of the main actor (`Task.yield()` in `.task`): run during the first layout, before the
rows have their heights, it stops short and clips a row below the fold.

## The line under the toolbar

AppKit's automatic separator (`titlebarSeparatorStyle = .automatic`) loses track once SwiftUI
swaps the detail's content: it keeps the line after the new page is shown from the top. So the
detail's scroll position drives it:

1. `DetailContainer` puts each page in a `ScrollView` (when `configuration.detailScrolling` is
   on) and applies `sidebarSettingsScrollTracking()`.
2. That modifier reads `DetailScrollState` from the environment and, on macOS 15 and later,
   writes `isScrolled` from `onScrollGeometryChange`. It also resets it on appear: a new page
   starts at the top and its scroll view reports nothing until it moves. `DetailContainer` puts
   `.id(page)` on the content, so switching pages builds the new page from the top.
3. `SettingsWindowController.followSeparator()` reads `scrollState.isScrolled` inside
   `withObservationTracking` and re-enters itself on change, then sets
   `detailItem.titlebarSeparatorStyle` to `.line` or `.none`. A page that scrolls itself (with
   `detailScrolling` off) applies the same modifier to its own scrolling view.

macOS 14 cannot report a scroll position to SwiftUI, so on 14 `.whenScrolled` shows the line
always. `.always` and `.never` behave the same on every version.

## Title and toolbar items

The window's title follows the page through `followTitle()`, which reads the title inside
`withObservationTracking` and re-enters on change; it also validates the visible toolbar items, so
back and forward enable and disable with the history. `.fixed` shows one title everywhere;
`.hidden` hides it with `titleVisibility = .hidden` while the window keeps a title for the Window
menu and VoiceOver.

`window.title` is set after `contentViewController`, because `NSWindow(contentViewController:)`
leaves the title "Untitled" until something changes it.

The toolbar is an `NSToolbar` with the controller as delegate, not SwiftUI's toolbar bridging,
which once produced an unlocalized first title. Its items are `.sidebarTrackingSeparator`, back and
forward; each button takes its label and tooltip from `configuration.strings`, its image from
`chevron.left` or `chevron.right` with the same accessibility description, and is marked
navigational so it draws as a toolbar control.

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

Keyboard handling lives in the window and the search field, not in the SwiftUI views, because a
window takes key equivalents before the menu does and the kit must not depend on the app having
the usual menus.

## Localization

`Sources/SidebarSettingsKit/Resources/en.lproj/Localizable.strings` and
`zh-Hans.lproj/Localizable.strings` hold the four strings the kit owns: Back, Forward, Search
and Settings…. The manifest sets `defaultLocalization: "en"`.

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
English page. An app shows the kit's Chinese only when it declares Simplified Chinese itself
(`CFBundleLocalizations` or a `zh-Hans.lproj` in its bundle); every other language falls back to
the development language, English, and an app in such a language passes its own words through
`configuration.strings`. The kit cannot tell the language of text an app writes without
localizing it, so it does not guess from the system's language.

Page titles, keywords and anything else user-visible come from the app, so the kit never writes
a literal user-visible string.

## Adjustments for macOS 26 and later

| Where | What | Why |
| --- | --- | --- |
| `SidebarView` root | `scrollEdgeEffectStyle(.soft, for: .all)` | rows fade under the toolbar as in System Settings |
| `DetailContainer` | `scrollContentBackground(.hidden)` | the form or list sits on the window's background on macOS 26 and later; on macOS 15 the same call leaves a band under the toolbar, so it applies from 26 on |
| `SidebarSettingsStyle` | no material anywhere | from 26 on the sidebar keeps the system's Liquid Glass; a preset only changes rows and icons |

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
