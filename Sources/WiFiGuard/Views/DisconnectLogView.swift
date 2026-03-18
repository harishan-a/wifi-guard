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

    private var stats: ConnectionStats {
        ConnectionStats(events: disconnectLog.events)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if !disconnectLog.events.isEmpty {
                statsPanel
                Divider()
            }

            eventTable
        }
        .padding()
        .frame(minWidth: 750, minHeight: 500)
    }

    // MARK: - Header

    private var header: some View {
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
    }

    // MARK: - Stats Panel

    private var statsPanel: some View {
        HStack(alignment: .top, spacing: 24) {
            statsGroup("Recovery Time") {
                statRow("Last", stats.lastReconnectionTime.map { DurationFormatter.format($0) })
                statRow("Average", stats.avgReconnectionTime.map { DurationFormatter.format($0) })
                statRow("Best", stats.minReconnectionTime.map { DurationFormatter.format($0) })
                statRow("Worst", stats.maxReconnectionTime.map { DurationFormatter.format($0) })
            }

            Divider().frame(height: 80)

            statsGroup("Drop Rate") {
                statRow("Last 1 min", "\(stats.disconnectsLastMinute)")
                statRow("Last 5 min", "\(stats.disconnectsLast5Minutes)")
                statRow("Last hour", "\(stats.disconnectsLastHour)")
                statRow("Avg/hr", stats.dropsPerHour.map { String(format: "%.1f", $0) })
            }

            Divider().frame(height: 80)

            statsGroup("Reliability") {
                statRow("Success rate", stats.reconnectionSuccessRate.map { String(format: "%.0f%%", $0) })
                statRow("Avg uptime", stats.avgUptimeBetweenDrops.map { DurationFormatter.format($0) })
                statRow("Streak", stats.currentStreak.map { DurationFormatter.format($0) })
                statRow("Total drops", "\(stats.totalDrops)")
            }

            if !stats.recoveryBreakdown.isEmpty {
                Divider().frame(height: 80)

                statsGroup("Recovery Breakdown") {
                    ForEach(stats.avgRecoveryByMethod.prefix(4), id: \.method) { item in
                        let count = stats.recoveryBreakdown.first { $0.method == item.method }?.count ?? 0
                        statRow(item.method, "\(count)x avg \(DurationFormatter.format(item.avg))")
                    }
                }
            }
        }
        .font(.system(.caption, design: .monospaced))
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private func statsGroup(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            content()
        }
        .frame(minWidth: 130, alignment: .leading)
    }

    private func statRow(_ label: String, _ value: String?) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value ?? "—")
                .fontWeight(.medium)
        }
    }

    // MARK: - Event Table

    @ViewBuilder
    private var eventTable: some View {
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
                .width(min: 130, ideal: 150)

                TableColumn("Failure") { event in
                    Text(event.reason)
                }
                .width(min: 80, ideal: 100)

                TableColumn("Recovery") { event in
                    Text(event.recoveryMethod ?? "—")
                }
                .width(min: 90, ideal: 110)

                TableColumn("Duration") { event in
                    Text(event.duration > 0 ? DurationFormatter.format(event.duration) : "—")
                }
                .width(min: 60, ideal: 70)

                TableColumn("OK") { event in
                    Text(event.reconnected ? "Yes" : "No")
                }
                .width(min: 35, ideal: 40)
            }
        }
    }

    // MARK: - Export

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
