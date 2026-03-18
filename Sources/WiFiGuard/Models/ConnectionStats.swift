import Foundation

/// Pure computed stats derived from disconnect events. No persistence needed.
struct ConnectionStats {
    let events: [DisconnectEvent]

    // MARK: - Resolved events (disconnects that were reconnected)

    private var resolved: [DisconnectEvent] {
        events.filter { $0.reconnected && $0.duration > 0 }
    }

    // MARK: - Reconnection timing

    var lastReconnectionTime: TimeInterval? {
        resolved.first?.duration
    }

    var avgReconnectionTime: TimeInterval? {
        guard !resolved.isEmpty else { return nil }
        return resolved.map(\.duration).reduce(0, +) / Double(resolved.count)
    }

    var minReconnectionTime: TimeInterval? {
        resolved.map(\.duration).min()
    }

    var maxReconnectionTime: TimeInterval? {
        resolved.map(\.duration).max()
    }

    // MARK: - Disconnect rates (events in time window)

    func disconnectsIn(last seconds: TimeInterval) -> Int {
        let cutoff = Date().addingTimeInterval(-seconds)
        return events.filter { $0.date >= cutoff }.count
    }

    var disconnectsLastMinute: Int { disconnectsIn(last: 60) }
    var disconnectsLast5Minutes: Int { disconnectsIn(last: 300) }
    var disconnectsLastHour: Int { disconnectsIn(last: 3600) }

    var dropsPerHour: Double? {
        guard let oldest = events.last, let newest = events.first else { return nil }
        let span = newest.date.timeIntervalSince(oldest.date)
        guard span > 60 else { return nil } // need at least 1min of data
        return Double(events.count) / (span / 3600.0)
    }

    // MARK: - Uptime between disconnects

    /// Average time the connection stayed up between consecutive disconnects.
    var avgUptimeBetweenDrops: TimeInterval? {
        guard events.count >= 2 else { return nil }
        var gaps: [TimeInterval] = []
        // Events are newest-first. Walk pairs: events[i] is newer than events[i+1].
        // The gap is: events[i].date - (events[i+1].date + events[i+1].duration)
        // i.e., time from reconnection of the older event to the disconnect of the newer event.
        for i in 0..<(events.count - 1) {
            let newer = events[i]
            let older = events[i + 1]
            let olderEnd = older.date.addingTimeInterval(older.duration)
            let gap = newer.date.timeIntervalSince(olderEnd)
            if gap > 0 {
                gaps.append(gap)
            }
        }
        guard !gaps.isEmpty else { return nil }
        return gaps.reduce(0, +) / Double(gaps.count)
    }

    // MARK: - Reliability

    var reconnectionSuccessRate: Double? {
        guard !events.isEmpty else { return nil }
        let succeeded = events.filter(\.reconnected).count
        return Double(succeeded) / Double(events.count) * 100.0
    }

    var totalDrops: Int { events.count }

    /// Time since the most recent disconnect ended (current stability streak).
    var currentStreak: TimeInterval? {
        guard let latest = events.first else { return nil }
        if latest.reconnected {
            let reconnectedAt = latest.date.addingTimeInterval(latest.duration)
            return Date().timeIntervalSince(reconnectedAt)
        }
        return nil // currently disconnected or unresolved
    }

    // MARK: - Failure & recovery breakdown

    /// Count of each failure type (e.g., "No IP (DHCP)": 5, "No SSID": 2).
    var failureBreakdown: [(type: String, count: Int)] {
        var counts: [String: Int] = [:]
        for event in events {
            counts[event.reason, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }.map { (type: $0.key, count: $0.value) }
    }

    /// Count of each recovery method (e.g., "Auto-recovery": 10, "DHCP Renewal": 3).
    var recoveryBreakdown: [(method: String, count: Int)] {
        var counts: [String: Int] = [:]
        for event in resolved {
            let method = event.recoveryMethod ?? "Unknown"
            counts[method, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }.map { (method: $0.key, count: $0.value) }
    }

    /// Average recovery time per method.
    var avgRecoveryByMethod: [(method: String, avg: TimeInterval)] {
        var sums: [String: (total: TimeInterval, count: Int)] = [:]
        for event in resolved {
            let method = event.recoveryMethod ?? "Unknown"
            let existing = sums[method, default: (total: 0, count: 0)]
            sums[method] = (total: existing.total + event.duration, count: existing.count + 1)
        }
        return sums.sorted { $0.value.total / Double($0.value.count) < $1.value.total / Double($1.value.count) }
            .map { (method: $0.key, avg: $0.value.total / Double($0.value.count)) }
    }

    // MARK: - Formatted summaries

    var menuBarSummary: String {
        let rate = disconnectsLastHour
        let avg = avgReconnectionTime.map { DurationFormatter.format($0) } ?? "—"
        return "\(rate) drops/hr, avg \(avg) recovery"
    }
}
