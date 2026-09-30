import AgentCronCore
import AgentCronTestSupport
import Foundation

/// A ``KeepAwakeController`` wired to a ``FakeSleepPreventer`` and a ``ManualClock``
/// whose date the controller reads as "now", so a test moves both of its time sources
/// with one call.
@MainActor
struct KeepAwakeFixture {
    /// "10:00" in the issue's worked examples; any fixed instant would do.
    static let tenOClockSince1970: TimeInterval = 1_700_000_000
    static let tenOClock = Date(timeIntervalSince1970: tenOClockSince1970)
    static let runningJobs = "AgentCron: running jobs"
    static let keptAwakeByYou = "AgentCron: kept awake by you"

    let preventer: FakeSleepPreventer
    let clock: ManualClock
    let controller: KeepAwakeController

    init() {
        self.init(preventer: FakeSleepPreventer())
    }

    init(preventer: FakeSleepPreventer) {
        let manualClock = ManualClock(start: Self.tenOClock)
        self.preventer = preventer
        clock = manualClock
        controller = KeepAwakeController(preventer: preventer, clock: manualClock) {
            manualClock.date
        }
    }

    /// Moves time forward, then lets the controller look at it.
    func pass(_ duration: Duration) {
        clock.advance(by: duration)
        controller.refresh()
    }
}
