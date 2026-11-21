import Foundation
import SwiftUI

/// How the settings window behaves. Every option defaults to what System Settings does;
/// change only the ones you need.
///
/// ```swift
/// var configuration = SidebarSettingsConfiguration()
/// configuration.resizing = .resizable(min: CGSize(width: 600, height: 400))
/// configuration.title = .fixed("Settings")
/// ```
public struct SidebarSettingsConfiguration: Sendable {
    /// The window's content size when it first opens. Default 715 × 600, System Settings'
    /// width with a height that fits a 13-inch screen.
    public var size = CGSize(width: 715, height: 600)

    /// Whether the window can be resized. Default ``Resizing/fixed``.
    public var resizing = Resizing.fixed

    /// The name AppKit saves the window's position under, so it reopens where it was
    /// left, across launches. `nil` saves nothing. Default `"SidebarSettingsWindow"`.
    public var autosaveName: String? = "SidebarSettingsWindow"

    /// The sidebar's width. Default ``SidebarWidth/fixed(_:)`` 215. The sidebar never
    /// collapses.
    public var sidebarWidth = SidebarWidth.fixed(215)

    /// The toolbar's look. Default ``ToolbarStyle/automatic``.
    public var toolbarStyle = ToolbarStyle.automatic

    /// Whether the toolbar shows back and forward buttons. Default `true`.
    public var showsNavigationButtons = true

    /// The window's title. Default ``TitleMode/followsPage``.
    public var title = TitleMode.followsPage

    /// Whether the sidebar has a search field. Default ``SearchMode/enabled``. To change
    /// what a search finds, implement ``SettingsPage/matches(searchText:)``.
    public var search = SearchMode.enabled

    /// What the window shows when it opens again. Default ``NavigationPersistence/session``.
    public var navigationPersistence = NavigationPersistence.session

    /// The words the window shows. Default ``Strings/default``, in every language macOS has.
    public var strings = Strings.default

    /// How the sidebar draws the pages' icons. Default ``Icons/plain``.
    public var icons = Icons.plain

    /// The defaults, which match System Settings.
    public init() {}

    /// Whether the window can be resized.
    public enum Resizing: Sendable, Equatable {
        /// The window keeps ``SidebarSettingsConfiguration/size``.
        case fixed
        /// The window can be resized between `min` and `max`; `nil` sets no limit.
        case resizable(min: CGSize? = nil, max: CGSize? = nil)
    }

    /// The sidebar's width.
    public enum SidebarWidth: Sendable, Equatable {
        /// A width the divider cannot change.
        case fixed(CGFloat)
        /// A width the divider can change between `min` and `max`, starting at `ideal`.
        case adjustable(min: CGFloat, ideal: CGFloat, max: CGFloat)
    }

    /// The toolbar's look, named after AppKit's styles. The others do not suit a window with
    /// a sidebar and back and forward buttons.
    public enum ToolbarStyle: Sendable, CaseIterable {
        /// One row with the title and buttons, as in System Settings. On macOS 26 the window
        /// uses ``automatic`` instead: there AppKit starts the sidebar below a compact toolbar
        /// rather than under it.
        case unifiedCompact
        /// One taller row with the title and buttons.
        case unified
        /// The system's choice for the window: on macOS 15, the same as ``unified``.
        case automatic
    }

    /// The window's title.
    public enum TitleMode: Sendable, Equatable {
        /// The selected page's ``SettingsPage/title``.
        case followsPage
        /// The same title on every page.
        case fixed(LocalizedStringResource)
        /// No title in the toolbar. The Window menu and VoiceOver still name the window
        /// after the selected page.
        case hidden
    }

    /// Whether the sidebar has a search field.
    public enum SearchMode: Sendable {
        /// A search field above the pages, which keeps the pages that
        /// ``SettingsPage/matches(searchText:)``. ⌘F focuses it, Esc clears it.
        case enabled
        /// No search field.
        case disabled
    }

    /// What the window shows when it opens again.
    public enum NavigationPersistence: Sendable {
        /// The page, history and search it was closed with, until the app quits. Nothing is
        /// saved to disk.
        case session
        /// The initial page with an empty history, every time.
        case resetOnShow
    }

    /// How the sidebar draws the pages' icons. Either way an icon fills the sidebar's icon slot,
    /// 16, 20 or 24 points as the user's Sidebar icon size setting picks, and every row keeps
    /// the system's text and height.
    public enum Icons: Sendable, Equatable {
        /// The icon alone, as the system's sidebars draw it: in its ``SettingsIcon`` tint or the
        /// sidebar's color, and white with the title on the selected row.
        case plain
        /// Each icon in white on a colored rounded square, as System Settings draws them. The
        /// square takes the icon's tint; an icon without one gets `defaultColor`.
        case tiled(defaultColor: Color)

        /// Tiles in gray for icons without a tint, as System Settings' General tile is.
        public static var tiled: Self { .tiled(defaultColor: .gray) }
    }

    /// The words the window shows. Each defaults to the kit's own, macOS's wording in the
    /// language the app runs in, or English when the app declares no language; set one to use
    /// your own.
    public struct Strings: Sendable {
        /// The back button's label, in the toolbar's overflow menu and for VoiceOver.
        public var back: LocalizedStringResource
        /// The forward button's label, in the toolbar's overflow menu and for VoiceOver.
        public var forward: LocalizedStringResource
        /// The placeholder in the empty search field.
        public var searchPrompt: LocalizedStringResource
        /// The menu item that opens the window, used by ``SidebarSettingsCommands`` and
        /// ``OpenSidebarSettingsButton``.
        public var settingsMenuItem: LocalizedStringResource
        /// What the sidebar shows in place of the pages when a search finds none.
        public var noSearchResults: LocalizedStringResource

        /// The kit's words, with yours where given.
        public init(
            back: LocalizedStringResource? = nil,
            forward: LocalizedStringResource? = nil,
            searchPrompt: LocalizedStringResource? = nil,
            settingsMenuItem: LocalizedStringResource? = nil,
            noSearchResults: LocalizedStringResource? = nil
        ) {
            self.back = back ?? Self.kitString("Back")
            self.forward = forward ?? Self.kitString("Forward")
            self.searchPrompt = searchPrompt ?? Self.kitString("Search")
            self.settingsMenuItem = settingsMenuItem ?? Self.kitString("Settings…")
            self.noSearchResults = noSearchResults ?? Self.kitString("No Results")
        }

        /// The kit's words.
        public static var `default`: Self { Self() }

        private static func kitString(_ key: String.LocalizationValue) -> LocalizedStringResource {
            // In the language the app runs in, as AppKit's own words are. A resource's default
            // locale is the system's, which would put the kit's Chinese into an app that speaks
            // only English on a Chinese Mac; the kit bundle's preferred localization follows the
            // app's.
            let language = Bundle.module.preferredLocalizations.first ?? "en"
            return LocalizedStringResource(
                key, locale: Locale(identifier: language), bundle: .atURL(Bundle.module.bundleURL))
        }
    }
}
