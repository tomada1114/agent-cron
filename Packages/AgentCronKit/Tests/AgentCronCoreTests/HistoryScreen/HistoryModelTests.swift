import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// The History list: day groups (REQ-001), filters (REQ-002, REQ-003), and its empty
/// states (REQ-006).
@MainActor
@Suite("History list")
struct HistoryModelTests {
    private func titles(_ history: HistoryModel) -> [String] {
        history.groups.map { $0.title.resolved(in: .english) }
    }

    // MARK: - Day groups (REQ-001)

    @Test
    func `nothing is read until reload`() {
        let run = HistoryFixture.run(HistoryFixture.digest, at: HistoryFixture.date(9, 30, 9, 0))
        let store = FakeRunStore(runs: [run])
        let history = HistoryFixture.model(store)
        #expect(history.runs.isEmpty)
        history.reload()
        #expect(history.runs.count == 1)
        #expect(history.storageError == nil)
    }

    @Test
    func `runs today and yesterday group under Today and Yesterday`() {
        let today = HistoryFixture.run(HistoryFixture.digest, at: HistoryFixture.date(9, 30, 9, 0))
        let yesterday = HistoryFixture.run(
            HistoryFixture.digest,
            at: HistoryFixture.date(9, 29, 22, 0),
            .failed,
        )
        let (history, _) = HistoryFixture.loaded([yesterday, today])
        #expect(titles(history) == ["Today", "Yesterday"])
        #expect(history.groups.map(\.rows.count) == [1, 1])
        #expect(history.groups[1].rows.first?.badge == .failed)
    }

    @Test
    func `older days are titled by date and every list is newest first`() {
        let early = HistoryFixture.run(HistoryFixture.digest, at: HistoryFixture.date(9, 1, 8, 0))
        let late = HistoryFixture.run(HistoryFixture.review, at: HistoryFixture.date(9, 1, 20, 0))
        let today = HistoryFixture.run(HistoryFixture.digest, at: HistoryFixture.date(9, 30, 9, 0))
        let (history, _) = HistoryFixture.loaded([early, today, late])
        #expect(titles(history) == ["Today", "Sep 1, 2026"])
        #expect(history.groups[1].rows.map(\.id) == [late.id, early.id])
        #expect(history.groups[1].id == HistoryFixture.date(9, 1, 0, 0))
    }

    @Test
    func `a run at midnight today groups under Today`() {
        let midnight = HistoryFixture.run(
            HistoryFixture.digest,
            at: HistoryFixture.date(9, 30, 0, 0),
        )
        let beforeMidnight = HistoryFixture.run(
            HistoryFixture.digest,
            at: HistoryFixture.date(9, 29, 23, 59, 59),
        )
        let (history, _) = HistoryFixture.loaded([midnight, beforeMidnight])
        #expect(titles(history) == ["Today", "Yesterday"])
        #expect(history.groups[0].rows.map(\.id) == [midnight.id])
    }

    @Test
    func `a recorded run shows without a reload and replaces its earlier copy`() {
        let (history, store) = HistoryFixture.loaded([])
        var run = Run(
            job: HistoryFixture.digest,
            trigger: .manual,
            startedAt: HistoryFixture.date(9, 30, 9, 0),
        )
        history.runRecorded(run)
        #expect(history.groups.first?.rows.first?.badge == .running)
        #expect(history.groups.first?.rows.first?.duration == nil)
        run.outcome = .succeeded
        run.endedAt = HistoryFixture.date(9, 30, 9, 1)
        history.runRecorded(run)
        #expect(history.runs.map(\.outcome) == [.succeeded])
        #expect(store.savedRuns.isEmpty)
    }

    // MARK: - Job filter (REQ-002)

    @Test
    func `a job filter shows only that job's runs`() {
        let digestRun = HistoryFixture.run(
            HistoryFixture.digest,
            at: HistoryFixture.date(9, 30, 9, 0),
        )
        let reviewRun = HistoryFixture.run(
            HistoryFixture.review,
            at: HistoryFixture.date(9, 30, 8, 0),
        )
        let (history, _) = HistoryFixture.loaded([digestRun, reviewRun])
        history.jobFilter = HistoryFixture.review.id
        #expect(history.groups.flatMap(\.rows).map(\.id) == [reviewRun.id])
        history.jobFilter = nil
        #expect(history.groups.flatMap(\.rows).count == 2)
    }

