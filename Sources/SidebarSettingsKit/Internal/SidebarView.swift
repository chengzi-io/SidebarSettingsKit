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
                switch style.selectionShape {
                case .system:
                    SystemSidebarList(
                        navigator: navigator, sections: shownSections, style: style, header: header)
                case .rounded(let radius):
                    DrawnSidebarList(
                        navigator: navigator, sections: shownSections, style: style, radius: radius,
                        header: header)
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

/// The system's sidebar list, with its own selection, keyboard and VoiceOver behavior.
private struct SystemSidebarList<Page: SettingsPage, Header: View>: View {
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
            .environment(\.defaultMinListRowHeight, style.rowHeight ?? 0)
            .insets(style.sidebarInsets)
            // System Settings opens with the list focused; ⌘F reaches the search field.
            .focused($focused)
            .onAppear {
                focused = true
                // The window may open on a page below the fold.
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
                .frame(minHeight: style.rowHeight)
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

/// Rows the kit lays out and highlights itself, for a selection shape the system list does
/// not draw. It keeps the list's arrow keys and tells VoiceOver which row is selected.
private struct DrawnSidebarList<Page: SettingsPage, Header: View>: View {
    let navigator: SettingsNavigator<Page>
    let sections: [SettingsPageSection<Page>]
    let style: SidebarSettingsStyle
    let radius: CGFloat
    let header: Header
    @FocusState private var focused: Bool
    @Environment(\.controlActiveState) private var controlActiveState

    /// The space that sets apart a group without a heading, as in System Settings.
    private static var groupSpacing: CGFloat { 10 }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: style.rowSpacing ?? 0) {
                    if Header.self != EmptyView.self { header }
                    ForEach(sections.indices, id: \.self) { index in
                        let section = sections[index]
                        if let title = section.title {
                            Text(title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.top, index == 0 ? 0 : Self.groupSpacing)
                                .accessibilityAddTraits(.isHeader)
                        } else if index > 0 {
                            Color.clear.frame(height: Self.groupSpacing)
                        }
                        ForEach(section.pages) { page in
                            row(page)
                        }
                    }
                }
            }
            .insets(style.sidebarInsets)
            .focusable()
            .focusEffectDisabled()
            .focused($focused)
            .onAppear {
                focused = true
                proxy.scrollTo(navigator.selection)
            }
            .onMoveCommand(perform: move)
            .onChange(of: navigator.selection) { _, page in
                proxy.scrollTo(page)
            }
        }
    }

    private func row(_ page: Page) -> some View {
        let isSelected = page == navigator.selection
        let isEmphasized = isSelected && controlActiveState != .inactive && focused
        return Button {
            navigator.open(page)
        } label: {
            SidebarRowLabel(page: page, style: style)
                .foregroundStyle(isEmphasized ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: style.rowHeight, alignment: .leading)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(isEmphasized ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .id(page)
    }

    private func move(_ direction: MoveCommandDirection) {
        let pages = sections.flatMap(\.pages)
        guard let index = pages.firstIndex(of: navigator.selection) else {
            if let first = pages.first { navigator.open(first) }
            return
        }
        switch direction {
        case .up where index > 0: navigator.open(pages[index - 1])
        case .down where index < pages.count - 1: navigator.open(pages[index + 1])
        default: break
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
        .font(style.rowFont)
    }
}

extension View {
    @ViewBuilder
    fileprivate func insets(_ insets: EdgeInsets?) -> some View {
        if let insets {
            contentMargins(.all, insets, for: .scrollContent)
        } else {
            self
        }
    }
}
