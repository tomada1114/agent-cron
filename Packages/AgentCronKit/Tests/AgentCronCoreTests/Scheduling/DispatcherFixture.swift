import AgentCronCore
import AgentCronTestSupport
import Foundation
import os

/// Hands out `00000000-0000-0000-0000-000000000001`, `…002`, … in order, so a test names
/// the runs a dispatcher records without drawing a random identifier.
final class SequentialIDs: Sendable {
    private let counter = OSAllocatedUnfairLock(initialState: 0)

    /// The `number`th identifier this source hands out, counting from 1.
    static func id(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number)) ?? UUID()
    }

    func next() -> UUID {
        Self.id(counter.withLock { count in
            count += 1
            return count
        })
    }
}

/// What a fixture's stores throw; `nil` for a call that succeeds.
struct StoreFailures {
    var jobLoad: StorageError?
    var jobSave: StorageError?
    var runSave: StorageError?
}

/// The world a ``DispatcherFixture`` sets up. Every field has the value most tests want —
/// one job, every day at 10:00, last checked at 09:55, the clock at 10:00 — so a test
/// names only what it changes.
struct DispatcherScenario {
    /// The job's `(hour, minute)` times, every day.
    var times = [(DispatcherFixture.tenHour, 0)]
    /// The wall-clock time the dispatcher's clock reads.
    var now = DispatcherFixture.at(DispatcherFixture.tenHour, 0)
    /// The saved last check.
    var lastCheckedAt: Date? = DispatcherFixture.at(
        DispatcherFixture.nineHour,
        DispatcherFixture.fiftyFive,
    )
    /// What every job's command line does once launched.
    var agent = FakeAgentRunner.Behavior.runsUntilTerminated
    /// What resolving `claude` in the login shell does.
    var resolve = DispatcherFixture.resolved
    /// What the stores fail with, when anything.
    var stores = StoreFailures()
    /// How many other jobs to save beside the job, on its schedule, in its directory.
    var siblings = 0
    /// A change to the job before it is saved.
    var edit: ((inout Job) -> Void)?
}

/// What a dispatcher reported through its two callbacks, in order.
@MainActor
final class DispatchReports {
    private(set) var runningSets: [Set<UUID>] = []
    private(set) var finished: [Run] = []

    /// Starts listening to `dispatcher`'s callbacks.
    init(listeningTo dispatcher: Dispatcher) {
        dispatcher.onRunningJobsChanged = { [weak self] jobIDs in
            self?.runningSets.append(jobIDs)
        }
        dispatcher.onRunFinished = { [weak self] run in
            self?.finished.append(run)
        }
    }
}

/// A ``Dispatcher`` over the shared fakes, a fixed UTC calendar, and two manual clocks:
/// one whose date the dispatcher reads as "now", and one the fake runner waits out
/// timeouts on, so moving the wall clock never times a run out by accident.
///
/// The job's directory is a real, empty temporary directory, because the dispatcher's
/// pre-flight and the fake runner both look for it; ``cleanUp()`` removes it.
///
/// Only what touches the dispatcher is main-actor isolated, so a ``DispatcherScenario``'s
/// defaults can read the constants here.
struct DispatcherFixture {
    static let nineHour = Fixture.nineOClock
    static let tenHour = 10
    static let fiftyFive = 55
    static let siblingIDBase = 1_000
    static let minutesPerHour = 60
    static let secondsPerMinute = 60
    /// How many times ``until(_:)`` yields before it gives up.
    static let yieldLimit = 100_000
    /// The path the availability check resolves `claude` to.
    static let claudePath = "/Users/me/.local/bin/claude"
    static let resolveArgv = AgentAvailabilityChecker.resolveArguments(for: .claudeCode)
    static let versionArgv = [claudePath, "--version"]
    /// The login shell finds `claude`.
    static let resolved = exits(0, "\(claudePath)\n")
    /// The login shell does not find `claude`: `command -v` exits 1 and prints nothing.
    static let notResolved = exits(1, "")
    /// The login shell itself could not start, so the check cannot answer either way.
    static let shellFails = exits(ProcessOutcome.notLaunchedExitCode, "")

    /// The fixed day every date is on: Monday 2026-10-05, 2026-10-05T00:00:00Z.
    static let daySeconds: TimeInterval = 1_791_158_400

