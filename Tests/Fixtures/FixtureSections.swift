import Foundation
import SidebarSettingsKit

/// The sidebar groupings the unit tests open windows with: titled like Finder's sidebar,
/// untitled so space alone sets the groups apart, mixed, or with a group that holds no pages.
public enum FixtureSections {
    /// One group without a title: what the window's `pages` initializers build.
    public static let ungrouped: [SettingsPageSection<FixturePage>] = [
        SettingsPageSection(pages: FixturePages.three),
    ]

    /// Every group with a title.
    public static let allTitled: [SettingsPageSection<FixturePage>] = [
        SettingsPageSection("Personal", pages: [FixturePages.general]),
        SettingsPageSection("System", pages: [FixturePages.appearance, FixturePages.advanced]),
    ]

    /// No group with a title, so only the space between groups sets them apart.
    public static let allUntitled: [SettingsPageSection<FixturePage>] = [
        SettingsPageSection(pages: [FixturePages.general, FixturePages.appearance]),
        SettingsPageSection(pages: [FixturePages.advanced]),
    ]

    /// Titled and untitled groups in one sidebar, as System Settings mixes them.
    public static let mixed: [SettingsPageSection<FixturePage>] = [
        SettingsPageSection(pages: [FixturePages.general]),
        SettingsPageSection("System", pages: [FixturePages.appearance, FixturePages.advanced]),
        SettingsPageSection(pages: [FixturePages.many[3], FixturePages.many[4]]),
    ]

    /// A group with no pages, which the window leaves out together with its title; the other
    /// groups are what a test counts.
    public static let withEmptySection: [SettingsPageSection<FixturePage>] = [
        SettingsPageSection("Personal", pages: [FixturePages.general]),
        SettingsPageSection("Empty", pages: []),
        SettingsPageSection("System", pages: [FixturePages.appearance]),
    ]
}
