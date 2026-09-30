import AgentCronCore
import Foundation
import Testing

/// Which finished runs notify (REQ-001–REQ-003) and what the notification says
/// (REQ-004), including the boundaries: a body over 120 characters, an empty reason and
/// result, and a stopped run under failures only.
@Suite("NotificationPolicy")
struct NotificationPolicyTests {
    /// The outcomes that notify under each setting, worked out by hand from requirements
    /// §3.5: "failure" is failed, timed out, or skipped; a running run has not finished
    /// and never notifies.
    static let notifyingOutcomes: [NotifyPolicy: Set<RunOutcome>] = [
        .never: [],
        .failuresOnly: [.failed, .skipped, .timedOut],
        .everyRun: [.failed, .skipped, .stopped, .succeeded, .timedOut],
    ]

    /// The English title each finished outcome gives a job named "Nightly review".
    static let titles: [(RunOutcome, String)] = [
        (.failed, "Nightly review failed"),
        (.skipped, "Nightly review was skipped"),
        (.stopped, "Nightly review was stopped"),
        (.succeeded, "Nightly review succeeded"),
        (.timedOut, "Nightly review timed out"),
    ]

    private static func content(for run: Run) -> NotificationContent? {
        NotificationPolicy.content(
            for: run,
            locale: .english,
            calendar: NotificationFixture.calendar,
        )
    }

    // MARK: - Whether to notify

    @Test(arguments: NotifyPolicy.allCases, RunOutcome.allCases)
    func `a setting and an outcome decide whether a run notifies`(
        setting: NotifyPolicy,
        outcome: RunOutcome,
    ) throws {
        let notifying = try #require(Self.notifyingOutcomes[setting])
        let run = NotificationFixture.finishedRun(
            of: NotificationFixture.job(notify: setting),
            outcome: outcome,
        )
        #expect(NotificationPolicy.shouldNotify(for: run) == notifying.contains(outcome))
    }

    @Test
    func `the setting the run started with decides, not an edit made while it ran`() {
        var job = NotificationFixture.job(notify: .never)
        let run = NotificationFixture.finishedRun(of: job, outcome: .failed)
        job.notify = .everyRun
        #expect(!NotificationPolicy.shouldNotify(for: run))
    }

    @Test
    func `a stopped run under failures only is not a failure`() {
        let run = NotificationFixture.finishedRun(
            of: NotificationFixture.job(notify: .failuresOnly),
            outcome: .stopped,
        )
        #expect(!NotificationPolicy.shouldNotify(for: run))
    }

    @Test
    func `a successful run under failures only does not notify`() {
        #expect(!NotificationPolicy.shouldNotify(for: NotificationFixture.rssDigestSucceeded()))
    }

    // MARK: - What it says

    @Test
    func `the timed-out nightly review reads as the worked example`() throws {
        let content = try #require(Self.content(for: NotificationFixture.nightlyReviewTimedOut()))
        #expect(content == NotificationContent(
            runID: Fixture.runID,
            title: "Nightly review timed out",
            subtitle: "· 22:00",
            body: "Timed out after 30 minutes",
        ))
    }

    @Test(arguments: titles)
    func `the title is the job's name and how its run ended`(
        outcome: RunOutcome,
        title: String,
    ) throws {
        let run = NotificationFixture.finishedRun(
            of: NotificationFixture.job(named: "Nightly review", notify: .everyRun),
            outcome: outcome,
        )
        #expect(try #require(Self.content(for: run)).title == title)
    }

    @Test
    func `a run still going has no notification to build`() {
        let run = NotificationFixture.finishedRun(
            of: NotificationFixture.job(notify: .everyRun),
            outcome: .running,
        )
        #expect(Self.content(for: run) == nil)
    }

    @Test
    func `the subtitle is the time the run was for, in the calendar's time zone`() throws {
        var tokyo = NotificationFixture.calendar
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        let run = NotificationFixture.nightlyReviewTimedOut()
        let content = try #require(NotificationPolicy.content(
            for: run,
            locale: .english,
            calendar: tokyo,
        ))
        // 22:00 UTC is 07:00 the next morning in Tokyo, which has no daylight saving.
        #expect(content.subtitle == "· 07:00")
    }

    @Test
    func `a run caught up late is still named by the time it was scheduled for`() throws {
        let job = NotificationFixture.job(notify: .failuresOnly)
        var run = Run(
            job: job,
            trigger: .catchUp,
            startedAt: NotificationFixture.nineAM,
            scheduledAt: NotificationFixture.tenPM,
            id: Fixture.runID,
        )
        run.outcome = .failed
        #expect(try #require(Self.content(for: run)).subtitle == "· 22:00")
    }

    @Test
    func `a manual run is named by the time it started`() throws {
        var run = Run(
            job: NotificationFixture.job(notify: .everyRun),
            trigger: .manual,
            startedAt: NotificationFixture.nineAM,
            id: Fixture.runID,
        )
        run.outcome = .succeeded
        #expect(try #require(Self.content(for: run)).subtitle == "· 09:00")
    }

    // MARK: - The body

    @Test
    func `the body is the reason's first line, ahead of the result`() throws {
        var run = NotificationFixture.nightlyReviewTimedOut()
        run.failureReason = "\n  Timed out after 30 minutes  \nSIGTERM sent"
        run.resultText = "Partial review"
        #expect(try #require(Self.content(for: run)).body == "Timed out after 30 minutes")
    }

    @Test
    func `without a reason, the body is the result's first line`() throws {
        var run = NotificationFixture.rssDigestSucceeded()
        run.failureReason = "   "
        run.resultText = "Wrote news.html with 12 stories.\n\n- World: 4"
        #expect(try #require(Self.content(for: run)).body == "Wrote news.html with 12 stories.")
    }

    @Test
    func `with neither a reason nor a result, the body is empty and the content still built`(
    ) throws {
        var run = NotificationFixture.nightlyReviewTimedOut()
        run.failureReason = nil
        run.resultText = ""
        let content = try #require(Self.content(for: run))
        #expect(content.body.isEmpty)
        #expect(content.title == "Nightly review timed out")
    }

    @Test(arguments: [(119, 119), (120, 120), (121, 120), (500, 120)])
    func `a first line over 120 characters is cut to 120`(length: Int, expected: Int) throws {
        var run = NotificationFixture.nightlyReviewTimedOut()
        let line = String(repeating: "x", count: length)
        run.failureReason = line + "\nsecond line"
        let body = try #require(Self.content(for: run)).body
        #expect(body.count == expected)
        #expect(body == String(repeating: "x", count: expected))
    }

    @Test
    func `the cut counts characters a reader sees, not bytes`() throws {
        var run = NotificationFixture.nightlyReviewTimedOut()
        run.failureReason = String(repeating: "失", count: 130)
        let body = try #require(Self.content(for: run)).body
        #expect(body == String(repeating: "失", count: 120))
    }

    @Test
    func `the longest body is 120 characters`() {
        #expect(NotificationPolicy.maximumBodyLength == 120)
    }
}