    @Test
    func `the job filter offers existing jobs, then deleted jobs labelled deleted`() {
        let gone = HistoryFixture.job("Archived", number: 3)
        let (history, _) = HistoryFixture.loaded([
            HistoryFixture.run(gone, at: HistoryFixture.date(9, 30, 9, 0)),
            HistoryFixture.run(HistoryFixture.digest, at: HistoryFixture.date(9, 30, 8, 0)),
        ])
        history.jobsChanged(to: [HistoryFixture.review, HistoryFixture.digest])
        let options = history.jobFilterOptions
        #expect(options.map(\.id) == [HistoryFixture.digest.id, HistoryFixture.review.id, gone.id])
        #expect(options.map(\.isDeleted) == [false, false, true])
        #expect(options.map { $0.title.resolved(in: .english) } == [
            "Digest", "Review", "Archived (deleted)",
        ])
    }

    @Test
    func `before the jobs are known no job is called deleted`() {
        let run = HistoryFixture.run(HistoryFixture.digest, at: HistoryFixture.date(9, 30, 9, 0))
        let (history, _) = HistoryFixture.loaded([run])
        #expect(history.jobFilterOptions.map(\.isDeleted) == [false])
    }

    // MARK: - Outcome filter (REQ-003)

    private func everyOutcome() -> (HistoryModel, [RunOutcome: Run]) {
        var runs: [RunOutcome: Run] = [:]
        for (index, outcome) in RunOutcome.allCases.enumerated() {
            runs[outcome] = HistoryFixture.run(
                HistoryFixture.digest,
                at: HistoryFixture.date(9, 30, 9, index),
                outcome,
            )
        }
        return (HistoryFixture.loaded(Array(runs.values)).0, runs)
    }

    @Test(arguments: [
        (HistoryOutcomeFilter.all, Set(RunOutcome.allCases)),
        (.failures, [.failed, .timedOut, .skipped]),
        (.succeeded, [.succeeded]),
        (.skipped, [.skipped]),
    ] as [(HistoryOutcomeFilter, Set<RunOutcome>)])
    func `the outcome filter shows only its outcomes`(
        filter: HistoryOutcomeFilter,
        shown: Set<RunOutcome>,
    ) {
        let (history, runs) = everyOutcome()
        history.outcomeFilter = filter
        let ids = Set(history.groups.flatMap(\.rows).map(\.id))
        #expect(ids == Set(shown.compactMap { runs[$0]?.id }))
    }

    @Test
    func `the outcome filter titles read as the screen names them`() {
        #expect(HistoryOutcomeFilter.pickerOrder.map { $0.title.resolved(in: .english) } == [
            "All", "Failures", "Succeeded", "Skipped",
        ])
        #expect(Set(HistoryOutcomeFilter.pickerOrder) == Set(HistoryOutcomeFilter.allCases))
        #expect(HistoryOutcomeFilter.failures.id == .failures)
    }

    // MARK: - Empty states (REQ-006)

    @Test
    func `no stored runs is the empty state`() {
        let (history, _) = HistoryFixture.loaded([])
        #expect(history.emptyState == .noRuns)
        #expect(history.emptyState?.message.resolved(in: .english)
            == "No runs yet. Runs appear here after a job runs.")
    }

    @Test
    func `failures filter with no failures is the filtered-to-zero state`() {
        let run = HistoryFixture.run(HistoryFixture.digest, at: HistoryFixture.date(9, 30, 9, 0))
        let (history, _) = HistoryFixture.loaded([run])
        #expect(history.emptyState == nil)
        history.outcomeFilter = .failures
        #expect(history.groups.isEmpty)
        #expect(history.emptyState == .noMatches)
        #expect(history.emptyState?.message
            .resolved(in: .english) == "No runs match these filters.")
    }

    @Test
    func `a failed read keeps the list and reports the error`() {
        let store = ThrowingRunStore()
        let history = HistoryFixture.model(store)
        history.runRecorded(HistoryFixture.run(
            HistoryFixture.digest,
            at: HistoryFixture.date(9, 30, 9, 0),
        ))
        history.reload()
        #expect(history.storageError == .readFailed(code: ThrowingRunStore.code))
        #expect(history.runs.count == 1)
    }
}
