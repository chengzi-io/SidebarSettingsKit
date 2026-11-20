import AppKit
import SidebarSettingsFixtures
import SwiftUI
import Testing

@testable import SidebarSettingsKit

extension WindowTestSuite {
    /// Probe branch only: what lies behind the page, with Reduce Transparency as the system has it.
    @Suite(.serialized) @MainActor
    struct GlassProbeTests {
        @Test func dumpTheLayersBehindThePage() async throws {
            let settings = SidebarSettingsWindow(
                pages: FixturePages.three, configuration: .windowTest
            ) { _ in
                Form { Toggle("Setting", isOn: .constant(true)) }.formStyle(.grouped)
            }
            try await withWindow(settings) { window in
                try await Task.sleep(for: .seconds(1))
                let w = window.window
                var lines = [
                    "os \(ProcessInfo.processInfo.operatingSystemVersionString) reduceTransparency=\(NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency)",
                    "window opaque=\(w.isOpaque) backgroundColor=\(w.backgroundColor.description) styleMask=\(w.styleMask.rawValue) toolbarStyle=\(w.toolbarStyle.rawValue)",
                ]
                w.effectiveAppearance.performAsCurrentDrawingAppearance {
                    let names: [(String, NSColor)] = [
                        ("windowBackgroundColor", .windowBackgroundColor),
                        ("controlBackgroundColor", .controlBackgroundColor),
                        ("underPageBackgroundColor", .underPageBackgroundColor),
                        ("textBackgroundColor", .textBackgroundColor),
                    ]
                    for (name, color) in names {
                        let rgb = color.usingColorSpace(.sRGB)
                        lines.append("\(name) = \(rgb.map { "\(Int($0.redComponent * 255)) \(Int($0.greenComponent * 255)) \(Int($0.blueComponent * 255)) a\($0.alphaComponent)" } ?? "pattern")")
                    }
                }
                @MainActor func walk(_ view: NSView, depth: Int) {
                    guard depth < 30 else { return }
                    var line = String(repeating: "  ", count: depth) + "\(type(of: view)) \(view.convert(view.bounds, to: nil))"
                    if view.isHidden { line += " hidden" }
                    if view.isOpaque { line += " opaque" }
                    if let effect = view as? NSVisualEffectView {
                        line += " EFFECT material=\(effect.material.rawValue) blending=\(effect.blendingMode.rawValue) state=\(effect.state.rawValue)"
                    }
                    if let scroll = view as? NSScrollView {
                        line += " scroll drawsBg=\(scroll.drawsBackground) bg=\(scroll.backgroundColor)"
                    }
                    if let clip = view as? NSClipView { line += " clip drawsBg=\(clip.drawsBackground)" }
                    if let color = view.layer?.backgroundColor, color.alpha > 0 { line += " layerBg=\(color.components ?? [])" }
                    if let filters = view.layer?.backgroundFilters, !filters.isEmpty { line += " bgFilters=\(filters.count)" }
                    lines.append(line)
                    for subview in view.subviews { walk(subview, depth: depth + 1) }
                }
                if let frameView = w.contentView?.superview { walk(frameView, depth: 0) }
                print(lines.map { "GLASSPROBE \($0)" }.joined(separator: "\n"))
            }
        }
    }
}
