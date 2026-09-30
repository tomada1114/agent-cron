import Foundation
import Observation

/// The job editor behind the Jobs screen's detail pane: a draft that is written to the
/// store only on an explicit ``save()`` (`docs/design/ux-guidelines.md` › Feedback and
/// loading), so a half-typed job never fires.
///
/// Every edit is an action named for what the user did; the draft, its errors, and the
/// pending bypass confirmation are read-only state a view renders. Validation follows
/// the guidelines' timing: a field is checked when focus leaves it
/// (``fieldLostFocus(_:)``), a field showing an error is checked again on every change so
/// the error clears as soon as it is fixed, and ``save()`` checks every field. The rules
/// themselves are ``Job/validate()``'s.
@MainActor
@Observable
public final class JobEditorModel {
    /// What a new draft's folder starts as: not a file URL, so ``Job/validate()`` reports
    /// ``JobValidationError/directoryNotLocal`` ("Choose a folder on this Mac.") until one
    /// is chosen. `URL(string:)` accepts the literal, so the fallback is never taken; a
    /// test of a new draft's errors fails if it ever were.
    private static let unchosenDirectory = URL(string: "about:blank") ?? URL(filePath: "/")

    /// The job as edited so far — what ``save()`` would write.
    public private(set) var draft: Job

    /// Whether the draft is a job the store has never held. A new job can be saved
    /// without an edit; it is not ``isEdited`` until it differs from how it started.
    public private(set) var isNew: Bool

    /// The error each field shows, at most one per field; a field without an entry shows
    /// none.
    public private(set) var errors: [JobEditorField: JobValidationError] = [:]

    /// Whether `bypassPermissions` was chosen and waits for the user to confirm it
    /// (`docs/product/ux-flows.md` S6). The draft keeps its previous mode until
    /// ``bypassConfirmed()``.
    public private(set) var isConfirmingBypass = false

    /// Whether the job is running, as last reported by ``runningStateChanged(isRunning:)``.
    public private(set) var isRunning = false

    /// Why the last save failed at the store, or `nil` once one succeeds.
    public private(set) var storageError: StorageError?

    /// The job as last saved, or the draft as it started for a new job — what
    /// ``revert()`` returns to and ``isEdited`` compares against.
    private var baseline: Job

    private let store: any JobStoring
    private let now: @Sendable () -> Date
    private let saved: (@MainActor (JobsDocument) -> Void)?

    /// Whether the draft differs from the saved job: the editor shows "Edited", and
    /// Revert and Save are enabled.
    public var isEdited: Bool {
        draft != baseline
    }

    /// Whether Save is enabled: while there are edits, and always for a new job.
    public var canSave: Bool {
        isNew || isEdited
    }

    /// The folder the draft runs in, or `nil` while a new job has none chosen yet.
    public var chosenDirectory: URL? {
        draft.directory.isFileURL ? draft.directory : nil
    }

    /// Whether the draft skips every permission check, which the editor warns about
    /// under the Permission row.
    public var usesBypassPermissions: Bool {
        draft.permissionMode == .bypassPermissions
    }

    /// The draft's schedule in one line, "Weekdays at 09:00, 12:00, 18:00", or `nil`
    /// while it has no day or no time.
    public var scheduleSummary: LocalizedStringResource? {
        draft.schedule.summary
    }

    /// The note under the header while the job runs, or `nil` when it does not. Saving
    /// stays allowed; the running process keeps the options it started with.
    public var runningNote: LocalizedStringResource? {
        guard isRunning else {
            return nil
        }
        return LocalizedStringResource(
            "jobEditor.runningNote",
            defaultValue: "Changes apply from the next run.",
            bundle: .module,
            comment: "Note under the job editor's header while the job is running.",
        )
    }

    /// The alert that confirms deleting the saved job, or `nil` for a new job, which has
    /// nothing saved to delete.
    public var deleteConfirmation: JobDeleteConfirmation? {
        isNew ? nil : JobDeleteConfirmation(job: baseline, isRunning: isRunning)
    }

