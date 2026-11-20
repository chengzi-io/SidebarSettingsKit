import SidebarSettingsKit
import SidebarSettingsFixtures
import Testing

/// The groups a window keeps: its own, in order, without the empty ones. Building the window
/// does not open it.
@MainActor
@Suite("Window groups")
struct SidebarSectionsTests {
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
