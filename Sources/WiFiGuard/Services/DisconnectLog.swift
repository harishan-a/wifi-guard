import Foundation

@Observable
final class DisconnectLog {
    private let maxEvents = 500
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

    /// Update the most recent event with reconnection details.
    func updateLast(
        reconnected: Bool,
        duration: TimeInterval,
        reason: String? = nil,
        recoveryMethod: String? = nil
    ) {
        guard !events.isEmpty else { return }
        let old = events[0]
        events[0] = DisconnectEvent(
            date: old.date,
            reason: reason ?? old.reason,
            duration: duration,
            reconnected: reconnected,
            recoveryMethod: recoveryMethod ?? old.recoveryMethod
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
        var csv = "Date,Reason,Duration (s),Reconnected,Recovery Method\n"
        let formatter = ISO8601DateFormatter()
        for event in events {
            let dateStr = formatter.string(from: event.date)
            let method = event.recoveryMethod ?? ""
            csv += "\(dateStr),\"\(event.reason)\",\(String(format: "%.1f", event.duration)),\(event.reconnected),\"\(method)\"\n"
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
