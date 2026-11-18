import SwiftUI

/// How the sidebar looks: its rows, icons and selection.
///
/// Start from a preset and change what you need:
///
/// ```swift
/// var style = SidebarSettingsStyle.branded
/// style.rowHeight = 36
/// ```
///
/// No preset changes the sidebar's material, so on macOS 26 it keeps the system's Liquid
/// Glass. Pages can read the style from the environment, ``SwiftUICore/EnvironmentValues/sidebarSettingsStyle``,
/// to match it.
public struct SidebarSettingsStyle: Sendable, Equatable {
    /// Each row's height; `nil` keeps the system's.
    public var rowHeight: CGFloat?

    /// The rows' font; `nil` keeps the system's, which follows the user's sidebar icon size
    /// setting.
    public var rowFont: Font?

    /// The icon's size in points: the symbol's size, and the box an image or custom icon
    /// fits in. `nil` keeps the system's symbol size, with images 16 points.
    public var iconSize: CGFloat?

    /// A colored rounded square behind each icon, as in System Settings on macOS 26 or
    /// CleanShot X; `nil` draws the bare icon.
    public var iconTile: IconTile?

    /// The selected row's highlight.
    public var selectionShape: SelectionShape

    /// The space between rows; `nil` keeps the system's. Applies with a
    /// ``SelectionShape/rounded(radius:)`` selection, where the kit draws the rows.
    public var rowSpacing: CGFloat?

    /// Space around the rows, inside the sidebar; `nil` keeps the system's.
    public var sidebarInsets: EdgeInsets?

    /// A style from its tokens; every token you leave out matches ``native``.
    public init(
        rowHeight: CGFloat? = nil,
        rowFont: Font? = nil,
        iconSize: CGFloat? = nil,
        iconTile: IconTile? = nil,
        selectionShape: SelectionShape = .system,
        rowSpacing: CGFloat? = nil,
        sidebarInsets: EdgeInsets? = nil
    ) {
        self.rowHeight = rowHeight
        self.rowFont = rowFont
        self.iconSize = iconSize
        self.iconTile = iconTile
        self.selectionShape = selectionShape
        self.rowSpacing = rowSpacing
        self.sidebarInsets = sidebarInsets
    }

    /// A colored rounded square behind an icon.
    public struct IconTile: Sendable, Equatable {
        /// The square's side in points.
        public var size: CGFloat
        /// The square's corner radius in points.
        public var cornerRadius: CGFloat
        /// The square's color for an icon without a tint.
        public var defaultColor: Color

        /// A tile of `size` points with corners of `cornerRadius`.
        public init(size: CGFloat = 24, cornerRadius: CGFloat = 6, defaultColor: Color = .gray) {
            self.size = size
            self.cornerRadius = cornerRadius
            self.defaultColor = defaultColor
        }
    }

    /// The selected row's highlight.
    public enum SelectionShape: Sendable, Equatable {
        /// The system's sidebar highlight, in a system `List`.
        case system
        /// A rounded rectangle in the accent color, drawn by the kit, which then lays the
        /// rows out itself.
        case rounded(radius: CGFloat)
    }

    /// The system's sidebar, untouched. The default.
    public static let native = Self()

    /// A livelier sidebar after CleanShot X: icons on colored tiles, taller rows, larger
    /// text and a rounded selection.
    public static let branded = Self(
        rowHeight: 32,
        rowFont: .system(size: 14, weight: .medium),
        iconSize: 14,
        iconTile: IconTile(size: 24, cornerRadius: 6, defaultColor: .gray),
        selectionShape: .rounded(radius: 8),
        rowSpacing: 2,
        sidebarInsets: EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
    )
}

extension EnvironmentValues {
    /// The settings window's sidebar style, for pages that want to match it.
    @Entry public var sidebarSettingsStyle = SidebarSettingsStyle.native
}
