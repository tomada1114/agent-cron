import Foundation
import Observation

/// One row of the Jobs screen's list (`docs/product/ux-flows.md` S2).
public struct JobListRow: Sendable, Identifiable {
    /// The job's identifier.
    public let id: UUID
    /// The job's name.
    public let name: String
    /// Whether the scheduler fires the job; a paused job sorts last.
    public let isEnabled: Bool
    /// Whether the job is running now.
    public let isRunning: Bool
    /// Whether the job skips every permission check, which the row badges.
    public let usesBypassPermissions: Bool
    /// When the job next fires, or `nil` when it is paused or its schedule never fires.
    public let nextRun: Date?
    /// The schedule shortened for the row, "Weekdays 09:00 +2", or `nil` when it has no
    /// day or no time.
    public let scheduleSummary: LocalizedStringResource?
}

/// The Jobs screen's list and selection: the saved jobs, sorted by when they next run,
/// and the ``JobEditorModel`` for the selected job or a new draft.
///
/// Every write reads the store afresh and never writes over a document that could not be
/// read (``JobStoring``'s rule for a corrupt or newer `jobs.json`); a failure is kept in
/// ``storageError`` for the view to report, and the list keeps what it last showed.
@MainActor
@Observable
public final class JobListModel {
    /// The saved jobs, in the store's order, as last loaded or written.
    public private(set) var jobs: [Job] = []

    /// Why the last load, save, or delete failed at the store, or `nil` once one
    /// succeeds.
    public private(set) var storageError: StorageError?

    /// The jobs that are running, as last reported by ``runningJobsChanged(to:)``.
    public private(set) var runningJobIDs: Set<UUID> = []

    /// The saved job the detail pane shows, or `nil` for none or a new draft.
    public private(set) var selectedJobID: UUID?

    /// The editor the detail pane shows: over the selected job, over a new draft after
    /// ``newJob()``, or `nil` when nothing is selected.
    public private(set) var editor: JobEditorModel?

    private let store: any JobStoring
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    /// The rows the list shows: enabled jobs by their next run, earliest first, then any
    /// enabled job that never fires, then paused jobs; jobs that tie keep the store's
    /// order.
    ///
    /// Read from `now` at the moment of asking; observation does not tick with the
    /// clock, so a view showing next runs re-reads it on its own schedule.
    public var rows: [JobListRow] {
        let date = now()
        let ranked = jobs.enumerated().map { index, job in
            let row = row(for: job, at: date)
            // Enabled before paused; among enabled, a next run before none.
            let group = (row.isEnabled ? 0 : 1, row.nextRun == nil ? 1 : 0)
            return (row: row, group: group, index: index)
        }
        let sorted = ranked.sorted { lhs, rhs in
            if lhs.group != rhs.group {
                return lhs.group < rhs.group
            }
            if let left = lhs.row.nextRun, let right = rhs.row.nextRun, left != right {
                return left < right
            }
            return lhs.index < rhs.index
        }
        return sorted.map(\.row)
    }

    /// Makes a list over `store`, reading schedules in `calendar` (whose time zone is the
    /// one fire dates are computed in) against the time `now` answers. Reads nothing
    /// until ``load()``.
    public init(
        store: any JobStoring,
        calendar: Calendar,
        now: @escaping @Sendable () -> Date = { Date.now },
    ) {
        self.store = store
        self.calendar = calendar
        self.now = now
    }

    /// Reads the saved jobs. On failure the list is empty and nothing is selected, since
    /// what was shown may no longer match the file; ``storageError`` says why.
    public func load() {
        do {
            jobs = try store.load().jobs
            storageError = nil
        } catch {
            jobs = []
            storageError = error
            AppLog.storage
                .error("job list load failed: \(String(describing: error), privacy: .public)")
        }
        if let selectedJobID, !jobs.contains(where: { $0.id == selectedJobID }) {
            select(jobID: nil)
        }
    }

    /// The user selected a job in the list, or cleared the selection with `nil`.
    ///
    /// Selecting the job already selected keeps its editor and draft. Asking whether to
    /// save unsaved edits first is the view's, from ``JobEditorModel/isEdited``.
    public func select(jobID: UUID?) {
        if jobID != nil, jobID == selectedJobID, editor != nil {
            return
        }
        guard let jobID, let job = jobs.first(where: { $0.id == jobID }) else {
            selectedJobID = nil
            editor = nil
            return
        }
        selectedJobID = jobID
        let opened = JobEditorModel(editing: job, store: store, now: now) { [weak self] document in
            self?.editorSaved(document, jobID: jobID)
        }
        opened.runningStateChanged(isRunning: runningJobIDs.contains(jobID))
        editor = opened
    }

    /// The user asked for a new job: the detail pane shows an empty draft, and the list
    /// selects it once it is saved.
    public func newJob() {
        let id = UUID()
        selectedJobID = nil
        editor = JobEditorModel(newJobWithID: id, store: store, now: now) { [weak self] document in
            self?.editorSaved(document, jobID: id)
        }
    }

    /// The app saw the set of running jobs change.
    public func runningJobsChanged(to jobIDs: Set<UUID>) {
        runningJobIDs = jobIDs
        if let editor {
            editor.runningStateChanged(isRunning: jobIDs.contains(editor.draft.id))
        }
    }

    /// The alert that confirms deleting the saved job `jobID`, or `nil` when no saved job
    /// has that identifier.
    public func deleteConfirmation(forJobID jobID: UUID) -> JobDeleteConfirmation? {
        guard let job = jobs.first(where: { $0.id == jobID }) else {
            return nil
        }
        return JobDeleteConfirmation(job: job, isRunning: runningJobIDs.contains(jobID))
    }

    /// The user confirmed deleting `jobID`: it is removed from the store, and from the
    /// selection when selected. Its runs stay in History. Stopping a running job is the
    /// runner's, not this model's.
    public func delete(jobID: UUID) {
        do {
            jobs = try store.updateJobs { $0.removeAll { $0.id == jobID } }.jobs
            storageError = nil
        } catch {
            storageError = error
            AppLog.storage
                .error("job delete failed: \(String(describing: error), privacy: .public)")
            return
        }
        if selectedJobID == jobID {
            select(jobID: nil)
        }
    }

    // MARK: - Private

    private func row(for job: Job, at date: Date) -> JobListRow {
        let nextRun = job.enabled
            ? ScheduleCalendar(schedule: job.schedule, calendar: calendar).nextFireDate(after: date)
            : nil
        return JobListRow(
            id: job.id,
            name: job.name,
            isEnabled: job.enabled,
            isRunning: runningJobIDs.contains(job.id),
            usesBypassPermissions: job.permissionMode == .bypassPermissions,
            nextRun: nextRun,
            scheduleSummary: job.schedule.compactSummary,
        )
    }

    private func editorSaved(_ document: JobsDocument, jobID: UUID) {
        jobs = document.jobs
        storageError = nil
        selectedJobID = jobID
    }
}
