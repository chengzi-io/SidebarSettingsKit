import SidebarSettingsKit
import SwiftUI

/// A page the unit tests and the demo put in the sidebar.
///
/// A struct rather than an enum, so a fixture set can hold any number of pages, including the
/// 40 of ``FixturePages/many``. Its icon is written down as ``FixtureIconDescription``, plain
/// `Sendable` values, because `SettingsIcon` is neither `Sendable` nor cheap to build.
public struct FixturePage: SettingsPage {
    /// How tall the page's detail is, which decides what ``FixtureDetail`` shows.
    public enum ContentKind: Sendable, Hashable {
        /// A detail shorter than the window, so the page never scrolls.
        case short
        /// A detail several times the window's height, so the page scrolls.
        case long
    }

    /// The page's identity, which the sidebar uses to tell rows apart.
    public let id: String

    /// The page's name in its sidebar row.
    public let title: LocalizedStringResource

    /// More words the sidebar's search matches the page by.
    public let searchKeywords: [String]

    /// The page's icon, written down as values rather than as a `SettingsIcon`.
    public let iconDescription: FixtureIconDescription

    /// How tall the page's detail is.
    public let contentKind: ContentKind

    /// A page with `id`, `title`, `searchKeywords` and an icon to draw.
    public init(
        id: String,
        title: LocalizedStringResource,
        searchKeywords: [String] = [],
        iconDescription: FixtureIconDescription = .system(name: "gearshape"),
        contentKind: ContentKind = .short
    ) {
        self.id = id
        self.title = title
        self.searchKeywords = searchKeywords
        self.iconDescription = iconDescription
        self.contentKind = contentKind
    }

    /// A page is its ``id``: two pages with the same id are the same row, whatever their
    /// other fields say. The title cannot join the synthesis because
    /// `LocalizedStringResource` is not `Hashable`.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    @MainActor public var icon: SettingsIcon {
        switch iconDescription {
        case .system(let name, let tint, let renderingMode, let isFilled, let weight):
            .system(
                name,
                tint: tint?.color,
                renderingMode: renderingMode?.symbolRenderingMode,
                variant: isFilled ? .fill : .none,
                weight: weight?.fontWeight
            )
        case .image(let tint):
            .image(Image(systemName: "photo"), tint: tint?.color)
        case .custom:
            .custom(Circle().fill(Color.orange))
        }
    }
}

/// A page's icon written down as plain values, so a page stays `Sendable`: `SettingsIcon` is
/// not, and building one touches the main actor.
public enum FixtureIconDescription: Sendable, Hashable {
    /// An SF Symbol, the form most pages use.
    case system(
        name: String,
        tint: FixtureTint? = nil,
        renderingMode: FixtureRenderingMode? = nil,
        isFilled: Bool = false,
        weight: FixtureSymbolWeight? = nil
    )
    /// An image rather than a symbol, built from `Image(systemName:)` because the fixtures
    /// carry no asset catalog.
    case image(tint: FixtureTint? = nil)
    /// A view of the page's own, drawn in the icon's box.
    case custom
}

/// A color an icon is tinted with.
public enum FixtureTint: Sendable, Hashable {
    case blue, orange, red

    /// The tint's SwiftUI color.
    public var color: Color {
        switch self {
        case .blue: .blue
        case .orange: .orange
        case .red: .red
        }
    }
}

/// A symbol rendering mode an icon is drawn in.
public enum FixtureRenderingMode: Sendable, Hashable {
    case monochrome, hierarchical, palette, multicolor

    /// The rendering mode's SwiftUI value.
    public var symbolRenderingMode: SymbolRenderingMode {
        switch self {
        case .monochrome: .monochrome
        case .hierarchical: .hierarchical
        case .palette: .palette
        case .multicolor: .multicolor
        }
    }
}

/// A symbol's stroke weight.
public enum FixtureSymbolWeight: Sendable, Hashable {
    case bold

    /// The weight's SwiftUI value.
    public var fontWeight: Font.Weight {
        switch self {
        case .bold: .bold
        }
    }
}
