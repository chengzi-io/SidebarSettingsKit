import Observation
import SwiftUI

/// Whether the page is scrolled under the toolbar; the line under the toolbar follows it.
@MainActor
@Observable
final class DetailScrollState {
    var isScrolled = false
}

extension EnvironmentValues {
    @Entry var detailScrollState: DetailScrollState? = nil
}

/// The selected page, starting at the top each time the page changes.
///
/// The page scrolls itself, as System Settings' grouped forms do; the window adds no scroll view
/// around it. On macOS 14 and 15 the toolbar takes its background from the scroll view under it,
/// and only a form or a list gives one that matches the page: around a plain `ScrollView` the
/// toolbar keeps a lighter bar of its own, with an edge that shows without any scrolling.
struct DetailContainer<Page: SettingsPage, Content: View>: View {
    let navigator: SettingsNavigator<Page>
    let scrollState: DetailScrollState
    let content: (Page) -> Content

    var body: some View {
        let page = navigator.selection
        content(page)
            .modifier(ScrollTracking())
            .id(page)
            .clearScrollBackgroundOnMacOS26()
            .environment(\.detailScrollState, scrollState)
    }
}

/// Reports whether the page's scroll view is scrolled past its top. Applied around the page, it
/// reaches the form, list or scroll view inside it.
private struct ScrollTracking: ViewModifier {
    @Environment(\.detailScrollState) private var scrollState

    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content
                .onScrollGeometryChange(for: Bool.self) {
                    $0.contentOffset.y + $0.contentInsets.top > 0
                } action: { _, isScrolled in
                    scrollState?.isScrolled = isScrolled
                }
                // A new page starts at the top; its scroll view reports nothing until it moves.
                .onAppear { scrollState?.isScrolled = false }
        } else {
            // SwiftUI reports no scroll offset before macOS 15.
            content
        }
    }
}

extension View {
    /// macOS 26 and later show the window's background behind a form or list. Earlier releases
    /// keep their own: without it macOS 15 draws a band under the toolbar.
    @ViewBuilder
    fileprivate func clearScrollBackgroundOnMacOS26() -> some View {
        if #available(macOS 26.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}
