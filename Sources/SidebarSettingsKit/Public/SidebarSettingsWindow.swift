import AppKit
import SwiftUI

/// A settings window laid out like System Settings: a sidebar of pages that keeps its
/// width, with a search field, beside the selected page, under a toolbar with back and
/// forward buttons.
///
/// Create it once, where it lives as long as the app, such as the `App`'s initializer, an
/// app delegate, or your own root object; not in a `body`, which runs many times. The window
/// itself is built the first time ``show(page:)`` runs.
///
/// ```swift
/// @main struct MyApp: App {
///     let settings = SidebarSettingsWindow(pages: [Pane.general, .advanced]) { pane in
///         switch pane {
///         case .general: GeneralView()
///         case .advanced: AdvancedView()
///         }
///     }
///     var body: some Scene {
///         WindowGroup { ContentView() }
///             .commands { SidebarSettingsCommands(window: settings) }
///     }
/// }
/// ```
///
/// Write each page as a grouped `Form`, as System Settings' pages are: a page scrolls itself,
/// and the line under the toolbar follows the form's scroll position. A page that is not a
/// form or a list and can be taller than the window goes in a `ScrollView`; on macOS 14 and 15
/// the toolbar then keeps a lighter background of its own above it.
///
/// The scene's environment does not reach the window's views: pass them your models
/// through their initializers. `openSettings` and `SettingsLink` do not open this window;
/// use ``SidebarSettingsCommands``, ``OpenSidebarSettingsButton`` or ``show(page:)``.
@MainActor
public final class SidebarSettingsWindow<Page: SettingsPage> {
    /// The selected page, its history and the search text. Call
    /// ``SettingsNavigator/open(_:)`` on it, or ``show(page:)``, to switch pages.
    public let navigator: SettingsNavigator<Page>

    /// The sidebar's groups, without empty ones.
    public let sections: [SettingsPageSection<Page>]

    /// How the window behaves and how its sidebar draws the pages' icons.
    public let configuration: SidebarSettingsConfiguration

    /// Built on the first ``show(page:)``, then kept, so the window reopens as it was.
    private(set) var controller: SettingsWindowController?
    private let makeController: () -> SettingsWindowController

    /// A window with grouped pages, a header at the top of the sidebar's list and a footer
    /// fixed at the sidebar's bottom.
    ///
    /// - Parameters:
    ///   - sections: the sidebar's groups, at least one page in all. Empty groups are left out.
    ///   - initialPage: the page the window opens on; the first page when `nil`.
    ///   - configuration: how the window behaves and draws the pages' icons.
    ///   - header: a view above the first page, such as an account row; it scrolls with the
    ///     pages.
    ///   - footer: a view under the pages, such as a version line; it stays put while the
    ///     pages scroll.
    ///   - detail: the view for a page, which scrolls itself, such as a grouped `Form`.
    public init<Header: View, Footer: View, Detail: View>(
        sections: [SettingsPageSection<Page>],
        initialPage: Page? = nil,
        configuration: SidebarSettingsConfiguration = .init(),
        @ViewBuilder header: () -> Header,
        @ViewBuilder footer: () -> Footer,
        @ViewBuilder detail: @escaping (Page) -> Detail
    ) {
        let sections = sections.filter { !$0.pages.isEmpty }
        let pages = sections.flatMap(\.pages)
        precondition(!pages.isEmpty, "SidebarSettingsWindow needs at least one page.")
        let initialPage = initialPage ?? pages[0]
        precondition(
            pages.contains(initialPage),
            "SidebarSettingsWindow's initialPage \(initialPage) is not one of its pages.")

        let navigator = SettingsNavigator(initial: initialPage)
        self.navigator = navigator
        self.sections = sections
        self.configuration = configuration
        let header = header()
        let footer = footer()
        makeController = {
            let scrollState = DetailScrollState()
            return SettingsWindowController(
                configuration: configuration,
                navigation: .init(
                    canGoBack: { navigator.canGoBack },
                    canGoForward: { navigator.canGoForward },
                    goBack: { navigator.goBack() },
                    goForward: { navigator.goForward() },
                    pageTitle: { String(localized: navigator.selection.title) }
                ),
                scrollState: scrollState,
                sidebar: SidebarView(
                    navigator: navigator,
                    sections: sections,
                    configuration: configuration,
                    header: header,
                    footer: footer
                ),
                detail: DetailContainer(
                    navigator: navigator,
                    scrollState: scrollState,
                    content: detail
                )
            )
        }
    }

    /// Brings the window forward, built the first time, and activates the app, which a menu
    /// bar app needs.
    ///
    /// - Parameter page: the page to switch to; `nil` keeps the page the window shows, or, with
    ///   ``SidebarSettingsConfiguration/NavigationPersistence/resetOnShow``, the initial page.
    ///   It must be one of the window's pages.
    public func show(page: Page? = nil) {
        let controller = controller ?? makeController()
        self.controller = controller
        if configuration.navigationPersistence == .resetOnShow, controller.window?.isVisible != true {
            navigator.reset()
        }
        if let page {
            precondition(
                sections.contains { $0.pages.contains(page) },
                "SidebarSettingsWindow.show(page:): \(page) is not one of the window's pages.")
            navigator.open(page)
        }
        // A menu bar app, or one without a Dock icon, is not active, and `activate()` alone is
        // a request the system may decline.
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
    }

