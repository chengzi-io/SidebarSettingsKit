import Foundation
import SidebarSettingsKit
import Testing

/// The configuration a window takes when the app sets nothing: System Settings' size and
/// behavior, under the toolbar the system picks.
@Suite("Configuration defaults")
struct ConfigurationTests {
    @Test func aFreshConfigurationHasTheDocumentedDefaults() {
        let configuration = SidebarSettingsConfiguration()

        #expect(configuration.size == CGSize(width: 715, height: 600))
        #expect(configuration.resizing == .fixed)
        #expect(configuration.autosaveName == "SidebarSettingsWindow")
        #expect(configuration.sidebarWidth == .fixed(215))
        #expect(configuration.toolbarStyle == .automatic)
        #expect(configuration.showsNavigationButtons)
        #expect(configuration.title == .followsPage)
        #expect(configuration.search == .enabled)
        #expect(configuration.navigationPersistence == .session)
        #expect(resolvedStrings(configuration.strings) == resolvedStrings(.default))
        #expect(configuration.icons == .plain)
        // Tiles without a color of their own are gray, as System Settings' General tile is.
        #expect(SidebarSettingsConfiguration.Icons.tiled == .tiled(defaultColor: .gray))
    }
}

/// The strings resolved in English, so two `Strings` values compare field by field: the type
/// itself is not `Equatable`.
private func resolvedStrings(_ strings: SidebarSettingsConfiguration.Strings) -> [String] {
    [
        strings.back, strings.forward, strings.searchPrompt, strings.settingsMenuItem,
        strings.noSearchResults,
    ].map {
        resolved($0, in: Locale(identifier: "en"))
    }
}
