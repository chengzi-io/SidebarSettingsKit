import CoreGraphics
import DemoFixtures
import Foundation
import SidebarSettingsKit

/// The control panel's state: the pages, the sidebar's chrome, and every option of
/// ``SidebarSettingsConfiguration``.
struct DemoOptions {
    var icons = DemoArguments.Icons.plain
    var pages = PageSet.three
    var grouping = Grouping.ungrouped
    var chrome = Chrome.none
    var tallFooter = false
    var size = Size.standard
    var resizing = Resizing.fixed
    var autosave = true
    var sidebarWidth = SidebarWidth.fixed
    var toolbarStyle = ToolbarStyle.automatic
    var showsNavigationButtons = true
    var title = Title.followsPage
    var search = true
    var navigationPersistence = NavigationPersistence.session
    var customStrings = false
}

/// One choice a control panel picker offers: the value, and the words for it.
protocol DemoChoice: CaseIterable, Hashable {
    /// The row of text the picker shows for this choice.
    var label: String { get }
}

extension DemoOptions {
    /// The pages the window shows: the three fixtures, or every page the fixtures have.
    enum PageSet: DemoChoice {
        case three
        case many

        var label: String {
            switch self {
            case .three: "Three pages"
            case .many: "40+ pages"
            }
        }

        /// The pages themselves; the large set mixes long and short pages, so the separator
        /// and the sidebar's scrolling can be seen. Its first page carries the 60-character
        /// title, so scenario 7 shows that row without scrolling the sidebar.
        var fixturePages: [FixturePage] {
            switch self {
            case .three: FixturePages.three
            case .many:
                FixturePages.longText + FixturePages.many + FixtureIconPages.all
            }
        }
    }

    /// How the pages are grouped in the sidebar.
    enum Grouping: DemoChoice {
        case ungrouped
        case grouped

        var label: String {
            switch self {
            case .ungrouped: "Ungrouped"
            case .grouped: "Three groups"
            }
        }

        /// The sidebar's groups for `pages`: one, or three set apart by space.
        func sections(of pages: [FixturePage]) -> [SettingsPageSection<FixturePage>] {
            switch self {
            case .ungrouped: [SettingsPageSection(pages: pages)]
            case .grouped: Self.chunks(of: pages).map { SettingsPageSection(pages: $0) }
            }
        }

        /// Three runs of `pages`, in order.
        private static func chunks(of pages: [FixturePage]) -> [[FixturePage]] {
            let size = max(1, (pages.count + 2) / 3)
            return stride(from: 0, to: pages.count, by: size).map { start in
                Array(pages[start..<min(start + size, pages.count)])
            }
        }
    }

    /// What the sidebar shows above and below its pages.
    enum Chrome: DemoChoice {
        case none
        case header
        case footer
        case both

        var label: String {
            switch self {
            case .none: "None"
            case .header: "Account header"
            case .footer: "Version footer"
            case .both: "Both"
            }
        }

        var showsHeader: Bool { self == .header || self == .both }
        var showsFooter: Bool { self == .footer || self == .both }
    }

    /// The window's content size.
    enum Size: DemoChoice {
        case standard
        case large

        var label: String {
            switch self {
            case .standard: "Default (715 × 600)"
            case .large: "Large (900 × 720)"
            }
        }

        var value: CGSize {
            switch self {
            case .standard: CGSize(width: 715, height: 600)
            case .large: CGSize(width: 900, height: 720)
            }
        }
    }

    /// Whether the window can be resized.
    enum Resizing: DemoChoice {
        case fixed
        case resizable

        var label: String {
            switch self {
            case .fixed: "Fixed"
            case .resizable: "Resizable, minimum 600 × 400"
            }
        }

        var value: SidebarSettingsConfiguration.Resizing {
            switch self {
            case .fixed: .fixed
            case .resizable: .resizable(min: CGSize(width: 600, height: 400))
            }
        }
    }

    /// The sidebar's width.
    enum SidebarWidth: DemoChoice {
        case fixed
        case adjustable

        var label: String {
            switch self {
            case .fixed: "Fixed (215)"
            case .adjustable: "Adjustable (180–320)"
            }
        }

        var value: SidebarSettingsConfiguration.SidebarWidth {
            switch self {
            case .fixed: .fixed(215)
            case .adjustable: .adjustable(min: 180, ideal: 240, max: 320)
            }
        }
    }

    /// The toolbar's look.
    enum ToolbarStyle: DemoChoice {
        case unifiedCompact
        case unified
        case automatic

        var label: String {
            switch self {
            case .unifiedCompact: "Unified compact"
            case .unified: "Unified"
            case .automatic: "Automatic"
            }
        }

        var value: SidebarSettingsConfiguration.ToolbarStyle {
            switch self {
            case .unifiedCompact: .unifiedCompact
            case .unified: .unified
            case .automatic: .automatic
            }
        }
    }

    /// The window's title.
    enum Title: DemoChoice {
        case followsPage
        case fixed
        case hidden

        var label: String {
            switch self {
            case .followsPage: "Follows the page"
            case .fixed: "Fixed (Demo Settings)"
            case .hidden: "Hidden"
            }
        }

        var value: SidebarSettingsConfiguration.TitleMode {
            switch self {
            case .followsPage: .followsPage
            case .fixed: .fixed("Demo Settings")
            case .hidden: .hidden
            }
        }
    }

    /// What the window shows when it opens again.
    enum NavigationPersistence: DemoChoice {
        case session
        case resetOnShow

        var label: String {
            switch self {
            case .session: "Session"
            case .resetOnShow: "Reset on every open"
            }
        }

        var value: SidebarSettingsConfiguration.NavigationPersistence {
            switch self {
            case .session: .session
            case .resetOnShow: .resetOnShow
            }
        }
    }

    /// The kit's words, or the demo's own in their place, as an app that wants other words, or
    /// is not localized, passes its own.
    var strings: SidebarSettingsConfiguration.Strings {
        guard customStrings else { return .default }
        return SidebarSettingsConfiguration.Strings(
            back: "Previous",
            forward: "Next",
            searchPrompt: "Find a page",
            settingsMenuItem: "Preferences…",
            noSearchResults: "Nothing found"
        )
    }

    /// The configuration these options stand for.
    var configuration: SidebarSettingsConfiguration {
        var configuration = SidebarSettingsConfiguration()
        configuration.size = size.value
        configuration.resizing = resizing.value
        configuration.autosaveName = autosave ? "SidebarSettingsDemo" : nil
        configuration.sidebarWidth = sidebarWidth.value
        configuration.toolbarStyle = toolbarStyle.value
        configuration.showsNavigationButtons = showsNavigationButtons
        configuration.title = title.value
        configuration.search = search ? .enabled : .disabled
        configuration.navigationPersistence = navigationPersistence.value
        configuration.strings = strings
        configuration.icons = icons.value
        return configuration
    }
}
