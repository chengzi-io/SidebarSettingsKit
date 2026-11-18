import SwiftUI

/// A detail several times the window's height, so a page that shows it has to scroll.
///
/// Sixty-four setting-like rows of a fixed height, which keeps the height the same on every
/// machine and every appearance.
public struct LongContentView: View {
    /// The least height the view has, 3 times the default 600 pt window height; a test asserts
    /// the window scrolls past it.
    public static let minimumHeight: CGFloat = 1800

    private static let rowHeight: CGFloat = 32
    private static let rowCount = 64

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<Self.rowCount, id: \.self) { row in
                HStack {
                    Text("Setting \(row + 1)")
                    Spacer()
                    Toggle("Setting \(row + 1)", isOn: .constant(row.isMultiple(of: 2)))
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                .padding(.horizontal, 20)
                .frame(height: Self.rowHeight)
                Divider()
            }
        }
    }
}

/// A detail shorter than the window, so a page that shows it fits without scrolling.
///
/// Five setting-like rows of a fixed height.
public struct ShortContentView: View {
    /// The most height the view has, which a test asserts a short page stays under.
    public static let maximumHeight: CGFloat = 300

    private static let rowHeight: CGFloat = 28
    private static let rowCount = 5

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<Self.rowCount, id: \.self) { row in
                HStack {
                    Text("Option \(row + 1)")
                    Spacer()
                    Toggle("Option \(row + 1)", isOn: .constant(row.isMultiple(of: 2)))
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                .padding(.horizontal, 20)
                .frame(height: Self.rowHeight)
                Divider()
            }
        }
    }
}

/// The detail of a ``FixturePage``: its title over the long or short control list, chosen by
/// the page's ``FixturePage/ContentKind``.
public struct FixtureDetail: View {
    /// The page to draw.
    public let page: FixturePage

    /// The detail for `page`.
    public init(page: FixturePage) {
        self.page = page
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(page.title)
                .font(.title2)
                .padding(20)
            switch page.contentKind {
            case .short: ShortContentView()
            case .long: LongContentView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
