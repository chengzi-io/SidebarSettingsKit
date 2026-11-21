import Foundation

/// One page per `SettingsIcon` form, so a sidebar can be compared against every case the API
/// draws: plain and tinted symbols, each rendering mode, a filled and a bold symbol, an image
/// with and without a tint, and a view of the page's own.
public enum FixtureIconPages {
    /// A plain symbol, drawn in the sidebar's default color.
    public static let plainSymbol = FixturePage(
        id: "icon-plain-symbol",
        title: "Plain Symbol",
        iconDescription: .system(name: "gearshape")
    )

    /// A symbol with a tint, which tiled icons turn into the tile's color.
    public static let tintedSymbol = FixturePage(
        id: "icon-tinted-symbol",
        title: "Tinted Symbol",
        iconDescription: .system(name: "gearshape", tint: .orange)
    )

    /// A monochrome symbol.
    public static let monochrome = FixturePage(
        id: "icon-monochrome",
        title: "Monochrome",
        iconDescription: .system(name: "person.crop.circle", renderingMode: .monochrome)
    )

    /// A hierarchical symbol, whose layers shade one another.
    public static let hierarchical = FixturePage(
        id: "icon-hierarchical",
        title: "Hierarchical",
        iconDescription: .system(name: "person.crop.circle", renderingMode: .hierarchical)
    )

    /// A palette symbol, drawn in more than one color.
    public static let palette = FixturePage(
        id: "icon-palette",
        title: "Palette",
        iconDescription: .system(name: "person.crop.circle", renderingMode: .palette)
    )

    /// A multicolor symbol, in each of its colors.
    public static let multicolor = FixturePage(
        id: "icon-multicolor",
        title: "Multicolor",
        iconDescription: .system(name: "person.crop.circle", renderingMode: .multicolor)
    )

    /// A filled symbol variant.
    public static let filled = FixturePage(
        id: "icon-filled",
        title: "Filled",
        iconDescription: .system(name: "star", isFilled: true)
    )

    /// A bold symbol, with a heavier stroke than the row's text.
    public static let bold = FixturePage(
        id: "icon-bold",
        title: "Bold",
        iconDescription: .system(name: "wifi", weight: .bold)
    )

    /// An image without a tint.
    public static let image = FixturePage(
        id: "icon-image",
        title: "Image",
        iconDescription: .image()
    )

    /// An image with a tint.
    public static let tintedImage = FixturePage(
        id: "icon-tinted-image",
        title: "Tinted Image",
        iconDescription: .image(tint: .red)
    )

    /// A view of the page's own, drawn in the icon's box.
    public static let custom = FixturePage(
        id: "icon-custom",
        title: "Custom",
        iconDescription: .custom
    )

    /// Every icon form, one page each.
    public static let all: [FixturePage] = [
        plainSymbol, tintedSymbol, monochrome, hierarchical, palette, multicolor, filled, bold,
        image, tintedImage, custom,
    ]
}
