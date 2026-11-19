import AppKit
import DemoFixtures
import Foundation

/// A demo scene a `--scenario` argument selects: how the settings window is set up, so a
/// screenshot or a manual check sees one particular behaviour.
enum Scenario: String, Sendable, CaseIterable {
    /// Three pages, opening on a short page, the window at its default 715 × 600.
    case one = "1"
    /// A long grouped Form scrolled to its end, so the line under the toolbar shows.
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
            // The window's own scroll view, scrolled from inside the page.
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
        if let dumpPath = ProcessInfo.processInfo.environment["SSK_PROBE_DUMP"] {
            try? await Task.sleep(for: .milliseconds(800))
            do {
                try probeDump(of: window).write(toFile: dumpPath, atomically: true, encoding: .utf8)
            } catch {
                DemoArguments.exit("Cannot write \(dumpPath): \(error)")
            }
        }
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

/// Probe branch only: the window's layout, for comparing macOS releases.
@MainActor
private func probeDump(of window: NSWindow) -> String {
    let env = ProcessInfo.processInfo.environment
    var lines = [
        "os: \(ProcessInfo.processInfo.operatingSystemVersionString)",
        "probe: \(env["SSK_PROBE"] ?? "")",
        "window.frame: \(window.frame) contentLayoutRect: \(window.contentLayoutRect)",
        "toolbarStyle: \(window.toolbarStyle.rawValue) titlebarSeparatorStyle: \(window.titlebarSeparatorStyle.rawValue) titleVisibility: \(window.titleVisibility.rawValue)",
        "toolbar items: \((window.toolbar?.items ?? []).map { "\($0.itemIdentifier.rawValue)<\(type(of: $0))>" })",
    ]
    if let split = window.contentViewController as? NSSplitViewController {
        for (index, item) in split.splitViewItems.enumerated() {
            let view = item.viewController.view
            var line = "item\(index): behavior=\(item.behavior.rawValue) fullHeight=\(item.allowsFullHeightLayout) separator=\(item.titlebarSeparatorStyle.rawValue) frameInWindow=\(view.convert(view.bounds, to: nil)) safeArea=\(view.safeAreaInsets) controller=\(type(of: item.viewController))"
            if #available(macOS 26, *) { line += " adjustsSafeArea=\(item.automaticallyAdjustsSafeAreaInsets)" }
            lines.append(line)
        }
    }
    func walk(_ view: NSView, depth: Int) {
        guard depth < 18, lines.count < 4000 else { return }
        var line = String(repeating: "  ", count: depth) + "\(type(of: view)) \(view.convert(view.bounds, to: nil))"
        if view.isHidden { line += " hidden" }
        if view.safeAreaInsets.top != 0 || view.safeAreaInsets.left != 0 { line += " safeArea=\(view.safeAreaInsets)" }
        if let scroll = view as? NSScrollView {
            line += " contentInsets=\(scroll.contentInsets) autoInsets=\(scroll.automaticallyAdjustsContentInsets) clip=\(scroll.contentView.bounds)"
        }
        if let effect = view as? NSVisualEffectView {
            line += " material=\(effect.material.rawValue) blending=\(effect.blendingMode.rawValue) state=\(effect.state.rawValue)"
        }
        if let layer = view.layer, layer.cornerRadius > 0 { line += " corner=\(layer.cornerRadius)" }
        lines.append(line)
        for subview in view.subviews { walk(subview, depth: depth + 1) }
    }
    if let frameView = window.contentView?.superview { walk(frameView, depth: 0) }
    return lines.joined(separator: "\n") + "\n"
}
