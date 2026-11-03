import Foundation

@main
struct HealthTests {
    static func main() {
        var health = ConnectivityHealth()
        health.reset(connected: false, now: 100)
        assert(health.state(now: 100) == .offline, "Link loss must be immediate")
        health.reset(connected: true, now: 101)
        assert(health.state(now: 101) == .checking)
        assert(health.state(now: 102.99) == .checking)
        assert(health.state(now: 103) == .offline, "First probe grace must end at 2 seconds")
        health.succeeded(now: 103.1)
        assert(health.state(now: 103.1) == .online, "Recovery must be immediate")
        assert(health.state(now: 105.09) == .online)
        assert(health.state(now: 105.1) == .offline, "Stale success must expire")
        health.succeeded(now: 105.2)
        assert(health.state(now: 105.2) == .online, "One successful target is sufficient")
        health.reset(connected: true, now: 106)
        assert(health.state(now: 106) == .checking, "Network change must clear previous success")
        health.reset(connected: false, now: 106.1)
        assert(health.state(now: 106.1) == .offline)
        print("Connectivity health tests passed (2-second timeout, immediate link loss/recovery, network changes).")
    }
}
