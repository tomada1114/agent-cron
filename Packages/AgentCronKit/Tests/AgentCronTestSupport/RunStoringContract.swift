import AgentCronCore
import Foundation
import Testing

/// The four runs the contract saves, and the letters a violation names them by.
private struct Sample {
    // 2026-10-31T23:00:00.000Z, 2026-10-31T23:59:59.500Z, 2026-11-01T00:00:00.250Z,
    // and 2026-11-01T01:00:00.000Z: two in October and two in November, UTC.
    private static let firstStart: TimeInterval = 1_793_487_600
    private static let secondStart: TimeInterval = 1_793_491_199.5
    private static let thirdStart: TimeInterval = 1_793_491_200.25
    private static let fourthStart: TimeInterval = 1_793_494_800
    /// 2026-11-01T00:02:03.750Z
    private static let secondEnd: TimeInterval = 1_793_491_323.75
    /// A signal's exit status, negative as the runner records one.
    private static let terminatedExitCode: Int32 = -15

    private static let job = Job(
        name: "Contract job",
        directory: URL(filePath: "/tmp/contract", directoryHint: .isDirectory),
        prompt: "Say hello.",
        schedule: Schedule(weekdays: [.monday], times: []),
        createdAt: Date(timeIntervalSince1970: firstStart),
    )

    let first = run(at: firstStart)
    private(set) var second = run(at: secondStart)
    let third = run(at: thirdStart)
    let fourth = run(at: fourthStart)

    private static func run(at seconds: TimeInterval) -> Run {
        Run(job: job, trigger: .scheduled, startedAt: Date(timeIntervalSince1970: seconds))
    }

    /// Fills in every field a finished run has, with values each file-format rule touches:
    /// a long decimal cost, a negative exit status, and text that needs escaping.
    mutating func finishSecond() {
        second.endedAt = Date(timeIntervalSince1970: Self.secondEnd)
        second.outcome = .timedOut
        second.failureReason = "timed out after 30 minutes"
        second.exitCode = Self.terminatedExitCode
        second.costUSD = Decimal(string: "12.3456789")
        second.sessionID = "contract-session"
        second.resultText = "## Done\n\"quoted\" — 日本語 / slash"
    }

    /// Each run's letter, starred when it is not the latest copy of that run, `?` for a
    /// run the contract never saved.
    func letters(_ runs: [Run]) -> String {
        guard !runs.isEmpty else {
            return "nothing"
        }
        let named = [("a", first), ("b", second), ("c", third), ("d", fourth)]
        return runs.map { run in
            guard let (letter, latest) = named.first(where: { $0.1.id == run.id }) else {
                return "?"
            }
            return run == latest ? letter : letter + "*"
        }
        .joined(separator: ", ")
    }
}

/// One pass of the contract over one store, collecting what it breaks.
private struct Checker<Store: RunStoring> {
    let store: Store
    var sample = Sample()
    private(set) var broken: [String] = []

    mutating func expectRuns(in interval: DateInterval, _ moment: String, _ expected: [Run]) {
        do {
            let answered = try store.runs(in: interval)
            if answered != expected {
                broken.append(
                    "\(moment) answered \(sample.letters(answered)), expected \(sample.letters(expected))",
                )
            }
        } catch {
            broken.append("\(moment) threw \(error)")
        }
    }

    /// Saves `runs` in order; `false`, with the failure recorded, when a save throws.
    mutating func save(_ runs: [Run], _ moment: String) -> Bool {
        do {
            for run in runs {
                try store.save(run)
            }
            return true
        } catch {
            broken.append("\(moment): save(_:) threw \(error)")
            return false
        }
    }

    mutating func expectDeleted(olderThan cutoff: Date, _ expected: Int, _ moment: String) {
        do {
            let removed = try store.deleteRuns(olderThan: cutoff)
            if removed != expected {
                broken.append("\(moment) answered \(removed), expected \(expected)")
            }
        } catch {
            broken.append("\(moment) threw \(error)")
        }
    }
}

/// The promises ``AgentCronCore/RunStoring`` makes, checked against any implementation of
/// it (`.claude/rules/testing.md` › One Contract Suite per Port).
///
/// `AgentCronCoreTests` runs it against ``FakeRunStore`` and against `FileRunStore` in a
/// temporary folder, on every `just test` and in CI. Every clause is one the port's `///`
/// states; a new clause is stated there first.
///
/// Four runs, `a` to `d`, start around a month boundary — the last hour of October 2026
/// and the first of November, UTC — so a store that files runs by month is read across
/// two. A violation names runs by letter; `*` marks a stale copy, `?` a run the contract
/// never saved.
package enum RunStoringContract {
    /// A description of every broken promise, empty when `store` keeps them all.
    ///
    /// `store` must be fresh — nothing ever saved to it — and is saved to and deleted
    /// from. Separate from ``check(_:)`` so a test can hand it a store that breaks a
    /// promise and see the contract notice — the proof it is not vacuous.
    package static func violations(of store: some RunStoring) -> [String] {
        var checker = Checker(store: store)
        let everything = DateInterval(start: .distantPast, end: .distantFuture)

        checker.expectRuns(in: everything, "before any save: runs(in:)", [])
        // Clause 1: saved out of order, read back oldest first; b's start is included and
        // d's, the end, excluded, across the month boundary between b and c.
        let sample = checker.sample
        guard checker.save(
            [sample.third, sample.first, sample.fourth, sample.second],
            "saving four runs",
        )
        else {
            return checker.broken
        }
        checker.expectRuns(
            in: DateInterval(start: sample.second.startedAt, end: sample.fourth.startedAt),
            "runs(in:) from the second start to the fourth",
            [sample.second, sample.third],
        )
        // Clause 2, and clause 1's every field: b ends, and is saved again.
        checker.sample.finishSecond()
        let finished = checker.sample
        guard checker.save([finished.second], "saving the second run again") else {
            return checker.broken
        }
        checker.expectRuns(
            in: everything,
            "after saving the second run again: runs(in:)",
            [finished.first, finished.second, finished.third, finished.fourth],
        )
        // Clause 3: a is older than b's start; b, starting exactly at it, stays.
        let cutoff = finished.second.startedAt
        checker.expectDeleted(olderThan: cutoff, 1, "deleteRuns(olderThan:) the second start")
        checker.expectDeleted(olderThan: cutoff, 0, "deleteRuns(olderThan:) the second start again")
        checker.expectRuns(
            in: everything,
            "after deleting runs older than the second start: runs(in:)",
            [finished.second, finished.third, finished.fourth],
        )
        return checker.broken
    }

    /// Records an issue for every promise `store` breaks.
    package static func check(_ store: some RunStoring) {
        let broken = violations(of: store)
        #expect(broken.isEmpty, "\(type(of: store)) breaks the RunStoring contract: \(broken)")
    }
}
