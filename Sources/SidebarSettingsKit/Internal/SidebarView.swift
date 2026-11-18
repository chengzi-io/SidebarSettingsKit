import SwiftUI

/// The window's left column: the search field, fixed at the top, over the pages. The header
/// is the list's first item and scrolls with it, as the account row does in System Settings;
/// the footer stays at the bottom while the list scrolls above it.
struct SidebarView<Page: SettingsPage, Header: View, Footer: View>: View {
    @Bindable var navigator: SettingsNavigator<Page>
    let sections: [SettingsPageSection<Page>]
    let configuration: SidebarSettingsConfiguration
    let style: SidebarSettingsStyle
    let header: Header
    let footer: Footer

    var body: some View {
        VStack(spacing: 0) {
            if configuration.search == .enabled {
                SearchField(
                    text: $navigator.searchText,
                    prompt: String(localized: configuration.strings.searchPrompt)
                )
                // System Settings' size and insets.
                .controlSize(.large)
                .padding([.horizontal, .bottom], 8)
            }
            Group {
                if shownSections.isEmpty {
                    // Only a search can empty the list: the window has at least one page.
                    ContentUnavailableView.search(text: navigator.searchText)
                        .frame(maxHeight: .infinity)
                } else {
                    SidebarList(
                        navigator: navigator, sections: shownSections, style: style, header: header)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if Footer.self != EmptyView.self { footer }
            }
        }
        .environment(\.sidebarSettingsStyle, style)
    }

    private var shownSections: [SettingsPageSection<Page>] {
        visibleSections(sections, search: configuration.search, searchText: navigator.searchText)
    }
}

/// The system's sidebar list, with its own selection, keyboard, type-to-select and VoiceOver
/// behavior. A style changes what a row holds and its height, never the selection.
private struct SidebarList<Page: SettingsPage, Header: View>: View {
    let navigator: SettingsNavigator<Page>
    let sections: [SettingsPageSection<Page>]
    let style: SidebarSettingsStyle
    let header: Header
    @FocusState private var focused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            List(selection: selection) {
                if Header.self != EmptyView.self { header }
                ForEach(sections.indices, id: \.self) { index in
                    let section = sections[index]
                    if let title = section.title {
                        Section {
                            rows(section.pages)
                        } header: {
                            Text(title)
                        }
                    } else {
                        Section {
                            rows(section.pages)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .focused($focused)
            .task {
                // After the window's first layout: the window gives the first key view, the
                // search field, the focus when it opens, and a scroll before the rows have
                // their heights stops short and clips a row below the fold. System Settings
                // opens with the list focused; ⌘F reaches the search field.
                await Task.yield()
                focused = true
                proxy.scrollTo(navigator.selection)
            }
            .onChange(of: navigator.selection) { _, page in
                proxy.scrollTo(page)
            }
        }
    }

    private func rows(_ pages: [Page]) -> some View {
        ForEach(pages) { page in
            SidebarRowLabel(page: page, style: style)
                .tag(page)
                .id(page)
        }
    }

    /// Command-clicking the selected row writes nil; keep the current page instead.
    private var selection: Binding<Page?> {
        Binding {
            navigator.selection
        } set: {
            if let page = $0 { navigator.open(page) }
        }
    }
}

/// A page's icon and title, in the style's font.
private struct SidebarRowLabel<Page: SettingsPage>: View {
    let page: Page
    let style: SidebarSettingsStyle

    var body: some View {
        Label {
            Text(page.title)
                .lineLimit(1)
                .truncationMode(.tail)
        } icon: {
            SettingsIconView(icon: page.icon, style: style)
        }
        .rowFont(style.rowFont)
    }
}

// A `nil` font leaves the system's alone: `.font(nil)` would replace the sidebar's own, which
// follows the user's sidebar icon size setting.
extension View {
    @ViewBuilder
    fileprivate func rowFont(_ font: Font?) -> some View {
        if let font {
            self.font(font)
        } else {
            self
        }
    }
}
