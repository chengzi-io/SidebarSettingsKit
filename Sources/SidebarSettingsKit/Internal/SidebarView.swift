import SwiftUI

/// The window's left column: the search field, fixed at the top, over the pages. The header
/// is the list's first item and scrolls with it, as the account row does in System Settings;
/// the footer stays at the bottom while the list scrolls above it.
struct SidebarView<Page: SettingsPage, Header: View, Footer: View>: View {
    @Bindable var navigator: SettingsNavigator<Page>
    let sections: [SettingsPageSection<Page>]
    let configuration: SidebarSettingsConfiguration
    let header: Header
    let footer: Footer
    @FocusState private var listFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if configuration.search == .enabled {
                SearchField(
                    text: $navigator.searchText,
                    prompt: String(localized: configuration.strings.searchPrompt),
                    moveDown: moveIntoList
                )
                // System Settings' size and insets.
                .controlSize(.large)
                .padding([.horizontal, .bottom], 8)
            }
            Group {
                if shownSections.isEmpty {
                    // Only a search can empty the list: the window has at least one page.
                    NoSearchResults(title: String(localized: configuration.strings.noSearchResults))
                        .frame(maxHeight: .infinity)
                } else {
                    SidebarList(
                        navigator: navigator, sections: shownSections,
                        icons: configuration.icons, header: header, focused: $listFocused)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if Footer.self != EmptyView.self { footer }
            }
        }
        .task {
            // After the window's first layout, or the window gives its first key view, the
            // search field, the focus. System Settings opens with the list focused; ⌘F reaches
            // the field. Not the list's own task: a list that comes back when a search finds
            // pages again would take the focus from the field mid-word.
            await Task.yield()
            listFocused = true
        }
    }

    private var shownSections: [SettingsPageSection<Page>] {
        visibleSections(sections, search: configuration.search, searchText: navigator.searchText)
    }

    /// ↓ in the search field, as in System Settings: the list takes the focus, on the page
    /// shown, or on the first page found when the search hides it.
    private func moveIntoList() {
        let pages = shownSections.flatMap(\.pages)
        guard let first = pages.first else { return }
        if !pages.contains(navigator.selection) { navigator.open(first) }
        listFocused = true
    }
}

/// The system's sidebar list, with its own selection, keyboard, type-to-select and VoiceOver
/// behavior. The icons change what a row holds, never the selection.
private struct SidebarList<Page: SettingsPage, Header: View>: View {
    let navigator: SettingsNavigator<Page>
    let sections: [SettingsPageSection<Page>]
    let icons: SidebarSettingsConfiguration.Icons
    let header: Header
    let focused: FocusState<Bool>.Binding

    var body: some View {
        ScrollViewReader { proxy in
            List(selection: selection) {
                if Header.self != EmptyView.self { header }
                ForEach(sections.indices, id: \.self) { index in
                    Section {
                        rows(sections[index].pages)
                    }
                }
            }
            .listStyle(.sidebar)
            .focused(focused)
            .task {
                // After the first layout: a scroll before the rows have their heights stops
                // short and clips a row below the fold.
                await Task.yield()
                proxy.scrollTo(navigator.selection)
            }
            .onChange(of: navigator.selection) { _, page in
                proxy.scrollTo(page)
            }
        }
    }

    private func rows(_ pages: [Page]) -> some View {
        ForEach(pages) { page in
            SidebarRowLabel(page: page, icons: icons)
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

/// What the sidebar shows when a search finds no page: a light, small line, which a narrow
/// column can hold; `ContentUnavailableView` sizes itself for a whole window.
private struct NoSearchResults: View {
    let title: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.light))
            Text(title)
                .font(.callout)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
    }
}

/// A page's icon and title, in the sidebar's own font, which follows the user's Sidebar icon
/// size setting.
private struct SidebarRowLabel<Page: SettingsPage>: View {
    let page: Page
    let icons: SidebarSettingsConfiguration.Icons

    var body: some View {
        Label {
            Text(page.title)
                .lineLimit(1)
                .truncationMode(.tail)
        } icon: {
            SettingsIconView(icon: page.icon, icons: icons)
        }
        // The sidebar's own tint, not a color on the symbol: the list turns the icon white
        // with the title on a selected row, and a blue icon on the blue selection vanished.
        // On a tile the tint is the tile's color instead.
        .listItemTint(icons == .plain ? page.icon.tint : nil)
    }
}
