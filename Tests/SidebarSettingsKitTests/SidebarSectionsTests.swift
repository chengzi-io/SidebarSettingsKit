import SidebarSettingsKit
import SidebarSettingsFixtures
import Testing

@testable import SidebarSettingsKit

/// The groups the sidebar shows: their order, their headings, and the empty ones left out —
/// both as the sidebar filters them and as the window stores them.
@Suite("Sidebar groups")
struct SidebarSectionsTests {
    @Test func titledGroupsKeepTheirOrderAndTitles() {
        let sections = visibleSections(
            FixtureSections.allTitled, search: .enabled, searchText: "")

        #expect(titles(sections) == ["Personal", "System"])
        #expect(
            sections.map(\.pages)
                == [[FixturePages.general], [FixturePages.appearance, FixturePages.advanced]])
    }

    @Test func untitledGroupsKeepTheirOrderWithoutTitles() {
        let sections = visibleSections(
            FixtureSections.allUntitled, search: .enabled, searchText: "")

        #expect(sections.count == 2)
        #expect(titles(sections) == [nil, nil])
        #expect(
            sections.map(\.pages)
                == [[FixturePages.general, FixturePages.appearance], [FixturePages.advanced]])
    }

    @Test func mixedGroupsKeepTheOrderOfTitledAndUntitledGroups() {
        let sections = visibleSections(FixtureSections.mixed, search: .enabled, searchText: "")

        #expect(titles(sections) == [nil, "System", nil])
        #expect(
            sections.map(\.pages)
                == [
                    [FixturePages.general],
                    [FixturePages.appearance, FixturePages.advanced],
                    [FixturePages.many[3], FixturePages.many[4]],
                ])
    }

    @Test func aGroupWithoutPagesIsLeftOut() {
        let sections = visibleSections(
            FixtureSections.withEmptySection, search: .enabled, searchText: "")

        #expect(titles(sections) == ["Personal", "System"])
        #expect(
            sections.map(\.pages) == [[FixturePages.general], [FixturePages.appearance]])
    }
}

/// The groups the window keeps, which are the ones its sidebar shows once its empty groups are
/// gone. Building the window does not open it.
@MainActor
@Suite("Window groups")
struct SidebarWindowSectionsTests {
    @Test func theWindowLeavesOutAnEmptyGroupWithItsTitle() {
        let window = SidebarSettingsWindow(sections: FixtureSections.withEmptySection) {
            FixtureDetail(page: $0)
        }

        #expect(!window.isVisible)
        #expect(titles(window.sections) == ["Personal", "System"])
        #expect(
            window.sections.map(\.pages) == [[FixturePages.general], [FixturePages.appearance]])
    }

    @Test func theWindowKeepsMixedGroupsInOrder() {
        let window = SidebarSettingsWindow(sections: FixtureSections.mixed) {
            FixtureDetail(page: $0)
        }

        #expect(titles(window.sections) == [nil, "System", nil])
        #expect(
            window.sections.map(\.pages)
                == [
                    [FixturePages.general],
                    [FixturePages.appearance, FixturePages.advanced],
                    [FixturePages.many[3], FixturePages.many[4]],
                ])
    }

    @Test func thePagesInitializerMakesOneUntitledGroup() {
        let window = SidebarSettingsWindow(pages: FixturePages.three) { FixtureDetail(page: $0) }

        #expect(window.sections.count == 1)
        #expect(window.sections.first?.title == nil)
        #expect(window.sections.first?.pages == FixturePages.three)
        // Without an initial page the window opens on the first one, as System Settings does.
        #expect(window.navigator.selection == FixturePages.general)
    }
}
