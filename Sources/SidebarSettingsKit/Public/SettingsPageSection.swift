import SwiftUI

/// A group of pages in the sidebar, set apart from its neighbors by space, as System Settings'
/// groups are. A group without pages is left out.
public struct SettingsPageSection<Page: SettingsPage>: Sendable {
    /// The group's pages, in sidebar order.
    public let pages: [Page]

    /// A group of `pages`, in sidebar order.
    public init(pages: [Page]) {
        self.pages = pages
    }
}
