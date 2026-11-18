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
        let style = options.style.sidebarStyle
        let detail = { (page: FixturePage) in
            DemoDetail(
                page: page,
                scrollsItself: !options.detailScrolling,
                startScrolled: startScrolled
            )
        }
        let header = { FixtureHeader() }
        let footer = { DemoFooter(tall: options.tallFooter) }
        // The kit takes the header and the footer as generic parameters, so each combination
        // needs its own initializer.
        switch (options.chrome.showsHeader, options.chrome.showsFooter) {
        case (false, false):
            return SidebarSettingsWindow(
                sections: sections, configuration: configuration, style: style, detail: detail)
        case (true, false):
            return SidebarSettingsWindow(
                sections: sections, configuration: configuration, style: style, header: header,
                detail: detail)
        case (false, true):
            return SidebarSettingsWindow(
                sections: sections, configuration: configuration, style: style, footer: footer,
                detail: detail)
        case (true, true):
            return SidebarSettingsWindow(
                sections: sections, configuration: configuration, style: style, header: header,
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

/// A page's detail. When the window does not put pages in a scroll view, the page brings its
/// own and tells the window's separator where it is.
private struct DemoDetail: View {
    let page: FixturePage
    let scrollsItself: Bool
    let startScrolled: Bool

    private static let endAnchor = "end"

    var body: some View {
        if scrollsItself {
            ScrollViewReader { proxy in
                ScrollView { content }
                    .sidebarSettingsScrollTracking()
                    .task { await scrollToEnd(proxy) }
            }
        } else if startScrolled {
            // The window owns the scroll view; a reader inside it scrolls that one.
            ScrollViewReader { proxy in
                content.task { await scrollToEnd(proxy) }
            }
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            if page == FixturePages.appearance {
                LongFormPage()
            } else {
                FixtureDetail(page: page)
            }
            if startScrolled {
                Color.clear
                    .frame(height: 1)
                    .id(Self.endAnchor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// A page that opens scrolled has to wait for the scroll view to take its size first.
    private func scrollToEnd(_ proxy: ScrollViewProxy) async {
        guard startScrolled else { return }
        try? await Task.sleep(for: .milliseconds(300))
        proxy.scrollTo(Self.endAnchor, anchor: .bottom)
    }
}

/// The demo's long page, written the way most apps write a settings page: a grouped `Form`,
/// taller than the window and scrolled by the window's scroll view.
private struct LongFormPage: View {
    private static let rowCount = 48

    var body: some View {
        Form {
            ForEach(1...Self.rowCount, id: \.self) { row in
                Toggle("Setting \(row)", isOn: .constant(row.isMultiple(of: 2)))
            }
        }
        .formStyle(.grouped)
    }
}
