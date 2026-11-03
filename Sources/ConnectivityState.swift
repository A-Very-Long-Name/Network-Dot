import Foundation

enum ConnectivityState: Equatable {
    case checking, online, offline
}

struct ConnectivityHealth {
    static let gracePeriod: TimeInterval = 2.0
    var connected = false
    var startedAt: TimeInterval = 0
    var lastSuccess: TimeInterval?

    mutating func reset(connected: Bool, now: TimeInterval) {
        self.connected = connected
        startedAt = now
        lastSuccess = nil
    }

    mutating func succeeded(now: TimeInterval) { lastSuccess = now }

    func state(now: TimeInterval) -> ConnectivityState {
        guard connected else { return .offline }
        if let lastSuccess, now - lastSuccess < Self.gracePeriod { return .online }
        if lastSuccess == nil && now - startedAt < Self.gracePeriod { return .checking }
        return .offline
    }
}
