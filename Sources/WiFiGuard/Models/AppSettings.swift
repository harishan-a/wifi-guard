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

    // MARK: - Reconnection Tuning

    var explicitJoinOnFirstAttempt: Bool {
        didSet { UserDefaults.standard.set(explicitJoinOnFirstAttempt, forKey: "explicitJoinOnFirstAttempt") }
    }

    var flushDNSOnRecovery: Bool {
        didSet { UserDefaults.standard.set(flushDNSOnRecovery, forKey: "flushDNSOnRecovery") }
    }

    var rssiWarningThreshold: Int {
        didSet { UserDefaults.standard.set(rssiWarningThreshold, forKey: "rssiWarningThreshold") }
    }

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "autoReconnectEnabled") == nil {
            defaults.set(true, forKey: "autoReconnectEnabled")
        }
        if defaults.object(forKey: "notificationsEnabled") == nil {
            defaults.set(true, forKey: "notificationsEnabled")
        }
        if defaults.object(forKey: "flushDNSOnRecovery") == nil {
            defaults.set(true, forKey: "flushDNSOnRecovery")
        }
        if defaults.object(forKey: "rssiWarningThreshold") == nil {
            defaults.set(-70, forKey: "rssiWarningThreshold")
        }

        self.autoReconnectEnabled = defaults.bool(forKey: "autoReconnectEnabled")
        self.notificationsEnabled = defaults.bool(forKey: "notificationsEnabled")
        self.globalHotkeyEnabled = defaults.bool(forKey: "globalHotkeyEnabled")
        self.explicitJoinOnFirstAttempt = defaults.bool(forKey: "explicitJoinOnFirstAttempt")
        self.flushDNSOnRecovery = defaults.bool(forKey: "flushDNSOnRecovery")
        let storedRSSI = defaults.integer(forKey: "rssiWarningThreshold")
        self.rssiWarningThreshold = storedRSSI != 0 ? storedRSSI : -70

        // SMAppService requires a proper app bundle
        if Bundle.main.bundleIdentifier != nil {
            self.launchAtLogin = (SMAppService.mainApp.status == .enabled)
        } else {
            self.launchAtLogin = false
        }
    }
}
