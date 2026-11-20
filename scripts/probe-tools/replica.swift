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
                    ForEach(1...5, id: \.self) { row in
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
