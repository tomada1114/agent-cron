import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// Editing a draft: what counts as edited and what revert restores, each edit, and the
/// running and delete wording. Validation timing and the
/// bypass confirmation are `JobEditorValidationTests`; saving is `JobEditorSaveTests`.
@MainActor
@Suite("Job editor")
struct JobEditorModelTests {
    private let store = FakeJobStore(document: JobsDocument(jobs: [Fixture.job()]))

    private func editor() -> JobEditorModel {
        JobEditorModel(editing: Fixture.job(), store: store, now: JobsScreenFixture.clock)
    }

    // MARK: - Edited and revert (REQ-002)

    @Test
    func `an editor over a saved job starts unedited, with nothing to save`() {
        let model = editor()
        #expect(model.draft == Fixture.job())
        #expect(!model.isNew)
        #expect(!model.isEdited)
        #expect(!model.canSave)
        #expect(model.errors.isEmpty)
        #expect(model.chosenDirectory == Fixture.directory)
    }

    @Test
    func `an edit marks the draft edited, and revert restores the saved job`() {
        let model = editor()
        model.nameChanged(to: "Morning digest")
        model.promptChanged(to: "Other prompt")
        #expect(model.isEdited)
        #expect(model.canSave)
        model.revert()
        #expect(model.draft == Fixture.job())
        #expect(!model.isEdited)
        #expect(!model.canSave)
    }

    @Test
    func `editing a field back to its saved value is no longer an edit`() {
        let model = editor()
        model.nameChanged(to: "Morning digest")
        model.nameChanged(to: Fixture.name)
        #expect(!model.isEdited)
    }

    @Test
    func `revert clears shown errors and a pending bypass confirmation`() {
        let model = editor()
        model.nameChanged(to: "")
        model.fieldLostFocus(.name)
        model.permissionModeChosen(.bypassPermissions)
        model.revert()
        #expect(model.errors.isEmpty)
        #expect(!model.isConfirmingBypass)
    }

    @Test
    func `a new job starts empty with defaults, saveable though unedited`() {
        let id = JobsScreenFixture.id(7)
        let model = JobEditorModel(newJobWithID: id, store: store, now: JobsScreenFixture.clock)
        #expect(model.isNew)
        #expect(!model.isEdited)
        #expect(model.canSave)
        #expect(model.draft.id == id)
        #expect(model.draft.name.isEmpty)
        #expect(model.draft.prompt.isEmpty)
        #expect(model.draft.schedule == Schedule(weekdays: [], times: []))
        #expect(model.draft.timeoutMinutes == 30)
        #expect(model.draft.permissionMode == .auto)
        #expect(model.draft.createdAt == JobsScreenFixture.now)
        #expect(model.chosenDirectory == nil)
        #expect(model.scheduleSummary == nil)
        #expect(model.deleteConfirmation == nil)
    }

    @Test
    func `a new job's empty fields all fail, with no folder chosen reported on Directory`() {
        let model = JobEditorModel(
            newJobWithID: JobsScreenFixture.id(7),
            store: store,
            now: JobsScreenFixture.clock,
        )
        #expect(model.save() == .invalid(firstField: .name))
        #expect(model.errors == [
            .name: .nameEmpty,
            .directory: .directoryNotLocal,
            .prompt: .promptEmpty,
            .days: .noWeekdays,
            .times: .noTimes,
        ])
        #expect(model.message(for: .directory)?
            .resolved(in: .english) == "Choose a folder on this Mac.")
        #expect(store.savedDocuments.isEmpty)
    }

    // MARK: - Field edits

    @Test
    func `each option edit lands in the draft`() {
        let model = editor()
        let folder = URL(filePath: "/Users/example/other", directoryHint: .isDirectory)
        model.directoryChosen(folder)
        model.modelChosen(.opus)
        model.effortChosen(.high)
        model.permissionModeChosen(.plan)
        model.timeoutChanged(to: 90)
        model.notifyChosen(.everyRun)
        model.enabledChanged(to: false)
        #expect(model.chosenDirectory == folder)
        #expect(model.draft.model == .opus)
        #expect(model.draft.effort == .high)
        #expect(model.draft.permissionMode == .plan)
        #expect(model.draft.timeoutMinutes == 90)
        #expect(model.draft.notify == .everyRun)
        #expect(!model.draft.enabled)
    }

    @Test
    func `day chips toggle and presets replace the selected days`() {
        let model = editor()
        model.weekdayToggled(.monday)
        #expect(model.draft.schedule.weekdays == [.tuesday, .wednesday, .thursday, .friday])
        model.weekdayToggled(.sunday)
        #expect(model.draft.schedule.weekdays == [
            .tuesday,
            .wednesday,
            .thursday,
            .friday,
            .sunday,
        ])
        model.presetChosen(.weekends)
        #expect(model.draft.schedule.weekdays == [.saturday, .sunday])
        model.presetChosen(.everyDay)
        #expect(model.draft.schedule.weekdays == Set(Weekday.allCases))
    }

    @Test
    func `times are added, changed, and removed by their ascending position`() {
        let model = editor()
        model.timeAdded(Fixture.time(18, 0))
        model.timeAdded(Fixture.time(12, 0))
        #expect(model.draft.schedule.times == [
            Fixture.time(9, 0),
            Fixture.time(12, 0),
            Fixture.time(18, 0),
        ])
        model.timeChanged(at: 0, to: Fixture.time(20, 0))
        #expect(model.draft.schedule.times == [
            Fixture.time(12, 0),
            Fixture.time(18, 0),
            Fixture.time(20, 0),
        ])
        model.timeRemoved(at: 1)
        #expect(model.draft.schedule.times == [Fixture.time(12, 0), Fixture.time(20, 0)])
    }

    @Test
    func `a time position outside the list changes nothing`() {
        let model = editor()
        model.timeRemoved(at: 1)
        model.timeRemoved(at: -1)
        model.timeChanged(at: 1, to: Fixture.time(20, 0))
        #expect(model.draft == Fixture.job())
    }

    @Test
    func `the summary follows the draft's schedule, as in the issue's example`() {
        let model = editor()
        model.timeAdded(Fixture.time(18, 0))
        model.timeAdded(Fixture.time(12, 0))
        #expect(model.scheduleSummary?.resolved(in: .english) == "Weekdays at 09:00, 12:00, 18:00")
    }

    // MARK: - Running note (REQ-006)

    @Test
    func `the running note shows only while the job runs`() {
        let model = editor()
        #expect(model.runningNote == nil)
        model.runningStateChanged(isRunning: true)
        #expect(model.isRunning)
        #expect(model.runningNote?.resolved(in: .english) == "Changes apply from the next run.")
        model.runningStateChanged(isRunning: false)
        #expect(model.runningNote == nil)
    }

    // MARK: - Delete confirmation (REQ-007)

    @Test
    func `the delete confirmation quotes the saved name and adds the running sentence`() throws {
        let model = editor()
        model.nameChanged(to: "Unsaved rename")
        let idle = try #require(model.deleteConfirmation)
        #expect(idle.jobID == Fixture.jobID)
        #expect(idle.title.resolved(in: .english) == "Delete “RSS digest”?")
        #expect(idle.message
            .resolved(in: .english) == "Its past runs stay in History for up to 90 days.")
        model.runningStateChanged(isRunning: true)
        let running = try #require(model.deleteConfirmation)
        #expect(running.isRunning)
        #expect(
            running.message.resolved(in: .english)
                ==
                "Its past runs stay in History for up to 90 days. The running job will be stopped.",
        )
    }
}
