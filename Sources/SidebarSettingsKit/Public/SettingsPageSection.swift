import SwiftUI

/// A group of pages in the sidebar.
///
/// A group with a title shows it above its rows, as Finder's sidebar does. A group without
/// one is set apart by space alone, as System Settings does. The two kinds can be mixed. A
/// group without pages is left out.
public struct SettingsPageSection<Page: SettingsPage>: Sendable {
    /// The heading above the group's rows; `nil` for a group set apart by space alone.
    public let title: LocalizedStringResource?

    /// The group's pages, in sidebar order.
    public let pages: [Page]

    /// A group with a heading.
    public init(_ title: LocalizedStringResource, pages: [Page]) {
        self.title = title
        self.pages = pages
    }

    /// A group set apart from its neighbors by space, without a heading.
    public init(pages: [Page]) {
        title = nil
        self.pages = pages
    }
}
