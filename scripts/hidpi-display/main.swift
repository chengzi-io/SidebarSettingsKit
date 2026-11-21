import AppKit
import CoreGraphics
import Foundation

// Creates a 2x (HiDPI) virtual display, makes it the one new windows open on, prints what the
// system made of it, writes a ready file, and then holds the display until it is killed: the
// display lives as long as the process that created it.
//
// usage: hidpi-display READY_FILE
//   exit 0 never (runs until killed), 2 no display, 3 no 2x mode, 4 no 2x screen

private let pointWidth: UInt32 = 1280
private let pointHeight: UInt32 = 800
private let pixelWidth: UInt32 = 2560
private let pixelHeight: UInt32 = 1600

/// One line at a time, unbuffered: the workflow reads this log while the tool still holds the
/// display, so no line may wait in a buffer.
private func log(_ line: String) {
    FileHandle.standardError.write(Data(("HIDPI " + line + "\n").utf8))
}

private func screenID(_ screen: NSScreen) -> CGDirectDisplayID {
    let key = NSDeviceDescriptionKey("NSScreenNumber")
    return (screen.deviceDescription[key] as? NSNumber)?.uint32Value ?? 0
}

private func onlineDisplayIDs() -> [CGDirectDisplayID] {
    var count: UInt32 = 0
    guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return [] }
    return Array(ids.prefix(Int(count)))
}

private func modes(of id: CGDirectDisplayID) -> [CGDisplayMode] {
    (CGDisplayCopyAllDisplayModes(id, nil) as? [CGDisplayMode]) ?? []
}

private func summary(_ mode: CGDisplayMode) -> String {
    let pixelsWide = mode.pixelWidth
    let pixelsHigh = mode.pixelHeight
    let scale = mode.width > 0 ? Double(pixelsWide) / Double(mode.width) : 0
    return "\(mode.width)x\(mode.height)pt \(pixelsWide)x\(pixelsHigh)px @\(mode.refreshRate)Hz scale=\(scale)"
}

private func logDisplays(_ label: String) {
    log("--- \(label): main display \(CGMainDisplayID()), online \(onlineDisplayIDs())")
    for id in onlineDisplayIDs() {
        let current = CGDisplayCopyDisplayMode(id).map(summary) ?? "none"
        log("display \(id): bounds \(CGDisplayBounds(id)) pixels \(CGDisplayPixelsWide(id))x\(CGDisplayPixelsHigh(id)) main=\(CGDisplayIsMain(id) != 0) active=\(CGDisplayIsActive(id) != 0) current \(current)")
        for mode in modes(of: id) where mode.pixelWidth != mode.width {
            log("display \(id): 2x mode \(summary(mode))")
        }
    }
    for (index, screen) in NSScreen.screens.enumerated() {
        log("screen \(index): id \(screenID(screen)) frame \(screen.frame) scale \(screen.backingScaleFactor) main=\(screen == NSScreen.main)")
    }
}

/// Puts the virtual display in its 2x mode: the one whose pixels are twice its points.
@discardableResult
private func select2xMode(_ id: CGDirectDisplayID) -> Bool {
    let all = modes(of: id)
    let candidates = all.filter { $0.pixelWidth >= 2 * $0.width }
    guard let mode = candidates.first(where: { $0.pixelWidth == Int(pixelWidth) })
        ?? candidates.first
    else {
        log("FAIL: display \(id) has no 2x mode; \(all.count) modes: \(all.map(summary))")
        return false
    }
    let error = CGDisplaySetDisplayMode(id, mode, nil)
    log("set display \(id) to \(summary(mode)): CGError \(error.rawValue)")
    return error == .success
}

/// Mirrors every other display onto the virtual one, so a single desktop is left and no window
/// can open on the 1x display. 0 on success.
private func mirrorEverything(onto virtualID: CGDirectDisplayID) -> Bool {
    var config: CGDisplayConfigRef?
    guard CGBeginDisplayConfiguration(&config) == .success, let config else {
        log("FAIL: cannot begin a display configuration")
        return false
    }
    var mirrored = true
    for id in onlineDisplayIDs() where id != virtualID {
        let error = CGConfigureDisplayMirrorOfDisplay(config, id, virtualID)
        log("mirror display \(id) onto \(virtualID): CGError \(error.rawValue)")
        mirrored = mirrored && error == .success
    }
    if !mirrored {
        CGCancelDisplayConfiguration(config)
        return false
    }
    let completed = CGCompleteDisplayConfiguration(config, .forSession)
    log("complete the display configuration: CGError \(completed.rawValue)")
    return completed == .success
}

