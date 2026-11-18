# Roadmap

Planned work and the limits the kit has today. Nothing here is promised for a version.

## Planned

| Work | Why | Notes |
| --- | --- | --- |
| A tabbed settings window from the same pages | some apps want System Settings' older `TabView` layout without a second page model | a second window type over `[SettingsPage]` and the same detail closure |
| Row badges | unread counts and "new" markers beside a page's title | a `SettingsPage` property, drawn in the row beside the title |
| Hiding pages by permission at run time | a page behind a login or a feature flag | today: build the window without that page, or make the page explain what to do |
| Changing pages after creation | plug-ins that load after the window object exists | `sections` is fixed today; a setter would need the sidebar views to follow it |
| Per-page detail scrolling | one window with both a `Form` page and a `List` page | `detailScrolling` is one value for the whole window today |

## Known limits

| Limit | Detail |
| --- | --- |
| macOS 14 always shows the toolbar line | SwiftUI cannot report a scroll position before macOS 15, so `.whenScrolled` behaves as `.always` |
| No macOS 14 CI | GitHub retired the `macos-14` runner on 2026-11-02; macOS 14 is tested by hand |
| Configuration is fixed per window object | `size`, `resizing`, `sidebarWidth`, `search` and the rest are read when the window is built; create a new `SidebarSettingsWindow` to change them |
| `detailScrolling` applies to every page | turn it off only when every page of the window scrolls itself |
| No custom selection shape | the selection is the system sidebar's in every style; a kit-drawn one would lose type-to-select and VoiceOver's list navigation |
| No `SettingsLink` support | `SettingsLink` and `openSettings()` open the `Settings` scene, not this window; use `show(page:)` or `OpenSidebarSettingsButton` |
| Pages cannot be previewed in the window | preview a page's view on its own, fixed to a frame |
