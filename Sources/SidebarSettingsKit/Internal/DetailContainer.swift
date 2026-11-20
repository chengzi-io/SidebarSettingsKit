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
            .id(page)
            .clearScrollBackgroundOnMacOS26()
    }
}

extension View {
    /// macOS 26 and later show the window's background behind a form or list. Earlier releases
    /// keep the form's own: hidden there, it left a band under the toolbar on macOS 15.
    @ViewBuilder
    fileprivate func clearScrollBackgroundOnMacOS26() -> some View {
        if #available(macOS 26.0, *), ProcessInfo.processInfo.environment["SSK_PROBE_SOFT_DETAIL"] != nil {
            scrollContentBackground(.hidden).scrollEdgeEffectStyle(.soft, for: .top)
        } else if #available(macOS 26.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}
