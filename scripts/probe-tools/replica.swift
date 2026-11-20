// Probe branch only: a plain SwiftUI window shaped like System Settings, to compare with the kit's.
import AppKit
import SwiftUI

@main
struct Replica: App {
    @State private var selection: String? = "General"
    private let pages = ["General", "Appearance", "Advanced"]

    init() {
        if ProcessInfo.processInfo.environment["SSK_REPLICA_AQUA"] != nil {
            NSApplication.shared.appearance = NSAppearance(named: .aqua)
        }
    }

    var body: some Scene {
        Window("General", id: "replica") {
            NavigationSplitView {
                List(pages, id: \.self, selection: $selection) { page in
                    Label(page, systemImage: "gearshape")
                }
                .navigationSplitViewColumnWidth(215)
            } detail: {
                Form {
                    ForEach(1...45, id: \.self) { row in
                        Toggle("Setting \(row)", isOn: .constant(row.isMultiple(of: 2)))
                    }
                }
                .formStyle(.grouped)
                .navigationTitle(selection ?? "")
                .toolbar {
                    ToolbarItemGroup(placement: .navigation) {
                        Button {} label: { Image(systemName: "chevron.backward") }
                        Button {} label: { Image(systemName: "chevron.forward") }
                    }
                }
            }
            .toolbar(removing: .sidebarToggle)
            .frame(width: 715, height: 600)
            .onAppear {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    dumpWindows()
                    // Again every 2 s, so the last one is after the probe script scrolls the page.
                    while let path = ProcessInfo.processInfo.environment["SSK_PROBE_TREE"] {
                        if let window = NSApp.windows.first(where: { $0.isVisible && $0.toolbar != nil }) {
                            try? probeTree(window).write(toFile: path, atomically: true, encoding: .utf8)
                        }
                        try? await Task.sleep(for: .seconds(2))
                    }
                }
            }
        }
        .windowResizability(.contentSize)
    }
}

@MainActor
func dumpWindows() {
    var lines: [String] = []
    func walk(_ view: NSView, depth: Int) {
        guard depth < 6 else { return }
        var line = String(repeating: "  ", count: depth) + "\(type(of: view)) \(view.convert(view.bounds, to: nil))"
        if view.isHidden { line += " hidden" }
        if let effect = view as? NSVisualEffectView {
            line += " EFFECT material=\(effect.material.rawValue) blending=\(effect.blendingMode.rawValue) state=\(effect.state.rawValue)"
        }
        if let color = view.layer?.backgroundColor, color.alpha > 0 { line += " layerBg=\(color.components ?? [])" }
        lines.append(line)
        for subview in view.subviews { walk(subview, depth: depth + 1) }
    }
    for window in NSApp.windows where window.isVisible {
        lines.append("window \(type(of: window)) opaque=\(window.isOpaque) bg=\(window.backgroundColor.description) styleMask=\(window.styleMask.rawValue) toolbarStyle=\(window.toolbarStyle.rawValue)")
        if let frameView = window.contentView?.superview { walk(frameView, depth: 0) }
    }
    let path = ProcessInfo.processInfo.environment["SSK_REPLICA_DUMP"] ?? "/tmp/replica-dump.txt"
    try! lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
}

// Probe only: the window frame's views, deep, for comparing the kit with a SwiftUI window.
@MainActor
func probeTree(_ window: NSWindow) -> String {
    var lines: [String] = []
    lines.append("window \(type(of: window)) title=\(window.title.debugDescription) titleVisibility=\(window.titleVisibility.rawValue) toolbarStyle=\(window.toolbarStyle.rawValue) titlebarSeparatorStyle=\(window.titlebarSeparatorStyle.rawValue) contentVC=\(window.contentViewController.map { "\(type(of: $0))" } ?? "nil")")
    if let toolbar = window.toolbar {
        lines.append("toolbar items=\(toolbar.items.map { "\($0.itemIdentifier.rawValue)" }) displayMode=\(toolbar.displayMode.rawValue)")
    }
    @MainActor func splitInfo(_ vc: NSViewController, depth: Int) {
        if let split = vc as? NSSplitViewController {
            for (i, item) in split.splitViewItems.enumerated() {
                var line = String(repeating: "  ", count: depth) + "splitItem[\(i)] behavior=\(item.behavior.rawValue) sep=\(item.titlebarSeparatorStyle.rawValue) fullHeight=\(item.allowsFullHeightLayout) vc=\(type(of: item.viewController))"
                if #available(macOS 26.0, *) {
                    line += " safeArea=\(item.automaticallyAdjustsSafeAreaInsets) top=\(item.topAlignedAccessoryViewControllers.count)"
                }
                lines.append(line)
                splitInfo(item.viewController, depth: depth + 1)
            }
        }
        for child in vc.children where !(vc is NSSplitViewController) { splitInfo(child, depth: depth + 1) }
    }
    if let vc = window.contentViewController { splitInfo(vc, depth: 0) }
    @MainActor func walk(_ view: NSView, depth: Int) {
        guard depth < 30 else { return }
        var line = String(repeating: " ", count: depth) + "\(type(of: view)) \(view.convert(view.bounds, to: nil).integral)"
        if view.isHidden { line += " hidden" }
        if view.alphaValue < 1 { line += " alpha=\(view.alphaValue)" }
        if let scroll = view as? NSScrollView {
            line += " SCROLL insets=\(scroll.contentInsets) auto=\(scroll.automaticallyAdjustsContentInsets) y=\(scroll.contentView.bounds.origin.y)"
        }
        if let field = view as? NSTextField { line += " text=\(field.stringValue.debugDescription)" }
        lines.append(line)
        // Rows of the lists and forms add nothing.
        if view is NSTableRowView { return }
        for sub in view.subviews { walk(sub, depth: depth + 1) }
    }
    if let frame = window.contentView?.superview { walk(frame, depth: 0) }
    return lines.joined(separator: "\n") + "\n"
}
