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
- `SettingsPageSection`: groups of pages, titled as in Finder's sidebar or set apart by space as
  in System Settings; empty groups are dropped.
- `SettingsNavigator`: the selected page, a browser-like history (`open(_:)`, `goBack()`,
  `goForward()`, `reset()`) and the search text. Kept while the app runs, never written to disk.
- `SidebarSettingsStyle` with the presets `.native` and `.branded`, and the tokens `rowFont`,
  `iconSize` and `iconTile`. Both presets keep the system's sidebar list.
- `SettingsIcon`: `.system(_:)`, `.image(_:)` and `.custom(_:)`, with tint, rendering mode, symbol
  variant and weight where they apply; `SidebarSettingsStyle.IconTile` draws a colored square
  behind an icon.
- `SidebarSettingsConfiguration` with `size`, `resizing`, `autosaveName`, `sidebarWidth`,
  `toolbarStyle`, `showsNavigationButtons`, `title`, `toolbarSeparator`, `search`,
  `navigationPersistence`, `detailScrolling` and `strings`.
- `SidebarSettingsCommands`: the app menu's "Settings…" item and ⌘,, in place of the `Settings`
  scene's; `OpenSidebarSettingsButton` opens the window from anywhere, optionally on a page.
- `sidebarSettingsScrollTracking()`: keeps the line under the toolbar following a page that
  scrolls itself.
- Keyboard: arrow keys move the selection, ⌘[ and ⌘] go back and forward, ⌘F focuses the search
  field, Esc clears it, ⌘W closes the window, ⌘, opens it. Typing a page's title selects its row.
  VoiceOver reads each row's title and selected state, and the back and forward labels.
- The kit's words localized in English and Simplified Chinese, shown in the language the app
  declares and runs in, English otherwise; each replaceable through
  `SidebarSettingsConfiguration.strings`.
- macOS 26 and later: the sidebar keeps Liquid Glass, its rows fade at the scroll edge, and the detail sits
  on the window's own background.
- Window position saved by AppKit under `autosaveName`; page and search kept for the session.
- Tests (unit and window targets with shared fixtures), a demo app, the screenshot script, CI on
  macos-15 and macos-26, and an agent skill in `skills/sidebar-settings-kit/`, installed with
  `npx skills add chengzi-io/SidebarSettingsKit`.
