import SwiftUI

/// An account row above the sidebar's pages, as System Settings has: an avatar, a name and a
/// line under it. It scrolls with the pages, so a test can scroll it out of sight.
public struct FixtureHeader: View {
    /// The row's height, about the one System Settings' Apple Account row has.
    public static let height: CGFloat = 56

    public init() {}

    public var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.blue.gradient)
                .frame(width: 30, height: 30)
                .overlay {
                    Text("C")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            VStack(alignment: .leading, spacing: 1) {
                Text("Casey Cheng")
                    .font(.body.weight(.semibold))
                Text("Apple Account")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: Self.height)
    }
}

/// A version line fixed at the sidebar's bottom, as a host app's "Version 1.0" line is.
public struct FixtureFooter: View {
    /// The line's height.
    public static let height: CGFloat = 28

    public init() {}

    public var body: some View {
        Text("SidebarSettingsKit 1.0")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: Self.height)
    }
}

/// A login area fixed at the sidebar's bottom, tall enough that a test can tell a footer's
/// height apart from a one-line footer's.
public struct TallFooter: View {
    /// The area's height, which the sidebar must leave for it.
    public static let height: CGFloat = 80

    public init() {}

    public var body: some View {
        VStack(spacing: 6) {
            Text("Sign in to sync your settings")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Sign In") {}
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
    }
}
