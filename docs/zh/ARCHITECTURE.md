# 架构

设置窗口是怎么搭起来的，以及每一部分为什么是现在这样。公开 API 见
`Sources/SidebarSettingsKit/Public/` 里的文档注释。

## 为什么是 AppKit 窗口

SwiftUI 没有能做出这个窗口的 scene。

| SwiftUI 提供 | 为什么不合适 |
| --- | --- |
| `Settings` scene | 保留偏好设置的工具栏：没有后退和前进，也放不进应用自己的工具栏条目 |
| `NavigationSplitView` | 分隔条往里一拖，它的侧边栏就折叠，而且没有办法把它找回来 |

所以 `SidebarSettingsWindow` 是在一个 `NSWindow` 外面套的 SwiftUI 形状的 API：一个
`NSSplitViewController`，详情旁边是不可折叠的侧边栏 item，上面是套件填充的 `NSToolbar`。公开签名里
不出现任何 AppKit 类型。

窗口不能最小化、缩放或全屏，这是 Apple 对设置窗口的要求：⌘, 会把它叫回来，尺寸也按它的页面来定。它的
style mask 去掉了 `.miniaturizable`；`.fullScreenNone` 和置灰的缩放按钮收回了 AppKit 给可缩放窗口的
那些动作；`SettingsWindow.zoom(_:)` 什么都不做，所以调用它的代码不会让窗口缩放。可缩放的窗口仍然可以从
边缘拖动改变大小。

套件不设置外观。窗口跟随应用的（`NSApp.appearance`），应用没有指定时跟随 Mac。SwiftUI 的
`.preferredColorScheme` 到不了它，即使从页面内部设置也不行。

## 对象图

```
SidebarSettingsWindow<Page>                            public, @MainActor class, created once
├── navigator: SettingsNavigator<Page>                 selection, history, searchText
├── sections: [SettingsPageSection<Page>]              the sidebar's groups
├── configuration                                      value type
└── controller: SettingsWindowController?              built by the first show()
    └── window: SettingsWindow                         NSWindow subclass: ⌘[ ⌘] ⌘W
        ├── toolbar: NSToolbar                         delegate = the controller
        │   └── items: .sidebarTrackingSeparator, back, forward
        └── contentViewController: NSSplitViewController
            ├── sidebarItem: NSSplitViewItem(sidebarWithViewController:)
            │   └── NSHostingController<SidebarView>
            │       → NSSearchField (fixed) + system sidebar List + header + footer
            └── detailItem: NSSplitViewItem(viewController:)
                └── NSHostingController<DetailContainer>
                    → the selected page, which scrolls itself
```

## 归属与生命周期

| 对象 | 由谁持有 | 活多久 |
| --- | --- | --- |
| `SidebarSettingsWindow` | 应用 | 与应用同样长；只创建一次，绝不要在 `body` 里创建 |
| `SettingsNavigator` | 窗口对象 | 整个应用：它挺过窗口关闭，所以窗口重新打开时还在原来那一页 |
| `SettingsWindowController` | 窗口对象 | 从第一次 `show(page:)` 到这个窗口对象销毁 |
| `SettingsWindow` | controller | 与 controller 同生共死：`isReleasedWhenClosed = false`，所以 AppKit 不会在关闭时释放它 |

`SidebarSettingsWindow.init` 捕获 `makeController`，但不构建任何东西：第一次 `show(page:)` 才调用
它、存下 controller、激活应用并显示窗口。`close()` 关闭窗口但留着 controller，所以下一次 `show()`
打开的是同一个。

controller 不沾 `Page`：`SettingsWindowController.Navigation` 用闭包持有 `canGoBack`、
`canGoForward`、`goBack`、`goForward` 和 `pageTitle`。

## 侧边栏

`SidebarView` 是一个没有间距的 `VStack`：

1. `configuration.search` 为 `.enabled` 时的搜索框：AppKit 的 `NSSearchField`，经
   `NSViewRepresentable` 包装，`.controlSize(.large)`，内边距 8 pt，和系统设置里的一样。
   `.searchable` 没法把搜索框放到列表上方，所以这里用了 AppKit。
2. 列表，会滚动（见下文）。头部是列表的第一项，随页面一起滚动，就像系统设置里的账户行。
3. 底部，通过 `.safeAreaInset(edge: .bottom)` 放置，所以列表在上面滚动时它一直待在底下，列表也为它
   留出了空间。

