import Observation

/// The settings window's selected page, its back and forward history, and the sidebar's
/// search text.
///
/// ``SidebarSettingsWindow`` creates one and keeps it as long as the window object lives,
/// so the window reopens on the page it was closed on. Nothing is written to disk: a new
/// launch starts on the initial page. Read it, or call ``open(_:)``, to drive the window
/// from elsewhere, such as a "Shortcuts…" menu item.
@MainActor
@Observable
public final class SettingsNavigator<Page: SettingsPage> {
    /// The text in the sidebar's search field.
    public var searchText = ""

    /// The page the window opens on, and returns to on ``reset()``.
    public let initialPage: Page

    private var history: [Page]
    private var index = 0

    /// A navigator on `initial`, with no history.
    public init(initial: Page) {
        initialPage = initial
        history = [initial]
    }

    /// The page shown in the detail.
    public var selection: Page { history[index] }

    /// Whether ``goBack()`` has a page to go to.
    public var canGoBack: Bool { index > 0 }

    /// Whether ``goForward()`` has a page to go to.
    public var canGoForward: Bool { index < history.count - 1 }

    /// Shows `page`. As in a browser, the pages ahead of the current one are dropped. Opening
    /// the page already shown changes nothing.
    public func open(_ page: Page) {
        guard page != selection else { return }
        history.removeSubrange((index + 1)...)
        history.append(page)
        index += 1
    }

    /// Shows the page before the current one in the history, if any.
    public func goBack() {
        guard canGoBack else { return }
        index -= 1
    }

    /// Shows the page after the current one in the history, if any.
    public func goForward() {
        guard canGoForward else { return }
        index += 1
    }

    /// Returns to ``initialPage`` with an empty history and search.
    public func reset() {
        history = [initialPage]
        index = 0
        searchText = ""
    }
}