    /// Closes the window. ``show(page:)`` opens it again, on the same page unless the
    /// configuration resets it.
    public func close() {
        controller?.close()
    }

    /// Whether the window is on screen.
    public var isVisible: Bool {
        controller?.window?.isVisible ?? false
    }
}

extension SidebarSettingsWindow {
    /// A window with grouped pages.
    ///
    /// - Parameters:
    ///   - sections: the sidebar's groups, at least one page in all. Empty groups are left out.
    ///   - initialPage: the page the window opens on; the first page when `nil`.
    ///   - configuration: how the window behaves and draws the pages' icons.
    ///   - detail: the view for a page, which scrolls itself, such as a grouped `Form`.
    public convenience init<Detail: View>(
        sections: [SettingsPageSection<Page>],
        initialPage: Page? = nil,
        configuration: SidebarSettingsConfiguration = .init(),
        @ViewBuilder detail: @escaping (Page) -> Detail
    ) {
        self.init(
            sections: sections, initialPage: initialPage, configuration: configuration,
            header: { EmptyView() }, footer: { EmptyView() }, detail: detail)
    }

    /// A window with grouped pages and a header at the top of the sidebar's list, which
    /// scrolls with the pages.
    public convenience init<Header: View, Detail: View>(
        sections: [SettingsPageSection<Page>],
        initialPage: Page? = nil,
        configuration: SidebarSettingsConfiguration = .init(),
        @ViewBuilder header: () -> Header,
        @ViewBuilder detail: @escaping (Page) -> Detail
    ) {
        self.init(
            sections: sections, initialPage: initialPage, configuration: configuration,
            header: header, footer: { EmptyView() }, detail: detail)
    }

    /// A window with grouped pages and a footer fixed at the sidebar's bottom.
    public convenience init<Footer: View, Detail: View>(
        sections: [SettingsPageSection<Page>],
        initialPage: Page? = nil,
        configuration: SidebarSettingsConfiguration = .init(),
        @ViewBuilder footer: () -> Footer,
        @ViewBuilder detail: @escaping (Page) -> Detail
    ) {
        self.init(
            sections: sections, initialPage: initialPage, configuration: configuration,
            header: { EmptyView() }, footer: footer, detail: detail)
    }

    /// A window with one ungrouped list of pages.
    ///
    /// - Parameters:
    ///   - pages: the sidebar's pages, in order; at least one.
    ///   - initialPage: the page the window opens on; the first page when `nil`.
    ///   - configuration: how the window behaves and draws the pages' icons.
    ///   - detail: the view for a page, which scrolls itself, such as a grouped `Form`.
    public convenience init<Detail: View>(
        pages: [Page],
        initialPage: Page? = nil,
        configuration: SidebarSettingsConfiguration = .init(),
        @ViewBuilder detail: @escaping (Page) -> Detail
    ) {
        self.init(
            sections: [SettingsPageSection(pages: pages)], initialPage: initialPage,
            configuration: configuration, detail: detail)
    }

    /// A window with one ungrouped list of pages and a header at the top of the list, which
    /// scrolls with the pages.
    public convenience init<Header: View, Detail: View>(
        pages: [Page],
        initialPage: Page? = nil,
        configuration: SidebarSettingsConfiguration = .init(),
        @ViewBuilder header: () -> Header,
        @ViewBuilder detail: @escaping (Page) -> Detail
    ) {
        self.init(
            sections: [SettingsPageSection(pages: pages)], initialPage: initialPage,
            configuration: configuration, header: header, detail: detail)
    }

    /// A window with one ungrouped list of pages and a footer fixed at the sidebar's bottom.
    public convenience init<Footer: View, Detail: View>(
        pages: [Page],
        initialPage: Page? = nil,
        configuration: SidebarSettingsConfiguration = .init(),
        @ViewBuilder footer: () -> Footer,
        @ViewBuilder detail: @escaping (Page) -> Detail
    ) {
        self.init(
            sections: [SettingsPageSection(pages: pages)], initialPage: initialPage,
            configuration: configuration, footer: footer, detail: detail)
    }

    /// A window with one ungrouped list of pages, a header at the top of the list and a footer
    /// fixed at the sidebar's bottom.
    public convenience init<Header: View, Footer: View, Detail: View>(
        pages: [Page],
        initialPage: Page? = nil,
        configuration: SidebarSettingsConfiguration = .init(),
        @ViewBuilder header: () -> Header,
        @ViewBuilder footer: () -> Footer,
        @ViewBuilder detail: @escaping (Page) -> Detail
    ) {
        self.init(
            sections: [SettingsPageSection(pages: pages)], initialPage: initialPage,
            configuration: configuration, header: header, footer: footer,
            detail: detail)
    }
}
