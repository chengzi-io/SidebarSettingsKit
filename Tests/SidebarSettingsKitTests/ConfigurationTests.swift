import AppKit
import Foundation
import SidebarSettingsKit
import Testing

@testable import SidebarSettingsKit

/// The configuration a window takes when the app sets nothing: what System Settings does.
@Suite("Configuration defaults")
struct ConfigurationTests {
    @Test func aFreshConfigurationMatchesSystemSettings() {
        let configuration = SidebarSettingsConfiguration()

        #expect(configuration.size == CGSize(width: 715, height: 600))
        #expect(configuration.resizing == .fixed)
        #expect(configuration.autosaveName == "SidebarSettingsWindow")
        #expect(configuration.sidebarWidth == .fixed(215))
        #expect(configuration.toolbarStyle.appKit == .unifiedCompact)
        #expect(configuration.showsNavigationButtons)
        #expect(configuration.title == .followsPage)
        #expect(configuration.toolbarSeparator.showsOnlyWhenScrolled)
        #expect(configuration.search.isEnabled)
        #expect(configuration.navigationPersistence.isSession)
        #expect(configuration.detailScrolling)
        #expect(resolvedStrings(configuration.strings) == resolvedStrings(.default))
    }

    @Test func eachToolbarStyleMapsToItsAppKitNamesake() {
        let mapping: [(SidebarSettingsConfiguration.ToolbarStyle, NSWindow.ToolbarStyle)] = [
            (.unifiedCompact, .unifiedCompact),
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

/// The four strings resolved in `locale`, so two `Strings` values compare field by field: the
/// type itself is not `Equatable`.
private func resolvedStrings(
    _ strings: SidebarSettingsConfiguration.Strings,
    in locale: Locale = Locale(identifier: "en")
) -> [String] {
    [strings.back, strings.forward, strings.searchPrompt, strings.settingsMenuItem].map {
        resolved($0, in: locale)
    }
}

private extension SidebarSettingsConfiguration.SeparatorMode {
    /// Whether the line under the toolbar shows only while the page is scrolled.
    var showsOnlyWhenScrolled: Bool { if case .whenScrolled = self { true } else { false } }
}

private extension SidebarSettingsConfiguration.SearchMode {
    /// Whether the sidebar has a search field.
    var isEnabled: Bool { if case .enabled = self { true } else { false } }
}

private extension SidebarSettingsConfiguration.NavigationPersistence {
    /// Whether the window shows the page it was closed on.
    var isSession: Bool { if case .session = self { true } else { false } }
}
