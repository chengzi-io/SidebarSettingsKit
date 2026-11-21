# Roadmap

Planned work and the limits the kit has today. Nothing here is promised for a version.

## Planned

| Work | Why | Notes |
| --- | --- | --- |
| A tabbed settings window from the same pages | some apps want System Settings' older `TabView` layout without a second page model | a second window type over `[SettingsPage]` and the same detail closure |
| Row badges | unread counts and "new" markers beside a page's title | a `SettingsPage` property, drawn in the row beside the title |
| Hiding pages by permission at run time | a page behind a login or a feature flag | today: build the window without that page, or make the page explain what to do |
| Changing pages after creation | plug-ins that load after the window object exists | `sections` is fixed today; a setter would need the sidebar views to follow it |
| Following an in-app language switch | apps that change language without a relaunch | a locale the window applies to the sidebar, the title, the toolbar and the kit's words |

## Known limits

| Limit | Detail |
| --- | --- |
| macOS 14: the line under the toolbar always shows | System Settings shows it once the page scrolls; SwiftUI reports no scroll position before macOS 15 ([ARCHITECTURE.md](ARCHITECTURE.md#the-line-under-the-toolbar)) |
| No macOS 14 CI | GitHub retired the `macos-14` runner on 2026-11-02; macOS 14 is tested by hand |
| Configuration is fixed per window object | `size`, `resizing`, `sidebarWidth`, `search` and the rest are read when the window is built; create a new `SidebarSettingsWindow` to change them |
| A plain `ScrollView` page has a lighter toolbar on macOS 14 and 15 | AppKit matches the toolbar's background to a form's or a list's scroll view, not to a plain `ScrollView`'s; write pages as grouped forms |
| An in-app language switch reaches only the pages | the sidebar's titles, the window title and the kit's words keep the launch language until a relaunch; the pages follow when the app applies its locale inside `detail` |
| On macOS 26 the title without the buttons is AppKit's | with the buttons off, the kit lines the title up with the page on macOS 14 and 15 only; macOS 26 puts toolbar items on glass, where the empty item that does it has not been checked |
| No custom selection shape | the selection is the system sidebar's, plain or tiled; a kit-drawn one would lose type-to-select and VoiceOver's list navigation |
| No `SettingsLink` support | `SettingsLink` and `openSettings()` open the `Settings` scene, not this window; use `show(page:)` or `OpenSidebarSettingsButton` |
| Pages cannot be previewed in the window | preview a page's view on its own, fixed to a frame |
