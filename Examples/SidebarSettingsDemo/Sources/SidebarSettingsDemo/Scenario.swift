import AppKit
import Foundation

/// A demo scenario a `--scenario` argument selects: how the settings window is set up, so a
/// screenshot or a manual check sees one particular behaviour.
enum Scenario: String, Sendable, CaseIterable {
    /// Three pages, opening on a short page, the window at its default 715 × 600.
    case one = "1"
    /// Not set up yet.
    case two = "2"
    /// Not set up yet.
    case three = "3"
    /// Not set up yet.
    case four = "4"
    /// Not set up yet.
    case five = "5"
    /// Not set up yet.
    case six = "6"
    /// Not set up yet.
    case sixB = "6b"
    /// Not set up yet.
    case seven = "7"
}

extension Scenario {
    /// The kit's toolbar identifier, which is how the demo finds the settings window: the kit
    /// exposes no AppKit type by design.
    private static let settingsToolbarIdentifier = "SidebarSettingsKit"

    /// Opens the window this scenario asks for and, with a `--window-id-file`, writes the
    /// window's number there once the window is on screen and laid out.
    @MainActor
    func run(in demo: Demo) {
        switch self {
        case .one:
            demo.settingsWindow.show(page: demo.shortPage)
            Task { @MainActor in await Self.writeWindowID(to: demo.arguments.windowIDFile) }
        case .two, .three, .four, .five, .six, .sixB, .seven:
            DemoArguments.exit("Scenario \(rawValue) is not implemented yet.")
        }
    }

    /// Writes the settings window's number, which is also its CGWindowID.
    @MainActor
    private static func writeWindowID(to path: String?) async {
        guard let path else { return }
        guard let window = await settingsWindow() else {
            DemoArguments.exit("The settings window did not appear.")
        }
        window.layoutIfNeeded()
        do {
            try "\(window.windowNumber)\n".write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            DemoArguments.exit("Cannot write \(path): \(error)")
        }
    }

    /// The settings window, once AppKit has given it a window number and put it on screen.
    @MainActor
    private static func settingsWindow() async -> NSWindow? {
        for _ in 0..<600 {
            let window = NSApp.windows.first {
                $0.toolbar?.identifier == settingsToolbarIdentifier
            }
            if let window, window.isVisible, window.windowNumber != 0 {
                return window
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return nil
    }
}
