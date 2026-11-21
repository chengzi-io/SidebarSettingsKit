# Development

How to work on the kit day to day: the demo, screenshots, CI and releasing.

## Requirements

| | |
| --- | --- |
| macOS | 14 or later to run what you build (the deployment target); nothing runs on 14, neither CI nor a person |
| Xcode | 26.2, the version in `.xcode-version` |
| Swift | 6.2 (the manifest is `swift-tools-version: 6.2`) |
| Dependencies | none; the package and the demo build offline |

Warnings are errors: the Makefile passes `-Xswiftc -warnings-as-errors`, never `Package.swift`,
because a package that uses `unsafeFlags` cannot be depended on. Do not silence a warning; fix it.

## Make targets

| Command | What it does |
| --- | --- |
| `make help` | lists the targets |
| `make build` | builds the package |
| `make test` | runs both test targets; some open real windows briefly |
| `make demo` | runs the demo app |
| `make demo-build` | builds the demo app |
| `make screenshots` | captures the screenshot matrix into `screenshots/` |
| `make ci` | build, test, demo build, in that order: what CI runs |
| `make clean` | removes `.build` and the demo's build output |

One test: `swift test -Xswiftc -warnings-as-errors --filter <name>`.

## The demo

`Examples/SidebarSettingsDemo/` is a separate package that depends on the root package by path,
so it always runs the code you are editing. It is manual QA and the source of the screenshots;
the root package never references it.

```
make demo                 # or: cd Examples/SidebarSettingsDemo && swift run --build-system native SidebarSettingsDemo
```

The main window is the demo's control panel: a grouped form with a picker or toggle for the
sidebar's icons, the page set, the grouping, the header and footer, and every option of
`SidebarSettingsConfiguration`. **Open Settings** (also Return) applies them. The window keeps the
configuration it was built with, so applying a change closes it and builds the next one. The app
menu's **Settings…** item (⌘,) opens the window on screen. With no `--scenario`, the demo shows
the control panel alone.

The demo declares every language the kit has in its embedded Info.plist, so
`-AppleLanguages "(ja)"` after the flags below shows the kit's words in Japanese; the demo's own
text stays English.

The demo compiles the shared fixtures (`Tests/Fixtures/`) a second time as target `DemoFixtures`
through the symlink `Sources/DemoFixtures`, so its pages are the ones the tests use.

### Flags

| Flag | Values | What it does |
| --- | --- | --- |
| `--icons` | `plain`, `tiled` | `configuration.icons`; `plain` when absent |
| `--appearance` | `light`, `dark` | forces `NSApp.appearance`; the system's when absent |
| `--scenario` | `1` `2` `3` `4` `5` `6` `6b` `7` | opens a settings window set up for one check; none when absent |
| `--window-id-file` | a path | writes the settings window's number there once it is on screen, for `screencapture -l` |

An unknown flag, or a flag without its value, prints the usage to stderr and exits with 2. A
single-dash argument is passed through with its value, as a launch-only default: the demo steps
over `-AppleLanguages "(zh-Hans)"` and the system reads it, without writing anything to the app's
persistent defaults. `-NSTableViewDefaultSizeMode 1` (small), `2` (medium) or `3` (large) works
the same way for the Sidebar icon size setting.

### Scenarios

| Scenario | What it shows |
| --- | --- |
| `1` | Three pages, the window on the short page, at the default 715 × 600 |
| `2` | A long grouped form opened at its end, scrolled under the toolbar |
| `3` | The 40+ page set, opened on its last page with the sidebar scrolled to it |
| `4` | The pages in three groups, set apart by space |
| `5` | An account header and the tall login area as the footer |
| `6` | A search that finds pages |
| `6b` | A search that finds nothing |
| `7` | A page with a 60-character title, and the kit's own words in Simplified Chinese (the screenshot script forces the language) |

`scripts/screenshots.sh` runs every scenario in `1 2 3 4 5 6 6b 7`. The scenario a screenshot
shows is in its file name.

## Local screenshots

```
make screenshots                        # all scenarios, both kinds of icons, both appearances
scripts/screenshots.sh OUT_DIR [scenario ...]
```

