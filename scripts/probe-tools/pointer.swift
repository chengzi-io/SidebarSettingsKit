// Probe branch only: `pointer X Y` moves the pointer to a screen point (top-left origin);
// `pointer X Y LINES` also scrolls there, down by LINES.
import CoreGraphics
import Foundation

let args = CommandLine.arguments.dropFirst().compactMap { Double($0) }
let point = CGPoint(x: args[0], y: args[1])
CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)!
    .post(tap: .cghidEventTap)
usleep(300_000)
if args.count > 2 {
    for _ in 0..<Int(args[2]) {
        CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: -3, wheel2: 0, wheel3: 0)!
            .post(tap: .cghidEventTap)
        usleep(50_000)
    }
}
