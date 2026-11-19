import AppKit
import SidebarSettingsFixtures
import SidebarSettingsKit
import SwiftUI
import Testing

@testable import SidebarSettingsKit

extension WindowTestSuite {
    /// A page that is a grouped `Form`, as System Settings' pages are: it scrolls itself, and the
    /// window adds no scroll view around it. On macOS 14 and 15 the toolbar takes its background
    /// from the scroll view right under it; around a scroll view of the kit's, it drew a lighter
    /// bar with an edge, though nothing was scrolled.
    @Suite(.serialized) @MainActor
    struct GroupedFormTests {
        @Test func theFormsScrollViewIsTheOnlyOneInTheDetail() async throws {
            try await withWindow(
                pages: FixturePages.three, configuration: .windowTest,
                detail: { _ in GroupedFormPage() }
            ) { window in
                let scrollViews = allViews(in: window.detailView).compactMap { $0 as? NSScrollView }
                #expect(scrollViews.count == 1, "scroll views in the detail: \(scrollViews)")
            }
        }

        @Test func separatorFollowsAGroupedForm() async throws {
            try await withWindow(
                pages: FixturePages.three, configuration: .windowTest,
                detail: { _ in GroupedFormPage() }
            ) { window in
                let detail = try window.detailScrollView()
                // The false-pass rule: the form must be taller than the space it is shown in.
                try requireScrollable(detail, atLeast: GroupedFormPage.minimumHeight)

                if #available(macOS 15.0, *) {
                    try await WindowTest.wait(for: "the line to be hidden at the top") {
                        window.separator == .none
                    }
                    scroll(detail, toOffsetFromTop: 300)
                    try await WindowTest.wait(for: "the line to show past the top") {
                        window.separator == .line
                    }
                    scroll(detail, toOffsetFromTop: 0)
                    try await WindowTest.wait(for: "the line to hide again at the top") {
                        window.separator == .none
                    }
                } else {
                    // macOS 14 cannot report a scroll offset to SwiftUI, so `.whenScrolled`
                    // shows the line always; there is nothing here to switch.
                    #expect(window.separator == .line)
                }
            }
        }
    }
}

/// Forty-five settings rows in a grouped form, several times the window's height.
private struct GroupedFormPage: View {
    /// The least height the form has, well past the 600 pt window.
    static let minimumHeight: CGFloat = 1000

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