搜索过滤是 `Internal/SidebarSections.swift` 里的 `visibleSections(_:search:searchText:)`：开启
搜索后，每个分组只留下 `matches(searchText:)` 为真的页面，没有页面剩下的分组被丢掉。没有页面匹配时，
列表让位给放大镜下面一行小的浅色 “No Results” 文字（`NoSearchResults`）；`ContentUnavailableView.search`
是按整个窗口来排版的，缩不小。只有搜索能让列表变空，因为窗口至少有一页。匹配本身属于 `SettingsPage`，
不属于配置，因为配置不是对页面类型泛型的。

## 侧边栏列表

侧边栏用 SwiftUI 的 `List` 和 `.listStyle(.sidebar)`（`SidebarList`）绘制页面，图标是纯色或方块，
所以选中、方向键、按字选择、VoiceOver 的列表导航，以及各 macOS 版本上选中的样子，都是系统的。
`configuration.icons` 改的是一行里图标槽位的内容，永远不改选中。系统列表画不出别的选中形状；套件自己
绘制的行为了得到圆角选中，丢掉了按字选择、VoiceOver 的列表结构和系统的选中样子，所以套件没有这样的
绘制方案。

一行的高度是内容加上列表的内边距，所以套件没有行高选项：侧边栏列表忽略 `defaultMinListRowHeight`，
给行的内容加 frame 只会把内边距摞在它上面。列表预留 16、20 或 24 点的图标槽位，按用户的侧边栏图标大小
设置来定（行环境里的 `\.sidebarRowSize`），距选中块的边缘 6 点。图标，纯色的也好、放在方块上的也好，
都填满这个槽位，和系统设置的方块一样，所以各行保持系统的高度，标题的起点也和纯色行的标题一致。比方块
槽位大的方块会让行变高、把标题挤窄，所以方块没有自己的尺寸。纯色图标通过 `listItemTint` 取色调，列表
在选中行上把它和标题一起变白；用 `foregroundStyle` 设在符号上的颜色会留着，蓝色图标就这样消失在蓝色
选中块里。方块上，色调就是方块的颜色，字形是白色，用的是中等的 image scale：macOS 27 上的侧边栏
列表会向行要大号的那一档，结果把符号画到了方块的边缘。

分组是不带标题的 `Section`，靠间距分开，和系统设置的分组一样。侧边栏列表里带标题的 `Section` 会变成
点标题就折叠的分组，带 SwiftUI 自己的动画；让它保持展开要用 `.collapsible(false)`，而 SwiftUI 已把
它标记为将废弃，所以分组不带标题。

列表会忽略命令点按写进选中项的 `nil`，所以当前页面留着。窗口出现时和每次变化时，它把选中的页面滚动
到可见处。出现时的那次滚动会让主 actor 等一拍（`.task` 里的 `Task.yield()`）：在第一次布局时就跑，
各行还没有自己的高度，它会停得太早，把折叠线下面的一行裁掉。

## 工具栏下方的分隔线

分隔线在每个 macOS 版本上都跟随系统设置，没有开关。macOS 15 上，页面会报告自己是否滚过了顶部
（`DetailContainer` 里的 `onScrollGeometryChange`），`ToolbarSeparator` 据此设置详情 item 的
`titlebarSeparatorStyle`：在顶部是 `.none`，滚动之后是 `.shadow`，和系统设置的线与阴影逐像素一致。
留着 `.automatic` 时，SwiftUI 一换页面，AppKit 就管不住它了：新页面从顶部显示时，线还留着。

| macOS | 系统设置 | 套件 |
| --- | --- | --- |
| 14 | （未检查：没有 CI） | 始终有一条线：macOS 15 之前 SwiftUI 不上报滚动位置 |
| 15 | 顶部没有线；滚动后有一条带阴影的线 | 相同 |
| 26 | 没有线；柔和的滚动边缘 | 相同：系统忽略这个样式 |
| 27 | 顶部没有线，指针在工具栏上时有一条；滚动后是带线的硬边缘 | 相同 |

macOS 27 上边缘会变硬，因为窗口标题显示在工具栏里：标题栏里有窗口标题这类自由浮动的文字时，自动样式会
解析成硬边缘（WWDC26 session 289）。系统设置的页面也显示标题，也同样变硬（在“辅助功能”和“隐私与安全性”
里检查过）；只有“通用”在头部卡片滚走之前不显示标题。设成 `title = .hidden` 时，套件的边缘保持柔和。
在自动样式之上再设 `.soft` 并不能在标题显示时去掉那条线，Apple 在 27 上也不建议这么做（WWDC26 session 278）。

