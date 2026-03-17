import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide Dock icon — LSUIElement in Info.plist handles this,
        // but set activation policy as a belt-and-suspenders approach
        NSApp.setActivationPolicy(.accessory)
    }
}
