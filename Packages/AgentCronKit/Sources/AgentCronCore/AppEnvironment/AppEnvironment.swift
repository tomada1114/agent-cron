import Foundation
import Observation

/// The app's object graph and the wiring between its parts (issue #28,
/// `docs/architecture.md` › AgentCron on these layers › Core flows).
///
/// `App/` — the composition root — builds the `AgentCronPlatform` adapters, hands them in
/// as ``AppPorts``, calls ``launch()`` once, and renders the models below. Everything that
/// decides how the parts talk lives here, where the coverage floor sees it:
///
/// - The ``Dispatcher``'s running set drives ``KeepAwakeController``, the popover, the
///   Jobs screen, and History; each finished run goes to the popover, History, and
///   ``RunNotificationController``, and each check's missed times to the latter once.
/// - Every ``SystemEvent`` but ``SystemEvent/willSleep`` checks the schedule and arms the
///   timer again for the earliest next fire date, and so does every save of the jobs.
/// - A notification click opens the main window on History with that run selected.
/// - Jobs that cannot be read at launch stop the scheduler before it starts: nothing
///   writes the file, ``launchError`` says why, and ``tryAgain()`` reads it again.
///
/// Opening a window is something only SwiftUI can do, so this asks for it through
/// ``isMainWindowRequested`` and a view answers with ``mainWindowRequestHandled()``.
@MainActor
@Observable
public final class AppEnvironment {
    /// The longest the timer is ever armed for: with no job due sooner, it still fires
    /// daily, so History's retention sweep runs even when nothing else happens.
    public static let longestTimerWait: TimeInterval = 86_400

    /// Where the main window is; the main menu acts on it while the window is closed.
    public let navigation: MainNavigationModel
    /// The scheduler.
    public let dispatcher: Dispatcher
    /// The one idle-sleep assertion.
    public let keepAwake: KeepAwakeController
    /// Which finished runs notify, and the authorization the Jobs screen notes.
    public let notifications: RunNotificationController
    /// The popover and the status item.
    public let popover: PopoverModel
    /// The Jobs screen, alive as long as the app so an unsaved draft outlives the window.
    public let jobList: JobListModel
    /// The History screen.
    public let history: HistoryModel
    /// The General screen.
    public let general: GeneralModel
    /// Launch at login and the Dock icon while the main window is open.
    public let lifecycle: AppLifecycleModel

    /// Why the saved jobs could not be read at launch, while the scheduler waits for
    /// ``tryAgain()``; `nil` once they were read.
    public private(set) var launchError: StorageError?

    /// Whether the scheduler has started: the jobs were read at launch and the timer armed.
    public private(set) var isSchedulerRunning = false

    /// Whether something asked for the main window and no view has opened it yet.
    public private(set) var isMainWindowRequested = false

    @ObservationIgnored private var hasLaunched = false
    @ObservationIgnored var eventLoop: Task<Void, Never>?
    @ObservationIgnored private var work: [Int: Task<Void, Never>] = [:]
    @ObservationIgnored private var nextWorkID = 0

    let jobStore: any JobStoring
    let systemEvents: any SystemEventsProviding
    let calendar: Calendar
    let now: @Sendable () -> Date
    private let notifier: any RunNotifying

    /// Builds the graph over `ports`, with `jobs.json` and the run files in the data root
    /// (`StorageLocation.root()`, ADR-0005). Reads, starts, and asks nothing until
    /// ``launch()``.
    public convenience init(ports: AppPorts) {
        self.init(ports: ports, configuration: .files())
    }

    /// Builds the graph over `ports` and `configuration`. Reads, starts, and asks nothing
    /// until ``launch()``.
    public init(ports: AppPorts, configuration: AppConfiguration) {
        let dispatch = configuration.dispatch
        jobStore = configuration.jobStore
        systemEvents = ports.systemEvents
        notifier = ports.notifier
        calendar = dispatch.calendar
        now = dispatch.now
        navigation = MainNavigationModel(defaults: configuration.defaults)
        dispatcher = configuration.makeDispatcher(runner: ports.runner)
        keepAwake = KeepAwakeController(
            preventer: ports.sleepPreventer,
            clock: configuration.clock,
            now: dispatch.now,
        )
        notifications = RunNotificationController(
            notifier: ports.notifier,
            locale: configuration.locale,
            calendar: dispatch.calendar,
        )
        popover = configuration.makePopover(keepAwake: keepAwake)
        jobList = JobListModel(
            store: configuration.jobStore,
            calendar: dispatch.calendar,
            now: dispatch.now,
        )
        history = configuration.makeHistory()
        general = GeneralModel(
            loginItem: ports.lifecycle.loginItem,
            checker: AgentAvailabilityChecker(runner: ports.runner),
            clock: configuration.clock,
        )
        lifecycle = AppLifecycleModel(
            loginItem: ports.lifecycle.loginItem,
            activationPolicy: ports.lifecycle.activationPolicy,
            defaults: configuration.defaults,
        )
    }

