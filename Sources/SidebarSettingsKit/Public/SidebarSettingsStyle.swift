import SwiftUI

/// How the sidebar's rows look: their font and icons.
///
/// Every style keeps the system's sidebar list, so selection, arrow keys, type-to-select and
/// VoiceOver behave as in any Mac sidebar; no token changes the selection. A row is as tall as
/// its content plus the list's padding, so a larger icon tile makes a taller row.
///
/// Start from a preset and change what you need:
///
/// ```swift
/// var style = SidebarSettingsStyle.branded
/// style.iconTile = .init(size: 28, cornerRadius: 7, defaultColor: .indigo)
/// ```
///
/// No preset changes the sidebar's material, so on macOS 26 it keeps the system's Liquid
/// Glass. Pages can read the style from the environment, ``SwiftUICore/EnvironmentValues/sidebarSettingsStyle``,
/// to match it.
public struct SidebarSettingsStyle: Sendable, Equatable {
    /// The rows' font; `nil` keeps the system's, which follows the user's sidebar icon size
    /// setting.
    public var rowFont: Font?

    /// The icon's size in points: the symbol's size, and the box an image or custom icon
    /// fits in. `nil` keeps the system's symbol size, with images 16 points.
    public var iconSize: CGFloat?

    /// A colored rounded square behind each icon, as in System Settings on macOS 26 or
    /// CleanShot X; `nil` draws the bare icon.
    public var iconTile: IconTile?

    /// A style from its tokens; every token you leave out matches ``native``.
    public init(
        rowFont: Font? = nil,
        iconSize: CGFloat? = nil,
        iconTile: IconTile? = nil
    ) {
        self.rowFont = rowFont
        self.iconSize = iconSize
        self.iconTile = iconTile
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

    /// The system's sidebar, untouched. The default.
    public static let native = Self()

    /// A livelier sidebar after CleanShot X: icons on colored tiles, which make the rows
    /// taller, and larger text.
    public static let branded = Self(
        rowFont: .system(size: 14, weight: .medium),
        iconSize: 14,
        iconTile: IconTile(size: 24, cornerRadius: 6, defaultColor: .gray)
    )
}

extension EnvironmentValues {
    /// The settings window's sidebar style, for pages that want to match it.
    @Entry public var sidebarSettingsStyle = SidebarSettingsStyle.native
}
