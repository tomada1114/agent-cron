import AgentCronCore
import AgentCronTestSupport
import Foundation

/// Numbers the Jobs screen's localization cases build their jobs from.
private enum ViewCaseNumber {
    static let untitledJob = 9
    static let saturdayJob = 3
    static let neverJob = 4
    static let pausedJob = 5
    static let nine = 9
    static let eight = 8
}

extension LocalizationTests {
    /// Every resource the Jobs screen's views render beyond the models' own state: the
    /// fixed wording, the option titles, the editor's notes and labels, and the rows'
    /// status lines — once per key, with the English arguments each takes.
    @MainActor
    static func jobsScreenViewCases() -> [Case] {
        fixedWordingCases() + optionTitleCases() + editorCases() + statusCases()
    }

    private static func fixedWordingCases() -> [Case] {
        [
            JobsScreenText.emptyTitle,
            JobsScreenText.emptyDescription,
            JobsScreenText.noSelection,
            JobsScreenText.loadFailed,
            JobsScreenText.saveFailed,
            JobsScreenText.noFolderChosen,
            JobsScreenText.taskSection,
            JobsScreenText.scheduleSection,
            JobsScreenText.agentSection,
            JobsScreenText.notificationsSection,
            JobsScreenText.agentLabel,
            JobsScreenText.modelLabel,
            JobsScreenText.effortLabel,
            JobsScreenText.permissionLabel,
            JobsScreenText.notifyLabel,
            JobsScreenText.enabledLabel,
            JobsScreenText.timeoutUnit,
            JobsScreenText.chooseFolder,
            JobsScreenText.addTime,
            JobsScreenText.revert,
            JobsScreenText.save,
            JobsScreenText.edited,
            JobsScreenText.deleteJob,
            JobsScreenText.delete,
            JobsScreenText.cancel,
            JobsScreenText.dontSave,
            JobsScreenText.bypassAlertTitle,
            JobsScreenText.bypassAlertMessage,
            JobsScreenText.useBypass,
            JobsScreenText.bypassNote,
            JobsScreenText.openSystemSettings,
        ]
        .map { Case(resource: $0, arguments: []) }
    }

    private static func optionTitleCases() -> [Case] {
        let titles = AgentKind.allCases.map(\.title)
            + ModelChoice.allCases.map(\.title)
            + EffortChoice.allCases.map(\.title)
            + PermissionMode.allCases.map(\.title)
            + NotifyPolicy.allCases.map(\.title)
            + JobEditorField.allCases.map(\.title)
        return titles.map { Case(resource: $0, arguments: []) }
    }

    @MainActor
    private static func editorCases() -> [Case] {
        let saved = JobEditorModel(
            editing: Fixture.job(),
            store: FakeJobStore(),
            now: JobsScreenFixture.clock,
            directoryExists: JobsScreenFixture.folderGone,
        )
        let untitled = JobEditorModel(
            newJobWithID: JobsScreenFixture.id(ViewCaseNumber.untitledJob),
            store: FakeJobStore(),
            now: JobsScreenFixture.clock,
        )
        let invalid = JobEditorModel(
            editing: Fixture.job(),
            store: FakeJobStore(),
            now: JobsScreenFixture.clock,
        )
        invalid.nameChanged(to: "")
        invalid.fieldLostFocus(.name)
        var cases = [
            Case(
                resource: saved.removeTimeLabel(for: Fixture.time(ViewCaseNumber.nine, 0)),
                arguments: ["09:00"],
            ),
            Case(resource: saved.saveChangesTitle, arguments: [Fixture.name]),
            Case(resource: untitled.saveChangesTitle, arguments: []),
            Case(
                resource: invalid.accessibilityLabel(for: .name),
                arguments: ["Name", "Enter a name."],
            ),
        ]
        let notes = [
            saved.directoryMissingNote,
            saved.notificationsOffNote(authorization: .denied),
        ]
        cases += notes.compactMap(\.self).map { Case(resource: $0, arguments: []) }
        return cases
    }

    @MainActor
    private static func statusCases() -> [Case] {
        let saturday = JobsScreenFixture.job(
            ViewCaseNumber.saturdayJob,
            "Weekend sweep",
            days: [.saturday],
            times: [(ViewCaseNumber.eight, 0)],
        )
        let never = JobsScreenFixture.job(
            ViewCaseNumber.neverJob,
            "Never",
            days: [],
            times: [(ViewCaseNumber.nine, 0)],
        )
        let (list, _) = JobsScreenFixture.loadedList([
            JobsScreenFixture.digest,
            JobsScreenFixture.review,
            saturday,
            never,
            JobsScreenFixture.paused(JobsScreenFixture.job(
                ViewCaseNumber.pausedJob,
                "Paused",
                days: [.monday],
                times: [(ViewCaseNumber.nine, 0)],
            )),
        ])
        let arguments: [UUID: [any CVarArg]] = [
            JobsScreenFixture.digest.id: ["12:00"],
            JobsScreenFixture.review.id: ["09:00"],
            saturday.id: ["Sat", "08:00"],
            never.id: [],
            JobsScreenFixture.id(ViewCaseNumber.pausedJob): [],
        ]
        return list.rows.map { row in
            Case(resource: list.status(of: row), arguments: arguments[row.id] ?? [])
        }
    }
}
