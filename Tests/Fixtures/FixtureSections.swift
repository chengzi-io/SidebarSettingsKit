import Foundation
import SidebarSettingsKit

/// The sidebar groupings the unit tests open windows with: one group, groups set apart by
/// space, or with a group that holds no pages.
public enum FixtureSections {
    /// One group: what the window's `pages` initializers build.
    public static let ungrouped: [SettingsPageSection<FixturePage>] = [
        SettingsPageSection(pages: FixturePages.three),
    ]

    /// Two groups, set apart by the space between them.
    public static let grouped: [SettingsPageSection<FixturePage>] = [
        SettingsPageSection(pages: [FixturePages.general]),
        SettingsPageSection(pages: [FixturePages.appearance, FixturePages.advanced]),
    ]

    /// A group with no pages, which the window leaves out; the other groups are what a test
    /// counts.
    public static let withEmptySection: [SettingsPageSection<FixturePage>] = [
        SettingsPageSection(pages: [FixturePages.general]),
        SettingsPageSection(pages: []),
        SettingsPageSection(pages: [FixturePages.appearance]),
    ]
}
