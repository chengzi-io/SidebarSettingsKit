import AppKit
import Observation
import SwiftUI

/// The AppKit window behind ``SidebarSettingsWindow``: a split view whose sidebar cannot
/// collapse, beside the detail, under a toolbar with back and forward buttons.
///
/// SwiftUI's scenes cannot build it: the `Settings` scene keeps the preferences toolbar, and
/// a `NavigationSplitView` sidebar collapses when its divider is dragged in, after which
/// nothing brings it back.
@MainActor
final class SettingsWindowController: NSWindowController, NSToolbarDelegate,
    NSToolbarItemValidation
{
    /// What the window needs from the navigator, so the controller stays free of `Page`.
    struct Navigation {
        let canGoBack: () -> Bool
        let canGoForward: () -> Bool
        let goBack: () -> Void
        let goForward: () -> Void
        /// Reads observable state, so the title follows it.
        let pageTitle: () -> String
    }

    static let backItem = NSToolbarItem.Identifier("SidebarSettingsKit.back")
    static let forwardItem = NSToolbarItem.Identifier("SidebarSettingsKit.forward")

    let configuration: SidebarSettingsConfiguration
    let scrollState: DetailScrollState
    let sidebarItem: NSSplitViewItem
    let detailItem: NSSplitViewItem
    let splitViewController: NSSplitViewController
    private let navigation: Navigation
    /// An adjustable sidebar's ideal width, given to it when the window first shows.
    private var sidebarIdealOnceShown: CGFloat?

    init(
        configuration: SidebarSettingsConfiguration,
        navigation: Navigation,
        scrollState: DetailScrollState,
        sidebar: some View,
        detail: some View
    ) {
        self.configuration = configuration
        self.navigation = navigation
        self.scrollState = scrollState

        let sidebarController = NSHostingController(rootView: sidebar.softScrollEdgeOnMacOS26())
        let detailController = NSHostingController(rootView: detail)
        // The split view and the window size the columns; the content's ideal size must not.
        sidebarController.sizingOptions = []
        detailController.sizingOptions = []

        sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarController)
        sidebarItem.canCollapse = false
        switch configuration.sidebarWidth {
        case .fixed(let width):
            sidebarItem.minimumThickness = width
            sidebarItem.maximumThickness = width
        case .adjustable(let min, let ideal, let max):
            sidebarItem.minimumThickness = min
            sidebarItem.maximumThickness = max
            sidebarIdealOnceShown = ideal
        }
        detailItem = NSSplitViewItem(viewController: detailController)
        splitViewController = NSSplitViewController()
        splitViewController.addSplitViewItem(sidebarItem)
        splitViewController.addSplitViewItem(detailItem)

        var styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        if case .resizable = configuration.resizing { styleMask.insert(.resizable) }
        let window = SettingsWindow(
            contentRect: .zero,
            styleMask: styleMask,
            backing: .buffered,
            defer: true
        )
        // The controller owns the window; AppKit must not release it again on close.
        window.isReleasedWhenClosed = false
        // Set after init: `NSWindow(contentViewController:)` leaves the title "Untitled"
        // until something changes it.
        window.contentViewController = splitViewController
        window.setContentSize(configuration.size)
        if case .resizable(let min, let max) = configuration.resizing {
            if let min { window.contentMinSize = min }
            if let max { window.contentMaxSize = max }
        }
        window.center()
        super.init(window: window)
        // On the controller: `init(window:)` clears a name set on the window. A window that
        // cannot be resized gets back only its saved position.
        if let autosaveName = configuration.autosaveName {
            windowFrameAutosaveName = autosaveName
        }

        if configuration.showsNavigationButtons {
            window.onBack = navigation.goBack
            window.onForward = navigation.goForward
        }
        // AppKit items: when SwiftUI's toolbar bridging built the toolbar, the window's
        // first title came out unlocalized.
        let toolbar = NSToolbar(identifier: "SidebarSettingsKit")
        toolbar.delegate = self
        window.toolbar = toolbar
        window.toolbarStyle = configuration.toolbarStyle.appKit
        if configuration.title == .hidden { window.titleVisibility = .hidden }

        followTitle()
        followSeparator()
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        guard let ideal = sidebarIdealOnceShown else { return }
        sidebarIdealOnceShown = nil
        let splitView = splitViewController.splitView
        splitView.setPosition(ideal, ofDividerAt: 0)
        splitView.layoutSubtreeIfNeeded()
        // On macOS 26 that position left the sidebar 8 pt narrower than the ideal, so the
        // divider moves by what the sidebar came out short.
        let shortfall = ideal - sidebarItem.viewController.view.frame.width
        if shortfall != 0 {
            splitView.setPosition(ideal + shortfall, ofDividerAt: 0)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The window's title, and the back and forward buttons' state, follow the page.
    private func followTitle() {
        let title = withObservationTracking {
            switch configuration.title {
            case .followsPage, .hidden: navigation.pageTitle()
            case .fixed(let resource): String(localized: resource)
            }
        } onChange: { [weak self] in
            // Weak here, not only in the task: the navigator keeps this closure, and the
            // window's views keep the navigator.
            Task { @MainActor [weak self] in self?.followTitle() }
        }
        window?.title = title
        window?.toolbar?.validateVisibleItems()
    }

    /// AppKit's automatic separator loses track once SwiftUI swaps the detail's content and
    /// then keeps the line, so the detail's scroll state drives it instead.
    private func followSeparator() {
        let style: NSTitlebarSeparatorStyle
        switch configuration.toolbarSeparator {
        case .always:
            style = .line
        case .never:
            style = .none
        case .whenScrolled:
            if #available(macOS 15.0, *) {
                let isScrolled = withObservationTracking {
                    scrollState.isScrolled
                } onChange: { [weak self] in
                    Task { @MainActor [weak self] in self?.followSeparator() }
                }
                style = isScrolled ? .line : .none
            } else {
                // SwiftUI reports no scroll offset before macOS 15.
                style = .line
            }
        }
        detailItem.titlebarSeparatorStyle = style
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        configuration.showsNavigationButtons
            ? [.sidebarTrackingSeparator, Self.backItem, Self.forwardItem]
            : [.sidebarTrackingSeparator]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        let isBack = identifier == Self.backItem
        guard isBack || identifier == Self.forwardItem else { return nil }
        let label = String(localized: isBack ? configuration.strings.back : configuration.strings.forward)
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = label
        item.toolTip = label
        item.image = NSImage(
            systemSymbolName: isBack ? "chevron.left" : "chevron.right",
            accessibilityDescription: label
        )
        item.isBordered = true
        item.isNavigational = true
        item.target = self
        item.action = isBack ? #selector(goBack) : #selector(goForward)
        return item
    }

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        switch item.itemIdentifier {
        case Self.backItem: navigation.canGoBack()
        case Self.forwardItem: navigation.canGoForward()
        default: false
        }
    }

    @objc private func goBack() {
        navigation.goBack()
    }

    @objc private func goForward() {
        navigation.goForward()
    }
}

/// Takes the window's keyboard shortcuts before the main menu, so they work in an app
/// without a File or Go menu, such as a menu bar app.
final class SettingsWindow: NSWindow {
    var onBack: (() -> Void)?
    var onForward: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command else {
            return super.performKeyEquivalent(with: event)
        }
        switch event.charactersIgnoringModifiers {
        case "[" where onBack != nil:
            onBack?()
            return true
        case "]" where onForward != nil:
            onForward?()
            return true
        case "w":
            performClose(nil)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}

extension SidebarSettingsConfiguration.ToolbarStyle {
    var appKit: NSWindow.ToolbarStyle {
        switch self {
        case .unifiedCompact: .unifiedCompact
        case .unified: .unified
        case .automatic: .automatic
        }
    }
}

extension View {
    /// Rows fade out under the toolbar on macOS 26 and later.
    @ViewBuilder
    fileprivate func softScrollEdgeOnMacOS26() -> some View {
        if #available(macOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            self
        }
    }
}
