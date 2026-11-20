import Foundation

/// The page sets the unit tests and the demo build windows from.
public enum FixturePages {
    /// Three pages, the first one short so a window opens on a page that fits without
    /// scrolling; one of them is long enough to scroll.
    public static let three: [FixturePage] = [general, appearance, advanced]

    /// Forty pages: more rows than fit the sidebar at the default 600 pt window height, so the
    /// sidebar must scroll.
    public static let many: [FixturePage] = (1...40).map { index in
        FixturePage(
            id: "many-\(index)",
            title: "Page \(index)",
            searchKeywords: ["page \(index)"],
            iconDescription: .system(name: "square.grid.2x2"),
            contentKind: index.isMultiple(of: 3) ? .long : .short
        )
    }

    /// A short page with a plain symbol icon.
    public static let general = FixturePage(
        id: "general",
        title: "General",
        searchKeywords: ["about", "software update"],
        iconDescription: .system(name: "gearshape"),
        contentKind: .short
    )

    /// A long page, scrolling to several times the window's height.
    public static let appearance = FixturePage(
        id: "appearance",
        title: "Appearance",
        searchKeywords: ["dark mode", "accent color"],
        iconDescription: .system(name: "paintbrush", tint: .blue),
        contentKind: .long
    )

    /// A short page after the long one, so a window can switch between the two heights.
    public static let advanced = FixturePage(
        id: "advanced",
        title: "Advanced",
        searchKeywords: ["developer", "logs"],
        iconDescription: .system(name: "wrench.and.screwdriver"),
        contentKind: .short
    )

    /// The pages that stress long text and search: titles of 60 characters, Chinese, a mix of
    /// Chinese and English, and keywords that are long, Chinese or full-width Latin.
    public static let longText: [FixturePage] = [
        longEnglishTitle, chineseTitle, mixedTitle, longKeyword, widthInsensitiveKeywords,
    ]

    /// A 60-character English title, which the sidebar has to truncate instead of widening.
    public static let longEnglishTitle = FixturePage(
        id: "long-english-title",
        title: "Advanced Network Diagnostics and Developer Preferences Panel",
        searchKeywords: ["diagnostics"],
        contentKind: .short
    )

    /// A Chinese title, whose glyphs are full width at the same point size.
    public static let chineseTitle = FixturePage(
        id: "chinese-title",
        title: "通用与隐私设置",
        searchKeywords: ["通用", "隐私"],
        contentKind: .short
    )

    /// A title mixing Chinese and English, as software localized in both looks.
    public static let mixedTitle = FixturePage(
        id: "mixed-title",
        title: "Wi-Fi 与蓝牙",
        searchKeywords: ["无线网络", "wireless"],
        contentKind: .short
    )

    /// A keyword longer than 100 characters, which the search must still match from any part.
    public static let longKeyword = FixturePage(
        id: "long-keyword",
        title: "Keywords",
        searchKeywords: [
            "diagnostics developer tools network permissions advanced privacy localization "
                + "accessibility appearance notifications battery storage security updates "
                + "troubleshooting",
        ],
        contentKind: .short
    )

    /// Keywords in Chinese and in full-width Latin letters, which a search typed in ordinary
    /// width must match.
    public static let widthInsensitiveKeywords = FixturePage(
        id: "width-insensitive-keywords",
        title: "Width-Insensitive Keywords",
        searchKeywords: ["ＡＢＣ", "中文关键词"],
        contentKind: .short
    )
}
