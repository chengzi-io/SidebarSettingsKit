import SwiftUI

/// The selected page, starting at the top each time the page changes.
///
/// The page scrolls itself, as System Settings' grouped forms do; the window adds no scroll view
/// around it. On macOS 14 and 15 the toolbar takes its background from the scroll view under it,
/// and only a form or a list gives one that matches the page: around a plain `ScrollView` the
/// toolbar keeps a lighter bar of its own, with an edge that shows without any scrolling.
struct DetailContainer<Page: SettingsPage, Content: View>: View {
    let navigator: SettingsNavigator<Page>
    let content: (Page) -> Content

    var body: some View {
        let page = navigator.selection
        content(page)
            .modifier(ReportsScrollPosition())
            .id(page)
            .clearScrollBackgroundOnMacOS26()
    }
}

extension EnvironmentValues {
    /// Called with whether the page is scrolled past its top.
    @Entry var pageScrolled: (@MainActor (Bool) -> Void)? = nil
}

/// Reports whether the page is scrolled past its top, for the line under the toolbar. Applied
/// around the page, it reaches the form, list or scroll view inside it.
private struct ReportsScrollPosition: ViewModifier {
    @Environment(\.pageScrolled) private var pageScrolled

    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content
                .onScrollGeometryChange(for: Bool.self) {
                    $0.contentOffset.y + $0.contentInsets.top > 0
                } action: { _, isScrolled in
                    pageScrolled?(isScrolled)
                }
                // A new page starts at the top; its scroll view reports nothing until it moves.
                .onAppear { pageScrolled?(false) }
        } else {
            // SwiftUI reports no scroll position before macOS 15.
            content
        }
    }
}

extension View {
    /// macOS 26 and later show the window's background behind a form or list. Earlier releases
    /// keep the form's own: hidden there, it left a band under the toolbar on macOS 15.
    @ViewBuilder
    fileprivate func clearScrollBackgroundOnMacOS26() -> some View {
        if #available(macOS 26.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}
