import SwiftUI

@main
struct WiFiGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var monitor = WiFiMonitor()
    @State private var locationManager = LocationManager()

    var body: some Scene {
        MenuBarExtra(
            "WiFi Guard",
            systemImage: MenuBarIcon.systemImageName(
                isConnected: monitor.state.isConnected,
                isWiFiOn: monitor.state.isWiFiPoweredOn,
                rssi: monitor.state.rssi
            )
        ) {
            MenuBarContent(state: monitor.state)
                .task {
                    locationManager.requestAuthorization()
                    monitor.start()
                }
        }
    }
}
