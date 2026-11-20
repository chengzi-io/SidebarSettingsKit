# 测试

Swift Testing，两个 target：从不开窗口的逻辑测试，和驱动真实窗口的窗口测试。`make test` 两个都跑。

## Target

| Target | 路径 | 窗口 | 放什么 |
| --- | --- | --- | --- |
| `SidebarSettingsKitTests` | `Tests/SidebarSettingsKitTests/` | 无 | 导航历史、搜索匹配、侧边栏分组、配置默认值、套件文字、窗口的前置条件（各自在子进程里） |
| `SidebarSettingsKitWindowTests` | `Tests/SidebarSettingsKitWindowTests/` | 真实窗口，一次一个 | frame 与缩放、工具栏和标题、工具栏下方的分隔线、头部和底部、侧边栏的行与滚动、键盘、生命周期、自动保存、内存 |

两个 target 都用 `@testable import` 导入套件，以便触到内部类型。能在值上检查的行为就放进逻辑测试：
不开窗口、不用等待、不会 flaky。

| 命令 | 跑什么 |
| --- | --- |
| `make test` | 两个 target，带 `-Xswiftc -warnings-as-errors` |
| `swift test --filter NavigatorTests` | 一个 suite，按它的类型名 |
| `swift test --filter AutosaveTests` | 一个窗口 suite，嵌套在 `WindowTestSuite` 里 |

suite 的显示名（`@Suite("Navigation history")`）是给测试日志看的；`--filter` 匹配的是类型名。

## Fixtures

`Tests/Fixtures/` 是 target `SidebarSettingsFixtures`，不在任何 product 里，所以依赖套件的应用永远不会
编译它。演示应用通过符号链接
`Examples/SidebarSettingsDemo/Sources/DemoFixtures → ../../../Tests/Fixtures` 把同样的文件再编译一遍，
作为 `DemoFixtures`，所以 fixture 代码从不写自己的模块名：没有 `import SidebarSettingsFixtures`，也没有
带模块限定的符号。

| 文件 | 提供什么 |
| --- | --- |
| `FixturePage.swift` | `FixturePage`（结构体页面，按 `id` 判等）、`FixtureIconDescription`、`FixtureTint`、`FixtureRenderingMode`、`FixtureSymbolWeight` |
| `FixturePages.swift` | `three`（`general`、长页 `appearance`、`advanced`）、`many`（40 页）、`longText`，带 `longEnglishTitle`、`chineseTitle`、`mixedTitle`、`longKeyword`、`widthInsensitiveKeywords` |
| `FixtureSections.swift` | `ungrouped`、`grouped`、`withEmptySection` |
| `FixtureIconPages.swift` | 每种 `SettingsIcon` 形式一页，以及 `all` |
| `DetailViews.swift` | `LongContentView`（`minimumHeight` 1800）、`ShortContentView`（`maximumHeight` 300）、`FixtureDetail(page:)`，后者把其中一个放进自己的 `ScrollView`，因为每个页面都自己滚动 |
| `ChromeViews.swift` | `FixtureHeader`、`FixtureFooter`（`height` 28）、`TallFooter`（`height` 80） |

如果第二个 suite 也会用到某个页面集合或视图，就把它加进 fixture 文件，不要加进测试里。

## 窗口测试

| 部件 | 在哪 | 做什么 |
| --- | --- | --- |
| `WindowTestSuite` | `Support/WindowTestSupport.swift` | 唯一的 `@Suite(.serialized)` 根 suite；每个领域都是写在 `extension WindowTestSuite` 里的 `@Suite(.serialized) @MainActor` 结构体 |
| `fixtureWindow` | 支持代码 | 构建但不显示一个用 `FixtureDetail` 页面的窗口 |
| `withWindow` | 支持代码 | 打开窗口、等它出现，并在 `defer` 里关掉，body 抛错时也关 |
| `WindowUnderTest` | 支持代码 | 显示出来的窗口，以及测试要读的那些部件 |

根 suite 是串行的，因为测试共用一个应用进程：first responder、`NSApp.windows`、`UserDefaults`。Swift
Testing 也会把 suite 的子 suite 串行化，所以新领域要建自己的嵌套 suite，而不是第二个根 suite。

`withWindow` 有两种形式：一种显示由 `pages:`、`initialPage:` 和 `configuration:` 构建的 `fixtureWindow`；
另一种显示测试自己构建的 `SidebarSettingsWindow`，用于分组、头部、底部或自己的 detail。两种都接受 `page:`
来指定打开在哪一页。`.windowTest.drawing(.tiled)` 是带方块图标的测试配置。

`WindowUnderTest` 提供 `settings`、`controller`、`window`，以及 `sidebarView`、`detailView`、
`separator`、`toolbarItem(_:)`、`detailScrollView()`、`sidebarScrollView()`、`sidebarTable()`、
`sidebarPageRowCount()`、`sidebarHeadingRowCount()`、`searchField()`。它的 `attach(_:)` 会等窗口上屏，
并等分栏视图把两栏都布局好；只有自己显示的窗口才需要直接调它。

### 等待