One PNG per kind of icons, appearance and scenario, named
`macos-<major>-<icons>-<appearance>-scenario-<n>.png` in the output directory, for example
`macos-26-tiled-light-scenario-5.png`. The script builds the demo in release, runs it once per
combination, waits for the window number, and copies the window with `screencapture -o -l`.
It builds with `--build-system native`, as `make demo` does: Swift 6.4's default build system
links the executable as if built with the macOS 14 SDK, and macOS 27 then draws the demo in its
look from before macOS 26, gray and without glass.
Scenario 7 is launched with `-AppleLanguages "(zh-Hans)"`, so its screenshot shows the Chinese
words.

The terminal needs **Screen Recording** permission (System Settings > Privacy & Security >
Screen Recording). Without it, `screencapture` returns a picture of the desktop instead of the
window, and the script still reports `ok`.

Local screenshots are for debugging and are never committed: `screenshots/` is gitignored, and
the README images come from the CI artifacts only.

## CI

Two workflows, each running on `macos-15` and `macos-26`; screenshots also run on `xcode-27`.
From Xcode 27 on, GitHub names a macOS image after its Xcode: `xcode-27` runs macOS 27 with only
Xcode 27, so that job uses the image's Xcode instead of `.xcode-version`. `make ci` does not run
there (see [TESTING.md](TESTING.md), Environment).

| Workflow | Trigger | What it does |
| --- | --- | --- |
| `.github/workflows/ci.yml` | pull requests, pushes to `main` | selects the Xcode in `.xcode-version`, caches `.build`, runs `make ci` |
| `.github/workflows/screenshots.yml` | pull requests, manual dispatch | selects the same Xcode, turns off Reduce Transparency and Reduce Motion, sets the default wallpaper, runs `scripts/screenshots.sh screenshots`, uploads the PNGs |

GitHub's macOS images turn on Reduce Transparency and Reduce Motion; a Mac has them off. With
Reduce Transparency on, macOS 26 and 27 draw no glass, and their System Settings shows a line
under the toolbar even at the top of a page, so the screenshot workflow turns both off first.

The images also set a solid black wallpaper. A window takes a tint from the wallpaper behind it,
so over black the sidebar and the page came out a flat, darker gray than on a Mac: on macOS 15
the page was 238 gray where a Mac with its default wallpaper shows 244. The workflow sets the
wallpaper that `/System/Library/CoreServices/DefaultDesktop.heic` links to, the default of the
macOS that runs, before it captures.

The runners' only display is 1024 × 768 at 1x, so a screenshot has one pixel per point: the
default window comes out 715 × 600 pixels, where a Retina Mac gives 1430 × 1200. A 2x virtual
display was tried: CoreGraphics creates it on the runners, but gives it no display mode, so the
README shows the 1x images at their own size rather than shrunk.

The screenshot artifacts are named `screenshots-<runner>` (`screenshots-macos-15`,
`screenshots-macos-26`, `screenshots-xcode-27`) and are uploaded even when capture fails, so a
partial matrix can be inspected:

```
gh run download --name screenshots-macos-26 --dir shots
```

GitHub retired the `macos-14` runner on 2026-11-02, and nobody runs macOS 14 by hand either, so
nothing runs on 14. The kit builds for macOS 14, its deployment target, and keeps its `#available`
branches for 14 small and obvious; the limits that follow from that are in
[ROADMAP.md](ROADMAP.md).

## Bumping Xcode

`.xcode-version` is the one place the version is written: both workflows read it, and the job
fails with an error naming the version if the runner does not have it. To move to a new Xcode,
edit that file, check that both `macos-15` and `macos-26` runners have the app installed, and
open a pull request so CI proves it.

## Releasing

1. Move `## [Unreleased]` in `CHANGELOG.md` to the version and date, and leave a fresh
   `## [Unreleased]` above it.
2. If the minor version changed, update the SwiftPM snippets that name it: the one in
   `README.md` and the one in `skills/sidebar-settings-kit/SKILL.md` (`.upToNextMinor(from:)`).
3. Run the checks in [MANUAL-QA.md](MANUAL-QA.md) on each macOS version you have.
4. Tag `X.Y.Z` (no `v`) and push the tag.

Tagging, pushing and releasing need the maintainer's go-ahead: they are outward-facing and
nothing in CI does them for you.

## Docs

How the window is built: [ARCHITECTURE.md](ARCHITECTURE.md). The test targets, fixtures and the
false-pass rule: [TESTING.md](TESTING.md).

Docs are written in English. The Chinese copies (`README.zh-Hans.md`, `docs/zh/`) are regenerated
from the English after it changes; never edit them by hand, and do not create one for a doc that
has none yet.
