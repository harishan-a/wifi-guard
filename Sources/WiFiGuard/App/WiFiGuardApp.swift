import SwiftUI

@main
struct WiFiGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("WiFi Guard", systemImage: "wifi") {
            Text("WiFi Guard")
                .font(.headline)
            Divider()
            Button("Quit WiFi Guard") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
