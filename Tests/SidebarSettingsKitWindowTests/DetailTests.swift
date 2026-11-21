import AppKit
import SidebarSettingsFixtures
import SidebarSettingsKit
import SwiftUI
import Testing

@testable import SidebarSettingsKit

extension WindowTestSuite {
    /// The page beside the sidebar: it scrolls itself, a new page starts at its top, and the line
    /// under the toolbar follows the page's scroll position.
    @Suite(.serialized) @MainActor
    struct DetailTests {
        /// On macOS 14 and 15 the toolbar takes its background from the scroll view right under
        /// it; around a scroll view of the kit's, it drew a lighter bar with an edge, though
        /// nothing was scrolled.
        @Test func theFormsScrollViewIsTheOnlyOneInTheDetail() async throws {
            let settings = SidebarSettingsWindow(
                pages: FixturePages.three, configuration: .windowTest
            ) { _ in GroupedFormPage() }
            try await withWindow(settings) { window in
                let scrollViews = allViews(in: window.detailView).compactMap { $0 as? NSScrollView }
                #expect(scrollViews.count == 1, "scroll views in the detail: \(scrollViews)")
            }
        }

        /// As System Settings on macOS 15: no line at the top of the page, a line with a shadow
        /// once it scrolls under the toolbar. macOS 14 cannot report the scroll position, so the
        /// line shows always; macOS 26 and later ignore the style.
        @Test func theLineUnderTheToolbarFollowsTheScroll() async throws {
            try await withWindow(initialPage: FixturePages.appearance) { window in
                let detail = try window.detailScrollView()
                // The false-pass rule: the page must be taller than the space it is shown in.
                try requireScrollable(detail, atLeast: LongContentView.minimumHeight)
                guard #available(macOS 15.0, *) else {
                    #expect(window.separator == .line)
                    return
                }
                try await WindowTest.wait(for: "no line at the top") { window.separator == .none }
                scroll(detail, toOffsetFromTop: 200)
                try await WindowTest.wait(for: "the line past the top") { window.separator == .shadow }
                scroll(detail, toOffsetFromTop: 0)
                try await WindowTest.wait(for: "no line back at the top") { window.separator == .none }
            }
        }

        @Test func newPageStartsAtTheTop() async throws {
            try await withWindow(initialPage: FixturePages.appearance) { window in
                let long = try window.detailScrollView()
                try requireScrollable(long, atLeast: LongContentView.minimumHeight)
                scroll(long, toOffsetFromTop: 400)
                // Otherwise the page would pass by never having left the top.
                try #require(scrollOffsetFromTop(long) > 0)
                if #available(macOS 15.0, *) {
                    try await WindowTest.wait(for: "the line while scrolled") {
                        window.separator == .shadow
                    }
                }

                window.settings.navigator.open(FixturePages.general)
                try await WindowTest.wait(for: "the new page to start at its top") {
                    guard let detail = firstScrollView(in: window.detailView),
                        let height = detail.documentView?.frame.height,
                        height <= ShortContentView.maximumHeight
                    else { return false }
                    return scrollOffsetFromTop(detail) == 0
                }
                if #available(macOS 15.0, *) {
                    try await WindowTest.wait(for: "no line on the new page") {
                        window.separator == .none
                    }
                }
            }
        }
    }
}

/// Forty-five settings rows in a grouped form, as System Settings' pages are, several times the
/// window's height.
private struct GroupedFormPage: View {
    private static let rowCount = 45

    var body: some View {
        Form {
            ForEach(0..<Self.rowCount, id: \.self) { row in
                LabeledContent("Setting \(row + 1)") {
                    Toggle("Setting \(row + 1)", isOn: .constant(row.isMultiple(of: 2)))
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
        }
        .formStyle(.grouped)
    }
}
