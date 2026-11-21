# 架构

设置窗口是怎么搭起来的，每一部分为什么是现在这样。公开 API 见
`Sources/SidebarSettingsKit/Public/` 里的文档注释。

## 为什么用 AppKit 窗口

SwiftUI 没有能做出这个窗口的 scene。

| SwiftUI 提供 | 为什么不合适 |
| --- | --- |
| `Settings` scene | 只有偏好设置那套工具栏：没有后退和前进，也放不进应用自己的工具栏条目 |
| `NavigationSplitView` | 分隔条往里一拖，侧边栏就折叠，再也没法恢复 |

所以 `SidebarSettingsWindow` 是一个包在 `NSWindow` 外面的 SwiftUI 风格 API：一个
`NSSplitViewController`，详情旁边是不能折叠的侧边栏 item，上面是本库填充的 `NSToolbar`。公开签名里
不出现任何 AppKit 类型。

按 Apple 对设置窗口的要求，窗口不能最小化、不能缩放、不能全屏：⌘, 会把它叫回来，尺寸按页面来定。它的
style mask 里没有 `.miniaturizable`。`.fullScreenNone` 加上置灰的缩放按钮，把 AppKit 给可缩放窗口的
那套动作收了回去；`SettingsWindow.zoom(_:)` 什么都不做，调它的代码也就缩不了窗口。可缩放的窗口照样能
从边缘拖动改变大小。

本库不设置外观。窗口跟随应用的（`NSApp.appearance`），应用没指定就跟 Mac 走。SwiftUI 的
`.preferredColorScheme` 管不到它，在页面里设置也一样。

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
| `SidebarSettingsWindow` | 应用 | 和应用一样长；只创建一次，别放进 `body` 里 |
| `SettingsNavigator` | 窗口对象 | 整个应用：窗口关了它还在，所以窗口重新打开时停在原来那一页 |
| `SettingsWindowController` | 窗口对象 | 从第一次 `show(page:)` 到这个窗口对象销毁 |
| `SettingsWindow` | controller | 跟 controller 一起：`isReleasedWhenClosed = false`，AppKit 关闭时不会释放它 |

`SidebarSettingsWindow.init` 只是把 `makeController` 存起来，什么都不建：第一次 `show(page:)` 才调用
它，存下 controller，激活应用，显示出窗口。`close()` 关掉窗口但留着 controller，所以下一次 `show()`
打开的还是同一个。

controller 不需要知道 `Page`：`SettingsWindowController.Navigation` 用闭包装着 `canGoBack`、
`canGoForward`、`goBack`、`goForward` 和 `pageTitle`。

## 侧边栏

`SidebarView` 是一个没有间距的 `VStack`，从上到下三层：

1. 搜索框，`configuration.search` 为 `.enabled` 时才有：用的是 AppKit 的 `NSSearchField`，经
   `NSViewRepresentable` 包进来，`.controlSize(.large)`，内边距 8 pt，和系统设置一样。`.searchable`
   没法把搜索框放到列表上方，所以这里只能用 AppKit。
2. 列表，它会滚动（见下文）。头部是列表的第一项，跟着页面一起滚，就像系统设置里的账户行。
3. 底部，用 `.safeAreaInset(edge: .bottom)` 放上去，所以列表在上面怎么滚它都在底下，列表也会给它留出
   空间。

搜索过滤在 `Internal/SidebarSections.swift` 的 `visibleSections(_:search:searchText:)` 里：开启搜索
后，每个分组只留下 `matches(searchText:)` 为真的页面，一个页面都不剩的分组被丢掉。所有页面都不匹配时，
列表换成放大镜下面一行小的浅色 “No Results” 文字（`NoSearchResults`）；`ContentUnavailableView.search`
是按整个窗口排版的，缩不到这么小。只有搜索能把列表清空，因为窗口至少有一页。匹配规则属于 `SettingsPage`，
不放在配置里，因为配置不是对页面类型泛型的。

## 侧边栏列表

侧边栏用 SwiftUI 的 `List` 加 `.listStyle(.sidebar)`（`SidebarList`）来画页面，图标是纯色或方块。于是
选中、方向键、按字选择、旁白的列表导航，以及各 macOS 版本上选中块的样子，全都是系统的。
`configuration.icons` 只改一行里图标槽位的内容，从不改选中的样子。系统列表也画不出别的选中形状。本库
曾经自己画行来换一个圆角选中块，结果丢了按字选择、旁白的列表结构和系统的选中外观，所以现在没有这种
自绘方案。

