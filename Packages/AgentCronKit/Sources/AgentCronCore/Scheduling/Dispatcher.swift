import Foundation
import Observation

/// What the ``Dispatcher`` reads from the world rather than deciding: the calendar a
/// schedule's wall times are read in, the time, and a new run's identity
/// (`designing-core-logic` › Inject time).
public struct DispatchEnvironment: Sendable {
    /// The system's calendar and time zone, following either when it changes; the real
    /// time; a random identifier per run.
    public static let live = Self(
        calendar: .autoupdatingCurrent,
        now: { Date.now },
        makeRunID: { UUID() },
    )

    /// The calendar, with its time zone, every job's schedule is read in.
    public let calendar: Calendar
    /// The time a run started by hand starts at, and the time every run ends at.
    public let now: @Sendable () -> Date
    /// The identity of each run the dispatcher records.
    public let makeRunID: @Sendable () -> UUID

    /// Makes an environment; tests pass a fixed calendar, a manual clock's date, and
    /// predictable identifiers.
    public init(
        calendar: Calendar,
        now: @escaping @Sendable () -> Date,
        makeRunID: @escaping @Sendable () -> UUID,
    ) {
        self.calendar = calendar
        self.now = now
        self.makeRunID = makeRunID
    }
}

/// The scheduler's decisions (ADR-0003, requirements §3.2–3.4): which saved jobs are due,
/// which missed times catch up and which are skipped, whether a run may start, and what
/// each run's record says — from the moment it starts to the moment it ends.
///
/// It owns no timer and observes no OS event: a caller tells it that time passed
/// (``tick(now:)``), that the Mac woke or the app launched (``didWake(now:)``), or what the
/// user chose (``runNow(jobID:)``, ``stop(runID:)``). Both checks read the jobs afresh, find
/// each enabled job's fire dates since the last check, and treat them alike:
///
/// - The latest date runs once when it is at most ``ScheduleCalendar/defaultGrace`` old;
///   every other date is recorded ``RunOutcome/skipped`` for ``SkipReason/missed``. A date
///   found within ``onTimeTolerance`` of it runs as ``RunTrigger/scheduled``, a later one
///   as ``RunTrigger/catchUp`` — so a timer that fires late on wake, before the wake
///   event arrives, still records a catch-up.
/// - A job whose previous run has not ended is recorded skipped for
///   ``SkipReason/stillRunning``; different jobs run in parallel, with no limit.
/// - A job whose directory is gone is recorded skipped for ``SkipReason/directoryMissing``,
///   and one whose agent the login shell does not find for ``SkipReason/agentNotFound``,
///   without launching anything. An availability check that cannot answer either way
///   does not hold a run back; the run itself then says what happened.
/// - A run is saved ``RunOutcome/running`` as it launches and saved again when it ends,
///   under the same identity, so the store keeps one record per run.
/// - A date before the job was last saved is not the job's: an edit that adds 10:00 at
///   10:10 does not catch 10:00 up.
///
/// The last check only moves forward: a clock set back never reruns a time already
/// handled. A jobs document that cannot be read is neither acted on nor saved over
/// (``JobStoring``'s rule); a store that refuses a write is logged and kept in
/// ``storageError``, and runs still start, since the schedule is what the user asked for.
///
/// What it reports — ``runningRuns``, ``onRunningJobsChanged``, ``onRunFinished`` — is
/// what keep-awake, notifications, and the screens react to; the composition root wires
/// them.
@MainActor
@Observable
public final class Dispatcher {
    /// How long after a fire date a check may find it and still call it on time: a timer
    /// fires a little late, and a run it starts is still the scheduled one.
    public static let onTimeTolerance: TimeInterval = 60

    private static let secondsPerMinute = 60

    /// The runs started and not yet ended, oldest first — at most one per job. A run is
    /// here from the moment it is dispatched, through its pre-flight, until it is recorded
    /// in its final state.
    public private(set) var runningRuns: [Run] = []

    /// The last moment the scheduler looked for due times, as saved or, when saving
    /// failed, as this session knows it; `nil` before the first check.
    public private(set) var lastCheckedAt: Date?

    /// Why the most recent store call failed, or `nil` once one succeeds.
    public private(set) var storageError: StorageError?

