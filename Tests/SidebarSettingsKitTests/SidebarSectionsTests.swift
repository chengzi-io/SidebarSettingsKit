import SidebarSettingsKit
import SidebarSettingsFixtures
import Testing

@testable import SidebarSettingsKit

/// The groups the sidebar shows: their order and the empty ones left out, both as the sidebar
/// filters them and as the window stores them.
@Suite("Sidebar groups")
struct SidebarSectionsTests {
    @Test func groupsKeepTheirOrder() {
        let sections = visibleSections(FixtureSections.grouped, search: .enabled, searchText: "")

        #expect(
            sections.map(\.pages)
                == [[FixturePages.general], [FixturePages.appearance, FixturePages.advanced]])
    }

    @Test func aGroupWithoutPagesIsLeftOut() {
        let sections = visibleSections(
            FixtureSections.withEmptySection, search: .enabled, searchText: "")

        #expect(
            sections.map(\.pages) == [[FixturePages.general], [FixturePages.appearance]])
    }
}

/// The groups the window keeps, which are the ones its sidebar shows once its empty groups are
/// gone. Building the window does not open it.
@MainActor
@Suite("Window groups")
struct SidebarWindowSectionsTests {
    @Test func theWindowLeavesOutAnEmptyGroup() {
        let window = SidebarSettingsWindow(sections: FixtureSections.withEmptySection) {
            FixtureDetail(page: $0)
        }

        #expect(!window.isVisible)
        #expect(
            window.sections.map(\.pages) == [[FixturePages.general], [FixturePages.appearance]])
    }

    @Test func theWindowKeepsItsGroupsInOrder() {
        let window = SidebarSettingsWindow(sections: FixtureSections.grouped) {
            FixtureDetail(page: $0)
        }

        #expect(
            window.sections.map(\.pages)
                == [[FixturePages.general], [FixturePages.appearance, FixturePages.advanced]])
    }

    @Test func thePagesInitializerMakesOneGroup() {
        let window = SidebarSettingsWindow(pages: FixturePages.three) { FixtureDetail(page: $0) }

        #expect(window.sections.count == 1)
        #expect(window.sections.first?.pages == FixturePages.three)
        // Without an initial page the window opens on the first one, as System Settings does.
        #expect(window.navigator.selection == FixturePages.general)
    }
}