    /// Makes an editor over the saved `job`.
    /// - Parameters:
    ///   - store: Where ``save()`` writes; it reads the document afresh first.
    ///   - now: The time ``save()`` stamps as `updatedAt`; required, so a trailing
    ///     closure is always `saved`.
    ///   - saved: Told the document as written after every successful save, so the
    ///     job list can show it; `nil` tells no one.
    public init(
        editing job: Job,
        store: any JobStoring,
        now: @escaping @Sendable () -> Date,
        saved: (@MainActor (JobsDocument) -> Void)? = nil,
    ) {
        draft = job
        baseline = job
        isNew = false
        self.store = store
        self.now = now
        self.saved = saved
    }

    /// Makes an editor over a new, empty job: no name, folder, prompt, day, or time, and
    /// every option at its default (requirements §3.1).
    /// - Parameters:
    ///   - id: The new job's identifier.
    ///   - store: Where ``save()`` writes; it reads the document afresh first.
    ///   - now: The time the draft is created at, and the time ``save()`` stamps.
    ///   - saved: Told the document as written after every successful save.
    public convenience init(
        newJobWithID id: UUID,
        store: any JobStoring,
        now: @escaping @Sendable () -> Date,
        saved: (@MainActor (JobsDocument) -> Void)? = nil,
    ) {
        let job = Job(
            name: "",
            directory: Self.unchosenDirectory,
            prompt: "",
            schedule: Schedule(weekdays: [], times: []),
            createdAt: now(),
            id: id,
        )
        self.init(editing: job, store: store, now: now, saved: saved)
        isNew = true
    }

    /// The first rule each field breaks, in ``Job/validate()``'s order.
    private static func errorsByField(of job: Job) -> [JobEditorField: JobValidationError] {
        var byField: [JobEditorField: JobValidationError] = [:]
        for error in job.validate() {
            let field = JobEditorField(showing: error)
            if byField[field] == nil {
                byField[field] = error
            }
        }
        return byField
    }

    /// The error `field` shows, as the sentence the user reads under it.
    public func message(for field: JobEditorField) -> LocalizedStringResource? {
        errors[field]?.message
    }

    // MARK: - Edits

    /// The user typed in the Name field.
    public func nameChanged(to name: String) {
        edit { $0.name = name }
    }

    /// The user chose a folder with the open panel.
    public func directoryChosen(_ directory: URL) {
        edit { $0.directory = directory }
    }

    /// The user typed in the Prompt editor.
    public func promptChanged(to prompt: String) {
        edit { $0.prompt = prompt }
    }

    /// The user toggled a day chip.
    public func weekdayToggled(_ day: Weekday) {
        edit { job in
            if job.schedule.weekdays.contains(day) {
                job.schedule.weekdays.remove(day)
            } else {
                job.schedule.weekdays.insert(day)
            }
        }
    }

    /// The user chose a preset; its days replace the selected ones.
    public func presetChosen(_ preset: SchedulePreset) {
        edit { $0.schedule.weekdays = preset.weekdays }
    }

    /// The user added a time. A time already listed is added again, so validation can
    /// say so rather than the second one silently vanishing.
    public func timeAdded(_ time: TimeOfDay) {
        edit { $0.schedule.times.append(time) }
    }

    /// The user removed the time at `index` of the draft's ascending times; an index
    /// outside them changes nothing.
    public func timeRemoved(at index: Int) {
        guard draft.schedule.times.indices.contains(index) else {
            return
        }
        edit { _ = $0.schedule.times.remove(at: index) }
    }

    /// The user changed the time at `index` of the draft's ascending times; the times
    /// are sorted again afterwards. An index outside them changes nothing.
    public func timeChanged(at index: Int, to time: TimeOfDay) {
        guard draft.schedule.times.indices.contains(index) else {
            return
        }
        edit { $0.schedule.times[index] = time }
    }

    /// The user chose a model.
    public func modelChosen(_ model: ModelChoice) {
        edit { $0.model = model }
    }

    /// The user chose an effort level.
    public func effortChosen(_ effort: EffortChoice) {
        edit { $0.effort = effort }
    }

