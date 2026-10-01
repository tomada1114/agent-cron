import Foundation
import Observation

/// The menu-bar popover's model: today's timeline, the unseen failures since the popover
/// was last opened, the status item's symbol, and the keep-awake choice (plan P22,
/// `docs/product/ux-flows.md` S1, F4, F5).
///
/// "Seen up to" is remembered in `UserDefaults` under `lastPopoverOpenedAt`, a `Date` —
/// a contract key (ADR-0012). A failed, timed-out, or skipped run whose end is strictly
/// after it counts as unseen; while the key is absent, nothing does.
///
/// Running jobs and finished runs arrive through ``runningRunsChanged(to:)`` and
/// ``runFinished(_:)``, so the model depends on no scheduler. Keep-awake is
/// ``KeepAwakeController``'s: the model shows and drives it and keeps no copy.
@MainActor
@Observable
public final class PopoverModel {
    /// The `UserDefaults` key for when the popover was last opened.
    public static let lastPopoverOpenedAtKey = "lastPopoverOpenedAt"

    /// How far before `lastPopoverOpenedAt` runs are read: a run is stored by its start,
    /// and one started up to the longest timeout earlier can still end after the key.
    private static let secondsPerMinute = 60
    private static let secondsPerDay: TimeInterval = 86_400
    private static let unseenLookBack = TimeInterval(Job.timeoutMinutesRange
        .upperBound * secondsPerMinute)

    /// The saved jobs as last loaded.
    public private(set) var jobs: [Job] = []

    /// The runs read for today and since the popover was last opened, plus finished runs
    /// reported since.
    public private(set) var runs: [Run] = []

    /// The jobs running now, from the runs last reported running.
    public private(set) var runningJobIDs: Set<UUID> = []

    /// The runs last reported running, re-applied after a load: the dispatcher saves a
    /// run only after its agent pre-check, so the store can lag a just-started run.
    private var runningRuns: [Run] = []

    /// Whether the agent CLI was not found in the login shell, for the banner.
    public private(set) var isAgentMissing = false

    /// Why the last load failed at a store, or `nil` once one succeeds.
    public private(set) var storageError: StorageError?

    /// When the popover was last opened, or `nil` before the first time.
    public private(set) var lastPopoverOpenedAt: Date?

    /// The keep-awake controller the popover shows and drives.
    public let keepAwake: KeepAwakeController

    let calendar: Calendar
    let locale: Locale
    let now: @Sendable () -> Date
    private let jobStore: any JobStoring
    private let runStore: any RunStoring
    private let defaults: UserDefaults

    /// Failed, timed-out, and skipped runs that ended after ``lastPopoverOpenedAt``.
    public var unseenFailureCount: Int {
        guard let seen = lastPopoverOpenedAt else {
            return 0
        }
        return runs.count { run in
            [.failed, .timedOut, .skipped]
                .contains(run.outcome) && (run.endedAt ?? run.startedAt) > seen
        }
    }

    /// Whether the status item shows its failure dot.
    public var showsFailureDot: Bool {
        unseenFailureCount > 0
    }

    /// The status item's symbol: running > manual hold > idle.
    public var statusSymbol: PopoverStatusSymbol {
        if !runningJobIDs.isEmpty {
            return .running
        }
        return keepAwake.manualMode == .off ? .idle : .manualHold
    }

    /// The manual keep-awake choice in force.
    public var keepAwakeMode: KeepAwakeMode {
        keepAwake.manualMode
    }

    /// How long a timed keep-awake choice has left, or `nil` when none is in force.
    public var remainingKeepAwakeTime: Duration? {
        keepAwake.remainingManualTime
    }

    /// Makes the model. Reads the `lastPopoverOpenedAt` key and nothing else until
    /// ``load()``.
    /// - Parameters:
    ///   - calendar: The calendar, with its time zone, "today" and fire dates are read in.
    ///   - locale: The locale a day label inside an empty-state sentence is rendered in.
    public init(
        jobStore: any JobStoring,
        runStore: any RunStoring,
        keepAwake: KeepAwakeController,
        calendar: Calendar,
        defaults: UserDefaults = .standard,
        locale: Locale = .current,
        now: @escaping @Sendable () -> Date = { Date.now },
    ) {
        self.jobStore = jobStore
        self.runStore = runStore
        self.keepAwake = keepAwake
        self.defaults = defaults
        self.calendar = calendar
        self.locale = locale
        self.now = now
        lastPopoverOpenedAt = defaults.object(forKey: Self.lastPopoverOpenedAtKey) as? Date
    }

    /// Reads the saved jobs, today's runs, and the runs since the popover was last opened.
    /// A store that fails leaves its part empty; ``storageError`` says why. The runs last
    /// reported running stay, whether or not the store has them yet.
    public func load() {
        let date = now()
        let startOfToday = calendar.startOfDay(for: date)
        var start = startOfToday
        if let seen = lastPopoverOpenedAt {
            start = min(start, seen.addingTimeInterval(-Self.unseenLookBack))
        }
        let end = max(startOfTomorrow(after: date), date)
        storageError = nil
        do {
            jobs = try jobStore.load().jobs
        } catch {
            jobs = []
            storageError = error
            AppLog.storage
                .error("popover job load failed: \(String(describing: error), privacy: .public)")
        }
        do {
            runs = try runStore.runs(in: DateInterval(start: start, end: end))
        } catch {
            runs = []
            storageError = error
            AppLog.storage
                .error("popover run load failed: \(String(describing: error), privacy: .public)")
        }
        upsert(runningRuns)
    }

    /// The user opened the popover: everything up to now is seen, so
    /// `lastPopoverOpenedAt` becomes now, and the popover reloads.
    public func open() {
        let date = now()
        defaults.set(date, forKey: Self.lastPopoverOpenedAtKey)
        lastPopoverOpenedAt = date
        load()
    }

    /// The app saw the set of running runs change. Each run is upserted by identifier,
    /// so a run that started since the last ``load()`` shows at once.
    public func runningRunsChanged(to running: [Run]) {
        runningRuns = running
        runningJobIDs = Set(running.map(\.jobID))
        upsert(running)
    }

    private func upsert(_ upserted: [Run]) {
        for run in upserted {
            runs.removeAll { $0.id == run.id }
            runs.append(run)
        }
    }

    /// A run started or ended; it replaces any run with the same identifier.
    public func runFinished(_ run: Run) {
        runs.removeAll { $0.id == run.id }
        runs.append(run)
    }

    /// The app checked whether the agent CLI resolves in the login shell.
    public func agentAvailabilityChanged(_ availability: AgentAvailability) {
        isAgentMissing = availability == .notFound
    }

    /// The user chose a keep-awake mode in the popover.
    public func chooseKeepAwake(_ mode: KeepAwakeMode) {
        keepAwake.chooseManualMode(mode)
    }

    func startOfTomorrow(after date: Date) -> Date {
        let today = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today
            .addingTimeInterval(Self.secondsPerDay)
    }
}
