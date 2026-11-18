import SwiftUI

/// A button that opens a ``SidebarSettingsWindow``, such as an item in a menu bar app's menu,
/// optionally on a given page.
public struct OpenSidebarSettingsButton<Page: SettingsPage, Label: View>: View {
    private let window: SidebarSettingsWindow<Page>
    private let page: Page?
    private let label: Label

    /// A button with your own label.
    ///
    /// - Parameters:
    ///   - window: the window to open.
    ///   - page: the page to open it on; `nil` keeps the page it shows.
    ///   - label: the button's label.
    public init(
        window: SidebarSettingsWindow<Page>,
        page: Page? = nil,
        @ViewBuilder label: () -> Label
    ) {
        self.window = window
        self.page = page
        self.label = label()
    }

    /// The button.
    public var body: some View {
        Button {
            window.show(page: page)
        } label: {
            label
        }
    }
}

extension OpenSidebarSettingsButton where Label == Text {
    /// A button titled with the window's
    /// ``SidebarSettingsConfiguration/Strings/settingsMenuItem``, "Settings…" by default.
    ///
    /// - Parameters:
    ///   - window: the window to open.
    ///   - page: the page to open it on; `nil` keeps the page it shows.
    public init(window: SidebarSettingsWindow<Page>, page: Page? = nil) {
        self.init(window: window, page: page) {
            Text(window.configuration.strings.settingsMenuItem)
        }
    }
}
