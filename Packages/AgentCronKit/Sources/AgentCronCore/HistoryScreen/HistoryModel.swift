import Foundation
import Observation

/// The History screen's model (`docs/product/ux-flows.md` S3): stored runs newest first
/// in day groups, the job and outcome filters, the selected run's detail, and the 90-day
/// retention sweep (`docs/product/requirements.md` §3.4).
///
/// A store failure is kept in ``storageError`` for the view to report; the list keeps
/// what it last showed.
@MainActor
@Observable
public final class HistoryModel {
    /// How long a run is kept, in days.
    public static let retentionDays = 90

    /// Every run loaded, newest first.
    public private(set) var runs: [Run] = []

    /// Why the last read or sweep failed at the store, or `nil` once one succeeds.
    public private(set) var storageError: StorageError?

    /// The job whose runs show, or `nil` for every job.
    public var jobFilter: UUID?

    /// Which outcomes show.
    public var outcomeFilter: HistoryOutcomeFilter = .all

    /// The run the detail pane shows — the value `MainNavigationModel.selectedRunID`
    /// mirrors.
    public private(set) var selectedRunID: UUID?

    /// When the last successful sweep ran, or `nil` before the first.
    public private(set) var lastSweepAt: Date?

    /// The saved jobs as last reported; meaningful only once `jobsKnown`.
    private var liveJobs: [Job] = []
    private var jobsKnown = false
    private let store: any RunStoring
    private let calendar: Calendar
    private let locale: Locale
    private let now: @Sendable () -> Date

    // MARK: - Reading

    /// The runs passing both filters, grouped by the day they started, newest day first.
    public var groups: [HistoryDayGroup] {
        let date = now()
        let visible = runs.filter { run in
            (jobFilter == nil || run.jobID == jobFilter) && outcomeFilter.includes(run.outcome)
        }
        var order: [Date] = []
        var byDay: [Date: [HistoryRow]] = [:]
        for run in visible {
            let day = calendar.startOfDay(for: run.startedAt)
            if byDay[day] == nil {
                order.append(day)
            }
            byDay[day, default: []].append(row(for: run))
        }
        return order.map { day in
            HistoryDayGroup(
                id: day,
                title: HistoryFormatting.dayTitle(
                    day,
                    now: date,
                    calendar: calendar,
                    locale: locale,
                ),
                rows: byDay[day] ?? [],
            )
        }
    }

    /// Why the list is empty, or `nil` when it shows runs.
    public var emptyState: HistoryEmptyState? {
        if runs.isEmpty {
            return .noRuns
        }
        return groups.isEmpty ? .noMatches : nil
    }

    /// The jobs the job filter offers: existing jobs by name, then deleted jobs that
    /// still have runs, by name.
    public var jobFilterOptions: [HistoryJobFilterOption] {
        var options: [UUID: HistoryJobFilterOption] = [:]
        for run in runs where options[run.jobID] == nil {
            // `runs` is newest first, so the first name seen is the latest.
            options[run.jobID] = HistoryJobFilterOption(
                id: run.jobID,
                name: run.jobName,
                isDeleted: jobsKnown,
            )
        }
        for job in liveJobs {
            options[job.id] = HistoryJobFilterOption(id: job.id, name: job.name, isDeleted: false)
        }
        return options.values.sorted { lhs, rhs in
            if lhs.isDeleted != rhs.isDeleted {
                return !lhs.isDeleted
            }
            let order = lhs.name.localizedStandardCompare(rhs.name)
            return order == .orderedSame ? lhs.id.uuidString < rhs.id.uuidString
                : order == .orderedAscending
        }
    }

    /// The selected run's detail, or `nil` when nothing is selected or the run is gone.
    public var detail: HistoryRunDetail? {
        guard let selectedRunID, let run = runs.first(where: { $0.id == selectedRunID }) else {
            return nil
        }
        return HistoryRunDetail(
            run: run,
            badge: OutcomeBadgeKind(run.outcome),
            trigger: HistoryFormatting.trigger(run.trigger),
            duration: duration(of: run),
            cost: run.costUSD.map { HistoryFormatting.cost($0, locale: locale) },
        )
    }

    /// Makes a model over `store`, grouping days in `calendar` (and its time zone),
    /// formatting in `locale`, against the time `now` answers. Reads nothing until
    /// ``reload()``.
    public init(
        store: any RunStoring,
        calendar: Calendar,
        locale: Locale,
        now: @escaping @Sendable () -> Date = { Date.now },
    ) {
        self.store = store
        self.calendar = calendar
        self.locale = locale
        self.now = now
    }

    private static func newestFirst(_ runs: [Run]) -> [Run] {
        runs.sorted { lhs, rhs in
            (lhs.startedAt, lhs.id.uuidString) > (rhs.startedAt, rhs.id.uuidString)
        }
    }

    // MARK: - Actions

    /// Reads the runs of the retention window from the store.
    public func reload() {
        let date = now()
        let start = retentionCutoff(at: date)
        do {
            let loaded = try store.runs(in: DateInterval(start: start, end: .distantFuture))
            runs = Self.newestFirst(loaded)
            storageError = nil
        } catch {
            storageError = error
            AppLog.storage
                .error("history load failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// A run was saved — started, or finished — so the list shows it without a reload.
    public func runRecorded(_ run: Run) {
        runs.removeAll { $0.id == run.id }
        runs.append(run)
        runs = Self.newestFirst(runs)
    }

    /// The saved jobs changed; any run whose job is not among `jobs` is a deleted job's.
    public func jobsChanged(to jobs: [Job]) {
        liveJobs = jobs
        jobsKnown = true
    }

    /// The user selected a run, or cleared the selection with `nil`.
    public func select(runID: UUID?) {
        selectedRunID = runID
    }

    /// Deletes runs older than ``retentionDays`` when no sweep has run yet or a day has
    /// passed since the last one — call it on launch and on a timer. Returns whether it
    /// swept.
    @discardableResult
    public func sweepIfDue() -> Bool {
        let date = now()
        let due = lastSweepAt.flatMap { calendar.date(byAdding: .day, value: 1, to: $0) }
        if let due, date < due {
            return false
        }
        do {
            let removed = try store.deleteRuns(olderThan: retentionCutoff(at: date))
            lastSweepAt = date
            storageError = nil
            if removed > 0 {
                runs.removeAll { $0.startedAt < retentionCutoff(at: date) }
            }
            return true
        } catch {
            storageError = error
            AppLog.storage
                .error("history sweep failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    // MARK: - Private

    private func retentionCutoff(at date: Date) -> Date {
        calendar.date(byAdding: .day, value: -Self.retentionDays, to: date)
            // A cutoff that cannot be computed deletes nothing rather than everything.
            ?? .distantPast
    }

    private func row(for run: Run) -> HistoryRow {
        HistoryRow(
            id: run.id,
            jobID: run.jobID,
            jobName: run.jobName,
            startedAt: run.startedAt,
            badge: OutcomeBadgeKind(run.outcome),
            duration: duration(of: run),
        )
    }

    private func duration(of run: Run) -> LocalizedStringResource? {
        run.endedAt.map { HistoryFormatting.duration(from: run.startedAt, to: $0) }
    }
}