| 辅助方法 | 返回 | 用来 |
| --- | --- | --- |
| `WindowTest.wait(for:timeout:_:)` | 抛错 | 一个必须成立的条件；抛出的 `WindowTestFailure` 会指明等了什么 |
| `WindowTest.poll(timeout:_:)` | `Bool` | 同样的等待，但不抛错，用于不能抛错的 body |
| `WindowTest.settle(_:)` | 无 | 没有状态可轮询的效果，比如关闭窗口 |
| `WindowTest.settled(_:timeout:)` | 稳定后的值 | SwiftUI 会跨好几帧才移到位的值，比如滚动偏移 |
| `require(_:_:)` | 值，或抛错 | 拆包视图、表格、frame，附带说明信息 |

`WindowTest.timeout` 是 5 秒，`WindowTest.step` 是 20 毫秒。每个等待都是 `async` 的，这有原因：套件在一个
SwiftUI task 里聚焦列表，而同步的 body 如果在 `RunLoop.main.run(until:)` 里堵住主线程，task 和主队列
都会饿死（在 macOS 15.7 上验证过），测试于是读到过期的状态。永远不要用 run loop 替代等待。

### 读视图

| 辅助方法 | 给出 |
| --- | --- |
| `allViews(in:)` | `view` 以及它下面的每个视图，深度优先 |
| `frameInWindow(_:)` | 视图在窗口坐标里的 frame |
| `firstScrollView(in:)` | 视图下面的第一个 `NSScrollView`：SwiftUI 的 `ScrollView`，或者 `List` 的 |
| `scrollOffsetFromTop(_:)` | 滚动视图的内容从顶部往下移了多远 |
| `scroll(_:toOffsetFromTop:)` | 把它移过去，并把这次移动发布给 SwiftUI |
| `requireScrollable(_:atLeast:)` | 内容不比显示它的空间高时失败 |

`NSEvent` 有两种用法：`commandKey(_:keyCode:in:)` 构造一次 ⌘ 按下，交给
`window.performKeyEquivalent(with:)`；`typeKeys(_:in:)` 把普通按键发给窗口的 first responder，并给每个
按键打上当前时间，因为列表的按字选择是按时间戳把按键归到一起的。

### 探针

头部或底部是没有 AppKit 句柄的 SwiftUI 视图。`ViewAnchor` 持有 SwiftUI 为它建出的 `NSView`，
`probed(_:_:)` 在 `overlay` 里把 1 pt 的探针放在它的左上角，所以它不占空间，而 `ViewAnchor.isShown` /
`ViewAnchor.frameInWindow` 回答套件有没有绘制它、它在哪儿。

### Defaults

`defaultsKeys()` 给 `UserDefaults.standard` 拍快照；`WindowTest.frameDefaultsPrefix` 是 AppKit 保存窗口
frame 时用的 `"NSWindow Frame "` 前缀，也是套件唯一可能留下的 key。`SidebarSettingsConfiguration.windowTest`
是测试用的配置：`autosaveName` 为 `nil`，所以不测 frame 的测试什么都不写。进程第一次构建文本视图时，AppKit
自己会写 `NSVisualBidiSelectionEnabled`；它是这条规则之外唯一被允许的 key，在 `AutosaveTests` 里按名字放行。

## 假通过规则

| 规则 | 看起来是什么样 |
| --- | --- |
| 滚动测试先断言自己滚得动，再滚 | `try requireScrollable(detail, atLeast: LongContentView.minimumHeight)`，或者内容比可见区域高出一截 |
| 修 bug 的测试要先看到它在没修时失败 | 把修复回退一次，看着新测试失败，再恢复 |
| suite 里没有 `withKnownIssue` | 要么问题修好了，要么测试删掉了；被跳过的断言不算测试 |

内容刚好放得下的滚动测试，一次都不用滚就通过了，新页面从顶部开始的滚动测试、侧边栏滚动到选中项的测试，
就是这样变绿的。侧边栏“内容比显示区域高”的检查也调用 `requireScrollable`，它会让这种情况大声失败。

## 环境

| 事实 | 后果 |
| --- | --- |
| 2026-11-02 之后没有 macOS 14 runner | macOS 14 的 `#available` 分支断言的是回退行为 |
| Stage Manager 会缩窄可见屏幕，AppKit 会把恢复的 frame 移进可见区域 | 需要摆放窗口的测试要把它放在 `NSScreen.main.visibleFrame` 里面足够深的位置 |
| 窗口测试读的是视图、状态和某一行自己的绘制（`cacheDisplay`），从不读屏幕 | 它们不需要 Screen Recording 权限；那是给 `scripts/screenshots.sh` 用的 |
| CI 通过 `make ci` 在 `macos-15` 和 `macos-26` 上跑两个 target | 本地能过的窗口测试在另一个 macOS 版本上仍可能失败；在认定某个窗口行为之前先跑 CI |
| macOS 27 上，测试进程发出的 Tab（经窗口或 `NSApp`）离不开侧边栏列表；真按键会去到搜索框，和系统设置一样（在 `xcode-27` runner 上用 System Events 验证过，演示应用用 macOS 27 SDK 链接） | `make ci` 不在 macOS 27 上跑：`downArrowLeavesTheSearchFieldForThePagesFound` 在那里会失败 |