一行的高度就是内容加上列表的内边距，所以本库没有行高选项：侧边栏列表不理会 `defaultMinListRowHeight`，
在行的内容上加 frame，也只是把内边距再摞一遍。列表会预留 16、20 或 24 点的图标槽位，尺寸跟着用户的
侧边栏图标大小设置走（行环境里的 `\.sidebarRowSize`），离选中块边缘 6 点。图标不论是纯色还是放在方块
上，都填满这个槽位，和系统设置的方块一样，于是各行保持系统的高度，标题的起点也跟纯色行对齐。方块要是
比槽位大，行就会变高、标题被挤，所以方块没有自己的尺寸。纯色图标用 `listItemTint` 取色调，在选中行上
列表把它和标题一起变白。用 `foregroundStyle` 直接设在符号上的颜色会留下来，蓝色图标就这么消失在蓝色
选中块里。放在方块上时，色调是方块的颜色，字形是白色，用的是中等的 image scale：macOS 27 上的侧边栏
列表会向行要大号那一档，符号就画到了方块的边上。

一个分组就是一个不带标题的 `Section`，靠间距分开，和系统设置的分组一样。侧边栏列表里带标题的
`Section` 会变成点一下标题就折叠的分组，动画是 SwiftUI 自己的；要让它一直展开得写
`.collapsible(false)`，而 SwiftUI 已经把这个标记为将废弃，所以分组不带标题。

命令点按会往选中项里写 `nil`，列表不理它，当前页面保持不变。窗口出现时和每次选中变化时，列表都把选中
的页面滚进可见区域。出现时的那次滚动要先让主 actor 等一拍（`.task` 里的 `Task.yield()`）：如果在第一次
布局时就滚，各行还没有高度，会滚不到位，把折叠线下面的一行切掉。

## 工具栏下方的分隔线

分隔线在每个 macOS 版本上都跟着系统设置走，没有开关。macOS 15 上，页面会报告自己有没有滚过顶部
（`DetailContainer` 里的 `onScrollGeometryChange`），`ToolbarSeparator` 据此设置详情 item 的
`titlebarSeparatorStyle`：在顶部用 `.none`，滚动之后用 `.shadow`，和系统设置的线、阴影逐像素一致。放着
`.automatic` 不管的话，SwiftUI 一换页面 AppKit 就跟丢了：新页面明明从顶部显示，线却还留着。

| macOS | 系统设置 | 本库 |
| --- | --- | --- |
| 14 | （没检查过：14 上什么都不跑） | 始终有一条线：macOS 15 之前 SwiftUI 不上报滚动位置 |
| 15 | 顶部没有线；滚动之后有线和阴影 | 相同 |
| 26 | 没有线；柔和的滚动边缘 | 相同：系统忽略这个样式 |
| 27 | 顶部没有线，指针移到工具栏上时有一条；滚动之后是带线的硬边缘 | 相同 |

macOS 27 上边缘会变硬，原因是窗口标题显示在工具栏里：标题栏里有窗口标题这类自由浮动的文字时，自动样式
就解析成硬边缘（WWDC26 session 289）。系统设置的页面自己也显示标题，也同样变硬（在“辅助功能”和
“隐私与安全性”里确认过）；只有“通用”在头部卡片滚走之前不显示标题。设成 `title = .hidden` 时，本库的
边缘保持柔和。在自动样式之上再设 `.soft`，并不能在标题显示时抹掉那条线，Apple 在 27 上也不建议这么干
（WWDC26 session 278）。

对比的时候要把减弱透明度关掉，Mac 出厂时本来就是关的。GitHub 的 macOS 镜像把它打开，打开之后系统设置
在 26 和 27 上连页面顶部都会显示一条线。

## 详情

页面自己滚动，窗口不会在外面再套一层滚动视图。macOS 14 和 15 上，工具栏的背景取自正下方那个滚动视图：
分组的表单或列表能给出和页面一致的背景，普通的 SwiftUI `ScrollView` 给不出，工具栏就退回自己那层更浅的
材质，不滚动也能看见它的边缘。本库要是给每个页面都套一层 `ScrollView`，结果就是这样。`DetailContainer`
在内容上设了 `.id(page)`，换页时新页面从顶部重新构建。

