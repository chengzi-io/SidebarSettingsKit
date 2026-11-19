// find-window OWNER: prints "id x y w h" of OWNER's largest on-screen window (top-left origin).
import CoreGraphics
import Foundation
let owner = CommandLine.arguments[1]
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as! [[String: Any]]
let best = list.filter { ($0[kCGWindowOwnerName as String] as? String) == owner && ($0[kCGWindowLayer as String] as? Int) == 0 }
    .compactMap { info -> (Int, CGRect)? in
        guard let id = info[kCGWindowNumber as String] as? Int,
              let bounds = info[kCGWindowBounds as String] as? NSDictionary,
              let rect = CGRect(dictionaryRepresentation: bounds) else { return nil }
        return (id, rect)
    }
    .max { $0.1.width * $0.1.height < $1.1.width * $1.1.height }
guard let (id, rect) = best else { FileHandle.standardError.write("no window for \(owner)\n".data(using: .utf8)!); exit(1) }
print(id, Int(rect.minX), Int(rect.minY), Int(rect.width), Int(rect.height))
