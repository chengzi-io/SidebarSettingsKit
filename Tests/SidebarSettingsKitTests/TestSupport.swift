import Foundation
import SidebarSettingsKit
import SwiftUI

/// A string resource as it reads in `locale`: the same lookup the window makes, with the
/// language forced instead of taken from the machine's settings.
func resolved(_ resource: LocalizedStringResource, in locale: Locale) -> String {
    var resource = resource
    resource.locale = locale
    return String(localized: resource)
}
