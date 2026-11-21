import SwiftUI

/// A page's icon as the sidebar draws it: alone, or on a colored tile. A bare icon takes its
/// tint from the row (`listItemTint`), so it turns white with the title when the row is selected.
struct SettingsIconView: View {
    let icon: SettingsIcon
    let icons: SidebarSettingsConfiguration.Icons

    @Environment(\.sidebarRowSize) private var rowSize

    var body: some View {
        switch icon.content {
        case .custom(let view):
            view.frame(width: slot, height: slot)
        case .image(let image):
            let image = image.resizable().scaledToFit()
            if case .tiled(let defaultColor) = icons {
                onTile(image.frame(width: glyph, height: glyph), defaultColor)
            } else {
                image.frame(width: slot, height: slot)
            }
        case .system(let name, let renderingMode, let variant, let weight):
            let symbol = Image(systemName: name)
                .symbolVariant(variant)
                .symbolRenderingMode(renderingMode)
                .fontWeight(weight)
            if case .tiled(let defaultColor) = icons {
                // The sidebar list on macOS 27 asks its rows for a large image scale, which drew
                // the symbol to the tile's edges; the tile keeps the scale it has on 14 to 26.
                onTile(symbol.font(.system(size: glyph)).imageScale(.medium), defaultColor)
            } else {
                symbol
            }
        }
    }

    /// The side of the sidebar's icon slot, which the user's Sidebar icon size setting picks.
    /// Measured on the system's sidebar list; System Settings' tiles fill the same slot.
    private var slot: CGFloat {
        switch rowSize {
        case .small: 16
        case .medium: 20
        case .large: 24
        @unknown default: 20
        }
    }

    /// The symbol or image on a tile: 60 percent of the tile's side, as in System Settings.
    private var glyph: CGFloat { slot * 0.6 }

    /// `glyph` in white on a tile that fills the slot, its corners a quarter of its side, as in
    /// System Settings, in the icon's tint or else `defaultColor`.
    private func onTile(_ glyph: some View, _ defaultColor: Color) -> some View {
        glyph
            .foregroundStyle(.white)
            .frame(width: slot, height: slot)
            .background(
                RoundedRectangle(cornerRadius: slot / 4, style: .continuous)
                    .fill((icon.tint ?? defaultColor).gradient)
            )
    }
}