## 标题与工具栏条目

窗口标题和后退、前进按钮通过 `FollowsNavigation` 跟随页面：这是套在详情外面的一个 modifier，用
`onChange` 盯着标题和历史记录，在绘制新页面的那次 SwiftUI 更新里设置标题、校验工具栏条目，所以标题和
页面在同一帧里换掉。如果改成等某次观察触发之后再用 task 设置，旧标题会在新页面上多停一帧。`.fixed`
在所有地方显示同一个标题；`.hidden` 用 `titleVisibility = .hidden` 把标题藏起来，窗口本身仍留着标题
给“窗口”菜单和旁白用。

工具栏只显示图标：在应用里，macOS 15 上 `.automatic` 会选更高的工具栏，箭头下面会冒出 “Back” 和
“Forward”，系统设置可不是这样。测试进程不管怎么设置都只有图标，所以这一项只能人工看。

controller 只在 macOS 26 上把 `.unifiedCompact` 工具栏样式换成 `.automatic`：那里紧凑工具栏会让侧边栏
从标题栏下面才开始，窗口按钮就孤零零落在一根空条上。macOS 14、15 和 27 用紧凑工具栏，默认值到处都是
`.automatic`。

`window.title` 要等 `contentViewController` 设好之后再设，因为 `NSWindow(contentViewController:)` 会把
标题留成 “Untitled”，直到有人去改它。

工具栏是 `NSToolbar`，以 controller 作 delegate，没用 SwiftUI 的工具栏桥接，因为后者曾经让第一个标题
没有本地化。它的条目是 `.sidebarTrackingSeparator`、后退和前进；每个按钮的标签和提示文字取自
`configuration.strings`，图像取自 `chevron.backward` 或 `chevron.forward`（在阿拉伯语和希伯来语里
方向正好相反），辅助功能描述也用同一份文字，并且被标记为导航类，所以画出来就是工具栏控件的样子。

关掉按钮之后，标题由 AppKit 自己放，距侧边栏 11 点，在页面分组表单的左边，而表单从 20 点处开始。本库
用一个空的导航类条目占住按钮的位置：导航类条目排在标题之前，AppKit 在它后面留的空隙正好让标题和页面对
齐。macOS 26 上 AppKit 自己就把标题和表单对上了，误差不到一点，前面也不会露出空的玻璃形状（在一张 2x
的 macOS 26 截图上确认过），所以那里工具栏就按 AppKit 的排布来。macOS 27 还没检查过。

窗口 frame 的 autosave 名字在 `super.init(window:)` 之后设到 controller 上，因为 `init(window:)` 会清掉
设在窗口上的名字。不能改变大小的窗口只会恢复它保存的位置。

## 键盘快捷键

| 快捷键 | 做什么 | 由谁处理 |
| --- | --- | --- |
| ⌘, | 打开窗口 | `SidebarSettingsCommands`，通过 `OpenSidebarSettingsButton.keyboardShortcut(",")` |
| ⌘[ , ⌘] | 后退、前进 | `SettingsWindow.performKeyEquivalent`，排在主菜单之前，所以在没有 File 或 Go 菜单的应用里也能用；只在 `showsNavigationButtons` 打开时接上 |
| ⌘W | 关闭窗口 | 同一个重写方法，走 `performClose(nil)` |
| ⌘F | 聚焦搜索框 | `FindShortcutSearchField.performKeyEquivalent`，在侧边栏的 `NSSearchField` 里：它从窗口的任何位置接过这个键，和系统设置的搜索框一样 |
| Esc | 清空搜索框 | `NSSearchField` 自己的行为 |
| ↑ , ↓ | 移动选中项 | 系统的 `List` |
| 搜索框里的 ↓ | 跳到搜到的页面 | `SearchField` 的 delegate 接住 field editor 的 `moveDown:`，再由 `SidebarView` 聚焦列表；搜索挡住了当前显示的页面时，打开第一个搜到的页面 |
| Tab | 在搜索框和列表之间切换 | AppKit 的 key view loop，窗口会重新计算它（`autorecalculatesKeyViewLoop`）：分栏视图留给列表的下一个 key view 是个拿不到焦点的视图，所以 Tab 以前哪儿也去不了 |

键盘处理放在窗口和搜索框里，不放在 SwiftUI 视图里：窗口比主菜单先接住 key equivalent，而本库不能指望
应用有那些常规菜单。

