// Probe branch only: a red window over the whole screen, behind whatever opens next, so a
// translucent window shows red through it.
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let frame = NSScreen.main!.frame
let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
window.backgroundColor = .systemRed
window.level = .normal
window.orderFrontRegardless()
app.run()