在一台关闭“减少透明度”的 Mac 上比较，Mac 出厂时它就是关的。GitHub 的 macOS 镜像把它打开，打开之后
系统设置在 26 和 27 上即使页面在顶部也会显示一条线。

## 详情

页面自己滚动；窗口不会在它外面再套滚动视图。macOS 14 和 15 上，工具栏的背景取自正下方那个滚动视图：
分组的表单或列表会给出与页面一致的背景，而普通的 SwiftUI `ScrollView` 给不出，工具栏就退回自己更浅的
材质，不滚动也能看到它的边缘。套件如果在每个页面外面套一层 `ScrollView`，正好就是这个结果。
`DetailContainer` 在内容上设置 `.id(page)`，所以换页时新页面从顶部构建。

## 标题与工具栏条目

窗口的标题和后退、前进按钮通过 `FollowsNavigation` 跟随页面：这是包在详情外面的一个 modifier，用
`onChange` 盯着标题和历史记录，并在绘制新页面的那次 SwiftUI 更新里设置标题、校验工具栏条目，所以标题
和页面在同一帧里改变。如果改成在某次观察触发之后由 task 设置，旧标题会在新页面上多停一帧。`.fixed`
到处都显示同一个标题；`.hidden` 用 `titleVisibility = .hidden` 隐藏它，窗口仍保留一个标题供“窗口”菜单
和 VoiceOver 使用。

工具栏只显示图标：在应用里，`.automatic` 在 macOS 15 上会挑更高的工具栏，在箭头下面显示 “Back” 和
“Forward”，系统设置不是这样。测试进程不管怎么设置都只有图标，所以这一项要手动检查。

controller 只在 macOS 26 上把 `.unifiedCompact` 工具栏样式映射成 `.automatic`：那里紧凑工具栏会把
侧边栏起始位置压到标题栏下方，窗口按钮就落在一块光秃秃的条上。macOS 14、15 和 27 拿到紧凑工具栏，默认
值到处都是 `.automatic`。

`window.title` 在 `contentViewController` 之后才设置，因为 `NSWindow(contentViewController:)` 会把
标题留成 “Untitled”，直到有东西去改它。

工具栏是 `NSToolbar`，以 controller 作 delegate，而不是 SwiftUI 的工具栏桥接，后者曾经产生过一个没
本地化的初始标题。它的条目是 `.sidebarTrackingSeparator`、后退和前进；每个按钮的标签和提示文字来自
`configuration.strings`，图像取自 `chevron.backward` 或 `chevron.forward`（在阿拉伯语和希伯来语里
指向左右相反的方向），带同样的辅助功能描述，并标记为导航类，所以它按工具栏控件的样子绘制。

关掉按钮时，光靠 AppKit 会把标题放在距侧边栏 11 点的位置，在页面分组表单的左边，而表单从 20 点处开始。
一个空的导航类条目占住按钮的位置：导航类条目排在标题之前，AppKit 在它后面留出的空隙让标题与页面对齐。
macOS 26 把工具栏条目放在玻璃上，而那里的空条目还没有验证过，所以那里工具栏保持 AppKit 的排布。

窗口 frame 的 autosave 名称在 `super.init(window:)` 之后设在 controller 上，因为 `init(window:)` 会
清掉设在窗口上的名称。不能改变大小的窗口只会恢复它保存的位置。

## 键盘快捷键

| 快捷键 | 做什么 | 由谁处理 |
| --- | --- | --- |
| ⌘, | 打开窗口 | `SidebarSettingsCommands`，通过 `OpenSidebarSettingsButton.keyboardShortcut(",")` |
| ⌘[ , ⌘] | 后退、前进 | `SettingsWindow.performKeyEquivalent`，在主菜单之前，所以在没有 File 或 Go 菜单的应用里也能用；只在 `showsNavigationButtons` 打开时接上 |
| ⌘W | 关闭窗口 | 同一个重写，走 `performClose(nil)` |
| ⌘F | 聚焦搜索框 | `FindShortcutSearchField.performKeyEquivalent`，在侧边栏的 `NSSearchField` 里：它从窗口的任何位置接过这个键，和系统设置的搜索框一样 |
| Esc | 清空搜索框 | `NSSearchField` 自己的行为 |
| ↑ , ↓ | 移动选中项 | 系统的 `List` |
| 搜索框里的 ↓ | 跳到搜到的页面 | `SearchField` 的 delegate 接住 field editor 的 `moveDown:`，`SidebarView` 聚焦列表；搜索挡住了当前显示的页面时，打开第一个搜到的页面 |
| Tab | 在搜索框和列表之间切换 | AppKit 的 key view loop，窗口会重新计算它（`autorecalculatesKeyViewLoop`）：分栏视图给列表的下一个 key view 是个拿不到焦点的视图，所以 Tab 以前哪儿也去不了 |