    /// Called with the jobs that have a run going each time that set changes — what
    /// ``KeepAwakeController/runningJobCountChanged(to:)`` counts and the Jobs screen
    /// badges.
    @ObservationIgnored public var onRunningJobsChanged: (@MainActor (Set<UUID>) -> Void)?

    /// Called with every run once it is recorded in its final state — ended, or skipped
    /// without starting — which is what ``RunNotificationController/runFinished(_:)``
    /// decides about.
    @ObservationIgnored public var onRunFinished: (@MainActor (Run) -> Void)?

    @ObservationIgnored private var tasks: [UUID: Task<Void, Never>] = [:]

    private let jobStore: any JobStoring
    private let runStore: any RunStoring
    private let runner: any AgentRunning
    private let availabilityChecker: AgentAvailabilityChecker
    private let environment: DispatchEnvironment

    /// The jobs that have a run going now.
    public var runningJobIDs: Set<UUID> {
        Set(runningRuns.map(\.jobID))
    }

    /// Makes a dispatcher that reads jobs from `jobStore`, records runs in `runStore`,
    /// launches them through `runner`, and checks each agent with `availability` first.
    ///
    /// Reads nothing and starts nothing until told something: construction has no side
    /// effect.
    public init(
        jobStore: any JobStoring,
        runStore: any RunStoring,
        runner: any AgentRunning,
        availability: AgentAvailabilityChecker,
        environment: DispatchEnvironment = .live,
    ) {
        self.jobStore = jobStore
        self.runStore = runStore
        self.runner = runner
        availabilityChecker = availability
        self.environment = environment
    }

