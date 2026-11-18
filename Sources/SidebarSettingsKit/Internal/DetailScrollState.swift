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

/// The page, in a scroll view when the window scrolls it, starting at the top each time the
/// page changes.
struct DetailContainer<Page: SettingsPage, Content: View>: View {
    let navigator: SettingsNavigator<Page>
    let scrollState: DetailScrollState
    let scrolls: Bool
    let style: SidebarSettingsStyle
    let content: (Page) -> Content

    var body: some View {
        let page = navigator.selection
        Group {
            if scrolls {
                ScrollView {
                    content(page)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .sidebarSettingsScrollTracking()
            } else {
                content(page)
            }
        }
        .id(page)
        .clearScrollBackgroundOnMacOS26()
        .environment(\.sidebarSettingsStyle, style)
        .environment(\.detailScrollState, scrollState)
    }
}

extension View {
    /// macOS 26 shows the window's background behind a form or list. Earlier releases keep
    /// their own: without it macOS 15 draws a band under the toolbar.
    @ViewBuilder
    fileprivate func clearScrollBackgroundOnMacOS26() -> some View {
        if #available(macOS 26.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}
