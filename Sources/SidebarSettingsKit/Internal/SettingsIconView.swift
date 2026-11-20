import SwiftUI

/// A page's icon as the sidebar draws it: alone, or on a colored tile. A bare icon takes its
/// tint from the row (`listItemTint`), so it turns white with the title when the row is selected.
struct SettingsIconView: View {
    let icon: SettingsIcon
    let icons: SidebarSettingsConfiguration.Icons

    @Environment(\.sidebarRowSize) private var rowSize
    @Environment(\.imageScale) private var probeImageScale
    @Environment(\.font) private var probeFont
    @Environment(\.controlSize) private var probeControlSize

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
                probeTiled(
                    name: name, symbol: symbol,
                    fit: Image(systemName: name).resizable().scaledToFit().symbolVariant(variant)
                        .symbolRenderingMode(renderingMode).fontWeight(weight),
                    defaultColor)
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

    // Probe only: SSK_PROBE_ICON picks how the symbol is sized on its tile.
    @ViewBuilder
    private func probeTiled(name: String, symbol: some View, fit: some View, _ defaultColor: Color) -> some View {
        let mode = ProcessInfo.processInfo.environment["SSK_PROBE_ICON"] ?? "font"
        Group {
            switch mode {
            case "medium": onTile(symbol.font(.system(size: glyph)).imageScale(.medium), defaultColor)
            case "small": onTile(symbol.font(.system(size: glyph)).imageScale(.small), defaultColor)
            case "fit": onTile(fit.frame(width: glyph, height: glyph), defaultColor)
            default: onTile(symbol.font(.system(size: glyph)), defaultColor)
            }
        }
        .onAppear {
            guard let path = ProcessInfo.processInfo.environment["SSK_PROBE_DUMP"] else { return }
            let config = NSImage.SymbolConfiguration(pointSize: glyph, weight: .regular)
            let size = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(config)?.size ?? .zero
            probeAppend(
                "icon \(name) mode \(mode) slot \(slot) glyph \(glyph) rowSize \(rowSize) imageScale \(probeImageScale) controlSize \(probeControlSize) font \(probeFont.map { "\($0)" } ?? "nil") nsimage \(size)",
                to: path)
        }
    }
}

