import AgentCronCore
import AgentCronTestSupport
import Foundation

/// The world an ``AppEnvironmentFixture`` sets up. Every field has the value most tests
/// want — one job, every day at 10:00, last checked at 08:00, the clock at 09:00,
/// notifications allowed — so a test names only what it changes.
struct AppScenario {
    /// The job's `(hour, minute)` times, every day.
    var times = [(DispatcherFixture.tenHour, 0)]
    /// The wall-clock time at launch.
    var now = DispatcherFixture.at(AppEnvironmentFixture.launchHour, 0)
    /// The saved last check.
    var lastCheckedAt: Date? = DispatcherFixture.at(AppEnvironmentFixture.lastCheckHour, 0)
    /// What the job's command line does once launched.
    var agent = FakeAgentRunner.Behavior.runsUntilTerminated
    /// What resolving `claude` in the login shell does.
    var resolve = DispatcherFixture.resolved
    /// The runs already stored.
    var runs: [Run] = []
    /// When the popover was last opened, as `UserDefaults` remembers it.
    var popoverSeenAt: Date?
    /// The user's notification permission.
    var authorization = NotificationAuthorizationState.authorized
    /// A change to the job before it is saved.
    var edit: ((inout Job) -> Void)?
}

/// An ``AppEnvironment`` over every port's fake, a scratch `UserDefaults`, a fixed UTC
/// calendar, and two manual clocks: the wall clock the app reads — which moves the fake
/// system events' clock with it, so an armed timer fires as time passes — and the one
/// the fake runner waits out timeouts on.
///
/// The job's directory is a real, empty temporary directory, because the dispatcher's
/// pre-flight and the fake runner both look for it; ``cleanUp()`` removes it.
@MainActor
final class AppEnvironmentFixture {
    nonisolated static let launchHour = 9
    nonisolated static let lastCheckHour = 8
    nonisolated static let secondsPerHour = 3_600
    nonisolated static let secondsPerDay: TimeInterval = 86_400

    let directory: URL
    let job: Job
    let jobStore: FakeJobStore
    let runStore: FakeRunStore
    let runner: FakeAgentRunner
    let events: FakeSystemEvents
    let preventer = FakeSleepPreventer()
    let notifier: FakeRunNotifier
    let loginItem = FakeLoginItem()
    let activation = FakeActivationPolicy()
    let wallClock: ManualClock
    /// What the fake runner waits out timeouts on, the agent check's included.
    let runnerClock: ManualClock
    let defaults: UserDefaults
    /// The fakes, as the environment was handed them.
    let ports: AppPorts
    let environment: AppEnvironment
    private let suiteName = "AgentCronTests-\(UUID().uuidString)"

    /// The final record of every run, oldest first: what History would show.
    var recorded: [Run] {
        runStore.runs
    }

    /// A fixture with every default.
    convenience init() {
        self.init(AppScenario())
    }

    init(_ scenario: AppScenario) {
        directory = DispatcherFixture.makeDirectory()
        job = Self.job(in: directory, scenario: scenario)
        jobStore = FakeJobStore(document: JobsDocument(
            jobs: [job],
            lastCheckedAt: scenario.lastCheckedAt,
        ))
        runStore = FakeRunStore(runs: scenario.runs)
        runnerClock = ManualClock(start: scenario.now)
        runner = FakeAgentRunner(
            behaviors: [
                DispatcherFixture.resolveArgv: scenario.resolve,
                DispatcherFixture.versionArgv: DispatcherFixture.exits(0, "2.1.0\n"),
            ],
            otherwise: scenario.agent,
            clock: runnerClock,
        )
        events = FakeSystemEvents(now: scenario.now)
        notifier = FakeRunNotifier(authorization: scenario.authorization, promptAnswer: .authorized)
        wallClock = ManualClock(start: scenario.now)
        defaults = UserDefaults(suiteName: suiteName) ?? .standard
        if let seen = scenario.popoverSeenAt {
            defaults.set(seen, forKey: PopoverModel.lastPopoverOpenedAtKey)
        }
        ports = AppPorts(
            runner: runner,
            systemEvents: events,
            sleepPreventer: preventer,
            notifier: notifier,
            lifecycle: AppLifecyclePorts(loginItem: loginItem, activationPolicy: activation),
        )
        environment = AppEnvironment(
            ports: ports,
            configuration: Self.configuration(
                stores: (jobStore, runStore),
                defaults: defaults,
                clock: wallClock,
            ),
        )
    }

    private static func job(in directory: URL, scenario: AppScenario) -> Job {
        var made = Job(
            name: "RSS digest",
            directory: directory,
            prompt: "Summarize today's feeds into news.html.",
            schedule: Schedule(
                weekdays: Set(Weekday.allCases),
                times: scenario.times.map { Fixture.time($0.0, $0.1) },
            ),
            createdAt: DispatcherFixture.at(lastCheckHour - 1, 0),
            id: Fixture.jobID,
        )
        scenario.edit?(&made)
        return made
    }

    private static func configuration(
        stores: (jobs: FakeJobStore, runs: FakeRunStore),
        defaults: UserDefaults,
        clock: ManualClock,
    ) -> AppConfiguration {
        let ids = SequentialIDs()
        return AppConfiguration(
            jobStore: stores.jobs,
            runStore: stores.runs,
            defaults: defaults,
            dispatch: DispatchEnvironment(
                calendar: DispatcherFixture.calendar,
                now: { clock.date },
                makeRunID: { ids.next() },
            ),
            clock: clock,
            locale: Locale(identifier: "en_US_POSIX"),
        )
    }

    /// Launches the app and waits for the work launch starts in the background.
    func launch() async {
        environment.launch()
        await environment.waitForPendingWork()
    }

    /// Moves the wall clock and the system events' clock forward together, firing the
    /// armed timer once its date is reached.
    func advance(hours: Int) {
        let duration = Duration.seconds(hours * Self.secondsPerHour)
        wallClock.advance(by: duration)
        events.advance(by: duration)
    }

    /// Lets the environment's tasks go until `condition` holds, and answers whether it
    /// did — as ``DispatcherFixture/until(_:)`` does, yielding rather than sleeping.
    func until(_ condition: () -> Bool) async -> Bool {
        for _ in 0 ..< DispatcherFixture.yieldLimit {
            if condition() {
                return true
            }
            await Task.yield()
        }
        return condition()
    }

    /// Lets every run and every piece of background work finish.
    func settle() async {
        await environment.dispatcher.waitForRuns()
        await environment.waitForPendingWork()
    }

    /// Stops every run still going, waits for the environment to settle, and removes the
    /// job's directory and the scratch defaults.
    func cleanUp() async {
        for run in environment.dispatcher.runningRuns {
            environment.stop(runID: run.id)
        }
        await settle()
        try? FileManager.default.removeItem(at: directory)
        defaults.removePersistentDomain(forName: suiteName)
    }
}
