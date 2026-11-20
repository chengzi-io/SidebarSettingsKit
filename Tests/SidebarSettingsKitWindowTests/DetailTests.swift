import AppKit
import SidebarSettingsFixtures
import SidebarSettingsKit
import SwiftUI
import Testing

@testable import SidebarSettingsKit

extension WindowTestSuite {
    /// The page beside the sidebar: it scrolls itself, a new page starts at its top, and the line
    /// under the toolbar stays wherever the page is scrolled.
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

        /// macOS 14 and 15 draw the line, as System Settings has it; macOS 26 and later ignore
        /// the setting and draw their own edge.
        @Test func theLineUnderTheToolbarStaysThroughScrollingAndPageChanges() async throws {
            try await withWindow(initialPage: FixturePages.appearance) { window in
                #expect(window.separator == .line)
                let detail = try window.detailScrollView()
                // The false-pass rule: the page must be taller than the space it is shown in.
                try requireScrollable(detail, atLeast: LongContentView.minimumHeight)
                scroll(detail, toOffsetFromTop: 300)
                await WindowTest.settle()
                #expect(window.separator == .line)

                window.settings.navigator.open(FixturePages.general)
                try await WindowTest.wait(for: "the short page to replace the long one") {
                    guard let short = firstScrollView(in: window.detailView),
                        let height = short.documentView?.frame.height
                    else { return false }
                    return height <= ShortContentView.maximumHeight
                }
                #expect(window.separator == .line)
            }
        }

        @Test func newPageStartsAtTheTop() async throws {
            try await withWindow(initialPage: FixturePages.appearance) { window in
                let long = try window.detailScrollView()
                try requireScrollable(long, atLeast: LongContentView.minimumHeight)
                scroll(long, toOffsetFromTop: 400)
                // Otherwise the page would pass by never having left the top.
                try #require(scrollOffsetFromTop(long) > 0)

                window.settings.navigator.open(FixturePages.general)
                try await WindowTest.wait(for: "the new page to start at its top") {
                    guard let detail = firstScrollView(in: window.detailView),
                        let height = detail.documentView?.frame.height,
                        height <= ShortContentView.maximumHeight
                    else { return false }
                    return scrollOffsetFromTop(detail) == 0
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
