import AppKit
import SwiftUI

/// Probe branch only: System Settings' layout in plain SwiftUI, to compare with the kit's.
struct ProbeReplica: View {
    @State private var selection: String? = "Appearance"
    @State private var search = ""
    private let pages = ["General", "Appearance", "Advanced"]
    private let mode = ProcessInfo.processInfo.environment["SSK_PROBE_REPLICA"] ?? ""

    var body: some View {
        NavigationSplitView {
            List(pages, id: \.self, selection: $selection) { page in
                Label(page, systemImage: "gearshape")
            }
            .searchable(text: $search, placement: .sidebar)
            .navigationSplitViewColumnWidth(215)
        } detail: {
            ScrollViewReader { proxy in
                Form {
                    ForEach(1...48, id: \.self) { row in
                        Toggle("Setting \(row)", isOn: .constant(row.isMultiple(of: 2))).id(row)
                    }
                }
                .formStyle(.grouped)
                .task {
                    guard mode.contains("end") else { return }
                    try? await Task.sleep(for: .milliseconds(300))
                    proxy.scrollTo(48, anchor: .bottom)
                }
            }
            .navigationTitle(selection ?? "")
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button {} label: { Image(systemName: "chevron.backward") }
                    Button {} label: { Image(systemName: "chevron.forward") }
                }
            }
        }
        .modifier(RemovesSidebarToggle(removes: !mode.contains("toggle")))
        .frame(width: 715, height: 600)
        .background(WindowReporter())
    }
}

private struct RemovesSidebarToggle: ViewModifier {
    let removes: Bool

    func body(content: Content) -> some View {
        if removes {
            content.toolbar(removing: .sidebarToggle)
        } else {
            content
        }
    }
}

/// Writes the window's layout and number once it has settled.
private struct WindowReporter: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ReporterView() }
    func updateNSView(_ view: NSView, context: Context) {}

    private final class ReporterView: NSView {
        private var reported = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, !reported else { return }
            reported = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1500))
                let env = ProcessInfo.processInfo.environment
                do {
                    if let path = env["SSK_PROBE_DUMP"] {
                        try probeDump(of: window).write(toFile: path, atomically: true, encoding: .utf8)
                    }
                    if let path = env["SSK_PROBE_ID_FILE"] {
                        try "\(window.windowNumber)\n".write(toFile: path, atomically: true, encoding: .utf8)
                    }
                } catch {
                    DemoArguments.exit("Cannot write the probe files: \(error)")
                }
            }
        }
    }
}
