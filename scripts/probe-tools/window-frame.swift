// Probe branch only: `window-frame ID` prints "x y w h" of a window, top-left origin.
import CoreGraphics
import Foundation

let id = CGWindowID(CommandLine.arguments[1])!
let info = CGWindowListCopyWindowInfo([.optionIncludingWindow], id) as! [[String: Any]]
let bounds = info.first![kCGWindowBounds as String] as! [String: CGFloat]
print(Int(bounds["X"]!), Int(bounds["Y"]!), Int(bounds["Width"]!), Int(bounds["Height"]!))
