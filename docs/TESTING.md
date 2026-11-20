# Testing

Swift Testing, two targets: logic tests that never open a window, and window tests that drive real
ones. `make test` runs both.

## Targets

| Target | Path | Windows | What belongs there |
| --- | --- | --- | --- |
| `SidebarSettingsKitTests` | `Tests/SidebarSettingsKitTests/` | none | navigation history, search matching, sidebar groups, configuration defaults, kit strings, the window's preconditions (each in a child process) |
| `SidebarSettingsKitWindowTests` | `Tests/SidebarSettingsKitWindowTests/` | real, one at a time | frame and resizing, toolbar and title, the line under the toolbar, header and footer, sidebar rows and scrolling, keyboard, lifecycle, autosave, memory |

Both import the kit with `@testable import`, to reach its internal types. If a behavior can be
checked on values, it goes in the logic target: no window, no wait, no flake.

| Command | Runs |
| --- | --- |
| `make test` | both targets, with `-Xswiftc -warnings-as-errors` |
| `swift test --filter NavigatorTests` | one suite, by its type name |
| `swift test --filter AutosaveTests` | one window suite, nested in `WindowTestSuite` |

A suite's display name (`@Suite("Navigation history")`) is for the test log; `--filter` matches the
type name.

## Fixtures

`Tests/Fixtures/` is target `SidebarSettingsFixtures`, in no product, so an app depending on the
kit never builds it. The demo compiles the same files a second time as `DemoFixtures` through the
symlink `Examples/SidebarSettingsDemo/Sources/DemoFixtures → ../../../Tests/Fixtures`, which is why
fixture code never names its module: no `import SidebarSettingsFixtures`, no qualified symbols.

| File | Provides |
| --- | --- |
| `FixturePage.swift` | `FixturePage` (a struct page, equal by `id`), `FixtureIconDescription`, `FixtureTint`, `FixtureRenderingMode`, `FixtureSymbolWeight` |
| `FixturePages.swift` | `three` (`general`, `appearance` long, `advanced`), `many` (40 pages), `longText` with `longEnglishTitle`, `chineseTitle`, `mixedTitle`, `longKeyword`, `widthInsensitiveKeywords` |
| `FixtureSections.swift` | `ungrouped`, `grouped`, `withEmptySection` |
| `FixtureIconPages.swift` | one page per `SettingsIcon` form, and `all` |
| `DetailViews.swift` | `LongContentView` (`minimumHeight` 1800), `ShortContentView` (`maximumHeight` 300), `FixtureDetail(page:)`, which puts one of them in its own `ScrollView`, as every page scrolls itself |
| `ChromeViews.swift` | `FixtureHeader`, `FixtureFooter` (`height` 28), `TallFooter` (`height` 80) |

Add a page set or a view to a fixture file, not to a test, when a second suite will want it too.

## Window tests

| Piece | Where | What it does |
| --- | --- | --- |
| `WindowTestSuite` | `Support/WindowTestSupport.swift` | the one `@Suite(.serialized)` root; each area is a `@Suite(.serialized) @MainActor` struct in an `extension WindowTestSuite` |
| `fixtureWindow` | support | builds, without showing, a window of `FixtureDetail` pages |
| `withWindow` | support | opens a window, waits for it, and closes it in a `defer`, also when the body throws |
| `WindowUnderTest` | support | the shown window and the parts the tests read |

The root is serial because the tests share one app process: first responder, `NSApp.windows`,
`UserDefaults`. Swift Testing serializes a suite's child suites too, so a new area needs its own
nested suite, not a second root.

`withWindow` has two forms: one shows a `fixtureWindow` built from `pages:`, `initialPage:` and
`configuration:`; the other shows a `SidebarSettingsWindow` the test built, for groups, a header, a
footer or a detail of its own. Both take `page:` to open on. `.windowTest.drawing(.tiled)` is the
test configuration with tiled icons.

`WindowUnderTest` exposes `settings`, `controller`, `window`, and `sidebarView`, `detailView`,
`separator`, `toolbarItem(_:)`, `detailScrollView()`, `sidebarScrollView()`, `sidebarTable()`,
`sidebarPageRowCount()`, `sidebarHeadingRowCount()`, `searchField()`. Its `attach(_:)` waits for the
window to be on screen and for the split view to lay out both columns; call it directly only for a
window you show yourself.

