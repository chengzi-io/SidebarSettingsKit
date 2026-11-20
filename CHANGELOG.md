# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html). While the version is 0.x, a
minor release may contain breaking changes; each one is listed here.

## [Unreleased]

The first release, 0.1.0.

### Added

- `SidebarSettingsWindow`: a settings window like System Settings, with a sidebar that never
  collapses, the selected page beside it and back and forward in the toolbar. Grouped
  (`sections:`) or flat (`pages:`) pages, optional header and footer, and an initializer per
  combination.
- `SettingsPage`: a page is a `Hashable` type with a `title`, an `icon`, optional
  `searchKeywords` and an overridable `matches(searchText:)`. An enum for a fixed set of pages, a
  struct for pages known at run time.
- `SettingsPageSection`: groups of pages set apart by space, as in System Settings; empty groups
  are dropped.
- `SettingsNavigator`: the selected page, a browser-like history (`open(_:)`, `goBack()`,
  `goForward()`, `reset()`) and the search text. Kept while the app runs, never written to disk.
- `SettingsIcon`: `.system(_:)`, `.image(_:)` and `.custom(_:)`, with tint, rendering mode, symbol
  variant and weight where they apply. Every icon fills the sidebar's icon slot, so it follows the
  user's Sidebar icon size setting and the rows keep the system's height.
- `SidebarSettingsConfiguration` with `size`, `resizing`, `autosaveName`, `sidebarWidth`,
  `toolbarStyle`, `showsNavigationButtons`, `title`, `search`, `navigationPersistence`, `strings`
  and `icons`: `.plain`, as the system sidebar draws them, or `.tiled`, in white on a square of
  the page's tint, as System Settings draws them (gray, or `.tiled(defaultColor:)`, without a
  tint). `toolbarStyle` defaults to `.automatic`; `.unifiedCompact` uses it on macOS 26, where a
  compact toolbar starts the sidebar below the title bar. The minimize and zoom buttons are
  dimmed and the window cannot go full screen, as Apple's guidelines ask of a settings window.
- The window follows the app's light or dark appearance (`NSApp.appearance`), which follows the
  Mac unless the app sets one.
- `SidebarSettingsCommands`: the app menu's "Settings…" item and ⌘,, in place of the `Settings`
  scene's; `OpenSidebarSettingsButton` opens the window from anywhere, optionally on a page.
- Pages scroll themselves, as System Settings' grouped forms do. The line under the toolbar shows
  on macOS 14, 15 and 27, and not on macOS 26, where the system ignores the separator style.
- Keyboard: arrow keys move the selection, ⌘[ and ⌘] go back and forward, ⌘F focuses the search
  field, ↓ in it moves to the pages found, Tab goes back to it, Esc clears it, ⌘W closes the
  window, ⌘, opens it. Typing a page's title selects its row. VoiceOver reads each row's title and
  selected state, and the back and forward labels.
- The kit's words (Back, Forward, Search, Settings…, and No Results for a search that finds no
  page) in every language macOS has, in macOS's own wording, shown in the language the app
  declares and runs in, English otherwise; each replaceable through
  `SidebarSettingsConfiguration.strings`. The back and forward arrows point the reading
  direction's way in Arabic and Hebrew.
- macOS 26 and later: the sidebar keeps Liquid Glass, its rows fade at the scroll edge, and the
  detail sits on the window's own background.
- Window position saved by AppKit under `autosaveName`; page and search kept for the session.
- Tests (unit and window targets with shared fixtures), a demo app, the screenshot script, CI on
  macos-15 and macos-26, and an agent skill in `skills/sidebar-settings-kit/`, installed with
  `npx skills add chengzi-io/SidebarSettingsKit`.
