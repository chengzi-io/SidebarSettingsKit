import SwiftUI

/// A page's icon as the style draws it: bare, or on a colored tile.
struct SettingsIconView: View {
    let icon: SettingsIcon
    let style: SidebarSettingsStyle

    /// The box an image or a custom icon fits in when the style sets no size.
    private static let defaultImageSize: CGFloat = 16

    var body: some View {
        switch icon.content {
        case .custom(let view):
            let side = style.iconTile?.size ?? style.iconSize ?? Self.defaultImageSize
            view.frame(width: side, height: side)
        case .image(let image):
            if let tile = style.iconTile {
                image.resizable().scaledToFit()
                    .foregroundStyle(.white)
                    .frame(width: style.iconSize ?? tile.size * 0.6, height: style.iconSize ?? tile.size * 0.6)
                    .frame(width: tile.size, height: tile.size)
                    .background(tileShape(tile).fill((icon.tint ?? tile.defaultColor).gradient))
            } else {
                let side = style.iconSize ?? Self.defaultImageSize
                image.resizable().scaledToFit()
                    .tinted(icon.tint)
                    .frame(width: side, height: side)
            }
        case .system(let name, let renderingMode, let variant, let weight):
            let symbol = Image(systemName: name)
                .symbolVariant(variant)
                .symbolRenderingMode(renderingMode)
                .fontWeight(weight)
            if let tile = style.iconTile {
                symbol
                    .font(.system(size: style.iconSize ?? tile.size * 0.6))
                    .foregroundStyle(.white)
                    .frame(width: tile.size, height: tile.size)
                    .background(tileShape(tile).fill((icon.tint ?? tile.defaultColor).gradient))
            } else if let size = style.iconSize {
                symbol.font(.system(size: size)).tinted(icon.tint)
            } else {
                symbol.tinted(icon.tint)
            }
        }
    }

    private func tileShape(_ tile: SidebarSettingsStyle.IconTile) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: tile.cornerRadius, style: .continuous)
    }
}

extension View {
    @ViewBuilder
    fileprivate func tinted(_ tint: Color?) -> some View {
        if let tint {
            foregroundStyle(tint)
        } else {
            self
        }
    }
}
