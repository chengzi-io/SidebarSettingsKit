import AppKit
import SwiftUI
import Testing

@testable import SidebarSettingsKit

/// A symbol on a tile keeps a margin around it, as System Settings' tiles do.
@MainActor
@Suite("Tiles")
struct TileTests {
    /// The sidebar list on macOS 27 asks its rows for a large image scale, which drew the symbol
    /// to the tile's edges. Drawn here outside a list, with the scale that list asks for.
    @Test func aSymbolKeepsAMarginOnItsTileAtALargeImageScale() throws {
        // The widest of the fixtures' symbols, white on a blue tile.
        let icon = SettingsIconView(icon: .system("wrench.and.screwdriver", tint: .blue), icons: .tiled)
            .environment(\.imageScale, .large)
        let renderer = ImageRenderer(content: icon)
        renderer.scale = 2
        let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage, "an image of the tile"))

        var columns: [Int] = []
        var rows: [Int] = []
        for x in 0..<bitmap.pixelsWide {
            for y in 0..<bitmap.pixelsHigh {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                    min(color.redComponent, color.greenComponent, color.blueComponent) > 0.8
                else { continue }
                columns.append(x)
                rows.append(y)
            }
        }
        let width = try #require(columns.max(), "white pixels") - columns.min()! + 1
        let height = try #require(rows.max(), "white pixels") - rows.min()! + 1
        let tile = bitmap.pixelsWide

        // The false-pass rule: the image is the tile, not an empty or clipped one.
        #expect(bitmap.pixelsHigh == tile)
        #expect(max(width, height) <= tile * 3 / 4, "symbol \(width) × \(height) px on a \(tile) px tile")
    }
}
