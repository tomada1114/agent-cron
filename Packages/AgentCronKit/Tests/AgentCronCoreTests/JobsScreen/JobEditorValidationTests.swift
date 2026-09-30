import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// When a field shows its error (REQ-004) and the bypass confirmation (REQ-005).
@MainActor
@Suite("Job editor validation")
struct JobEditorValidationTests {
    private let store = FakeJobStore(document: JobsDocument(jobs: [Fixture.job()]))

    private func editor() -> JobEditorModel {
        JobEditorModel(editing: Fixture.job(), store: store, now: JobsScreenFixture.clock)
    }

    // MARK: - Validation timing (REQ-004)

    @Test
    func `a field shows no error until focus leaves it`() {
        let model = editor()
        model.nameChanged(to: "")
        #expect(model.errors.isEmpty)
        model.fieldLostFocus(.name)
        #expect(model.errors == [.name: .nameEmpty])
        #expect(model.message(for: .name)?.resolved(in: .english) == "Enter a name.")
    }

    @Test
    func `a field in error re-validates on every change and clears once fixed`() {
        let model = editor()
        model.nameChanged(to: "")
        model.fieldLostFocus(.name)
        model.nameChanged(to: String(repeating: "n", count: 61))
        #expect(model.errors == [.name: .nameTooLong(characterCount: 61)])
        model.nameChanged(to: "Fixed")
        #expect(model.errors.isEmpty)
        #expect(model.message(for: .name) == nil)
    }

    @Test
    func `a change leaves fields that show no error unchecked`() {
        let model = editor()
        model.nameChanged(to: "")
        model.fieldLostFocus(.name)
        model.promptChanged(to: "   ")
        #expect(model.errors == [.name: .nameEmpty])
    }

    @Test
    func `focus leaving a valid field shows no error`() {
        let model = editor()
        model.fieldLostFocus(.prompt)
        #expect(model.errors.isEmpty)
    }

    @Test
    func `emptying the days reads "Choose at least one day." once checked`() {
        let model = editor()
        for day in SchedulePreset.weekdays.weekdays {
            model.weekdayToggled(day)
        }
        model.fieldLostFocus(.days)
        #expect(model.errors == [.days: .noWeekdays])
        #expect(model.message(for: .days)?.resolved(in: .english) == "Choose at least one day.")
        model.presetChosen(.weekends)
        #expect(model.errors.isEmpty)
    }

    @Test(arguments: [
        (JobValidationError.nameEmpty, JobEditorField.name),
        (.nameTooLong(characterCount: 61), .name),
        (.directoryNotLocal, .directory),
        (.promptEmpty, .prompt),
        (.noWeekdays, .days),
        (.noTimes, .times),
        (.duplicateTimes([Fixture.time(9, 0)]), .times),
        (.timeoutOutOfRange(minutes: 0), .timeout),
    ])
    func `each validation error shows on its own field`(
        error: JobValidationError,
        field: JobEditorField,
    ) {
        #expect(JobEditorField(showing: error) == field)
    }

    @Test
    func `fields are ordered as the editor lays them out`() {
        #expect(JobEditorField.allCases == [.name, .directory, .prompt, .days, .times, .timeout])
    }

    // MARK: - Bypass confirmation (REQ-005)

    @Test
    func `choosing bypass waits for confirmation and applies only on confirm`() {
        let model = editor()
        model.permissionModeChosen(.bypassPermissions)
        #expect(model.isConfirmingBypass)
        #expect(model.draft.permissionMode == .auto)
        #expect(!model.usesBypassPermissions)
        model.bypassConfirmed()
        #expect(!model.isConfirmingBypass)
        #expect(model.draft.permissionMode == .bypassPermissions)
        #expect(model.usesBypassPermissions)
    }

    @Test
    func `cancelling the bypass confirmation keeps the previous mode`() {
        let model = editor()
        model.permissionModeChosen(.bypassPermissions)
        model.bypassCancelled()
        #expect(!model.isConfirmingBypass)
        #expect(model.draft.permissionMode == .auto)
        #expect(!model.isEdited)
    }

    @Test
    func `choosing another mode while bypass is pending drops the confirmation`() {
        let model = editor()
        model.permissionModeChosen(.bypassPermissions)
        model.permissionModeChosen(.dontAsk)
        #expect(!model.isConfirmingBypass)
        #expect(model.draft.permissionMode == .dontAsk)
        model.bypassConfirmed()
        #expect(model.draft.permissionMode == .dontAsk)
    }

    @Test
    func `choosing bypass again when it is already set asks nothing`() {
        let model = editor()
        model.permissionModeChosen(.bypassPermissions)
        model.bypassConfirmed()
        model.permissionModeChosen(.bypassPermissions)
        #expect(!model.isConfirmingBypass)
        #expect(model.draft.permissionMode == .bypassPermissions)
    }
}
