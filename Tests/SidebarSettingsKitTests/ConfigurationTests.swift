import AppKit
import Foundation
import SidebarSettingsKit
import Testing

@testable import SidebarSettingsKit

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
        #expect(configuration.toolbarStyle.appKit == .automatic)
        #expect(configuration.showsNavigationButtons)
        #expect(configuration.title == .followsPage)
        #expect(configuration.search.isEnabled)
        #expect(configuration.navigationPersistence.isSession)
        #expect(resolvedStrings(configuration.strings) == resolvedStrings(.default))
        #expect(configuration.icons == .plain)
        // Tiles without a color of their own are gray, as System Settings' General tile is.
        #expect(SidebarSettingsConfiguration.Icons.tiled == .tiled(defaultColor: .gray))
    }

    /// Except on macOS 26, where a compact toolbar starts the sidebar below the title bar.
    @Test func eachToolbarStyleMapsToItsAppKitNamesake() {
        let isMacOS26 = ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 26
        let mapping: [(SidebarSettingsConfiguration.ToolbarStyle, NSWindow.ToolbarStyle)] = [
            (.unifiedCompact, isMacOS26 ? .automatic : .unifiedCompact),
            (.unified, .unified),
            (.automatic, .automatic),
        ]

        // Every case is covered, so a new case cannot slip past this test.
        #expect(mapping.count == SidebarSettingsConfiguration.ToolbarStyle.allCases.count)
        for (style, appKit) in mapping {
            #expect(style.appKit == appKit)
        }
    }
}

/// The strings resolved in `locale`, so two `Strings` values compare field by field: the
/// type itself is not `Equatable`.
private func resolvedStrings(
    _ strings: SidebarSettingsConfiguration.Strings,
    in locale: Locale = Locale(identifier: "en")
) -> [String] {
    [
        strings.back, strings.forward, strings.searchPrompt, strings.settingsMenuItem,
        strings.noSearchResults,
    ].map {
        resolved($0, in: locale)
    }
}

private extension SidebarSettingsConfiguration.SearchMode {
    /// Whether the sidebar has a search field.
    var isEnabled: Bool { if case .enabled = self { true } else { false } }
}

private extension SidebarSettingsConfiguration.NavigationPersistence {
    /// Whether the window shows the page it was closed on.
    var isSession: Bool { if case .session = self { true } else { false } }
}
