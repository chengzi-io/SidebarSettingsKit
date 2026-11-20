import AppKit
import DemoFixtures
import Foundation

/// A demo scene a `--scenario` argument selects: how the settings window is set up, so a
/// screenshot or a manual check sees one particular behaviour.
enum Scenario: String, Sendable {
    /// Three pages, opening on a short page, the window at its default 715 × 600.
    case one = "1"
    /// A long grouped Form scrolled to its end, under the toolbar.
    case two = "2"
    /// The 40+ page set, opened on its last page with the sidebar scrolled to it.
    case three = "3"
    /// The pages in three groups, set apart by space.
    case four = "4"
    /// An account header and the tall login area as the footer.
    case five = "5"
    /// A search that finds pages.
    case six = "6"
    /// A search that finds nothing.
    case sixB = "6b"
    /// A page with a 60-character title, the kit's own words in Simplified Chinese.
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
        var options = demo.options
        var page: FixturePage?
        var searchText: String?
        var startScrolled = false
        switch self {
        case .one:
            break
        case .two:
            page = FixturePages.appearance
            startScrolled = true
        case .three:
            options.pages = .many
            page = options.pages.fixturePages.last
        case .four:
            options.grouping = .grouped
        case .five:
            options.chrome = .both
            options.tallFooter = true
        case .six:
            page = FixturePages.appearance
            searchText = "app"
        case .sixB:
            searchText = "zzz"
        case .seven:
            options.pages = .many
            page = FixturePages.longEnglishTitle
        }
        demo.apply(options, startScrolled: startScrolled, selecting: page, searchText: searchText)
        Task { @MainActor in await Self.writeWindowID(to: demo.arguments.windowIDFile) }
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
            if let dumpPath = ProcessInfo.processInfo.environment["SSK_PROBE_DUMP"] {
                try await Task.sleep(for: .seconds(1))
                try probeDump(of: window).write(toFile: dumpPath, atomically: true, encoding: .utf8)
            }
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

/// Probe branch only: the window's layers and colors.
@MainActor
func probeDump(of window: NSWindow) -> String {
    var lines = [
        "os \(ProcessInfo.processInfo.operatingSystemVersionString)",
        "app appearance \(NSApp.effectiveAppearance.name.rawValue) window appearance \(window.effectiveAppearance.name.rawValue)",
        "window \(type(of: window)) opaque=\(window.isOpaque) bg=\(window.backgroundColor.description) alpha=\(window.alphaValue) styleMask=\(window.styleMask.rawValue) toolbarStyle=\(window.toolbarStyle.rawValue) key=\(window.isKeyWindow) main=\(window.isMainWindow) appActive=\(NSApp.isActive)",
    ]
    window.effectiveAppearance.performAsCurrentDrawingAppearance {
        if let c = NSColor.windowBackgroundColor.usingColorSpace(.sRGB) {
            lines.append("windowBackgroundColor \(Int(c.redComponent * 255)) \(Int(c.greenComponent * 255)) \(Int(c.blueComponent * 255))")
        }
    }
    for other in NSApp.windows where other.isVisible {
        lines.append("visible window \(type(of: other)) frame=\(other.frame) level=\(other.level.rawValue) title=\(other.title)")
    }
    func walk(_ view: NSView, depth: Int) {
        guard depth < 14 else { return }
        var line = String(repeating: "  ", count: depth) + "\(type(of: view)) \(view.convert(view.bounds, to: nil))"
        if view.isHidden { line += " hidden" }
        if view.alphaValue < 1 { line += " alpha=\(view.alphaValue)" }
        if let effect = view as? NSVisualEffectView {
            line += " EFFECT material=\(effect.material.rawValue) blending=\(effect.blendingMode.rawValue) state=\(effect.state.rawValue)"
        }
        if let color = view.layer?.backgroundColor, color.alpha > 0 { line += " layerBg=\(color.components ?? [])" }
        if let layer = view.layer, layer.opacity < 1 { line += " layerOpacity=\(layer.opacity)" }
        if let filters = view.layer?.compositingFilter { line += " compositing=\(filters)" }
        lines.append(line)
        for subview in view.subviews { walk(subview, depth: depth + 1) }
    }
    if let frameView = window.contentView?.superview { walk(frameView, depth: 0) }
    return lines.joined(separator: "\n") + "\n"
}
