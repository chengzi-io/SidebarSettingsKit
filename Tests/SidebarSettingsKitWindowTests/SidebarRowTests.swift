import AppKit
import SidebarSettingsFixtures
import SidebarSettingsKit
import SwiftUI
import Testing

@testable import SidebarSettingsKit

extension WindowTestSuite {
    /// The rows the system's sidebar list draws, with plain and with tiled icons.
    @Suite(.serialized) @MainActor
    struct SidebarRowTests {
        /// A tile fills the sidebar's icon slot, as System Settings' tiles do, so it follows the
        /// user's Sidebar icon size setting and makes no row taller than the system's. A test
        /// process sees one size, whatever the setting says; docs/MANUAL-QA.md checks all three.
        @Test func aTileMakesNoRowTallerThanTheSystemsRow() async throws {
            let plain = try await Self.pageRowHeight(icons: .plain)
            let tiled = try await Self.pageRowHeight(icons: .tiled)

            #expect(tiled == plain)
        }

        /// An icon without a tint sits on a tile of the configuration's `defaultColor`; plain,
        /// it has no tile. General's icon has no tint.
        @Test func anUntintedIconsTileTakesTheDefaultColor() async throws {
            let tiled = try await Self.redPixelsInGeneralsIcon(icons: .tiled(defaultColor: .red))
            let plain = try await Self.redPixelsInGeneralsIcon(icons: .plain)

            #expect(tiled > 0)
            #expect(plain == 0)
        }

        /// A tinted icon turns white on the selected row, as the title and an untinted icon do;
        /// drawn in its tint, a blue icon vanished into the blue selection.
        @Test func aTintedIconTurnsWhiteOnTheSelectedRow() async throws {
            // General's icon has no tint; Appearance's is blue.
            let untinted = try await Self.whitePixelsInSelectedRowsIcon(FixturePages.general)
            let tinted = try await Self.whitePixelsInSelectedRowsIcon(FixturePages.appearance)

            // An untinted icon is white when selected: the pixels read are the icon's.
            #expect(untinted > 0)
            #expect(tinted > 0)
        }

        /// The white pixels in the icon of `page`'s row, drawn selected as in the key window. A
        /// test window is not key, so the row is told to draw its selection emphasized.
        private static func whitePixelsInSelectedRowsIcon(_ page: FixturePage) async throws -> Int {
            var count = 0
            try await withWindow(page: page) { window in
                let table = try require(window.sidebarTable(), "the sidebar's table")
                try await WindowTest.wait(for: "the page's row to be selected") { table.selectedRow >= 0 }
                // The list takes the focus once the window is up, and AppKit then sets each row's
                // emphasis from the window's key state; wait for that before setting it.
                await WindowTest.settle(.milliseconds(300))
                let row = try require(
                    table.rowView(atRow: table.selectedRow, makeIfNecessary: false), "the selected row")
                row.isEmphasized = true
                await WindowTest.settle()

                count = try iconPixels(in: row) {
                    min($0.redComponent, $0.greenComponent, $0.blueComponent) > 0.95
                }
            }
            return count
        }

        /// The red pixels in General's icon, its row not selected.
        private static func redPixelsInGeneralsIcon(
            icons: SidebarSettingsConfiguration.Icons
        ) async throws -> Int {
            var count = 0
            let configuration = SidebarSettingsConfiguration.windowTest.drawing(icons)
            try await withWindow(configuration: configuration, page: FixturePages.appearance) { window in
                let table = try require(window.sidebarTable(), "the sidebar's table")
                try await WindowTest.wait(for: "Appearance's row to be selected") { table.selectedRow >= 0 }
                await WindowTest.settle()
                // A group adds a heading row of no height before General's.
                let pageRows = (0..<table.numberOfRows).filter { table.rect(ofRow: $0).height > 0 }
                let generalRow = try require(pageRows.first, "General's row")
                #expect(table.selectedRow != generalRow, "General's row is selected")
                let row = try require(
                    table.rowView(atRow: generalRow, makeIfNecessary: false), "General's row")
                count = try iconPixels(in: row) {
                    $0.redComponent > 0.7 && $0.greenComponent < 0.4 && $0.blueComponent < 0.4
                }
            }
            return count
        }

        /// The pixels of `row`'s icon that pass `test`. The icon lies between 14 and 34 pt from
        /// the row's edge at every sidebar icon size; the title starts further right.
        private static func iconPixels(in row: NSView, where test: (NSColor) -> Bool) throws -> Int {
            let image = try require(
                row.bitmapImageRepForCachingDisplay(in: row.bounds), "an image of the row")
            row.cacheDisplay(in: row.bounds, to: image)
            let scale = CGFloat(image.pixelsWide) / row.bounds.width
            var count = 0
            for x in Int(14 * scale)..<Int(34 * scale) {
                for y in 0..<image.pixelsHigh {
                    guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                    if test(color) { count += 1 }
                }
            }
            return count
        }

        /// The height of the rows that show a page, which the list draws all alike.
        private static func pageRowHeight(
            icons: SidebarSettingsConfiguration.Icons
        ) async throws -> CGFloat {
            var heights: Set<CGFloat> = []
            try await withWindow(configuration: .windowTest.drawing(icons)) { window in
                let table = try require(window.sidebarTable(), "the sidebar's table")
                // A group adds a heading row of no height.
                heights = Set((0..<table.numberOfRows).map { table.rect(ofRow: $0).height }.filter { $0 > 0 })
            }
            #expect(heights.count == 1, "rows with \(icons) icons differ: \(heights)")
            return try require(heights.first, "a page row")
        }
    }
}
