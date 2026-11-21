import SwiftUI

/// The image in a page's sidebar row: an SF Symbol, an image, or any view.
///
/// Every icon fills the sidebar's icon slot, which follows the user's Sidebar icon size setting,
/// so an icon carries no size of its own. ``SidebarSettingsConfiguration/icons`` decides
/// whether it sits on a colored tile.
public struct SettingsIcon {
    enum Content {
        case system(
            name: String,
            renderingMode: SymbolRenderingMode?,
            variant: SymbolVariants,
            weight: Font.Weight?
        )
        case image(Image)
        case custom(AnyView)
    }

    let content: Content
    let tint: Color?

    /// An SF Symbol.
    ///
    /// - Parameters:
    ///   - name: the symbol's name, such as `"gearshape"`.
    ///   - tint: the symbol's color, white on the selected row as the title is; with
    ///     ``SidebarSettingsConfiguration/Icons/tiled(defaultColor:)``, the tile's color, with
    ///     the symbol in white. `nil` keeps the sidebar's default color, or the tile's
    ///     `defaultColor`.
    ///   - renderingMode: monochrome, hierarchical, palette or multicolor; `nil` keeps the
    ///     sidebar's default.
    ///   - variant: such as `.fill`.
    ///   - weight: the stroke weight; `nil` follows the row's text.
    public static func system(
        _ name: String,
        tint: Color? = nil,
        renderingMode: SymbolRenderingMode? = nil,
        variant: SymbolVariants = .none,
        weight: Font.Weight? = nil
    ) -> Self {
        Self(
            content: .system(name: name, renderingMode: renderingMode, variant: variant, weight: weight),
            tint: tint
        )
    }

    /// An image, such as the app's logo from an asset catalog. It is scaled to fit the
    /// icon's size.
    ///
    /// - Parameter tint: the color of a template image, white on the selected row; with
    ///   ``SidebarSettingsConfiguration/Icons/tiled(defaultColor:)``, the tile's color.
    public static func image(_ image: Image, tint: Color? = nil) -> Self {
        Self(content: .image(image), tint: tint)
    }

    /// Any view, drawn as it is in a frame of the icon's size, without a tile.
    @MainActor
    public static func custom(_ view: some View) -> Self {
        Self(content: .custom(AnyView(view)), tint: nil)
    }
}
