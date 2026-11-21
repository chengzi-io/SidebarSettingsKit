import Foundation
import SidebarSettingsKit
import Testing

/// The kit's own words: English text, its translations into every language macOS has, and the
/// words an app puts in place of them.
@Suite("Kit strings")
struct StringsTests {
    private static let english = Locale(identifier: "en")
    private static let simplifiedChinese = Locale(identifier: "zh-Hans")

    /// macOS's 41 languages. English (Australia and UK), French (Canada), Spanish (US) and
    /// Chinese (Hong Kong) use their parent's words, so they have no folder of their own.
    private static let languages: Set<String> = [
        "ar", "ca", "cs", "da", "de", "el", "en", "es", "es-419", "fi", "fr", "he", "hi", "hr",
        "hu", "id", "it", "ja", "ko", "ms", "nb", "nl", "pl", "pt-BR", "pt-PT", "ro", "ru", "sk",
        "sl", "sv", "th", "tr", "uk", "vi", "zh-Hans", "zh-Hant",
    ]

    @Test func theKitBundleHasEveryLanguageMacOSHas() throws {
        // SwiftPM lowercases the folder name (zh-hans.lproj); Foundation matches it either way.
        let shipped = Set(try kitBundle().localizations.map { $0.lowercased() })

        #expect(shipped == Set(Self.languages.map { $0.lowercased() }))
    }

    /// A word missing from one language would show in English there, without an error.
    @Test func everyLanguageHasEveryWord() throws {
        let bundle = try kitBundle()
        let keys = Set(kitStrings().map(\.english))
        for language in bundle.localizations {
            let path = try #require(
                bundle.path(
                    forResource: "Localizable", ofType: "strings", inDirectory: nil,
                    forLocalization: language),
                "\(language)")
            let words = try #require(NSDictionary(contentsOfFile: path) as? [String: String], "\(language)")

            #expect(Set(words.keys) == keys, "\(language)")
            #expect(words.values.allSatisfy { !$0.isEmpty }, "\(language)")
        }
    }

    /// A region without a folder of its own takes its language's words, as macOS's own do.
    @Test(arguments: [
        ("en-GB", "Settings…"), ("es-US", "Configuración…"), ("fr-CA", "Réglages…"),
        ("zh-HK", "設定⋯"),
    ])
    func aRegionTakesItsLanguagesWords(region: String, settingsMenuItem: String) {
        let resource = SidebarSettingsConfiguration.Strings.default.settingsMenuItem

        #expect(resolved(resource, in: Locale(identifier: region)) == settingsMenuItem)
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
        let bundle = try kitBundle()

        #expect(String(localized: resource) == bundle.localizedString(forKey: "Back", value: nil, table: nil))
    }

    @Test func anOverrideReadsAsTheAppWroteIt() {
        let strings = SidebarSettingsConfiguration.Strings(
            back: "Previous",
            forward: "Next",
            searchPrompt: "Find",
            settingsMenuItem: "Preferences…",
            noSearchResults: "Nothing found")

        #expect(resolved(strings.back, in: Self.english) == "Previous")
        #expect(resolved(strings.forward, in: Self.english) == "Next")
        #expect(resolved(strings.searchPrompt, in: Self.english) == "Find")
        #expect(resolved(strings.settingsMenuItem, in: Self.english) == "Preferences…")
        #expect(resolved(strings.noSearchResults, in: Self.english) == "Nothing found")
        // A language the app did not translate still shows the app's words, not the kit's.
        #expect(resolved(strings.back, in: Self.simplifiedChinese) == "Previous")
    }
}

/// The defaults the kit ships, each with the text its resource file gives in English and
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
        ("noSearchResults", strings.noSearchResults, "No Results", "无结果"),
    ]
}

/// The bundle the kit's own words come from.
private func kitBundle() throws -> Bundle {
    let resource = SidebarSettingsConfiguration.Strings.default.back
    guard case .atURL(let url) = resource.bundle else {
        throw KitBundleNotFound()
    }
    return try #require(Bundle(url: url))
}

/// The kit's strings came from a bundle other than the kit's resource bundle.
private struct KitBundleNotFound: Error {}