窗口打开时列表拿到焦点，和系统设置一样。这件事由 `SidebarView` 上的 task 做，不是列表上的 task：搜索
没有结果时列表会被换掉，字母一删列表回来，它自己的 task 就会在用户还在打字时抢走搜索框的焦点。在搜到的
第一个页面上按 ↑ 仍留在列表里，和系统设置一样；Tab 回到搜索框。

## 本地化

`Sources/SidebarSettingsKit/Resources/<language>.lproj/Localizable.strings` 里放着本库自带的五段文字：
Back、Forward、Search、Settings… 和 No Results，macOS 有的语言全都齐了。清单里设了
`defaultLocalization: "en"`。

这些措辞取自 macOS 自己在同样控件上的说法，从系统的本地化表里读出来
（`plutil -convert json -o - <table>`，macOS 15），没有手工翻译：

| 文字 | 表 | Key |
| --- | --- | --- |
| Back、Forward、Search | `/System/Applications/System Settings.app/Contents/Resources/Localizable.loctable` | `BACK_AXDESCRIPTION`、`FORWARD_AXDESCRIPTION`、`SEARCH_LABEL` |
| Settings… | `/System/Library/Frameworks/AppKit.framework/Resources/MenuCommands.loctable` | `Settings\U2026` |
| No Results | `/System/Library/Frameworks/SwiftUI.framework/Resources/Localizable.loctable` | `ContentUnavailableView_Search_Text` |

36 个目录覆盖了 macOS 的 41 种语言。英文（澳大利亚、英国）、法文（加拿大）、西班牙文（美国）和中文
（香港）这四套，五段文字分别和英文、法文、西班牙文（拉丁美洲）、繁体中文一模一样，Foundation 会回退到
它们。目录名用的是 Xcode 的叫法（`nb`、`pt-BR`、`pt-PT`、`zh-Hans`、`zh-Hant`），而表里写的是 `no`、
`pt_BR` 或 `pt`、`pt_PT`、`zh_CN`、`zh_TW`。本库以后新增文字，也得在那几张表里找到出处。

这里用的是 `.strings` 文件，不是 string catalog（`.xcstrings`）：SwiftPM 的命令行（`swift build`、
`swift test`、`swift run`）会把 catalog 拷进 bundle 却不编译，翻译就只存在于 Xcode 的构建里，测试和
演示应用都看不到。

`SidebarSettingsConfiguration.Strings` 用下面这段代码构建每个默认值：

```swift
let language = Bundle.module.preferredLocalizations.first ?? "en"
LocalizedStringResource(
    key, locale: Locale(identifier: language), bundle: .atURL(Bundle.module.bundleURL))
```

在本库模块里创建的 resource 必须写明本库的 bundle 才能解析出来，否则会去查应用自己的表。locale 决定用
哪种语言，和 AppKit 自己的文字（“窗口”菜单、搜索框上的“取消”）一样：Foundation 在应用声明的语言里挑
一个；不给 locale 的话 resource 会跟着系统语言走，于是在中文 Mac 上，一个只有英文的应用，页面旁边会
显示中文的后退和前进。应用没有本地化的文字，本库无从判断它是什么语言，所以不会拿系统语言去猜；每种情况
下应用到底显示什么，见 README 的语言一节。

页面标题、关键词以及其他所有用户看得见的文字都来自应用，所以本库从不写死任何用户可见的字符串。

## 针对 macOS 26 及更高版本的调整

| 位置 | 做法 | 原因 |
| --- | --- | --- |
| `SidebarView` 根视图 | `scrollEdgeEffectStyle(.soft, for: .all)` | 行在工具栏下方淡出，和系统设置一样 |
| `DetailContainer` | `scrollContentBackground(.hidden)` | macOS 26 及以后，表单或列表直接坐在窗口背景上；macOS 15 上同样的调用会在工具栏下面留一条色带，所以只在 26 起使用 |
| 侧边栏的行 | 哪里都不加材质 | 从 26 起侧边栏保留系统的 Liquid Glass；`configuration.icons` 只改图标 |

## 其他

测试 target 和 fixtures 见 [TESTING.md](TESTING.md)，演示应用见 [DEVELOPMENT.md](DEVELOPMENT.md)，
公开 API 的规则见 `AGENTS.md`。
