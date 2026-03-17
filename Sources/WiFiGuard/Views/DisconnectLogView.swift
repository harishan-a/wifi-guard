import SwiftUI
import UniformTypeIdentifiers

struct DisconnectLogView: View {
    let disconnectLog: DisconnectLog

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Disconnect Log")
                    .font(.title2.bold())
                Spacer()
                Text("\(disconnectLog.events.count) events")
                    .foregroundStyle(.secondary)
                Button("Export CSV...") {
                    exportCSV()
                }
                Button("Clear All") {
                    disconnectLog.clearAll()
                }
            }

            if disconnectLog.events.isEmpty {
                ContentUnavailableView(
                    "No Disconnects",
                    systemImage: "wifi",
                    description: Text("Disconnect events will appear here")
                )
            } else {
                Table(disconnectLog.events) {
                    TableColumn("Date") { event in
                        Text(Self.dateFormatter.string(from: event.date))
                    }
                    .width(min: 140, ideal: 160)

                    TableColumn("Reason") { event in
                        Text(event.reason)
                    }
                    .width(min: 100, ideal: 140)

                    TableColumn("Duration") { event in
                        Text(event.duration > 0 ? DurationFormatter.format(event.duration) : "—")
                    }
                    .width(min: 70, ideal: 80)

                    TableColumn("Reconnected") { event in
                        Text(event.reconnected ? "Yes" : "No")
                    }
                    .width(min: 80, ideal: 90)
                }
            }
        }
        .padding()
        .frame(minWidth: 550, minHeight: 350)
    }

    private func exportCSV() {
        let csv = disconnectLog.exportCSV()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "wifi-guard-disconnects.csv"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? csv.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}