    /// The user chose a permission mode. Every mode applies at once except switching to
    /// `bypassPermissions`, which waits in ``isConfirmingBypass`` for
    /// ``bypassConfirmed()``; choosing any other mode drops a pending confirmation.
    public func permissionModeChosen(_ mode: PermissionMode) {
        guard mode == .bypassPermissions, draft.permissionMode != .bypassPermissions else {
            isConfirmingBypass = false
            edit { $0.permissionMode = mode }
            return
        }
        isConfirmingBypass = true
    }

    /// The user confirmed skipping every permission check; the draft now uses
    /// `bypassPermissions`. Does nothing when no confirmation is pending.
    public func bypassConfirmed() {
        guard isConfirmingBypass else {
            return
        }
        isConfirmingBypass = false
        edit { $0.permissionMode = .bypassPermissions }
    }

    /// The user cancelled the bypass confirmation; the draft keeps its mode.
    public func bypassCancelled() {
        isConfirmingBypass = false
    }

    /// The user changed the timeout, in whole minutes.
    public func timeoutChanged(to minutes: Int) {
        edit { $0.timeoutMinutes = minutes }
    }

    /// The user chose which finished runs notify.
    public func notifyChosen(_ policy: NotifyPolicy) {
        edit { $0.notify = policy }
    }

    /// The user turned the job on or off; like every edit it applies on save.
    public func enabledChanged(to isEnabled: Bool) {
        edit { $0.enabled = isEnabled }
    }

    /// Focus left `field`: it now shows its error, or none if it keeps its rules.
    public func fieldLostFocus(_ field: JobEditorField) {
        errors[field] = Self.errorsByField(of: draft)[field]
    }

    /// The app saw the job start or stop running.
    public func runningStateChanged(isRunning: Bool) {
        self.isRunning = isRunning
    }

    // MARK: - Saving

    /// Throws the edits away: the draft returns to the saved job (or, for a new job, to
    /// how it started), and no error or pending confirmation is left showing.
    public func revert() {
        draft = baseline
        errors = [:]
        isConfirmingBypass = false
    }

    /// Validates every field and, when all keep their rules, writes the draft to the
    /// store — replacing the saved job with the same identifier, or adding a new one
    /// last — and stamps `updatedAt` (and, for a new job, `createdAt`).
    ///
    /// Writes nothing when a field breaks a rule, and nothing when the saved document
    /// cannot be read: a corrupt or newer `jobs.json` is never saved over. The
    /// document's `lastCheckedAt` is kept as it was read.
    @discardableResult
    public func save() -> JobEditorSaveResult {
        errors = Self.errorsByField(of: draft)
        if let firstField = JobEditorField.allCases.first(where: { errors[$0] != nil }) {
            return .invalid(firstField: firstField)
        }
        let job = stamped(draft, at: now())
        let document: JobsDocument
        do {
            document = try store.updateJobs { jobs in
                if let index = jobs.firstIndex(where: { $0.id == job.id }) {
                    jobs[index] = job
                } else {
                    jobs.append(job)
                }
            }
        } catch {
            storageError = error
            AppLog.storage.error("job save failed: \(String(describing: error), privacy: .public)")
            return .failed(error)
        }
        draft = job
        baseline = job
        isNew = false
        storageError = nil
        saved?(document)
        return .saved
    }

    // MARK: - Private

    /// Applies `change` to the draft, then re-checks every field that shows an error.
    private func edit(_ change: (inout Job) -> Void) {
        change(&draft)
        guard !errors.isEmpty else {
            return
        }
        let current = Self.errorsByField(of: draft)
        for field in Array(errors.keys) {
            errors[field] = current[field]
        }
    }

    /// `job` as saved at `date`: a new job is created then, an existing one updated.
    private func stamped(_ job: Job, at date: Date) -> Job {
        guard isNew else {
            var updated = job
            updated.updatedAt = date
            return updated
        }
        return Job(
            name: job.name,
            directory: job.directory,
            prompt: job.prompt,
            schedule: job.schedule,
            createdAt: date,
            id: job.id,
            agent: job.agent,
            model: job.model,
            effort: job.effort,
            permissionMode: job.permissionMode,
            timeoutMinutes: job.timeoutMinutes,
            notify: job.notify,
            enabled: job.enabled,
        )
    }
}
