/// The groups the sidebar shows: with search on, each group keeps the pages that match the
/// search text. A group without pages is dropped.
func visibleSections<Page: SettingsPage>(
    _ sections: [SettingsPageSection<Page>],
    search: SidebarSettingsConfiguration.SearchMode,
    searchText: String
) -> [SettingsPageSection<Page>] {
    let searchText = search == .enabled ? searchText : ""
    return sections.compactMap { section in
        let pages = section.pages.filter { $0.matches(searchText: searchText) }
        guard !pages.isEmpty else { return nil }
        return SettingsPageSection(pages: pages)
    }
}
