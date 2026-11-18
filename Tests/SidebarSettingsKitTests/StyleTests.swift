import SidebarSettingsKit
import SwiftUI
import Testing

/// The two styles the kit ships: `.native` leaves everything to the system, `.branded` names
/// every token.
@Suite("Style presets")
struct StyleTests {
    @Test func nativeLeavesEveryTokenToTheSystem() {
        let style = SidebarSettingsStyle.native

        #expect(style.rowFont == nil)
        #expect(style.iconSize == nil)
        #expect(style.iconTile == nil)
        // The memberwise initializer with every token left out is the same style.
        #expect(SidebarSettingsStyle() == style)
    }

    @Test func brandedNamesEveryToken() {
        let style = SidebarSettingsStyle.branded

        #expect(style.rowFont == .system(size: 14, weight: .medium))
        #expect(style.iconSize == 14)
        #expect(
            style.iconTile
                == SidebarSettingsStyle.IconTile(size: 24, cornerRadius: 6, defaultColor: .gray))
    }

    @Test func changingACopyLeavesThePresetAlone() {
        var style = SidebarSettingsStyle.branded
        style.rowFont = .body
        style.iconSize = 20
        style.iconTile = nil

        let preset = SidebarSettingsStyle.branded
        #expect(preset.rowFont == .system(size: 14, weight: .medium))
        #expect(preset.iconSize == 14)
        #expect(
            preset.iconTile
                == SidebarSettingsStyle.IconTile(size: 24, cornerRadius: 6, defaultColor: .gray))
        // The default is untouched too.
        #expect(SidebarSettingsStyle.native == SidebarSettingsStyle())
    }
}
