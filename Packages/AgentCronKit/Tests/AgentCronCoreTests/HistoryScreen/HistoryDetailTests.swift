import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// The selected run's detail and formatting (REQ-004), and the retention sweep (REQ-005).
@MainActor
@Suite("History detail and retention")
struct HistoryDetailTests {
    // MARK: - Detail and formatting (REQ-004)

    @Test
    func `selecting a run shows its detail with cost in USD and duration`() {
        let run = HistoryFixture.run(
            HistoryFixture.digest,
            at: HistoryFixture.date(9, 30, 9, 0),
            .failed,
            seconds: 134,
            cost: 0.42,
        )
        let (history, _) = HistoryFixture.loaded([run])
        #expect(history.detail == nil)
        history.select(runID: run.id)
        #expect(history.selectedRunID == run.id)
        let detail = history.detail
        #expect(detail?.run == run)
        #expect(detail?.badge == .failed)
        #expect(detail?.cost == "$0.42")
        #expect(detail?.duration?.resolved(in: .english) == "2m 14s")
        #expect(detail?.trigger.resolved(in: .english) == "Scheduled")
        history.select(runID: nil)
        #expect(history.detail == nil)
    }

    @Test
    func `a run with no cost omits it from the detail`() {
        let run = HistoryFixture.run(
            HistoryFixture.digest,
            at: HistoryFixture.date(9, 30, 9, 0),
            .succeeded,
            seconds: 60,
            cost: nil,
        )
        let (history, _) = HistoryFixture.loaded([run])
        history.select(runID: run.id)
        #expect(history.detail != nil)
        #expect(history.detail?.cost == nil)
    }

    @Test
    func `a run that has not ended has no duration`() {
        let run = HistoryFixture.run(
            HistoryFixture.digest,
            at: HistoryFixture.date(9, 30, 9, 0),
            .running,
            seconds: nil,
            cost: nil,
        )
        let (history, _) = HistoryFixture.loaded([run])
        history.select(runID: run.id)
        #expect(history.detail?.duration == nil)
    }

    @Test
    func `a duration under a minute reads in seconds`() {
        let start = HistoryFixture.now
        #expect(HistoryFormatting.duration(from: start, to: start + 42)
            .resolved(in: .english) == "42s")
        #expect(HistoryFormatting.duration(from: start, to: start + 60).resolved(in: .english)
            == "1m 0s")
        #expect(HistoryFormatting.duration(from: start, to: start - 5)
            .resolved(in: .english) == "0s")
    }

    @Test
    func `every trigger has a label`() {
        #expect(RunTrigger.allCases.map { HistoryFormatting.trigger($0).resolved(in: .english) }
            == ["Catch-up", "Run Now", "Scheduled"])
    }

    @Test
    func `cost formats as US dollars in the injected locale`() {
        #expect(HistoryFormatting
            .cost(Decimal(string: "1.5") ?? 0, locale: HistoryFixture.locale) == "$1.50")
    }

    // MARK: - Retention (REQ-005)

    @Test
    func `launch sweeps runs older than 90 days once`() {
        let old = HistoryFixture.run(HistoryFixture.digest, at: HistoryFixture.date(7, 1, 10, 0))
        let kept = HistoryFixture.run(HistoryFixture.digest, at: HistoryFixture.date(7, 2, 10, 0))
        let (history, store) = HistoryFixture.loaded([old, kept])
        #expect(history.sweepIfDue())
        #expect(history.lastSweepAt == HistoryFixture.now)
        #expect(store.runs.map(\.id) == [kept.id])
        #expect(!history.sweepIfDue())
    }

    @Test
    func `the sweep cutoff is now minus 90 days`() {
        let store = RecordingRunStore()
        let history = HistoryFixture.model(store)
        history.sweepIfDue()
        #expect(store.cutoffs == [HistoryFixture.date(7, 2, 10, 0)])
    }

    @Test
    func `the sweep runs again once a day has passed`() {
        let store = RecordingRunStore()
        HistoryFixture.model(store, now: HistoryFixture.now).sweepIfDue()
        let clock = MutableDate(HistoryFixture.now)
        let history = HistoryModel(
            store: store,
            calendar: HistoryFixture.calendar,
            locale: HistoryFixture.locale,
        ) { clock.value }
        #expect(history.sweepIfDue())
        clock.value = HistoryFixture.date(10, 1, 9, 59)
        #expect(!history.sweepIfDue())
        clock.value = HistoryFixture.date(10, 1, 10, 0)
        #expect(history.sweepIfDue())
        #expect(store.cutoffs.count == 3)
    }

    @Test
    func `a failed sweep reports the error and stays due`() {
        let history = HistoryFixture.model(ThrowingRunStore())
        #expect(!history.sweepIfDue())
        #expect(history.storageError == .writeFailed(code: ThrowingRunStore.code))
        #expect(history.lastSweepAt == nil)
    }
}
