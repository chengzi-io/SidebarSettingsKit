/// The groups the sidebar shows: with search on, each group keeps the pages that match the
/// search text, and a group left without pages is dropped. Groups without pages are always
/// dropped.
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
