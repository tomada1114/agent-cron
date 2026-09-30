import AgentCronCore
import AgentCronTestSupport
import os
import Testing

// MARK: - Preventers that each break one promise

/// The OS status every broken preventer below throws, when it throws.
private let refusal = SleepPreventionError.systemFailure(code: -1)

private struct NeverReleasing: SleepPreventing {
    let inner = FakeSleepPreventer()

    func hold(reason: String) throws(SleepPreventionError) -> SleepPreventionToken {
        try inner.hold(reason: reason)
    }

    func release(_: SleepPreventionToken) {
        // Breaks clause 1: a released hold stays in force.
    }
}

private struct ReleasingEverything: SleepPreventing {
    let inner = FakeSleepPreventer()

    func hold(reason: String) throws(SleepPreventionError) -> SleepPreventionToken {
        try inner.hold(reason: reason)
    }

    func release(_: SleepPreventionToken) {
        // Breaks clause 2: releasing one hold ends them all. The fake numbers its
        // tokens from 1, and the contract never takes more than `holdsAtOnce`.
        for id in 1 ... SleepPreventingContract.holdsAtOnce {
            inner.release(SleepPreventionToken(id: UInt64(id)))
        }
    }
}

private final class OneTokenForAll: SleepPreventing {
    static let token = SleepPreventionToken(id: 1)

    private let holds = OSAllocatedUnfairLock(initialState: 0)

    func activeHolds(named _: String) -> Int {
        holds.withLock { $0 }
    }

    func hold(reason _: String) -> SleepPreventionToken {
        // Breaks clause 2: every hold answers the same token.
        holds.withLock { $0 += 1 }
        return Self.token
    }

    func release(_ token: SleepPreventionToken) {
        guard token == Self.token else {
            return
        }
        holds.withLock { $0 = max($0 - 1, 0) }
    }
}

private struct FailingSecondHold: SleepPreventing {
    let inner = FakeSleepPreventer()

    func hold(reason: String) throws(SleepPreventionError) -> SleepPreventionToken {
        // Keeps every promise; the OS merely refuses every hold after the first.
        guard inner.holdRequests.isEmpty else {
            throw refusal
        }
        return try inner.hold(reason: reason)
    }

    func release(_ token: SleepPreventionToken) {
        inner.release(token)
    }
}

private struct HoldingDespiteThrowing: SleepPreventing {
    let inner = FakeSleepPreventer()

    func hold(reason: String) throws(SleepPreventionError) -> SleepPreventionToken {
        // Breaks clause 4: the hold is taken, then reported as refused.
        _ = try inner.hold(reason: reason)
        throw refusal
    }

    func release(_ token: SleepPreventionToken) {
        inner.release(token)
    }
}

/// The fake half of the `SleepPreventing` contract suite: the same
/// ``SleepPreventingContract`` that `AgentCronPlatformTests` runs against the real
/// adapter under `just test-local` runs here against ``FakeSleepPreventer``, on every
/// `just test` and in CI, so the fake cannot drift from the port's promises.
@Suite("SleepPreventing contract, against the fake")
struct SleepPreventingContractTests {
    @Test
    func `the fake keeps the contract`() {
        let preventer = FakeSleepPreventer()
        SleepPreventingContract.check(
            preventer,
            reason: SleepPreventingContract.uniqueReason(),
            activeHolds: preventer.activeHolds(named:),
        )
        #expect(preventer.activeCount == 0)
    }

    @Test
    func `each run is named uniquely, so another process's holds are never counted`() {
        let first = SleepPreventingContract.uniqueReason()
        let second = SleepPreventingContract.uniqueReason()
        #expect(first != second)
        #expect(first.hasPrefix("AgentCron contract "))
    }

    // The contract's own oracle: a preventer that breaks a promise must be reported, or
    // `check` would pass anything, the real adapter included.

    @Test
    func `a release that ends nothing is reported`() {
        let preventer = NeverReleasing()
        let violations = SleepPreventingContract.violations(
            of: preventer,
            reason: "r",
            activeHolds: preventer.inner.activeHolds(named:),
        )
        #expect(violations == [
            "after releasing the first of two holds: 2 holds in force, expected 1",
            "after releasing the first hold a second time: 2 holds in force, expected 1",
            "after releasing a token the preventer never issued: 2 holds in force, expected 1",
            "after releasing both holds: 2 holds in force, expected 0",
        ])
    }

    @Test
    func `a release that ends every hold is reported`() {
        let preventer = ReleasingEverything()
        let violations = SleepPreventingContract.violations(
            of: preventer,
            reason: "r",
            activeHolds: preventer.inner.activeHolds(named:),
        )
        #expect(violations == [
            "after releasing the first of two holds: 0 holds in force, expected 1",
            "after releasing the first hold a second time: 0 holds in force, expected 1",
            "after releasing a token the preventer never issued: 0 holds in force, expected 1",
        ])
    }

    @Test
    func `two holds sharing a token are reported`() {
        let preventer = OneTokenForAll()
        let violations = SleepPreventingContract.violations(
            of: preventer,
            reason: "r",
            activeHolds: preventer.activeHolds(named:),
        )
        #expect(violations.first == "two outstanding holds share the token \(OneTokenForAll.token)")
    }

    @Test
    func `a first hold that throws is reported`() {
        let preventer = FakeSleepPreventer(failingWith: [refusal])
        let violations = SleepPreventingContract.violations(
            of: preventer,
            reason: "r",
            activeHolds: preventer.activeHolds(named:),
        )
        #expect(violations == [
            "hold(reason:) threw systemFailure(code: -1), so the contract could not run",
        ])
    }

    @Test
    func `a second hold that throws is reported, and the first is released`() {
        let preventer = FailingSecondHold()
        let violations = SleepPreventingContract.violations(
            of: preventer,
            reason: "r",
            activeHolds: preventer.inner.activeHolds(named:),
        )
        #expect(violations == [
            "hold(reason:) threw systemFailure(code: -1), so the contract could not run",
        ])
        #expect(preventer.inner.activeCount == 0)
    }

    @Test
    func `a hold that throws yet holds is reported`() {
        let preventer = HoldingDespiteThrowing()
        let violations = SleepPreventingContract.violations(
            of: preventer,
            reason: "r",
            activeHolds: preventer.inner.activeHolds(named:),
        )
        #expect(violations == [
            "after the first hold threw systemFailure(code: -1): 1 holds in force, expected 0",
            "hold(reason:) threw systemFailure(code: -1), so the contract could not run",
        ])
    }
}
