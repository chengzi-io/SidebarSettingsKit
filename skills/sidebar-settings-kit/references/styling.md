# Styling

The sidebar is always the system's sidebar list, with its selection, keyboard, type-to-select and
VoiceOver; on macOS 26 and later it keeps the system's Liquid Glass. What the kit lets you choose
is how it draws the pages' icons. The pages are the app's own views: the kit adds no background,
form or font to them.

## Pick the icons

`configuration.icons`:

| | `.plain` (default) | `.tiled` |
| --- | --- | --- |
| Look | the system sidebar, untouched | icons in white on colored rounded squares, as in System Settings |
| Color | the icon's `tint`, or the sidebar's; white on the selected row | the tile is the icon's `tint`, or gray; `.tiled(defaultColor: .indigo)` picks another for icons without a tint |
| Rows | system height and font | the same |
| Suits | tools, utilities, developer apps | consumer apps with a brand |

```swift
var configuration = SidebarSettingsConfiguration()
configuration.icons = .tiled
let settings = SidebarSettingsWindow(pages: SettingsPane.allCases, configuration: configuration) { pane in
    SettingsPaneView(pane: pane)
}
```

Every icon, plain or on a tile, fills the sidebar's icon slot: 16, 20 or 24 pt, as the user's
Sidebar icon size setting picks. So the rows keep the system's height and follow that setting,
and the kit has no icon size, font or row height option.

## Icons

```swift
.system("gearshape")                                   // bare symbol in the sidebar's color
.system("bell.badge", tint: .red)                      // red symbol; on a tile: red tile, white symbol
.system("cloud", renderingMode: .hierarchical, variant: .fill, weight: .semibold)
.image(Image("AppLogo"))                               // an asset, scaled to fit
.image(Image("Mono"), tint: .green)                    // a template image tinted; on a tile: green tile
.custom(MyBadgeView())                                 // any view, drawn as is, never on a tile
```

An icon has no size of its own. With `.tiled`, give each page a distinct `tint`, as System
Settings colors its tiles; pages without one get gray or the `defaultColor`.

## Header and footer

```swift
SidebarSettingsWindow(
    pages: SettingsPane.allCases,
    header: { AccountRow(account: model.account) },
    footer: { Text("Version \(appVersion)").font(.caption).foregroundStyle(.secondary).padding(10) }
) { pane in
    SettingsPaneView(pane: pane)
}
```

The header is the list's first item and scrolls with the pages, as the account row does in
System Settings. The footer stays at the bottom while the pages scroll above it; keep it short,
it takes space from the list.

## The pages

For System Settings' look, make each page a `Form` with `.formStyle(.grouped)`.
