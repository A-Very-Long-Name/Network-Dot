import Foundation

/// Main-thread state machine. Each target is launched at most once per round.
struct ProbeRound {
    enum Result: Equatable {
        case ignored, waiting, startFallback, allFailed, winner(Int)
    }
    let id = UUID()
    let count: Int
    let primary: Int
    private(set) var launched: Set<Int> = []
    private(set) var pending: Set<Int> = []
    private(set) var finished = false

    mutating func start() -> [Int] {
        guard !finished, launched.isEmpty, (0..<count).contains(primary) else { return [] }
        launched.insert(primary); pending.insert(primary)
        return [primary]
    }
    mutating func fallback() -> [Int] {
        guard !finished else { return [] }
        let remaining = (0..<count).filter { !launched.contains($0) }
        launched.formUnion(remaining); pending.formUnion(remaining)
        return remaining
    }
    mutating func complete(index: Int, success: Bool) -> Result {
        guard !finished, pending.remove(index) != nil else { return .ignored }
        if success { finished = true; return .winner(index) }
        if launched.count < count { return .startFallback }
        if pending.isEmpty { finished = true; return .allFailed }
        return .waiting
    }
}

struct ProbeSelection {
    static let appleRetryInterval: TimeInterval = 60
    private(set) var preferred = 0
    private(set) var lastAppleAttempt = -TimeInterval.infinity

    mutating func reset() { preferred = 0; lastAppleAttempt = -.infinity }
    func primary(now: TimeInterval, count: Int) -> Int {
        guard count > 0 else { return 0 }
        if preferred == 0 || now - lastAppleAttempt >= Self.appleRetryInterval { return 0 }
        return min(preferred, count - 1)
    }
    mutating func launched(index: Int, now: TimeInterval) {
        if index == 0 { lastAppleAttempt = now }
    }
    mutating func succeeded(index: Int) { preferred = index }
}
