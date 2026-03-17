import Foundation
import ServiceManagement

@MainActor
@Observable
final class AppSettings {
    var autoReconnectEnabled: Bool {
        didSet { UserDefaults.standard.set(autoReconnectEnabled, forKey: "autoReconnectEnabled") }
    }

    var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }

    var globalHotkeyEnabled: Bool {
        didSet { UserDefaults.standard.set(globalHotkeyEnabled, forKey: "globalHotkeyEnabled") }
    }

    var launchAtLogin: Bool {
        didSet {
            guard Bundle.main.bundleIdentifier != nil else { return }
            if launchAtLogin {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "autoReconnectEnabled") == nil {
            defaults.set(true, forKey: "autoReconnectEnabled")
        }
        if defaults.object(forKey: "notificationsEnabled") == nil {
            defaults.set(true, forKey: "notificationsEnabled")
        }

        self.autoReconnectEnabled = defaults.bool(forKey: "autoReconnectEnabled")
        self.notificationsEnabled = defaults.bool(forKey: "notificationsEnabled")
        self.globalHotkeyEnabled = defaults.bool(forKey: "globalHotkeyEnabled")

        // SMAppService requires a proper app bundle
        if Bundle.main.bundleIdentifier != nil {
            self.launchAtLogin = (SMAppService.mainApp.status == .enabled)
        } else {
            self.launchAtLogin = false
        }
    }
}
