import Foundation
import SidebarSettingsKit
import Testing

/// The kit's own words: English text, the Simplified Chinese translation behind it, and the
/// words an app puts in place of both.
@Suite("Kit strings")
struct StringsTests {
    private static let english = Locale(identifier: "en")
    private static let simplifiedChinese = Locale(identifier: "zh-Hans")

    @Test func theKitBundleDeclaresEnglishAndSimplifiedChinese() throws {
        let resource = SidebarSettingsConfiguration.Strings.default.back
        guard case .atURL(let url) = resource.bundle else {
            Issue.record("The kit's strings come from a bundle other than the kit's resource bundle.")
            return
        }
        let localizations = try #require(Bundle(url: url)).localizations

        // SwiftPM lowercases the folder name (zh-hans.lproj); Foundation matches it either way.
        let lowercased = localizations.map { $0.lowercased() }
        #expect(lowercased.contains("en"))
        #expect(lowercased.contains("zh-hans"))
    }

    @Test func eachDefaultStringIsEnglishInEnglish() {
        for string in kitStrings() {
            #expect(resolved(string.resource, in: Self.english) == string.english, "\(string.name)")
        }
    }

    @Test func eachDefaultStringIsTranslatedInSimplifiedChinese() {
        for string in kitStrings() {
            #expect(
                resolved(string.resource, in: Self.simplifiedChinese) == string.chinese,
                "\(string.name)")
        }
    }

    /// An app that speaks only English shows the kit's English even on a Mac set to Chinese,
    /// as AppKit's own words do: the kit follows the language the app runs in, which the
    /// bundle API picks, not the system's locale.
    @Test func defaultStringsFollowTheLanguageTheAppRunsIn() throws {
        let resource = SidebarSettingsConfiguration.Strings.default.back
        guard case .atURL(let url) = resource.bundle else {
            Issue.record("The kit's strings come from a bundle other than the kit's resource bundle.")
            return
        }
        let bundle = try #require(Bundle(url: url))

        #expect(String(localized: resource) == bundle.localizedString(forKey: "Back", value: nil, table: nil))
    }

    @Test func anOverrideReadsAsTheAppWroteIt() {
        let strings = SidebarSettingsConfiguration.Strings(
            back: "Previous",
            forward: "Next",
            searchPrompt: "Find",
            settingsMenuItem: "Preferences…")

        #expect(resolved(strings.back, in: Self.english) == "Previous")
        #expect(resolved(strings.forward, in: Self.english) == "Next")
        #expect(resolved(strings.searchPrompt, in: Self.english) == "Find")
        #expect(resolved(strings.settingsMenuItem, in: Self.english) == "Preferences…")
        // A language the app did not translate still shows the app's words, not the kit's.
        #expect(resolved(strings.back, in: Self.simplifiedChinese) == "Previous")
    }
}

/// The four defaults the kit ships, each with the text its resource file gives in English and
/// in Simplified Chinese.
private func kitStrings() -> [(
    name: String, resource: LocalizedStringResource, english: String, chinese: String
)] {
    let strings = SidebarSettingsConfiguration.Strings.default
    return [
        ("back", strings.back, "Back", "返回"),
        ("forward", strings.forward, "Forward", "前进"),
        ("searchPrompt", strings.searchPrompt, "Search", "搜索"),
        ("settingsMenuItem", strings.settingsMenuItem, "Settings…", "设置…"),
    ]
}
