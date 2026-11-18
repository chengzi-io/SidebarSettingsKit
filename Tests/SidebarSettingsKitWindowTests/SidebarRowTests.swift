import AppKit
import SidebarSettingsFixtures
import SidebarSettingsKit
import SwiftUI
import Testing

@testable import SidebarSettingsKit

extension WindowTestSuite {
    /// The rows a style draws in the system's sidebar list.
    @Suite(.serialized) @MainActor
    struct SidebarRowTests {
        /// A row is its content plus the list's padding, so the tile sets a branded row's height.
        @Test func aLargerTileMakesATallerRow() async throws {
            var heights: [CGFloat: [CGFloat]] = [:]
            for tile in [24.0, 32.0] {
                var style = SidebarSettingsStyle.branded
                style.iconTile?.size = tile
                try await withWindow(style: style) { window in
                    let table = try require(window.sidebarTable(), "the sidebar's table")
                    // An untitled group adds a heading row of no height.
                    heights[tile] = (0..<table.numberOfRows)
                        .map { table.rect(ofRow: $0).height }
                        .filter { $0 > 0 }
                }
            }
            let small = try require(heights[24], "the rows with 24 pt tiles")
            let large = try require(heights[32], "the rows with 32 pt tiles")
            #expect(small.count == FixturePages.three.count)
            #expect(Set(small).count == 1, "rows of one style differ: \(small)")
            #expect(Set(large).count == 1, "rows of one style differ: \(large)")
            #expect(large.first == small.first.map { $0 + 8 }, "\(small) then \(large)")
        }
    }
}
