# 开发

日常怎么开发本库：演示应用、截图、CI 和发布。

## 环境要求

| | |
| --- | --- |
| macOS | 14 或更高，这是跑你构建出来的东西的最低要求（部署目标）；14 上什么都不跑，CI 和人工都没有 |
| Xcode | 26.2，就是 `.xcode-version` 里那个版本 |
| Swift | 6.2（清单是 `swift-tools-version: 6.2`） |
| 依赖 | 无；包和演示应用都能离线构建 |

警告按错误处理：`-Xswiftc -warnings-as-errors` 写在 Makefile 里，从不写进 `Package.swift`，因为用了
`unsafeFlags` 的包没法被别人依赖。不要屏蔽警告，去修它。

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

`Examples/SidebarSettingsDemo/` 是一个独立包，按路径依赖根包，所以它跑的永远是你正在改的代码。它既用来
手动 QA，也是截图的来源；根包从不引用它。

```
make demo                 # or: cd Examples/SidebarSettingsDemo && swift run --build-system native SidebarSettingsDemo
```

主窗口就是演示应用的控制面板：一个分组表单，里面有侧边栏图标、页面集合、分组方式、头部和底部，以及
`SidebarSettingsConfiguration` 的每一个选项，各用一个选择器或开关来设。按 **Open Settings**（按 Return
也行）应用这些设置。窗口保留它构建时拿到的配置，所以每应用一次改动，当前窗口就关掉，再建一个新的。应用
菜单里的 **Settings…** 项（⌘,）打开屏幕上那个窗口。不带 `--scenario` 时，演示应用只显示控制面板。

演示应用在嵌入的 Info.plist 里声明了本库支持的每一种语言，所以在下面的参数后面加
`-AppleLanguages "(ja)"`，就能看到本库的文字变成日文；演示应用自己的文字仍然是英文。

演示应用通过符号链接 `Sources/DemoFixtures` 把共用的 fixtures（`Tests/Fixtures/`）再编译一遍，作为
target `DemoFixtures`，所以它用的页面就是测试用的那些。

### 参数

| 参数 | 取值 | 做什么 |
| --- | --- | --- |
| `--icons` | `plain`、`tiled` | `configuration.icons`；不带时是 `plain` |
| `--appearance` | `light`、`dark` | 强制设定 `NSApp.appearance`；不带时跟系统 |
| `--scenario` | `1` `2` `3` `4` `5` `6` `6b` `7` | 打开一个为某次检查配置好的设置窗口；不带时不打开 |
| `--window-id-file` | 一个路径 | 设置窗口上屏后把它的编号写进去，供 `screencapture -l` 使用 |

参数不认识，或者参数缺了取值，就把用法打到 stderr 并以 2 退出。单横线参数连取值一起原样传给系统，当作
只对这次启动有效的默认值：演示应用放过 `-AppleLanguages "(zh-Hans)"`，由系统去读，应用的持久化
defaults 里一个字节都不写。`-NSTableViewDefaultSizeMode 1`（小）、`2`（中）、`3`（大）也用同样的方式
代替侧边栏图标大小设置。

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
| `7` | 一个标题有 60 个字符的页面，以及本库用简体中文显示的文字（截图脚本会强制这个语言） |

`scripts/screenshots.sh` 会跑 `1 2 3 4 5 6 6b 7` 里的每一个场景。某张截图是哪个场景，看文件名就知道。

## 本地截图

```
make screenshots                        # all scenarios, both kinds of icons, both appearances
scripts/screenshots.sh OUT_DIR [scenario ...]
```

每种图标、每种外观、每个场景各一张 PNG，放在输出目录里，命名成
`macos-<major>-<icons>-<appearance>-scenario-<n>.png`，例如 `macos-26-tiled-light-scenario-5.png`。
脚本用 release 配置构建演示应用，每个组合跑一次，等窗口编号出现，再用 `screencapture -o -l` 把窗口拷
下来。它用 `--build-system native` 构建，和 `make demo` 一样：Swift 6.4 默认的构建系统会把可执行文件
当成用 macOS 14 SDK 构建来链接，macOS 27 于是把演示应用画成 macOS 26 之前的样子，灰的、没有玻璃。
场景 7 带 `-AppleLanguages "(zh-Hans)"` 启动，所以它的截图里是中文。

终端需要有 **屏幕录制** 权限（系统设置 > 隐私与安全性 > 屏幕录制）。没有这个权限时，`screencapture`
拿回来的是桌面而不是窗口，脚本照样报 `ok`。

