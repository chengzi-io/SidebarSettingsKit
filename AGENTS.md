# AGENTS.md

SidebarSettingsKit is a public Swift package that gives any macOS SwiftUI app a settings window
laid out like System Settings: a fixed sidebar of pages with a search field, the selected page
beside it, back and forward in the toolbar. SwiftUI cannot build that window on its own, so the
kit bridges to AppKit internally and exposes only SwiftUI-shaped API. This file holds what every
task needs; the docs below hold the rest.

## Done means

| Command | When | Takes |
| --- | --- | --- |
| `make test` | after every change: unit and window tests (opens real windows briefly) | under a minute |
| `make ci` | before calling a task done: build, test, demo build, same as CI | minutes |
| `make demo` | to try the kit by hand in the example app | a minute |
| `make screenshots` | to capture the screenshot matrix locally (needs Screen Recording permission) | minutes |

CI (`.github/workflows/ci.yml`) runs `make ci` on macos-15 and macos-26;
`.github/workflows/screenshots.yml` uploads screenshots per runner, xcode-27 (macOS 27) included.
`make ci` skips macOS 27: a Tab sent in a test process does not leave the sidebar list there
(`docs/TESTING.md`). GitHub retired the macos-14 runner on 2026-11-02, so macOS 14 has no CI:
keep `#available` branches for 14 small and obvious.

## Layout

| Path | What | Rule |
| --- | --- | --- |
| `Package.swift` | one product, `SidebarSettingsKit`; no dependencies | never add a dependency or a second product |
| `Sources/SidebarSettingsKit/Public/` | every public symbol | no AppKit type in a public signature |
| `Sources/SidebarSettingsKit/Internal/` | AppKit window controller, sidebar, search field, detail container | `internal`; tests reach it with `@testable import` |
| `Sources/SidebarSettingsKit/Resources/<lang>.lproj/Localizable.strings` | every user-visible string the kit owns, in every macOS language | no literal user-visible text in Sources; words are macOS's own, never translated by hand (`docs/ARCHITECTURE.md`, Localization); `.strings`, not `.xcstrings`: SwiftPM's command line copies a string catalog without compiling it, so `swift build`/`swift run` would show English only |
| `Tests/Fixtures/` | shared fixtures, target `SidebarSettingsFixtures` (in no product) | the demo compiles the same files through a symlink; never name the module in fixture code |
| `Tests/SidebarSettingsKitTests/`, `Tests/SidebarSettingsKitWindowTests/` | Swift Testing logic tests (no window) and window tests (real windows, one at a time) | |
| `Examples/SidebarSettingsDemo/` | separate package depending on `../..`; manual QA and screenshots | the root package never references it |
| `skills/sidebar-settings-kit/` | agent skill that integrates the kit into any app | |
| `scripts/screenshots.sh` | screenshot loop used by `make screenshots` and the workflow | |

## Toolchain

Swift 6.2, Xcode 26.2 (`.xcode-version`, read by both workflows), `swift-tools-version: 6.2`,
macOS 14 deployment target, Swift 6 language mode with strict concurrency. Warnings are errors
through `-Xswiftc -warnings-as-errors` in the Makefile, never through `unsafeFlags` in
`Package.swift` (packages that use `unsafeFlags` cannot be depended on).

## API rules

- Public API: no AppKit types, every option has a default, the shortest use is `pages` + `detail`.
- Every public symbol has a `///` doc comment.
- UI types are `@MainActor`. Never write `@unchecked Sendable` or `nonisolated(unsafe)`.
- The kit stores nothing: no `UserDefaults`, no files. The one exception is AppKit's window frame
  autosave, which `configuration.autosaveName = nil` turns off.
- Semantic versioning; during 0.x a breaking change is allowed but goes in `CHANGELOG.md`.

## Decisions that are easy to undo by accident

- The sidebar never collapses and has no collapse option. Groups have no titles: a titled
  `Section` in a sidebar list folds with SwiftUI's own animation, and keeping it open needs
  `.collapsible(false)`, which SwiftUI marks for deprecation.
- A bare icon takes its tint through `listItemTint`, never `foregroundStyle`: the list turns it
  white on the selected row, and a blue icon on the blue selection vanished.
- The window's title and the back and forward buttons are set from the SwiftUI update that draws
  the page (`FollowsNavigation`); set later, from an observation, the old title stayed for a frame.
- The search field is fixed above the list; the header is the list's first item and scrolls with
  it; the footer stays at the bottom (`safeAreaInset`).
- The list takes the focus on open from `SidebarView`'s task, not the list's: the list comes back
  after a search that found nothing, and its own task took the focus from the field mid-word.
- The sidebar is SwiftUI's `List` with `.listStyle(.sidebar)`, plain or tiled: native selection,
  keyboard, type-to-select and VoiceOver. `configuration.icons` changes a row's icon, never the
  selection. Kit-drawn rows (for a rounded selection) were tried and dropped: they lost those.
- The line under the toolbar is `titlebarSeparatorStyle = .line` on the detail item, set once:
  macOS 14 and 15 show it always, as System Settings does there; left `.automatic`, AppKit lost
  track when SwiftUI swapped the page. macOS 26 and later ignore it; 26 shows no line (System
  Settings draws one through a private view), a known limit the kit does not draw around.
- `ToolbarStyle.unifiedCompact` becomes `.automatic` on macOS 26 only: there a compact toolbar
  starts the sidebar below the title bar. `sidebarRunsUnderTheToolbar` catches it on macos-26.
- The window adds no scroll view around a page; each page scrolls itself. On macOS 14 and 15 the
  toolbar takes its background from the scroll view under it: a form or list matches the page,
  a plain `ScrollView` gives a lighter bar whose edge shows without scrolling.
- Icons and tiles fill the sidebar's icon slot (16, 20 or 24 pt, from `sidebarRowSize`), so rows
  keep the system's height and follow the user's Sidebar icon size setting. Hence no size, font
  or row height option: a tile larger than the slot made a taller row and crowded the title.
- Custom search matching is `SettingsPage.matches(searchText:)`, not a configuration closure:
  the configuration is not generic over the page type.
- Navigation lives in `SettingsNavigator`, owned by `SidebarSettingsWindow`: it survives closing
  the window and dies with the app.

## Never

- Don't add a dependency, a second library product, or demo code to the root package.
- Don't delete, loosen or skip a test to make it pass; fix the code. A scroll test first asserts
  that the content is taller than the visible area, or it passes without scrolling.
- Don't silence a warning.
- Don't commit screenshots from local runs; README images come from CI artifacts only.
- Don't push, tag or release without the user's go-ahead.

## Docs

| File | Covers | Reader |
| --- | --- | --- |
| `README.md` | what the kit is, quick start, options at a glance | users |
| `docs/ARCHITECTURE.md` | how the window is built and why | contributors, agents when needed |
| `docs/DEVELOPMENT.md` | daily loop, demo, local screenshots, CI, releasing | contributors |
| `docs/TESTING.md` | fixtures, window tests, the false-pass rule | contributors, agents writing tests |
| `docs/MANUAL-QA.md` | checks a person makes before a release | maintainers |
| `docs/ROADMAP.md` | planned work and known limits | everyone |
| `CHANGELOG.md` | changes per version | users |

Docs are written in English; the Chinese copies (`README.zh-Hans.md`, `docs/zh/`) are
regenerated from the English after it changes. Do not edit the copies by hand.

## Commits

Conventional Commits (`feat:`, `fix:`, `test:`, `docs:`, `ci:`, `chore:`), imperative summary
under 50 characters, one concern per commit.
