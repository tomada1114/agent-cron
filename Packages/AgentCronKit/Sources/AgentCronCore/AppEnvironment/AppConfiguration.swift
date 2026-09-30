import Foundation

/// What ``AppEnvironment`` reads from the world rather than deciding: where jobs and runs
/// are kept, where settings are remembered, and the time, calendar, and language
/// (`designing-core-logic` › Inject time). The app uses ``files(at:)``; a test passes
/// fakes, a scratch `UserDefaults`, and manual clocks.
public struct AppConfiguration {
    /// The jobs document the scheduler, the Jobs screen, and the popover share.
    public let jobStore: any JobStoring
    /// The run records History, the popover, and the scheduler share.
    public let runStore: any RunStoring
    /// Where navigation, the popover's "seen up to", and the first-launch flag live.
    public let defaults: UserDefaults
    /// The calendar schedules are read in, the time, and each new run's identity.
    public let dispatch: DispatchEnvironment
    /// What keep-awake's timed choice and General's spinner wait on.
    public let clock: any Clock<Duration>
    /// The language dates and costs are formatted in.
    public let locale: Locale

    /// Makes a configuration; everything but the stores defaults to the real thing.
    public init(
        jobStore: any JobStoring,
        runStore: any RunStoring,
        defaults: UserDefaults = .standard,
        dispatch: DispatchEnvironment = .live,
        clock: any Clock<Duration> = ContinuousClock(),
        locale: Locale = .autoupdatingCurrent,
    ) {
        self.jobStore = jobStore
        self.runStore = runStore
        self.defaults = defaults
        self.dispatch = dispatch
        self.clock = clock
        self.locale = locale
    }

    /// The app's own configuration: `jobs.json` and the run files in `root`, standard
    /// defaults, the system calendar and time, and a continuous clock that keeps counting
    /// while the Mac sleeps.
    public static func files(at root: URL = StorageLocation.root()) -> Self {
        Self(jobStore: FileJobStore(root: root), runStore: FileRunStore(root: root))
    }
}

/// The models whose every input is in the configuration, built the one way the app uses.
extension AppConfiguration {
    @MainActor
    func makeDispatcher(runner: any AgentRunning) -> Dispatcher {
        Dispatcher(
            jobStore: jobStore,
            runStore: runStore,
            runner: runner,
            availability: AgentAvailabilityChecker(runner: runner),
            environment: dispatch,
        )
    }

    @MainActor
    func makePopover(keepAwake: KeepAwakeController) -> PopoverModel {
        PopoverModel(
            jobStore: jobStore,
            runStore: runStore,
            keepAwake: keepAwake,
            calendar: dispatch.calendar,
            defaults: defaults,
            locale: locale,
            now: dispatch.now,
        )
    }

    @MainActor
    func makeHistory() -> HistoryModel {
        HistoryModel(
            store: runStore,
            calendar: dispatch.calendar,
            locale: locale,
            now: dispatch.now,
        )
    }
}