本地截图只用来调试，从不提交：`screenshots/` 在 gitignore 里，README 里的图片只来自 CI 产物。

## CI

两个工作流，都跑在 `macos-15` 和 `macos-26` 上；截图还多一个 `xcode-27`。从 Xcode 27 起，GitHub 按
Xcode 的版本给 macOS 镜像命名：`xcode-27` 跑的是只装了 Xcode 27 的 macOS 27，所以那个 job 用的是镜像
自带的 Xcode，不是 `.xcode-version`。`make ci` 不在那里跑（见 [TESTING.md](TESTING.md) 的“环境”一节）。

| 工作流 | 触发 | 做什么 |
| --- | --- | --- |
| `.github/workflows/ci.yml` | pull request、推送到 `main` | 选中 `.xcode-version` 里的 Xcode，缓存 `.build`，跑 `make ci` |
| `.github/workflows/screenshots.yml` | pull request、手动触发 | 选中同一个 Xcode，关掉减弱透明度和减弱动态效果，设好默认墙纸，跑 `scripts/screenshots.sh screenshots`，上传 PNG |

GitHub 的 macOS 镜像默认打开减弱透明度和减弱动态效果，Mac 上这两项是关的。打开减弱透明度之后，macOS 26
和 27 不画玻璃，系统设置即使在页面顶部也会在工具栏下面显示一条线，所以截图工作流先把这两项关掉。

这些镜像还把墙纸设成纯黑。窗口会从背后的墙纸上取色调，所以在黑底上，侧边栏和页面拍出来是一片更暗、更平
的灰，和 Mac 上不一样：macOS 15 上页面是 238 灰，而用默认墙纸的 Mac 上是 244。截图工作流在抓图之前，把
`/System/Library/CoreServices/DefaultDesktop.heic` 指向的那张墙纸设上，也就是所跑的那个 macOS 的默认
墙纸。

runner 上唯一的显示器是 1024 × 768，1x，也就是一个点一个像素：默认窗口截出来就是 715 × 600 像素，而在
Retina Mac 上是 1430 × 1200。也试过 2x 的虚拟显示器：CoreGraphics 能在 runner 上建出来，却给不了它
显示模式，所以 README 里的 1x 图片就按原尺寸放着，不再缩小。

截图产物命名成 `screenshots-<runner>`（`screenshots-macos-15`、`screenshots-macos-26`、
`screenshots-xcode-27`），抓取失败也会上传，所以不完整的矩阵也能查看：

```
gh run download --name screenshots-macos-26 --dir shots
```

GitHub 在 2026-11-02 停用了 `macos-14` runner，也没人手工跑 macOS 14，所以 14 上什么都不跑。本库仍然为
部署目标 macOS 14 构建，给 14 写的 `#available` 分支也保持简短明了；由此带来的限制记在
[ROADMAP.md](ROADMAP.md) 里。

## 升级 Xcode

版本号只写在 `.xcode-version` 一处：两个工作流都读它，runner 上没有这个版本时，job 会直接报错，错误里
带着这个版本号。要换新 Xcode，就改这个文件，确认 `macos-15` 和 `macos-26` 两个 runner 都装了它，然后提
一个 pull request 让 CI 来验证。

## 发布

1. 把 `CHANGELOG.md` 里的 `## [Unreleased]` 改成版本号和日期，并在它上面留一个新的 `## [Unreleased]`。
2. 次版本号变了的话，更新提到它的 SwiftPM 片段：`README.md` 里的那个，以及
   `skills/sidebar-settings-kit/SKILL.md` 里的那个（`.upToNextMinor(from:)`）。
3. 在你手上每个 macOS 版本上跑一遍 [MANUAL-QA.md](MANUAL-QA.md) 里的检查。
4. 打 `X.Y.Z` 标签（不带 `v`）并推送这个标签。

打标签、推送和发布都要维护者先点头：它们是对外的动作，CI 不会替你完成。

## 文档

窗口是怎么搭起来的：[ARCHITECTURE.md](ARCHITECTURE.md)。测试 target、fixtures 和“假通过”规则：
[TESTING.md](TESTING.md)。

文档用英文写。中文副本（`README.zh-Hans.md`、`docs/zh/`）在英文改动之后按英文重新生成；不要手工编辑
它们，也不要给还没有副本的文档新建一份。
