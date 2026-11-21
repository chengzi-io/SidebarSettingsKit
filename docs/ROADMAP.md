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
| A page header that hides the title | a page led by a large header with its name, as System Settings' General, without the name again in the toolbar | tried and set aside: AppKit's automatic toolbar style turns compact while the title is hidden (52 pt to 38 on macOS 15), so the page jumped when the title came back; it needs a fixed toolbar style and checks on macOS 26 and 27 |

## Known limits

| Limit | Detail |
| --- | --- |
| macOS 14: the line under the toolbar always shows | System Settings shows it once the page scrolls; SwiftUI reports no scroll position before macOS 15 ([ARCHITECTURE.md](ARCHITECTURE.md#the-line-under-the-toolbar)) |
| Nothing runs on macOS 14 | the kit builds for 14, its deployment target, and keeps its `#available` branches small, but GitHub retired the `macos-14` runner on 2026-11-02 and nobody checks 14 by hand, so it is untested |
| Configuration is fixed per window object | `size`, `resizing`, `sidebarWidth`, `search` and the rest are read when the window is built. Create a new `SidebarSettingsWindow` to change them |
| A plain `ScrollView` page has a lighter toolbar on macOS 14 and 15 | AppKit matches the toolbar's background to a form's or a list's scroll view, not to a plain `ScrollView`'s. Write pages as grouped forms |
| macOS 27: the title without the buttons is unchecked | from macOS 26 on, the kit leaves the title where AppKit puts it; on 26 that is in line with the page's form, on 27 nobody has looked |
| An in-app language switch reaches only the pages | the sidebar's titles, the window title and the kit's words keep the launch language until a relaunch. The pages follow when the app applies its locale inside `detail` |
| No custom selection shape | the selection is the system sidebar's, plain or tiled; a kit-drawn one would lose type-to-select and VoiceOver's list navigation |
| No `SettingsLink` support | `SettingsLink` and `openSettings()` open the `Settings` scene, not this window; use `show(page:)` or `OpenSidebarSettingsButton` |
| Pages cannot be previewed in the window | preview a page's view on its own, fixed to a frame |
