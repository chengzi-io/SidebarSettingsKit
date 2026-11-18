import SidebarSettingsKit
import SidebarSettingsFixtures
import SwiftUI
import Testing

/// A window needs at least one page, and an `initialPage` among them; one that breaks either
/// rule stops the process instead of opening an empty window. Each case runs in a child
/// process, so the crash there cannot end this test run.
@Suite("Window preconditions")
struct WindowPreconditionTests {
    @Test func aWindowWithoutPagesStopsTheProcess() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                _ = SidebarSettingsWindow<FixturePage>(pages: [], detail: { _ in EmptyView() })
            }
        }
    }

    @Test func aWindowWhoseGroupsAreAllEmptyStopsTheProcess() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                _ = SidebarSettingsWindow<FixturePage>(
                    sections: [SettingsPageSection("Empty", pages: [])],
                    detail: { _ in EmptyView() })
            }
        }
    }

    @Test func aWindowWhoseInitialPageIsNotOneOfItsPagesStopsTheProcess() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                _ = SidebarSettingsWindow<FixturePage>(
                    pages: FixturePages.three,
                    initialPage: FixturePages.many[0],
                    detail: { _ in EmptyView() })
            }
        }
    }
}
