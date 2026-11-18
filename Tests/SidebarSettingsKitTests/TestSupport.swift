import Foundation
import SidebarSettingsKit
import SwiftUI

/// The groups' headings as a person reads them, `nil` for a group set apart by space alone, so
/// a test can compare a sidebar's groups with a list of words.
func titles<Page: SettingsPage>(_ sections: [SettingsPageSection<Page>]) -> [String?] {
    sections.map { section in
        section.title.map { String(localized: $0) }
    }
}

/// A string resource as it reads in `locale`: the same lookup the window makes, with the
/// language forced instead of taken from the machine's settings.
func resolved(_ resource: LocalizedStringResource, in locale: Locale) -> String {
    var resource = resource
    resource.locale = locale
    return String(localized: resource)
}