    private static func directoryExists(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: url.path(percentEncoded: false),
            isDirectory: &isDirectory,
        )
        return exists && isDirectory.boolValue
    }

    /// The timer reached a fire date: starts what is due, records what was missed, and
    /// moves the last check to `now`.
    public func tick(now: Date) {
        check(now: now, cause: "tick")
    }

    /// The Mac woke from sleep or the app launched: catches up what was missed since the
    /// last check, as ``tick(now:)`` does. The first check ever catches nothing up; it
    /// only starts watching from `now`.
    public func didWake(now: Date) {
        check(now: now, cause: "wake")
    }

    /// The user chose Run Now: starts the saved job as it is now, enabled or not, with no
    /// scheduled time — or records why it could not start.
    ///
    /// - Returns: The run as first recorded — running, or skipped with its reason — or
    ///   `nil` when no saved job has `jobID` or the jobs could not be read.
    @discardableResult
    public func runNow(jobID: UUID) -> Run? {
        guard let document = loadJobs() else {
            return nil
        }
        guard let job = document.jobs.first(where: { $0.id == jobID }) else {
            AppLog.scheduler.error("run now: no saved job with that identifier")
            return nil
        }
        return dispatch(job, trigger: .manual, scheduledAt: nil, at: environment.now())
    }

    /// The user chose Stop: cancels the run, which is then recorded
    /// ``RunOutcome/stopped`` once its process has ended.
    ///
    /// - Returns: Whether a run with `runID` was going.
    @discardableResult
    public func stop(runID: UUID) -> Bool {
        guard let task = tasks[runID] else {
            return false
        }
        task.cancel()
        AppLog.scheduler.info("stop requested")
        return true
    }

    /// Returns once every run going now has been recorded in its final state. For tests: a
    /// run whose process never ends on its own must be stopped first.
    package func waitForRuns() async {
        while let task = tasks.values.first {
            await task.value
        }
    }

    // MARK: - Checking

    private func check(now: Date, cause: String) {
        guard let document = loadJobs() else {
            return
        }
        let previous = [document.lastCheckedAt, lastCheckedAt].compactMap(\.self).max()
        advanceLastCheck(to: max(previous ?? now, now))
        guard let previous else {
            AppLog.scheduler.info("\(cause, privacy: .public): first check, nothing to catch up")
            return
        }
        let enabled = document.jobs.filter(\.enabled)
        AppLog.scheduler.debug(
            "\(cause, privacy: .public): checking \(enabled.count, privacy: .public) enabled jobs",
        )
        for job in enabled {
            dispatchDue(job, since: previous, now: now)
        }
    }

    private func dispatchDue(_ job: Job, since previous: Date, now: Date) {
        let schedule = ScheduleCalendar(schedule: job.schedule, calendar: environment.calendar)
        let plan = schedule.catchUpPlan(lastChecked: max(previous, job.updatedAt), now: now)
        for missed in plan.skipped {
            let run = newRun(of: job, trigger: .catchUp, scheduledAt: missed, at: now)
            recordSkipped(run.skipped(.missed, at: now))
        }
        guard let due = plan.runOnce else {
            return
        }
        let onTime = now.timeIntervalSince(due) <= Self.onTimeTolerance
        dispatch(job, trigger: onTime ? .scheduled : .catchUp, scheduledAt: due, at: now)
    }

    private func advanceLastCheck(to date: Date) {
        lastCheckedAt = date
        do {
            try jobStore.updateLastCheckedAt(date)
            storageError = nil
        } catch {
            report(error, while: "saving the last check")
        }
    }

    // MARK: - Running

    @discardableResult
    private func dispatch(
        _ job: Job,
        trigger: RunTrigger,
        scheduledAt: Date?,
        at date: Date,
    ) -> Run {
        let run = newRun(of: job, trigger: trigger, scheduledAt: scheduledAt, at: date)
        if runningJobIDs.contains(job.id) {
            return recordSkipped(run.skipped(.stillRunning, at: date))
        }
        guard Self.directoryExists(run.snapshot.directory) else {
            return recordSkipped(run.skipped(.directoryMissing, at: date))
        }
        runningRuns.append(run)
        onRunningJobsChanged?(runningJobIDs)
        tasks[run.id] = Task { [weak self] in
            await self?.execute(run)
        }
        return run
    }

    private func execute(_ run: Run) async {
        let snapshot = run.snapshot
        let availability = await availabilityChecker.check(snapshot.agent)
        guard !Task.isCancelled else {
            finish(run.stopped(at: environment.now()))
            return
        }
        switch availability {
        case .notFound:
            finish(run.skipped(.agentNotFound, at: environment.now()))
            return

        case let .error(reason):
            AppLog.scheduler
                .error("agent check did not answer (\(reason, privacy: .public)); running anyway")

        case .available:
            break
        }
        save(run)
        AppLog.scheduler.info("run launched (\(run.trigger.rawValue, privacy: .public))")
        let builder = snapshot.agent.commandBuilder
        let outcome = await runner.run(
            argv: builder.arguments(for: RunRequest(snapshot)),
            directory: snapshot.directory,
            timeout: .seconds(snapshot.timeoutMinutes * Self.secondsPerMinute),
        )
        finish(run.finished(
            with: outcome,
            result: builder.result(of: outcome),
            at: environment.now(),
        ))
    }

    private func finish(_ run: Run) {
        save(run)
        runningRuns.removeAll { $0.id == run.id }
        tasks[run.id] = nil
        onRunningJobsChanged?(runningJobIDs)
        onRunFinished?(run)
        AppLog.scheduler.info("run ended: \(run.outcome.rawValue, privacy: .public)")
    }

    // MARK: - Recording

    private func newRun(
        of job: Job,
        trigger: RunTrigger,
        scheduledAt: Date?,
        at date: Date,
    ) -> Run {
        Run(
            job: job,
            trigger: trigger,
            startedAt: date,
            scheduledAt: scheduledAt,
            id: environment.makeRunID(),
        )
    }

    /// Records a run that ends as it is recorded: a skipped time.
    @discardableResult
    private func recordSkipped(_ run: Run) -> Run {
        save(run)
        onRunFinished?(run)
        let reason = run.skipReason?.rawValue ?? "none"
        AppLog.scheduler.info("run skipped: \(reason, privacy: .public)")
        return run
    }

    private func save(_ run: Run) {
        do {
            try runStore.save(run)
            storageError = nil
        } catch {
            report(error, while: "saving a run")
        }
    }

    private func loadJobs() -> JobsDocument? {
        do {
            let document = try jobStore.load()
            storageError = nil
            return document
        } catch {
            report(error, while: "reading the jobs")
            return nil
        }
    }

    private func report(_ error: StorageError, while action: StaticString) {
        storageError = error
        let described = String(describing: error)
        let doing = String(describing: action)
        AppLog.scheduler.error("\(doing, privacy: .public) failed: \(described, privacy: .public)")
    }
}
