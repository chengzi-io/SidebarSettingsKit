# Styling

`SidebarSettingsStyle` changes how the sidebar looks; it never changes the sidebar's material,
so on macOS 26 the system's Liquid Glass stays. The pages are the app's own views: the kit adds
no background, form or font to them.

## Pick a preset

| | `.native` (default) | `.branded` |
| --- | --- | --- |
| Look | the system sidebar, untouched | after CleanShot X: icons on colored tiles |
| Rows | system height and font; follows the user's sidebar icon size setting | as tall as the tiles need, 14 pt medium text |
| Icons | bare SF Symbols in the accent color, or their tint | white symbols on 24 pt tiles in the page's tint |
| Selection | the system highlight | the system highlight |
| Suits | tools, utilities, developer apps | consumer apps with a brand |

On macOS 14 and 15 `.native` stays the plain system sidebar; it is not dressed up. Choose
`.branded` for a more designed look on every version.

## Adjust a preset

The style is a value: copy a preset and change tokens. The preset itself does not change.

```swift
var style = SidebarSettingsStyle.branded
style.iconTile = .init(size: 28, cornerRadius: 7, defaultColor: .indigo)
let settings = SidebarSettingsWindow(pages: SettingsPane.allCases, style: style) { pane in
    SettingsPaneView(pane: pane)
}
```

| Token | `.native` | `.branded` | Effect |
| --- | --- | --- | --- |
| `rowFont` | `nil` (system) | `.system(size: 14, weight: .medium)` | the row's title font |
| `iconSize` | `nil` (system) | 14 | the symbol's point size; the box for images and custom icons (16 when `nil`) |
| `iconTile` | `nil` | size 24, radius 6, gray | a rounded square behind each icon |

Every style is the system's sidebar list: selection, arrow keys, type-to-select and VoiceOver
come from it, and no token changes the selection's shape or color. A row is as tall as its
content plus the list's padding: for taller rows, use a larger tile.

## Icons

```swift
.system("gearshape")                                   // bare symbol in the sidebar's color
.system("bell.badge", tint: .red)                      // red symbol; on a tile: red tile, white symbol
.system("cloud", renderingMode: .hierarchical, variant: .fill, weight: .semibold)
.image(Image("AppLogo"))                               // an asset, scaled to fit
.image(Image("Mono"), tint: .green)                    // a template image tinted; on a tile: green tile
.custom(MyBadgeView())                                 // any view, drawn as is, no tile
```

Every row's icon gets the same size from the style; an icon has no size of its own. With
`.branded`, give each page a distinct `tint`, as System Settings colors its tiles; pages without
one use the tile's `defaultColor`.

## Header and footer

```swift
SidebarSettingsWindow(
    pages: SettingsPane.allCases,
    style: .branded,
    header: { AccountRow(account: model.account) },
    footer: { Text("Version \(appVersion)").font(.caption).foregroundStyle(.secondary).padding(10) }
) { pane in
    SettingsPaneView(pane: pane)
}
```

The header is the list's first item and scrolls with the pages, as the account row does in
System Settings. The footer stays at the bottom while the pages scroll above it; keep it short,
it takes space from the list.

## Match the pages to the sidebar

Pages can read the style to share its tokens:

```swift
struct SettingsPaneView: View {
    @Environment(\.sidebarSettingsStyle) private var style
    var body: some View {
        Form { /* ... */ }
            .formStyle(.grouped)
            .font(style.rowFont)
    }
}
```

For System Settings' look, make each page a `Form` with `.formStyle(.grouped)`.
