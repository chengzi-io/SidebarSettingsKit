/// The groups the sidebar shows: with search on, each group keeps the pages that match the
/// search text, and a group left without pages is dropped with its heading. Groups without
/// pages are always dropped.
func visibleSections<Page: SettingsPage>(
    _ sections: [SettingsPageSection<Page>],
    search: SidebarSettingsConfiguration.SearchMode,
    searchText: String
) -> [SettingsPageSection<Page>] {
    let searchText = search == .enabled ? searchText : ""
    return sections.compactMap { section in
        let pages = section.pages.filter { $0.matches(searchText: searchText) }
        guard !pages.isEmpty else { return nil }
        return section.title.map { SettingsPageSection($0, pages: pages) }
            ?? SettingsPageSection(pages: pages)
    }
}
