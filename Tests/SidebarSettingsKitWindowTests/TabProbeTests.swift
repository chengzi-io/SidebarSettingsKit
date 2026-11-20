import AppKit
import SidebarSettingsFixtures
import SidebarSettingsKit
import SwiftUI
import Testing

@testable import SidebarSettingsKit

@MainActor
private func describe(_ responder: NSResponder?) -> String {
    guard let responder else { return "nil" }
    var text = String(describing: type(of: responder))
    if let editor = responder as? NSTextView, let delegate = editor.delegate {
        text += "(editing \(type(of: delegate)))"
    }
    if let view = responder as? NSView {
        let frame = view.convert(view.bounds, to: nil)
        text += " @(\(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height)))"
    }
    return text
}

extension WindowTestSuite {
    @Suite(.serialized) @MainActor
    struct TabProbeTests {
        @Test func probeTab() async throws {
            try await withWindow(pages: FixturePages.three, initialPage: FixturePages.general) {
                window in
                let table = try require(window.sidebarTable(), "the sidebar's table")
                try await WindowTest.wait(for: "the list to take the focus") {
                    window.window.firstResponder === table
                }
                let mode = UserDefaults.standard.object(forKey: "AppleKeyboardUIMode")
                print("PROBE AppleKeyboardUIMode=\(String(describing: mode)) isFullKeyboardAccessEnabled=\(NSApp.isFullKeyboardAccessEnabled)")
                var chain: [String] = []
                var view: NSView? = table
                for _ in 0..<8 {
                    view = view?.nextValidKeyView
                    chain.append(describe(view))
                }
                print("PROBE nextValidKeyView from table: \(chain)")
                var all: [String] = []
                view = table
                for _ in 0..<8 {
                    view = view?.nextKeyView
                    all.append(describe(view))
                }
                print("PROBE nextKeyView from table: \(all)")
                for step in 1...5 {
                    try press(.tab, in: window.window)
                    await WindowTest.settle(.milliseconds(400))
                    print("PROBE list start, Tab \(step): \(describe(window.window.firstResponder))")
                }

                // The failing test's path: search, ↓ into the list, then Tab.
                let field = try require(window.searchField(), "the search field")
                window.window.makeFirstResponder(field)
                await WindowTest.settle(.milliseconds(300))
                try typeKeys("ance", in: window.window)
                await WindowTest.settle(.milliseconds(300))
                try press(.down, in: window.window)
                await WindowTest.settle(.milliseconds(300))
                print("PROBE after search and down: \(describe(window.window.firstResponder))")
                for step in 1...4 {
                    try press(.tab, in: window.window)
                    await WindowTest.settle(.milliseconds(400))
                    print("PROBE search path, Tab \(step): \(describe(window.window.firstResponder))")
                }
            }
        }
    }
}
