# 开发

日常流程、演示应用、截图、CI 和发布。

## 环境要求

| | |
| --- | --- |
| macOS | 14 或更高，用来跑你构建出来的东西（部署目标） |
| Xcode | 26.2，即 `.xcode-version` 里的版本 |
| Swift | 6.2（清单是 `swift-tools-version: 6.2`） |
| 依赖 | 无；包和演示应用都能离线构建 |

警告就是错误：Makefile 传 `-Xswiftc -warnings-as-errors`，从不写进 `Package.swift`，因为用了
`unsafeFlags` 的包不能被依赖。不要屏蔽警告，去修它。

## Make target

| 命令 | 做什么 |
| --- | --- |
| `make help` | 列出所有 target |
| `make build` | 构建这个包 |
| `make test` | 跑两个测试 target；其中一些会短暂打开真实窗口 |
| `make demo` | 运行演示应用 |
| `make demo-build` | 构建演示应用 |
| `make screenshots` | 把截图矩阵抓取到 `screenshots/` |
| `make ci` | 按顺序构建、测试、构建演示应用：CI 跑的就是这些 |
| `make clean` | 删除 `.build` 和演示应用的构建产物 |

只跑一个测试：`swift test -Xswiftc -warnings-as-errors --filter <name>`。

## 演示应用

`Examples/SidebarSettingsDemo/` 是一个独立包，按路径依赖根包，所以它跑的永远是你正在改的代码。它既是手动
QA 的工具，也是截图的来源；根包从不引用它。

```
make demo                 # or: cd Examples/SidebarSettingsDemo && swift run --build-system native SidebarSettingsDemo
```

主窗口就是演示应用的控制面板：一个分组表单，里面有侧边栏图标、页面集合、分组、头部和底部，以及
`SidebarSettingsConfiguration` 的每一个选项的选择器或开关。**Open Settings**（Return 也可以）会应用
它们。窗口保留它构建时用的配置，所以应用一次改动就会关掉当前窗口、再建下一个。应用菜单里的 **Settings…**
条目（⌘,）打开屏幕上那个窗口。不带 `--scenario` 时，演示应用只显示控制面板。

演示应用在嵌入的 Info.plist 里声明了套件有的每一种语言，所以在下面的参数后面加上
`-AppleLanguages "(ja)"` 就能看到套件用日文写的文字；演示应用自己的文字仍是英文。

演示应用通过符号链接 `Sources/DemoFixtures` 把共用的 fixtures（`Tests/Fixtures/`）再编译一遍，作为
target `DemoFixtures`，所以它的页面就是测试用的那些页面。

### 参数

| 参数 | 取值 | 做什么 |
| --- | --- | --- |
| `--icons` | `plain`、`tiled` | `configuration.icons`；不带时是 `plain` |
| `--appearance` | `light`、`dark` | 强制 `NSApp.appearance`；不带时跟系统 |
| `--scenario` | `1` `2` `3` `4` `5` `6` `6b` `7` | 打开一个为某次检查配置好的设置窗口；不带时不打开 |
| `--window-id-file` | 一个路径 | 设置窗口上屏后把它的编号写到那里，供 `screencapture -l` 使用 |

未知参数，或者参数缺了取值，会把用法打到 stderr 并以 2 退出。单横线的参数连取值原样传下去，当作只在这次
启动有效的默认值：演示应用跳过 `-AppleLanguages "(zh-Hans)"`，由系统去读，不往应用的持久化 defaults 里
写任何东西。`-NSTableViewDefaultSizeMode 1`（小）、`2`（中）或 `3`（大）用同样的方式代替侧边栏图标大小
设置。

### 场景

| 场景 | 展示什么 |
| --- | --- |
| `1` | 三个页面，窗口停在短页面上，默认的 715 × 600 |
| `2` | 一个很长的分组表单，打开时在末尾，滚动到工具栏之下 |
| `3` | 40 多页的页面集合，打开在最后一页，侧边栏也滚到了那里 |
| `4` | 页面分成三组，用间距隔开 |
| `5` | 账户头部，以及作为底部的高登录区 |
| `6` | 能搜到页面的搜索 |
| `6b` | 搜不到任何页面的搜索 |
| `7` | 一个标题有 60 个字符的页面，以及套件用简体中文显示的文字（截图脚本会强制这个语言） |

`scripts/screenshots.sh` 会依次跑 `1 2 3 4 5 6 6b 7` 里的每个场景。某张截图对应哪个场景写在它的文件名里。

## 本地截图

