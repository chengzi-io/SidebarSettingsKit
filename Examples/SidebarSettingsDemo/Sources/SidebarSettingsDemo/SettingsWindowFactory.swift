import DemoFixtures
import SidebarSettingsKit
import SwiftUI

/// Builds the settings window the control panel's options describe. A
/// ``SidebarSettingsWindow`` keeps its configuration for its lifetime, so every change means
/// a new window.
@MainActor
enum SettingsWindowFactory {
    /// A window for `options`, its long page already at its end when `startScrolled` is set.
    static func make(
        options: DemoOptions,
        startScrolled: Bool = false
    ) -> SidebarSettingsWindow<FixturePage> {
        let sections = options.grouping.sections(of: options.pages.fixturePages)
        let configuration = options.configuration
        let detail = { (page: FixturePage) in
            DemoPage(page: page, startScrolled: startScrolled)
        }
        let header = { FixtureHeader() }
        let footer = { DemoFooter(tall: options.tallFooter) }
        // The kit takes the header and the footer as generic parameters, so each combination
        // needs its own initializer.
        switch (options.chrome.showsHeader, options.chrome.showsFooter) {
        case (false, false):
            return SidebarSettingsWindow(
                sections: sections, configuration: configuration, detail: detail)
        case (true, false):
            return SidebarSettingsWindow(
                sections: sections, configuration: configuration, header: header,
                detail: detail)
        case (false, true):
            return SidebarSettingsWindow(
                sections: sections, configuration: configuration, footer: footer,
                detail: detail)
        case (true, true):
            return SidebarSettingsWindow(
                sections: sections, configuration: configuration, header: header,
                footer: footer, detail: detail)
        }
    }
}

/// The sidebar's footer: the version line, or the taller login area.
private struct DemoFooter: View {
    let tall: Bool

    var body: some View {
        if tall {
            TallFooter()
        } else {
            FixtureFooter()
        }
    }
}

/// A page as most apps write one, and as System Settings' are: a grouped `Form`, which scrolls
/// itself and gives its switches System Settings' size.
private struct DemoPage: View {
    let page: FixturePage
    /// Whether the page opens scrolled to its end.
    let startScrolled: Bool

    /// The settings that are on; every second one to begin with.
    @State private var on = Set(stride(from: 2, through: Self.longRowCount, by: 2))

    private static let longRowCount = 48
    private static let shortRowCount = 5
    private static let rowsPerSection = 8

    private var rowCount: Int {
        switch page.contentKind {
        case .short: Self.shortRowCount
        case .long: Self.longRowCount
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                ForEach(Array(stride(from: 1, through: rowCount, by: Self.rowsPerSection)), id: \.self) {
                    first in
                    Section {
                        ForEach(first...min(first + Self.rowsPerSection - 1, rowCount), id: \.self) { row in
                            Toggle("Setting \(row)", isOn: isOn(row))
                                .id(row)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .task { await scrollToEnd(proxy) }
        }
    }

    private func isOn(_ row: Int) -> Binding<Bool> {
        Binding {
            on.contains(row)
        } set: {
            if $0 { on.insert(row) } else { on.remove(row) }
        }
    }

    /// A page that opens scrolled has to wait for the form to take its size first.
    private func scrollToEnd(_ proxy: ScrollViewProxy) async {
        guard startScrolled else { return }
        try? await Task.sleep(for: .milliseconds(300))
        proxy.scrollTo(rowCount, anchor: .bottom)
    }
}
