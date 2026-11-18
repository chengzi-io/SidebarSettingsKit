import SidebarSettingsKit
import SidebarSettingsFixtures
import Testing

/// The window's page history: what back and forward walk through, and what a page opened from
/// the sidebar or a menu item does to it.
@MainActor
@Suite("Navigation history")
struct NavigatorTests {
    @Test func startsOnTheInitialPageWithNoHistory() {
        let navigator = SettingsNavigator(initial: FixturePages.appearance)

        #expect(navigator.selection == FixturePages.appearance)
        #expect(navigator.initialPage == FixturePages.appearance)
        #expect(!navigator.canGoBack)
        #expect(!navigator.canGoForward)
        #expect(navigator.searchText == "")
    }

    @Test func openingANewPageAddsItToTheHistory() {
        let navigator = SettingsNavigator(initial: FixturePages.general)

        navigator.open(FixturePages.appearance)

        #expect(navigator.selection == FixturePages.appearance)
        #expect(navigator.canGoBack)
        #expect(!navigator.canGoForward)
        #expect(navigator.initialPage == FixturePages.general)

        navigator.goBack()

        #expect(navigator.selection == FixturePages.general)
    }

    @Test func openingTheCurrentPageChangesNothing() {
        let navigator = SettingsNavigator(initial: FixturePages.general)
        navigator.open(FixturePages.appearance)
        navigator.goBack()

        navigator.open(FixturePages.general)

        #expect(navigator.selection == FixturePages.general)
        // The page ahead is still there, so the history was not rewritten.
        #expect(navigator.canGoForward)
        navigator.goForward()
        #expect(navigator.selection == FixturePages.appearance)
    }

    @Test func backAndForwardMoveThroughTheHistory() {
        let navigator = SettingsNavigator(initial: FixturePages.general)
        navigator.open(FixturePages.appearance)
        navigator.open(FixturePages.advanced)

        #expect(navigator.canGoBack)
        #expect(!navigator.canGoForward)

        navigator.goBack()

        #expect(navigator.selection == FixturePages.appearance)
        #expect(navigator.canGoBack)
        #expect(navigator.canGoForward)

        navigator.goBack()

        #expect(navigator.selection == FixturePages.general)
        #expect(!navigator.canGoBack)
        #expect(navigator.canGoForward)

        navigator.goForward()
        #expect(navigator.selection == FixturePages.appearance)

        navigator.goForward()
        #expect(navigator.selection == FixturePages.advanced)
        #expect(!navigator.canGoForward)
    }

    @Test func backAndForwardDoNothingAtTheEnds() {
        let navigator = SettingsNavigator(initial: FixturePages.general)

        navigator.goBack()
        #expect(navigator.selection == FixturePages.general)
        #expect(!navigator.canGoBack)

        navigator.goForward()
        #expect(navigator.selection == FixturePages.general)
        #expect(!navigator.canGoForward)

        navigator.open(FixturePages.advanced)
        navigator.goForward()
        #expect(navigator.selection == FixturePages.advanced)
        #expect(!navigator.canGoForward)
        #expect(navigator.canGoBack)
    }

    @Test func openingAPageDropsThePagesAhead() {
        let navigator = SettingsNavigator(initial: FixturePages.general)
        navigator.open(FixturePages.appearance)
        navigator.open(FixturePages.advanced)
        navigator.goBack()

        navigator.open(FixturePages.general)

        #expect(navigator.selection == FixturePages.general)
        #expect(!navigator.canGoForward)
        navigator.goForward()
        #expect(navigator.selection == FixturePages.general)
        navigator.goBack()
        #expect(navigator.selection == FixturePages.appearance)
        navigator.goBack()
        #expect(navigator.selection == FixturePages.general)
        #expect(!navigator.canGoBack)
    }

    @Test func resetReturnsToTheInitialPageWithNoHistoryAndNoSearch() {
        let navigator = SettingsNavigator(initial: FixturePages.appearance)
        navigator.open(FixturePages.advanced)
        navigator.searchText = "dark"

        navigator.reset()

        #expect(navigator.selection == FixturePages.appearance)
        #expect(navigator.initialPage == FixturePages.appearance)
        #expect(!navigator.canGoBack)
        #expect(!navigator.canGoForward)
        #expect(navigator.searchText == "")
        navigator.goBack()
        #expect(navigator.selection == FixturePages.appearance)
    }

    @Test func aNewNavigatorStartsOverOnItsInitialPage() {
        let used = SettingsNavigator(initial: FixturePages.general)
        used.open(FixturePages.advanced)
        used.searchText = "page"

        let relaunched = SettingsNavigator(initial: FixturePages.general)

        #expect(relaunched.selection == FixturePages.general)
        #expect(!relaunched.canGoBack)
        #expect(!relaunched.canGoForward)
        #expect(relaunched.searchText == "")
        // The used navigator is untouched by the new one.
        #expect(used.selection == FixturePages.advanced)
    }
}
