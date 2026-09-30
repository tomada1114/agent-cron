import AgentCronCore
import Foundation
import Testing

/// The promises ``AgentCronCore/SleepPreventing`` makes, checked against any
/// implementation of it (`.claude/rules/testing.md` › One Contract Suite per Port).
///
/// The port answers nothing about whether a hold is in force, so the caller supplies that
/// observation: `activeHolds(reason)` counts the holds named `reason` in force right now.
/// `AgentCronCoreTests` answers it from ``FakeSleepPreventer`` on every `just test` and in
/// CI; `AgentCronPlatformTests` answers it from `pmset -g assertions` for
/// `PowerAssertionSleepPreventer` under `.requiresLocalMachine` (`just test-local`).
/// Every clause is one the port's `///` states; a new clause is stated there first.
package enum SleepPreventingContract {
    /// A token no implementation issues: the fake counts up from 1 and IOKit's assertion
    /// identifiers are 32-bit, so releasing this must do nothing (clause 3).
    package static let foreignToken = SleepPreventionToken(id: .max)

    /// How many holds the contract takes at once: two, so it can see that releasing one
    /// leaves the other in force (clause 2).
    package static let holdsAtOnce = 2

    /// A description of every broken promise, empty when `preventer` keeps them all.
    ///
    /// The holds are named `reason`, which must be unique to this run
    /// (``uniqueReason()``) so another process's holds are never counted as this one's.
    /// Separate from ``check(_:reason:activeHolds:)`` so a test can hand it a preventer
    /// that breaks a promise and see the contract notice — the proof it is not vacuous.
    package static func violations(
        of preventer: some SleepPreventing,
        reason: String,
        activeHolds: (String) -> Int,
    ) -> [String] {
        var broken: [String] = []
        func expectHolds(_ expected: Int, _ moment: String) {
            let actual = activeHolds(reason)
            if actual != expected {
                broken.append("\(moment): \(actual) holds in force, expected \(expected)")
            }
        }

        let first: SleepPreventionToken
        do {
            first = try preventer.hold(reason: reason)
        } catch {
            expectHolds(0, "after the first hold threw \(error)")
            return broken + ["hold(reason:) threw \(error), so the contract could not run"]
        }
        expectHolds(1, "after one hold")

        let second: SleepPreventionToken
        do {
            second = try preventer.hold(reason: reason)
        } catch {
            expectHolds(1, "after the second hold threw \(error)")
            preventer.release(first)
            return broken + ["hold(reason:) threw \(error), so the contract could not run"]
        }

        if first == second {
            broken.append("two outstanding holds share the token \(first)")
        }
        expectHolds(holdsAtOnce, "after two holds")
        preventer.release(first)
        expectHolds(1, "after releasing the first of two holds")
        preventer.release(first)
        expectHolds(1, "after releasing the first hold a second time")
        preventer.release(foreignToken)
        expectHolds(1, "after releasing a token the preventer never issued")
        preventer.release(second)
        expectHolds(0, "after releasing both holds")
        return broken
    }

    /// Records an issue for every promise `preventer` breaks.
    package static func check(
        _ preventer: some SleepPreventing,
        reason: String,
        activeHolds: (String) -> Int,
    ) {
        let broken = violations(of: preventer, reason: reason, activeHolds: activeHolds)
        #expect(
            broken.isEmpty,
            "\(type(of: preventer)) breaks the SleepPreventing contract: \(broken)",
        )
    }

    /// A hold name no other run, and no running copy of the app, uses.
    package static func uniqueReason() -> String {
        "AgentCron contract \(UUID().uuidString)"
    }
}
