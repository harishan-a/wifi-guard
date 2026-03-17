import AppKit
import Carbon

@MainActor
final class GlobalHotkeyManager {
    private var monitor: Any?
    var onHotkeyPressed: (() -> Void)?

    /// Start listening for Ctrl+Opt+Cmd+W globally.
    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Check for Ctrl+Opt+Cmd+W
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let requiredFlags: NSEvent.ModifierFlags = [.control, .option, .command]

            if flags == requiredFlags && event.keyCode == 13 { // 13 = 'W' key
                Task { @MainActor in
                    self?.onHotkeyPressed?()
                }
            }
        }
    }

    /// Stop listening for the global hotkey.
    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