```
make screenshots                        # all scenarios, both kinds of icons, both appearances
scripts/screenshots.sh OUT_DIR [scenario ...]
```

每种图标、每种外观和每个场景一张 PNG，命名成 `macos-<major>-<icons>-<appearance>-scenario-<n>.png`
放在输出目录里，例如 `macos-26-tiled-light-scenario-5.png`。脚本用 release 配置构建演示应用，每个组合跑
一次，等窗口编号出现，再用 `screencapture -o -l` 把窗口拷下来。它用 `--build-system native` 构建，
和 `make demo` 跑的一样：Swift 6.4 默认的构建系统会把可执行文件当成用 macOS 14 SDK 构建来链接，
macOS 27 于是把演示应用画成 macOS 26 之前的样子，灰的、没有玻璃。
场景 7 是用 `-AppleLanguages "(zh-Hans)"` 启动的，所以它的截图里是中文文字。

终端需要有 **Screen Recording** 权限（系统设置 > 隐私与安全性 > 屏幕录制）。没有这个权限时，
`screencapture` 返回的是桌面截图而不是窗口，脚本仍然报 `ok`。

本地截图只用来调试，从不提交：`screenshots/` 在 gitignore 里，README 里的图片只来自 CI 产物。

## CI

两个工作流，各自跑在 `macos-15` 和 `macos-26` 上；截图还会在 `xcode-27` 上跑。从 Xcode 27 起，GitHub 用
Xcode 的名字来命名 macOS 镜像：`xcode-27` 跑的是只装了 Xcode 27 的 macOS 27，所以那个 job 用镜像自带的
Xcode，而不是 `.xcode-version`。`make ci` 不在那里跑（见 [TESTING.md](TESTING.md) 的“环境”一节）。

| 工作流 | 触发 | 做什么 |
| --- | --- | --- |
| `.github/workflows/ci.yml` | pull request、推送到 `main` | 选中 `.xcode-version` 里的 Xcode，缓存 `.build`，跑 `make ci` |
| `.github/workflows/screenshots.yml` | pull request、手动触发 | 选中同一个 Xcode，关掉“减少透明度”和“减弱动态效果”，跑 `scripts/screenshots.sh screenshots`，上传 PNG |

GitHub 的 macOS 镜像默认打开减少透明度和减弱动态效果；Mac 上这两项是关的。打开减少透明度时，
macOS 26 和 27 不绘制玻璃，它们的系统设置即使在页面顶部也会在工具栏下方显示一条线，所以截图工作流
先把这两项关掉。

截图产物命名成 `screenshots-<runner>`（`screenshots-macos-15`、`screenshots-macos-26`、
`screenshots-xcode-27`），即使抓取失败也会上传，所以不完整的矩阵也能查看：

```
gh run download --name screenshots-macos-26 --dir shots
```

GitHub 已在 2026-11-02 停用 `macos-14` runner，所以 macOS 14 没有 CI。给 macOS 14 写的 `#available`
分支要保持小而清楚，并按 [ROADMAP.md](ROADMAP.md) 里 macOS 14 的限制来处理。

## 升级 Xcode

`.xcode-version` 是版本号唯一写下的地方：两个工作流都读它，runner 上没有这个版本时，job 会以一个点名该版本的
错误失败。要换到新的 Xcode，就编辑这个文件，确认 `macos-15` 和 `macos-26` 两个 runner 都装了这个应用，然后
提一个 pull request 让 CI 来证明。

## 发布

1. 把 `CHANGELOG.md` 里的 `## [Unreleased]` 改成版本号和日期，并在它上面留一个新的 `## [Unreleased]`。
2. 如果次版本号变了，更新提到它的 SwiftPM 片段：`README.md` 里的那个，以及
   `skills/sidebar-settings-kit/SKILL.md` 里的那个（`.upToNextMinor(from:)`）。
3. 在你手上每个 macOS 版本上跑一遍 [MANUAL-QA.md](MANUAL-QA.md) 里的检查。
4. 打 `X.Y.Z` 标签（不带 `v`）并推送这个标签。

打标签、推送和发布都要维护者先点头：它们是对外的动作，CI 不会替你完成。

## 文档

窗口是怎么搭起来的：[ARCHITECTURE.md](ARCHITECTURE.md)。测试 target、fixtures 和“假通过”规则：
[TESTING.md](TESTING.md)。

文档用英文写。中文副本（`README.zh-Hans.md`、`docs/zh/`）在英文改动之后按英文重新生成；不要手工编辑它们，也
不要为还没有副本的文档新建副本。
