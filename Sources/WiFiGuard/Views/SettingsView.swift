import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                Toggle("Auto-reconnect on disconnect", isOn: $settings.autoReconnectEnabled)
                Toggle("Show notifications", isOn: $settings.notificationsEnabled)
                Toggle("Global hotkey (Ctrl+Opt+Cmd+W)", isOn: $settings.globalHotkeyEnabled)
            }

            Section("About") {
                LabeledContent("Version", value: "1.0")
                LabeledContent("Build", value: "Swift Package Manager")
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 400, height: 250)
    }
}
