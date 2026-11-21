import SidebarSettingsKit
import SidebarSettingsFixtures
import SwiftUI
import Testing

@testable import SidebarSettingsKit

/// What the sidebar's search field keeps: the default title and keyword matching, the width
/// and case forms it ignores, and the pages and groups it leaves out.
@Suite("Search matching")
struct SearchTests {
    @Test func theSearchMatchesTheTitle() {
        #expect(FixturePages.general.matches(searchText: "General"))
        #expect(FixturePages.general.matches(searchText: "Gener"))
        #expect(!FixturePages.general.matches(searchText: "Appearance"))
    }

    @Test func theSearchMatchesAKeywordTitleDoesNotContain() {
        #expect(FixturePages.general.matches(searchText: "about"))
        #expect(FixturePages.advanced.matches(searchText: "logs"))
        // The long keyword matches from its middle and from its end, not only from its start.
        #expect(FixturePages.longKeyword.matches(searchText: "accessibility"))
        #expect(FixturePages.longKeyword.matches(searchText: "troubleshooting"))
    }

    @Test func theSearchIgnoresCase() {
        #expect(FixturePages.general.matches(searchText: "GENERAL"))
        #expect(FixturePages.general.matches(searchText: "Software Update"))
        #expect(FixturePages.longKeyword.matches(searchText: "DEVELOPER TOOLS"))
    }

    @Test func theSearchIgnoresFullWidthAndHalfWidthForms() {
        // A half-width query finds a full-width keyword.
        #expect(FixturePages.widthInsensitiveKeywords.matches(searchText: "abc"))
        // A full-width query finds a half-width title.
        #expect(FixturePages.general.matches(searchText: "ＧＥＮＥＲＡＬ"))
        #expect(FixturePages.widthInsensitiveKeywords.matches(searchText: "ＡＢＣ"))
    }

    @Test func theSearchMatchesChineseText() {
        #expect(FixturePages.chineseTitle.matches(searchText: "隐私"))
        #expect(FixturePages.chineseTitle.matches(searchText: "通用与隐私设置"))
        #expect(FixturePages.widthInsensitiveKeywords.matches(searchText: "中文关键词"))
        #expect(!FixturePages.chineseTitle.matches(searchText: "外观"))
    }

    @Test func theSearchMatchesAMixOfChineseAndEnglish() {
        #expect(FixturePages.mixedTitle.matches(searchText: "蓝牙"))
        #expect(FixturePages.mixedTitle.matches(searchText: "wi-fi"))
        #expect(FixturePages.mixedTitle.matches(searchText: "Wi-Fi 与蓝牙"))
        #expect(FixturePages.mixedTitle.matches(searchText: "无线网络"))
    }

    @Test func aBlankSearchKeepsEveryGroupAndPageInOrder() {
        let sections = visibleSections(
            FixtureSections.grouped, search: .enabled, searchText: " \n\t ")

        #expect(
            sections.map(\.pages)
                == [[FixturePages.general], [FixturePages.appearance, FixturePages.advanced]])
        #expect(FixturePages.general.matches(searchText: "   "))
    }

    @Test func aSearchWithoutAMatchLeavesNoSections() {
        let sections = visibleSections(
            FixtureSections.grouped, search: .enabled, searchText: "zzzz")

        #expect(sections.isEmpty)
    }

    @Test func disablingTheSearchShowsEveryPageWhateverTheText() {
        let sections = visibleSections(
            FixtureSections.ungrouped, search: .disabled, searchText: "appearance")

        #expect(sections.flatMap(\.pages) == FixturePages.three)
        #expect(
            visibleSections(FixtureSections.ungrouped, search: .disabled, searchText: "zzzz")
                .flatMap(\.pages) == FixturePages.three)
    }

    @Test func aPageWithItsOwnMatcherUsesIt() {
        let page = PlantPage(id: "garden", title: "Garden")
        let sections = [SettingsPageSection(pages: [page])]

        // The title says "Garden"; only the page's own word list knows "plant".
        #expect(page.matches(searchText: "plant"))
        #expect(!page.matches(searchText: "garden"))

        #expect(
            visibleSections(sections, search: .enabled, searchText: "plant").flatMap(\.pages)
                == [page])
        #expect(visibleSections(sections, search: .enabled, searchText: "garden").isEmpty)
    }

    /// General's group has no match and goes; Appearance's group stays, without Advanced.
    @Test func aGroupWithoutAMatchDisappears() {
        let sections = visibleSections(
            FixtureSections.grouped, search: .enabled, searchText: "appearance")

        #expect(sections.map(\.pages) == [[FixturePages.appearance]])
    }
}

/// A page that matches by a word its title does not contain, the way an app with its own
/// search words does. No fixture does this: the fixtures all keep the default matching.
private struct PlantPage: SettingsPage {
    let id: String
    let title: LocalizedStringResource

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    @MainActor var icon: SettingsIcon { .system("leaf") }

    func matches(searchText: String) -> Bool { searchText.lowercased().contains("plant") }
}
