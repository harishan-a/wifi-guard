import Foundation

@MainActor
@Observable
final class DisconnectLog {
    private let maxEvents = 100
    private let defaultsKey = "disconnectEvents"

    private(set) var events: [DisconnectEvent] = []

    init() {
        load()
    }

    /// Add a new disconnect event and persist.
    func add(_ event: DisconnectEvent) {
        events.insert(event, at: 0)
        if events.count > maxEvents {
            events = Array(events.prefix(maxEvents))
        }
        save()
    }

    /// Update the most recent event (e.g., to set reconnected=true and duration).
    func updateLast(reconnected: Bool, duration: TimeInterval) {
        guard !events.isEmpty else { return }
        let old = events[0]
        events[0] = DisconnectEvent(
            date: old.date,
            reason: old.reason,
            duration: duration,
            reconnected: reconnected
        )
        save()
    }

    /// The 5 most recent events for the menu submenu.
    var recentEvents: [DisconnectEvent] {
        Array(events.prefix(5))
    }

    /// Clear all events.
    func clearAll() {
        events.removeAll()
        save()
    }

    /// Export to CSV string.
    func exportCSV() -> String {
        var csv = "Date,Reason,Duration (s),Reconnected\n"
        let formatter = ISO8601DateFormatter()
        for event in events {
            let dateStr = formatter.string(from: event.date)
            csv += "\(dateStr),\"\(event.reason)\",\(String(format: "%.0f", event.duration)),\(event.reconnected)\n"
        }
        return csv
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([DisconnectEvent].self, from: data) else {
            return
        }
        events = decoded
    }
}