键盘处理放在窗口和搜索框里，不放 SwiftUI 视图里，因为窗口在主菜单之前接住 key equivalent，而套件不能
依赖应用有那些常规菜单。

窗口打开时列表拿到焦点，和系统设置一样，这件事由 `SidebarView` 上的 task 做，而不是列表上：搜索没有
结果时列表会被换掉，字母一删列表回来时，它自己的 task 会在用户还在打字时抢走搜索框的焦点。搜到的第一个
页面上按 ↑ 仍留在列表里，和系统设置一样；Tab 回到搜索框。

## 本地化

`Sources/SidebarSettingsKit/Resources/<language>.lproj/Localizable.strings` 保存套件自带的五段文字：
Back、Forward、Search、Settings… 和 No Results，覆盖 macOS 支持的所有语言。清单里设置
`defaultLocalization: "en"`。

这些措辞是 macOS 在同样控件上自己的措辞，取自系统的本地化表
（`plutil -convert json -o - <table>`，macOS 15），不是手工翻译的：

| 文字 | 表 | Key |
| --- | --- | --- |
| Back、Forward、Search | `/System/Applications/System Settings.app/Contents/Resources/Localizable.loctable` | `BACK_AXDESCRIPTION`、`FORWARD_AXDESCRIPTION`、`SEARCH_LABEL` |
| Settings… | `/System/Library/Frameworks/AppKit.framework/Resources/MenuCommands.loctable` | `Settings\U2026` |
| No Results | `/System/Library/Frameworks/SwiftUI.framework/Resources/Localizable.loctable` | `ContentUnavailableView_Search_Text` |

36 个目录覆盖了 macOS 的 41 种语言。英文（澳大利亚、英国）、法文（加拿大）、西班牙文（美国）和中文（香港）
和英文、法文、西班牙文（拉丁美洲）以及繁体中文用的是同样的五段文字，Foundation 会回退到它们。目录名用 Xcode
的名字（`nb`、`pt-BR`、`pt-PT`、`zh-Hans`、`zh-Hant`），而表里写的是 `no`、`pt_BR` 或 `pt`、`pt_PT`、
`zh_CN` 和 `zh_TW`。套件新增文字时，也要在那些表里有出处。

它们是 `.strings` 文件，不是 string catalog（`.xcstrings`）：SwiftPM 的命令行
（`swift build`、`swift test`、`swift run`）把 catalog 拷进 bundle 却不编译它，那些翻译就只存在于
Xcode 的构建里，测试和演示应用都看不到。

`SidebarSettingsConfiguration.Strings` 用下面这段代码构建每个默认值：

```swift
let language = Bundle.module.preferredLocalizations.first ?? "en"
LocalizedStringResource(
    key, locale: Locale(identifier: language), bundle: .atURL(Bundle.module.bundleURL))
```

在套件模块里创建的 resource 必须写明套件的 bundle 才能解析，否则会去查应用自己的表。locale 决定了应用运行
的语言，和 AppKit 自己的文字（“窗口”菜单、搜索框的“取消”）一样：Foundation 在应用声明的语言里选，而
没有 locale 的话 resource 会跟随系统的语言，于是在中文 Mac 上，一个只有英文的应用页面旁边会显示中文的后退
和前进。套件没法知道应用没做本地化的文字是什么语言，所以它不按系统语言去猜；每种情况下应用显示什么，见
README 的 Languages 一节。

页面标题、关键词和其他所有用户可见的文字都来自应用，所以套件从不写死任何用户可见的字符串。

## 针对 macOS 26 及更高版本的调整

| 位置 | 做法 | 原因 |
| --- | --- | --- |
| `SidebarView` 根视图 | `scrollEdgeEffectStyle(.soft, for: .all)` | 行在工具栏下方淡出，和系统设置一样 |
| `DetailContainer` | `scrollContentBackground(.hidden)` | 从 macOS 26 起，表单或列表直接坐在窗口背景上；macOS 15 上同样的调用会在工具栏下面留一条色带，所以只在 26 及以上使用 |
| 侧边栏的行 | 到处都不加材质 | 从 26 起侧边栏保留系统的 Liquid Glass；`configuration.icons` 只改图标 |

## 其他

测试 target 和 fixtures 在 [TESTING.md](TESTING.md)，演示应用在
[DEVELOPMENT.md](DEVELOPMENT.md)，公开 API 的规则在 `AGENTS.md`。
