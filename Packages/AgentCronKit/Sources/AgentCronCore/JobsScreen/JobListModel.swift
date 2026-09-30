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

    /// Where the user asked to go while the editor held unsaved edits: the
    /// unsaved-changes alert shows until ``unsavedChangesSaved()``,
    /// ``unsavedChangesDiscarded()``, or ``unsavedChangesCancelled()`` answers it.
    public private(set) var pendingSelection: JobListTarget?

    /// Whether ``jobs`` is what the store holds. False after a failed read, when the saved
    /// jobs are unknown rather than gone, so a remembered selection must not be cleared
    /// on their account.
    public private(set) var areJobsKnown = true

    /// The delete alert waiting for the user's answer (`docs/product/ux-flows.md` S5),
    /// or `nil` when none shows.
    public private(set) var pendingDeletion: JobDeleteConfirmation?

    private let store: any JobStoring
    /// The calendar schedules are read in, which the rows' status lines use too.
    let calendar: Calendar
    /// The time the rows are read against.
    let now: @Sendable () -> Date
    private let directoryExists: @Sendable (URL) -> Bool

    /// The identifiers of the saved jobs, for ``MainNavigationModel/knownJobsChanged(to:)``
    /// while ``areJobsKnown``.
    public var jobIDs: Set<UUID> {
        Set(jobs.map(\.id))
    }

    /// The row of the selected saved job, which the editor's header reads its status
    /// from, or `nil` for none or a new draft.
    public var selectedRow: JobListRow? {
        guard let selectedJobID, let job = jobs.first(where: { $0.id == selectedJobID }) else {
            return nil
        }
        return row(for: job, at: now())
    }

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
    /// until ``load()``. `directoryExists` is handed to every editor it opens
    /// (``JobEditorModel/isDirectoryMissing``).
    public init(
        store: any JobStoring,
        calendar: Calendar,
        now: @escaping @Sendable () -> Date = { Date.now },
        directoryExists: @escaping @Sendable (URL) -> Bool = JobEditorModel.folderExists,
    ) {
        self.store = store
        self.calendar = calendar
        self.now = now
        self.directoryExists = directoryExists
    }

    /// Reads the saved jobs. On failure the list is empty, since what was shown may no
    /// longer match the file, and ``storageError`` says why; nothing stays selected
    /// unless the editor holds unsaved edits, which a failed read never throws away.
    public func load() {
        do {
            jobs = try store.load().jobs
            storageError = nil
            areJobsKnown = true
        } catch {
            jobs = []
            storageError = error
            areJobsKnown = false
            AppLog.storage
                .error("job list load failed: \(String(describing: error), privacy: .public)")
            if editor?.isEdited == true {
                return
            }
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
        let opened = JobEditorModel(
            editing: job,
            store: store,
            now: now,
            saved: { [weak self] document in
                self?.editorSaved(document, jobID: jobID)
            },
            directoryExists: directoryExists,
        )
        opened.runningStateChanged(isRunning: runningJobIDs.contains(jobID))
        editor = opened
    }

    /// The user asked for a new job: the detail pane shows an empty draft, and the list
    /// selects it once it is saved.
    public func newJob() {
        let id = UUID()
        selectedJobID = nil
        editor = JobEditorModel(
            newJobWithID: id,
            store: store,
            now: now,
            saved: { [weak self] document in
                self?.editorSaved(document, jobID: id)
            },
            directoryExists: directoryExists,
        )
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
            areJobsKnown = true
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

    // MARK: - Leaving unsaved edits

    /// The Jobs screen appeared: reads the saved jobs, then goes to `jobID` — the
    /// navigation's remembered selection — unless the editor already shows it. Going
    /// elsewhere asks first when there are unsaved edits, as any selection does.
    public func screenAppeared(restoringSelection jobID: UUID?) {
        load()
        guard jobID != selectedJobID || editor == nil else {
            return
        }
        selectionRequested(jobID: jobID)
    }

    /// The user picked a row in the list, or cleared the selection with `nil`. With
    /// unsaved edits the editor stays and ``pendingSelection`` asks first
    /// (`docs/design/ux-guidelines.md` › Feedback and loading).
    public func selectionRequested(jobID: UUID?) {
        go(to: jobID.map(JobListTarget.job) ?? .nothing)
    }

    /// The user asked for a new job (New Job, ⌘N); with unsaved edits,
    /// ``pendingSelection`` asks first.
    public func newJobRequested() {
        go(to: .newJob)
    }

    /// The user chose Save in the unsaved-changes alert: the draft is saved and the
    /// pending selection follows. A save that is refused keeps the editor and drops the
    /// pending selection, so the errors show where the user can fix them.
    /// - Returns: What the save did, or `nil` when nothing was pending.
    @discardableResult
    public func unsavedChangesSaved() -> JobEditorSaveResult? {
        guard let target = pendingSelection, let editor else {
            pendingSelection = nil
            return nil
        }
        let result = editor.save()
        guard result == .saved else {
            pendingSelection = nil
            return result
        }
        apply(target)
        return result
    }

    /// The user chose Don't Save: the edits are thrown away and the pending selection
    /// follows.
    public func unsavedChangesDiscarded() {
        guard let target = pendingSelection else {
            return
        }
        editor?.revert()
        apply(target)
    }

    /// The user chose Cancel: the editor stays as it was, edits and all.
    public func unsavedChangesCancelled() {
        pendingSelection = nil
    }

    // MARK: - Deleting

    /// The user asked to delete the saved job `jobID` (Delete Job…, or Job › Delete…):
    /// ``pendingDeletion`` asks first. Nothing shows for a job that is not saved.
    public func deleteRequested(jobID: UUID) {
        pendingDeletion = deleteConfirmation(forJobID: jobID)
    }

    /// The user confirmed the pending deletion.
    public func deletionConfirmed() {
        guard let pending = pendingDeletion else {
            return
        }
        pendingDeletion = nil
        delete(jobID: pending.jobID)
    }

    /// The user cancelled the pending deletion.
    public func deletionCancelled() {
        pendingDeletion = nil
    }

    // MARK: - Menu commands

    /// A main-menu command reached the Jobs screen through
    /// ``MainNavigationModel/pendingJobsScreenRequest``. Enable / Disable edits the
    /// open editor's draft, like the header's switch, and applies on save.
    public func menuCommandRequested(_ command: JobsScreenCommand) {
        switch command {
        case .newJob:
            newJobRequested()

        case let .delete(jobID):
            deleteRequested(jobID: jobID)

        case let .toggleEnabled(jobID):
            guard let editor, editor.draft.id == jobID else {
                return
            }
            editor.enabledChanged(to: !editor.draft.enabled)
        }
    }

    // MARK: - Private

    private func go(to target: JobListTarget) {
        if case let .job(jobID) = target, jobID == selectedJobID, editor != nil {
            pendingSelection = nil
            return
        }
        guard let editor, editor.isEdited else {
            apply(target)
            return
        }
        pendingSelection = target
    }

    private func apply(_ target: JobListTarget) {
        pendingSelection = nil
        switch target {
        case let .job(jobID):
            select(jobID: jobID)

        case .newJob:
            newJob()

        case .nothing:
            select(jobID: nil)
        }
    }

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
        areJobsKnown = true
        selectedJobID = jobID
    }
}
