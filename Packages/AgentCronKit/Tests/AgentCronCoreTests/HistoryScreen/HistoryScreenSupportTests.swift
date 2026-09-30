import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// What the History screen's view reads from the model beyond grouping and filters: the
/// detail's body per outcome, deleted jobs, Clear Filters, and the clock-style texts
/// (#24).
@MainActor
@Suite("History screen support")
struct HistoryScreenSupportTests {
    private static let start = HistoryFixture.date(9, 30, 9, 0)

    private static func detail(of run: Run) -> HistoryRunDetail? {
        let (history, _) = HistoryFixture.loaded([run])
        history.select(runID: run.id)
        return history.detail
    }

    // MARK: - Detail body

    @Test
    func `a running run's detail is the running state with nothing to copy`() {
        let run = HistoryFixture.run(
            HistoryFixture.digest,
            at: Self.start,
            .running,
            seconds: nil,
            cost: nil,
        )
        let detail = Self.detail(of: run)
        #expect(detail?.body == .running)
        #expect(detail?.copyableText == nil)
    }

    @Test
    func `a skipped run's detail shows its reason instead of a result`() {
        var run = HistoryFixture.run(HistoryFixture.digest, at: Self.start, .skipped)
        run.skipReason = .missed
        run.resultText = "ignored"
        let detail = Self.detail(of: run)
        #expect(detail?.body == .skipped(.missed))
        #expect(detail?.copyableText == nil)
    }

    @Test
    func `a failed run shows its error output ahead of any result text`() {
        var run = HistoryFixture.run(HistoryFixture.digest, at: Self.start, .failed)
        run.failureReason = "error_during_execution"
        run.resultText = "partial"
        #expect(Self.detail(of: run)?.body == .output("error_during_execution"))
        run.failureReason = nil
        #expect(Self.detail(of: run)?.body == .output("partial"))
    }

    @Test
    func `a succeeded run shows its result, which is what Copy copies`() {
        var run = HistoryFixture.run(HistoryFixture.digest, at: Self.start, .succeeded)
        run.resultText = "## Today's digest"
        let detail = Self.detail(of: run)
        #expect(detail?.body == .output("## Today's digest"))
        #expect(detail?.copyableText == "## Today's digest")
    }

    @Test(arguments: [RunOutcome.succeeded, .stopped, .timedOut, .failed])
    func `an ended run with no text shows that it has none`(outcome: RunOutcome) {
        let run = HistoryFixture.run(HistoryFixture.digest, at: Self.start, outcome)
        #expect(Self.detail(of: run)?.body == .noOutput)
    }

    @Test
    func `a stopped run falls back to its failure reason when it has no result`() {
        var run = HistoryFixture.run(HistoryFixture.digest, at: Self.start, .stopped)
        run.failureReason = "stopped by the user"
        #expect(Self.detail(of: run)?.body == .output("stopped by the user"))
    }

    @Test
    func `the detail formats its start and scheduled times in the model's locale`() {
        let run = HistoryFixture.run(HistoryFixture.digest, at: HistoryFixture.date(9, 30, 9, 0, 2))
        let detail = Self.detail(of: run)
        #expect(detail?.startedText == "Sep 30, 2026 at 9:00:02\u{202F}AM")
        #expect(detail?.scheduledText == detail?.startedText)
        let manual = Run(job: HistoryFixture.digest, trigger: .manual, startedAt: Self.start)
        #expect(Self.detail(of: manual)?.scheduledText == nil)
    }

    // MARK: - Deleted jobs

    @Test
    func `before the jobs are reported, no run's job counts as deleted`() {
        let run = HistoryFixture.run(HistoryFixture.digest, at: Self.start)
        let (history, _) = HistoryFixture.loaded([run])
        history.select(runID: run.id)
        #expect(history.isDeleted(jobID: HistoryFixture.digest.id) == false)
        #expect(history.detail?.canOpenJob == true)
        #expect(history.groups.first?.rows.first?.isJobDeleted == false)
    }

    @Test
    func `a deleted job's run is labelled deleted and offers no Open Job`() {
        let run = HistoryFixture.run(HistoryFixture.digest, at: Self.start)
        let (history, _) = HistoryFixture.loaded([run])
        history.jobsChanged(to: [HistoryFixture.review])
        history.select(runID: run.id)
        let detail = history.detail
        #expect(detail?.isJobDeleted == true)
        #expect(detail?.canOpenJob == false)
        #expect(detail?.jobTitle.resolved(in: .english) == "Digest (deleted)")
        let row = history.groups.first?.rows.first
        #expect(row?.jobTitle.resolved(in: .english) == "Digest (deleted)")
        history.jobsChanged(to: [HistoryFixture.digest])
        #expect(history.detail?.canOpenJob == true)
        #expect(history.groups.first?.rows.first?.jobTitle.resolved(in: .english) == "Digest")
    }

    // MARK: - Rows and filters

    @Test
    func `a row carries its start time and cost`() {
        let run = HistoryFixture.run(
            HistoryFixture.digest,
            at: Self.start,
            .succeeded,
            seconds: 134,
            cost: 0.12,
        )
        let (history, _) = HistoryFixture.loaded([run])
        let row = history.groups.first?.rows.first
        #expect(row?.timeText == "9:00\u{202F}AM")
        #expect(row?.cost == "$0.12")
    }

    @Test
    func `clearing the filters shows every job and outcome again`() {
        let runs = [
            HistoryFixture.run(HistoryFixture.digest, at: Self.start),
            HistoryFixture.run(
                HistoryFixture.review,
                at: HistoryFixture.date(9, 30, 8, 0),
                .failed,
            ),
        ]
        let (history, _) = HistoryFixture.loaded(runs)
        history.jobFilter = HistoryFixture.digest.id
        history.outcomeFilter = .failures
        #expect(history.emptyState == .noMatches)
        history.clearFilters()
        #expect(history.jobFilter == nil)
        #expect(history.outcomeFilter == .all)
        #expect(history.emptyState == nil)
        #expect(history.groups.first?.rows.count == 2)
    }

    // MARK: - Elapsed

    @Test
    func `elapsed time reads as a clock, with hours from an hour on`() {
        let origin = HistoryFixture.now
        #expect(HistoryFormatting.elapsed(from: origin, to: origin + 252) == "4:12")
        #expect(HistoryFormatting.elapsed(from: origin, to: origin + 5.9) == "0:05")
        #expect(HistoryFormatting.elapsed(from: origin, to: origin + 3_852) == "1:04:12")
        #expect(HistoryFormatting.elapsed(from: origin, to: origin - 10) == "0:00")
    }

    @Test
    func `every skip reason has its own wording`() {
        let titles = SkipReason.allCases.map { String(localized: $0.title) }
        #expect(Set(titles).count == SkipReason.allCases.count)
        #expect(SkipReason.missed.title.resolved(in: .english) == "Missed beyond 60 min")
    }
}