/// The fallback: an extended arrangement with the virtual display at the origin, which is where
/// the menu bar and therefore the display new windows open on sits.
private func extendAround(originOf virtualID: CGDirectDisplayID) -> Bool {
    var config: CGDisplayConfigRef?
    guard CGBeginDisplayConfiguration(&config) == .success, let config else {
        log("FAIL: cannot begin a display configuration")
        return false
    }
    let moved = CGConfigureDisplayOrigin(config, virtualID, 0, 0)
    log("move display \(virtualID) to (0,0): CGError \(moved.rawValue)")
    var x = Int32(pixelWidth)
    for id in onlineDisplayIDs() where id != virtualID {
        let error = CGConfigureDisplayOrigin(config, id, x, 0)
        log("move display \(id) to (\(x),0): CGError \(error.rawValue)")
        x += Int32(CGDisplayPixelsWide(id))
    }
    let completed = CGCompleteDisplayConfiguration(config, .forSession)
    log("complete the display configuration: CGError \(completed.rawValue)")
    return completed == .success
}

// MARK: - Main

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: hidpi-display READY_FILE\n".utf8))
    exit(64)
}
let readyFile = CommandLine.arguments[1]

log("start on \(ProcessInfo.processInfo.operatingSystemVersionString)")
logDisplays("before")

let before = Set(onlineDisplayIDs())

let descriptor = CGVirtualDisplayDescriptor()
descriptor.name = "SidebarSettingsKit 2x"
descriptor.serialNum = 1
descriptor.productID = 0x5C2D
descriptor.vendorID = 0x5C2D
descriptor.maxPixelsWide = pixelWidth
descriptor.maxPixelsHigh = pixelHeight
// 2560 px on 300 mm is a desktop-sized density, high enough for macOS to offer 2x.
descriptor.sizeInMillimeters = CGSize(width: 300, height: 188)
descriptor.queue = DispatchQueue.main
descriptor.terminationHandler = { terminated in
    log("the system terminated the virtual display \(terminated?.displayID ?? 0)")
}

// CoreGraphics imports this private initializer as failable.
guard let display = CGVirtualDisplay(descriptor: descriptor) else {
    log("FAIL: CoreGraphics returned no virtual display")
    exit(2)
}
let settings = CGVirtualDisplaySettings()
settings.hiDPI = 1
settings.modes = [
    CGVirtualDisplayMode(width: pointWidth, height: pointHeight, refreshRate: 60),
    CGVirtualDisplayMode(width: pixelWidth, height: pixelHeight, refreshRate: 60),
]
let applied = display.apply(settings)
log("apply \(pointWidth)x\(pointHeight)pt \(pixelWidth)x\(pixelHeight)px hiDPI settings: CGError \(applied), display id \(display.displayID)")
guard applied == 0 else {
    log("FAIL: the system refused the virtual display")
    exit(2)
}

// The display is needed in the online list before its mode can be set.
var virtualID = display.displayID
let deadline = Date().addingTimeInterval(10)
while Date() < deadline {
    let online = onlineDisplayIDs()
    if virtualID == 0, let new = Set(online).subtracting(before).first { virtualID = new }
    if virtualID != 0, online.contains(virtualID) { break }
    usleep(200_000)
}
guard virtualID != 0, onlineDisplayIDs().contains(virtualID) else {
    log("FAIL: the virtual display never came online; online \(onlineDisplayIDs())")
    exit(2)
}
log("virtual display id \(virtualID)")

guard select2xMode(virtualID) else { exit(3) }
if !mirrorEverything(onto: virtualID) {
    log("mirroring failed, extending the desktop instead")
    _ = extendAround(originOf: virtualID)
}
// A configuration can reset the mode; put the 2x mode back if it did.
sleep(1)
if let current = CGDisplayCopyDisplayMode(virtualID),
    current.pixelWidth != Int(pixelWidth)
{
    log("the configuration changed the mode, setting it again")
    select2xMode(virtualID)
}
sleep(1)

logDisplays("with the virtual display")

// AppKit learns about a new screen through the run loop, which is why it runs while we wait.
// Mirrored onto the physical display, macOS may keep only one NSScreen for the mirror set, so the
// 2x desktop counts either way.
var virtualScale: CGFloat = 0
var lowestScale: CGFloat = 0
let screenDeadline = Date().addingTimeInterval(15)
repeat {
    RunLoop.main.run(until: Date().addingTimeInterval(0.2))
    virtualScale = NSScreen.screens.first { screenID($0) == virtualID }?.backingScaleFactor ?? 0
    lowestScale = NSScreen.screens.map(\.backingScaleFactor).min() ?? 0
} while Date() < screenDeadline && max(virtualScale, lowestScale) != 2

guard virtualScale == 2 || lowestScale == 2 else {
    log(
        "FAIL: the desktop is still 1x (virtual display \(virtualID) scale \(virtualScale), lowest screen scale \(lowestScale)); main display \(CGMainDisplayID())"
    )
    exit(4)
}
if CGMainDisplayID() != virtualID {
    log(
        "WARNING: the main display is \(CGMainDisplayID()), not the virtual display \(virtualID): a new window may open on the 1x display"
    )
}
log("ready: virtual display \(virtualID) scale \(virtualScale), lowest screen scale \(lowestScale), main display \(CGMainDisplayID())")

try Data().write(to: URL(fileURLWithPath: readyFile))
log("wrote \(readyFile); holding the display until killed")

// The display stays for as long as this process runs.
RunLoop.main.run()
