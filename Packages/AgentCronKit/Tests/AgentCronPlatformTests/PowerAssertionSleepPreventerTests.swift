import AgentCronCore
import AgentCronPlatform
import AgentCronTestSupport
import Foundation
import Testing

/// `PowerAssertionSleepPreventer` against the real power-management daemon, read back
/// through `pmset -g assertions` — the one thing a Core test with `FakeSleepPreventer`
/// cannot show: that a hold is an idle-sleep assertion the OS actually lists, under the
/// name Core gave it, and that a release removes it (REQ-006).
///
/// Beside it sits the adapter half of the port's contract suite: `SleepPreventingContract`,
/// the same function `AgentCronCoreTests` runs against the fake on every `just test`.
///
/// It needs no TCC grant and no admin rights (ADR-0006) — only a real Mac, which is what a
/// CI runner's session is not. Counts are compared before and after rather than taken as
/// absolute, so a running copy of the app holding the same name cannot fail the test.
@Suite("PowerAssertionSleepPreventer against the real IOKit", .requiresLocalMachine)
struct PowerAssertionSleepPreventerTests {
    /// The `pmset -g assertions` lines that list a `PreventUserIdleSystemSleep` assertion
    /// named `reason` — one per assertion, owned by any process.
    static func idleSleepAssertions(named reason: String) throws -> [String] {
        let pmset = Process()
        pmset.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        pmset.arguments = ["-g", "assertions"]
        let output = Pipe()
        pmset.standardOutput = output
        try pmset.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        pmset.waitUntilExit()
        try #require(
            pmset.terminationStatus == 0,
            "pmset -g assertions exited \(pmset.terminationStatus)",
        )
        let text = try #require(
            String(bytes: data, encoding: .utf8),
            "pmset printed something other than UTF-8",
        )
        return text
            .split(separator: "\n")
            .map(String.init)
            .filter { line in
                line.contains("PreventUserIdleSystemSleep") && line.contains("named: \"\(reason)\"")
            }
    }

    /// ``idleSleepAssertions(named:)``'s count, recording an issue and answering -1 when
    /// `pmset` could not be read, so the contract reports a mismatch instead of passing.
    static func countIdleSleepAssertions(named reason: String) -> Int {
        do {
            return try idleSleepAssertions(named: reason).count
        } catch {
            Issue.record("could not read pmset -g assertions: \(error)")
            return -1
        }
    }

    @MainActor
    @Test
    func `a hold is an idle-sleep assertion pmset lists by name, until it is released`() throws {
        let reason = KeepAwakeController.runningJobsReason
        let before = try Self.idleSleepAssertions(named: reason).count
        let preventer = PowerAssertionSleepPreventer()

        let token = try preventer.hold(reason: reason)
        let whileHeld = try Self.idleSleepAssertions(named: reason)
        #expect(whileHeld.count == before + 1, "pmset lists \(whileHeld)")
        #expect(whileHeld
            .contains { $0.contains("pid \(ProcessInfo.processInfo.processIdentifier)(") })

        preventer.release(token)
        #expect(try Self.idleSleepAssertions(named: reason).count == before)
    }

    @MainActor
    @Test
    func `the manual hold's name reaches pmset too`() throws {
        let reason = KeepAwakeController.manualReason
        let before = try Self.idleSleepAssertions(named: reason).count
        let preventer = PowerAssertionSleepPreventer()

        let token = try preventer.hold(reason: reason)
        #expect(try Self.idleSleepAssertions(named: reason).count == before + 1)
        preventer.release(token)
        #expect(try Self.idleSleepAssertions(named: reason).count == before)
    }

    @Test
    func `a token another preventer issued is ignored`() throws {
        let reason = SleepPreventingContract.uniqueReason()
        let owner = PowerAssertionSleepPreventer()
        let stranger = PowerAssertionSleepPreventer()

        let token = try owner.hold(reason: reason)
        stranger.release(token)
        #expect(try Self.idleSleepAssertions(named: reason).count == 1)
        owner.release(token)
        #expect(try Self.idleSleepAssertions(named: reason).isEmpty)
    }

    @Test
    func `holds still outstanding are released when the preventer goes away`() throws {
        let reason = SleepPreventingContract.uniqueReason()
        do {
            let preventer = PowerAssertionSleepPreventer()
            try withExtendedLifetime(preventer) {
                _ = try preventer.hold(reason: reason)
                #expect(try Self.idleSleepAssertions(named: reason).count == 1)
            }
        }
        #expect(try Self.idleSleepAssertions(named: reason).isEmpty)
    }

    @Test
    func `keeps the SleepPreventing contract the fake is held to`() {
        SleepPreventingContract.check(
            PowerAssertionSleepPreventer(),
            reason: SleepPreventingContract.uniqueReason(),
            activeHolds: Self.countIdleSleepAssertions(named:),
        )
    }
}
