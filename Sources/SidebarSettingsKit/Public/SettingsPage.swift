import SwiftUI

/// A page of the settings window: one row in the sidebar and the detail shown when it is
/// selected.
///
/// Any `Hashable` type works, an enum for a fixed set of pages or a struct for pages known
/// only at run time (plug-ins, pages behind a permission).
///
/// ```swift
/// enum Pane: SettingsPage {
///     case general, advanced
///     var id: Self { self }
///     var title: LocalizedStringResource { self == .general ? "General" : "Advanced" }
///     var icon: SettingsIcon { .system(self == .general ? "gearshape" : "wrench.and.screwdriver") }
/// }
/// ```
public protocol SettingsPage: Hashable, Identifiable, Sendable {
    /// The page's name in its sidebar row and, by default, in the window's title.
    var title: LocalizedStringResource { get }

    /// The image in front of the title in the sidebar row.
    @MainActor var icon: SettingsIcon { get }

    /// More words the sidebar's search finds the page by, such as the labels of the
    /// settings on it. Pass them localized. Empty by default.
    var searchKeywords: [String] { get }

    /// Whether the page stays in the sidebar while someone searches for `searchText`.
    ///
    /// The default keeps the page when its title or one of its ``searchKeywords`` contains
    /// the text, ignoring case, diacritics and full- or half-width forms; a blank search keeps
    /// every page.
    /// Implement it to match differently.
    func matches(searchText: String) -> Bool
}

extension SettingsPage {
    /// No keywords: the search matches the title alone.
    public var searchKeywords: [String] { [] }

    /// Matches the title and ``searchKeywords``, ignoring case, diacritics and width.
    public func matches(searchText: String) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return ([String(localized: title)] + searchKeywords).contains {
            $0.range(
                of: query,
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: .current
            ) != nil
        }
    }
}