### Waiting

| Helper | Returns | Use for |
| --- | --- | --- |
| `WindowTest.wait(for:timeout:_:)` | throws | a condition that must hold; throws `WindowTestFailure` naming what it waited for |
| `WindowTest.poll(timeout:_:)` | `Bool` | the same, without throwing, for a body that must not throw |
| `WindowTest.settle(_:)` | nothing | an effect with no state to poll, such as a close |
| `WindowTest.settled(_:timeout:)` | the steady value | a value SwiftUI moves over several frames, such as a scroll offset |
| `require(_:_:)` | the value or throws | unwrapping a view, a table, a frame, with a message |

`WindowTest.timeout` is 5 s and `WindowTest.step` is 20 ms. Every wait is `async` for a reason: the
kit focuses the list from a SwiftUI task, and a synchronous body that blocks the main thread in
`RunLoop.main.run(until:)` starves tasks and the main queue both (checked on macOS 15.7), so the
test reads stale state. Never replace a wait with a run loop.

### Reading views

| Helper | Gives |
| --- | --- |
| `allViews(in:)` | `view` and every view below it, depth first |
| `frameInWindow(_:)` | a view's frame in window coordinates |
| `firstScrollView(in:)` | the first `NSScrollView` below a view: SwiftUI's `ScrollView`, or a `List`'s |
| `scrollOffsetFromTop(_:)` | how far a scroll view's content moved down from the top |
| `scroll(_:toOffsetFromTop:)` | moves it there and publishes the move to SwiftUI |
| `requireScrollable(_:atLeast:)` | fails when the content is not taller than the space it is shown in |

`NSEvent` goes in two ways: `commandKey(_:keyCode:in:)` builds a ⌘ press to hand to
`window.performKeyEquivalent(with:)`, and `typeKeys(_:in:)` sends plain key presses to the window's
first responder, stamping each with the current time because the list's type-to-select joins presses
by timestamp.

### Probes

A header or a footer is a SwiftUI view with no AppKit handle. `ViewAnchor` holds the `NSView` SwiftUI
built for it, `probed(_:_:)` puts a 1 pt probe at its top-left corner in an `overlay`, so it takes no
room, and `ViewAnchor.isShown` / `ViewAnchor.frameInWindow` answer whether the kit drew it and where
it sits.

### Defaults

`defaultsKeys()` snapshots `UserDefaults.standard`; `WindowTest.frameDefaultsPrefix` is the
`"NSWindow Frame "` prefix AppKit saves a window's frame under, the one key the kit may leave behind.
`SidebarSettingsConfiguration.windowTest` is the configuration the tests use: `autosaveName` is
`nil`, so a test that is not about the frame writes nothing. AppKit writes
`NSVisualBidiSelectionEnabled` itself the first time the process builds a text view; it is the one
key outside that rule, allowed by name in `AutosaveTests`.

## The false-pass rule

| Rule | How it looks |
| --- | --- |
| A scroll test asserts it can scroll before it scrolls | `try requireScrollable(detail, atLeast: LongContentView.minimumHeight)`, or content taller than the visible area by a margin |
| A test for a fix is seen failing without the fix | revert the fix once, watch the new test fail, restore it |
| No `withKnownIssue` in the suite | the issue is fixed or the test is deleted; a skipped assertion is not a test |

A scroll test whose content fits passes without ever scrolling, which is how a scroll test for a new
page starting at its top, or for the sidebar scrolling to the selection, goes green.
`requireScrollable`, which the sidebar's taller-than-shown check also calls, makes that fail loudly.

## Environment

| Fact | Consequence |
| --- | --- |
| No macOS 14 runner since 2026-11-02 | a macOS 14 `#available` branch asserts the fallback |
| Stage Manager narrows the visible screen, and AppKit moves a restored frame into the visible area | a test that places a window puts it well inside `NSScreen.main.visibleFrame` |
| Window tests read views, state and a row's own drawing (`cacheDisplay`), never the screen | they need no Screen Recording permission; that is for `scripts/screenshots.sh` |
| CI runs both targets on `macos-15` and `macos-26` through `make ci` | a window test that passes locally can still fail on the other macOS version; run CI before assuming a window behavior |
