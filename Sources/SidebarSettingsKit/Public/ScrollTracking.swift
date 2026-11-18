import SwiftUI

extension View {
    /// Lets the settings window show the line under its toolbar while this view is scrolled.
    ///
    /// Apply it to a page's own scrolling view, such as a `Form` or `List`, when
    /// ``SidebarSettingsConfiguration/detailScrolling`` is `false`. Outside the settings
    /// window it does nothing. On macOS 14 SwiftUI cannot report the scroll position, and the
    /// line always shows.
    public func sidebarSettingsScrollTracking() -> some View {
        modifier(ScrollTracking())
    }
}

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
            content
        }
    }
}