    static let calendar: Calendar = {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "UTC") ?? gregorian.timeZone
        return gregorian
    }()

    let directory: URL
    let job: Job
    /// Other jobs saved beside ``job``.
    let siblings: [Job]
    let jobStore: FakeJobStore
    let runStore: FakeRunStore
    let runner: FakeAgentRunner
    let wallClock: ManualClock
    let runnerClock: ManualClock
    let dispatcher: Dispatcher

    /// The command line a run of ``job`` launches.
    var jobArgv: [String] {
        Self.argv(for: job)
    }

    /// The command lines the fake runner was asked to launch for ``job``, availability
    /// checks left out.
    var launches: [[String]] {
        runner.requests.map(\.argv).filter { $0 == jobArgv }
    }

    /// The final record of every run, oldest first: what History would show.
    var recorded: [Run] {
        runStore.runs
    }

    @MainActor
    init(_ scenario: DispatcherScenario) {
        let made = Self.makeDirectory()
        directory = made
        job = Self.job(in: made, scenario: scenario)
        siblings = Self.siblings(of: job, count: scenario.siblings)
        jobStore = Self.jobStore(holding: [job] + siblings, scenario: scenario)
        runStore = scenario.stores.runSave.map { FakeRunStore(saveError: $0) } ?? FakeRunStore()
        let waits = ManualClock(start: scenario.now)
        runnerClock = waits
        runner = FakeAgentRunner(
            behaviors: [
                Self.resolveArgv: scenario.resolve,
                Self.versionArgv: Self.exits(0, "2.1.0\n"),
            ],
            // Every job's command line, siblings' included, does what the scenario says.
            otherwise: scenario.agent,
            clock: waits,
        )
        let reads = ManualClock(start: scenario.now)
        wallClock = reads
        let ids = SequentialIDs()
        dispatcher = Dispatcher(
            jobStore: jobStore,
            runStore: runStore,
            runner: runner,
            availability: AgentAvailabilityChecker(runner: runner, directory: made),
            environment: DispatchEnvironment(
                calendar: Self.calendar,
                now: { reads.date },
                makeRunID: { ids.next() },
            ),
        )
    }

    /// The fixed day at `hour:minute` UTC.
    static func at(_ hour: Int, _ minute: Int) -> Date {
        let midnight = Date(timeIntervalSince1970: daySeconds)
        return midnight
            .addingTimeInterval(TimeInterval((hour * minutesPerHour + minute) * secondsPerMinute))
    }

    static func exits(_ code: Int32, _ stdout: String) -> FakeAgentRunner.Behavior {
        exits(code, stdout, stderr: "")
    }

    static func exits(_ code: Int32, _ stdout: String, stderr: String) -> FakeAgentRunner.Behavior {
        .exits(code: code, stdout: Data(stdout.utf8), stderr: stderr)
    }

    static func argv(for job: Job) -> [String] {
        job.agent.commandBuilder.arguments(for: RunRequest(JobSnapshot(of: job)))
    }

    static func makeDirectory() -> URL {
        let made = FileManager.default.temporaryDirectory
            .appending(path: "AgentCronTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: made, withIntermediateDirectories: true)
        } catch {
            preconditionFailure("could not create the fixture's directory")
        }
        return made
    }

    private static func job(in directory: URL, scenario: DispatcherScenario) -> Job {
        var made = Job(
            name: "RSS digest",
            directory: directory,
            prompt: "Summarize today's feeds into news.html.",
            schedule: Schedule(
                weekdays: Set(Weekday.allCases),
                times: scenario.times.map { Fixture.time($0.0, $0.1) },
            ),
            createdAt: at(Fixture.nineOClock - 1, 0),
            id: Fixture.jobID,
        )
        scenario.edit?(&made)
        return made
    }

    private static func siblings(of job: Job, count: Int) -> [Job] {
        (0 ..< count).map { index in
            Job(
                name: "Sibling \(index)",
                directory: job.directory,
                prompt: "Sibling chore \(index).",
                schedule: job.schedule,
                createdAt: job.createdAt,
                id: SequentialIDs.id(siblingIDBase + index),
            )
        }
    }

    private static func jobStore(
        holding jobs: [Job],
        scenario: DispatcherScenario,
    ) -> FakeJobStore {
        let failures = scenario.stores
        guard failures.jobLoad == nil, failures.jobSave == nil else {
            return FakeJobStore(loadError: failures.jobLoad, saveError: failures.jobSave)
        }
        return FakeJobStore(document: JobsDocument(
            jobs: jobs,
            lastCheckedAt: scenario.lastCheckedAt,
        ))
    }

    /// Lets the dispatcher's run tasks go until `condition` holds, and answers whether it
    /// did. Yields rather than sleeps: nothing here waits on wall-clock time, and a bound
    /// on the yields turns a run that never gets there into a failed expectation instead
    /// of a hung test.
    @MainActor
    func until(_ condition: () -> Bool) async -> Bool {
        for _ in 0 ..< Self.yieldLimit {
            if condition() {
                return true
            }
            await Task.yield()
        }
        return condition()
    }

    /// Stops every run still going and waits until each is recorded, so no task outlives
    /// the test.
    @MainActor
    func stopAll() async {
        for run in dispatcher.runningRuns {
            dispatcher.stop(runID: run.id)
        }
        await dispatcher.waitForRuns()
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: directory)
    }
}
