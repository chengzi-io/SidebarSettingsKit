import Foundation

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

    /// The toolbar's look. Default ``ToolbarStyle/unifiedCompact``.
    public var toolbarStyle = ToolbarStyle.unifiedCompact

    /// Whether the toolbar shows back and forward buttons. Default `true`.
    public var showsNavigationButtons = true

    /// The window's title. Default ``TitleMode/followsPage``.
    public var title = TitleMode.followsPage

    /// When the line under the toolbar shows. Default ``SeparatorMode/whenScrolled``.
    public var toolbarSeparator = SeparatorMode.whenScrolled

    /// Whether the sidebar has a search field. Default ``SearchMode/enabled``. To change
    /// what a search finds, implement ``SettingsPage/matches(searchText:)``.
    public var search = SearchMode.enabled

    /// What the window shows when it opens again. Default ``NavigationPersistence/session``.
    public var navigationPersistence = NavigationPersistence.session

    /// Whether the window puts each page in a scroll view. Default `true`.
    ///
    /// Set it to `false` when a page scrolls by itself, such as a `Form` or a `List`, and
    /// apply ``SwiftUICore/View/sidebarSettingsScrollTracking()`` to that page's scrolling
    /// view so the line under the toolbar still follows it.
    public var detailScrolling = true

    /// The words the window shows. Default ``Strings/default``, in English and Simplified
    /// Chinese.
    public var strings = Strings.default

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
        /// One row with the title and buttons, as in System Settings.
        case unifiedCompact
        /// One taller row with the title and buttons.
        case unified
        /// The system's choice for the window.
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

    /// When the line under the toolbar shows.
    public enum SeparatorMode: Sendable {
        /// Only while the page is scrolled down, as in System Settings. On macOS 14, which
        /// cannot report the scroll position to SwiftUI, the line always shows.
        case whenScrolled
        /// Always.
        case always
        /// Never.
        case never
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

    /// The words the window shows. Each defaults to the kit's own, localized in English and
    /// Simplified Chinese; set one to use your own.
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

        /// The kit's words, with yours where given.
        public init(
            back: LocalizedStringResource? = nil,
            forward: LocalizedStringResource? = nil,
            searchPrompt: LocalizedStringResource? = nil,
            settingsMenuItem: LocalizedStringResource? = nil
        ) {
            self.back = back ?? Self.kitString("Back")
            self.forward = forward ?? Self.kitString("Forward")
            self.searchPrompt = searchPrompt ?? Self.kitString("Search")
            self.settingsMenuItem = settingsMenuItem ?? Self.kitString("Settings…")
        }

        /// The kit's words.
        public static var `default`: Self { Self() }

        private static func kitString(_ key: String.LocalizationValue) -> LocalizedStringResource {
            LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
        }
    }
}