    // MARK: - Launch

    /// The app is launching: routes notification clicks, registers the login item on the
    /// first launch, connects the parts, and starts the scheduler — unless the saved jobs
    /// cannot be read, which ``launchError`` then reports. A second call does nothing.
    ///
    /// The click handler is set first, so a click that launched the app is not lost
    /// (``RunNotifying/setClickHandler(_:)``).
    public func launch() {
        guard !hasLaunched else {
            return
        }
        hasLaunched = true
        notifier.setClickHandler { [weak self] runID in
            Task { @MainActor in
                self?.notificationClicked(runID: runID)
            }
        }
        connect()
        lifecycle.appLaunched()
        startScheduler()
    }

    /// The user chose Try Again in the unreadable-jobs alert: the alert closes and the
    /// jobs are read again on the next turn, so a file still unreadable shows the alert
    /// anew rather than leaving the old one in place. Once they read, the Jobs screen —
    /// already open behind the alert, and so not appearing again to load — reads them
    /// too, replacing the error it showed.
    public func tryAgain() {
        guard launchError != nil else {
            return
        }
        launchError = nil
        perform { environment in
            environment.startScheduler()
            if environment.isSchedulerRunning {
                environment.jobList.load()
            }
        }
    }

    // MARK: - User actions

    /// The user chose Run Now for `jobID` (the Job menu, ⌘R).
    public func runNow(jobID: UUID) {
        dispatcher.runNow(jobID: jobID)
    }

    /// The user chose Stop on the run `runID` (History's detail).
    public func stop(runID: UUID) {
        dispatcher.stop(runID: runID)
    }

    /// The user chose Stop on the job `jobID` (a popover row, the Job menu, ⌘.): its run,
    /// if one is going, is stopped without asking.
    public func stopJob(jobID: UUID) {
        for run in dispatcher.runningRuns where run.jobID == jobID {
            dispatcher.stop(runID: run.id)
        }
    }

    /// The user clicked the notification about `runID`: the main window opens on History
    /// with that run selected (requirements §3.5, `docs/product/ux-flows.md` F4).
    public func notificationClicked(runID: UUID) {
        navigation.select(section: .history)
        navigation.select(runID: runID)
        history.select(runID: runID)
        isMainWindowRequested = true
        AppLog.notifications.info("notification clicked: opening History")
    }

    /// A view opened the main window this asked for.
    public func mainWindowRequestHandled() {
        isMainWindowRequested = false
    }

    /// The main window opened: the app shows its Dock icon and main menu, History reads
    /// the runs afresh, and the notification authorization is read again, since it may
    /// have changed in System Settings.
    public func mainWindowOpened() {
        lifecycle.mainWindowOpened()
        reloadHistory()
        perform { environment in
            await environment.notifications.refreshAuthorization()
        }
    }

    /// The main window closed: the app is only a status item again.
    public func mainWindowClosed() {
        lifecycle.mainWindowClosed()
    }

    /// Returns once the work this environment started in the background — notifications,
    /// the agent check, a retried launch — has finished. For tests.
    package func waitForPendingWork() async {
        while let task = work.values.first {
            await task.value
        }
    }

    /// Runs `operation` on a later turn of the main actor, tracked so a test can wait for
    /// it.
    func perform(_ operation: @escaping @MainActor (AppEnvironment) async -> Void) {
        nextWorkID += 1
        let id = nextWorkID
        work[id] = Task { [weak self] in
            if let self {
                await operation(self)
                work[id] = nil
            }
        }
    }

    // MARK: - Private

    private func startScheduler() {
        guard !isSchedulerRunning else {
            return
        }
        let document: JobsDocument
        do {
            document = try jobStore.load()
        } catch {
            launchError = error
            isMainWindowRequested = true
            AppLog.storage.error(
                "jobs unreadable at launch, scheduler held: \(String(describing: error), privacy: .public)",
            )
            return
        }
        launchError = nil
        isSchedulerRunning = true
        let date = now()
        dispatcher.recoverInterruptedRuns(now: date)
        history.jobsChanged(to: document.jobs)
        history.sweepIfDue()
        history.reload()
        popover.load()
        listenToSystemEvents()
        dispatcher.didWake(now: date)
        armTimer()
        perform { environment in
            await environment.notifications.refreshAuthorization()
        }
        perform { environment in
            await environment.checkAgent()
        }
        AppLog.scheduler.info("scheduler started")
    }

    private func checkAgent() async {
        await general.checkAgain()
        if let agent = general.agent {
            popover.agentAvailabilityChanged(agent)
        }
    }
}
