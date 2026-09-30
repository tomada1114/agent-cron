import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// What the job editor shows beyond the draft: the folder-missing and notifications-off
/// notes, VoiceOver's labels, the unsaved-changes title, and the time Add Time adds.
@MainActor
@Suite("Job editor presentation")
struct JobEditorPresentationTests {
    private static let saturdayEightHour = 8

    private static func editor(
        _ job: Job = Fixture.job(),
        directoryExists: @escaping @Sendable (URL) -> Bool = { _ in true },
    ) -> JobEditorModel {
        JobEditorModel(
            editing: job,
            store: FakeJobStore(),
            now: JobsScreenFixture.clock,
            directoryExists: directoryExists,
        )
    }

    private static func newEditor(
        directoryExists: @escaping @Sendable (URL) -> Bool = { _ in true },
    ) -> JobEditorModel {
        JobEditorModel(
            newJobWithID: JobsScreenFixture.id(9),
            store: FakeJobStore(),
            now: JobsScreenFixture.clock,
            directoryExists: directoryExists,
        )
    }

    // MARK: - Folder missing

    @Test
    func `a chosen folder that is gone shows the folder-missing note`() {
        let editor = Self.editor { _ in false }
        #expect(editor.isDirectoryMissing)
        #expect(editor.directoryMissingNote?
            .resolved(in: .english) == "This folder no longer exists.")
    }

    @Test
    func `a chosen folder that is there shows no note`() {
        let editor = Self.editor { _ in true }
        #expect(!editor.isDirectoryMissing)
        #expect(editor.directoryMissingNote == nil)
    }

    @Test
    func `a new job without a folder is not missing one`() {
        let editor = Self.newEditor { _ in false }
        #expect(!editor.isDirectoryMissing)
        #expect(editor.directoryPath == nil)
    }

    @Test
    func `the file system answers only for a folder that is there`() throws {
        let folder = FileManager.default.temporaryDirectory
            .appending(
                path: "JobEditorPresentationTests-\(UUID().uuidString)",
                directoryHint: .isDirectory,
            )
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: folder)
        }
        let file = folder.appending(path: "note.txt")
        try Data("x".utf8).write(to: file)
        #expect(JobEditorModel.folderExists(folder))
        #expect(!JobEditorModel.folderExists(file))
        #expect(!JobEditorModel.folderExists(folder.appending(
            path: "gone",
            directoryHint: .isDirectory,
        )))
    }

    @Test
    func `the directory row writes the home folder as a tilde`() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let inside = Self.editor()
        inside.directoryChosen(home.appending(path: "ghq/news-digest", directoryHint: .isDirectory))
        #expect(inside.directoryPath == "~/ghq/news-digest/")
        let atHome = Self.editor()
        atHome.directoryChosen(home)
        #expect(atHome.directoryPath == "~")
        let outside = Self.editor()
        outside.directoryChosen(URL(filePath: "/opt/jobs", directoryHint: .isDirectory))
        #expect(outside.directoryPath == "/opt/jobs/")
    }

    @Test
    func `a failed folder choice keeps the folder`() {
        let editor = Self.editor()
        editor.directoryChoiceFailed(CocoaError(.fileReadNoPermission))
        #expect(editor.draft == Fixture.job())
        #expect(!editor.isEdited)
    }

    // MARK: - Notifications off (REQ-N1)

    @Test(arguments: [
        (NotificationAuthorizationState?.some(.denied), NotifyPolicy.failuresOnly, true),
        (.denied, .everyRun, true),
        (.denied, .never, false),
        (.authorized, .failuresOnly, false),
        (.notDetermined, .everyRun, false),
        (nil, .everyRun, false),
    ])
    func `the notifications-off note shows only while denied and the job notifies`(
        authorization: NotificationAuthorizationState?,
        notify: NotifyPolicy,
        shows: Bool,
    ) {
        let editor = Self.editor()
        editor.notifyChosen(notify)
        let note = editor.notificationsOffNote(authorization: authorization)
        #expect((note != nil) == shows)
        if let note {
            #expect(note
                .resolved(in: .english) ==
                "Notifications are off for AgentCron in System Settings.")
        }
    }

    // MARK: - Accessibility

    @Test
    func `a field's accessibility label carries its error while it shows one`() {
        let editor = Self.editor()
        #expect(editor.accessibilityLabel(for: .name).resolved(in: .english) == "Name")
        editor.nameChanged(to: " ")
        editor.fieldLostFocus(.name)
        #expect(editor.accessibilityLabel(for: .name)
            .resolved(in: .english) == "Name, Enter a name.")
        editor.nameChanged(to: "Fixed")
        #expect(editor.accessibilityLabel(for: .name).resolved(in: .english) == "Name")
    }

    @Test(arguments: [
        (JobEditorField.name, "Name"),
        (.directory, "Directory"),
        (.prompt, "Prompt"),
        (.days, "Days"),
        (.times, "Times"),
        (.timeout, "Timeout"),
    ])
    func `every field has its row label`(field: JobEditorField, english: String) {
        #expect(field.title.resolved(in: .english) == english)
    }

    @Test
    func `the remove button names its time`() {
        let label = Self.editor().removeTimeLabel(for: Fixture.time(18, 5))
        #expect(label.resolved(in: .english) == "Remove 18:05")
    }

    // MARK: - Unsaved changes title

    @Test
    func `the unsaved-changes title quotes the saved name, not the renamed draft`() {
        let editor = Self.editor()
        editor.nameChanged(to: "Renamed")
        #expect(editor.saveChangesTitle.resolved(in: .english) == "Save changes to “RSS digest”?")
    }

    @Test
    func `a new job's unsaved-changes title quotes its draft name or none`() {
        let editor = Self.newEditor()
        #expect(editor.saveChangesTitle.resolved(in: .english) == "Save the new job?")
        editor.nameChanged(to: "  Nightly review ")
        #expect(editor.saveChangesTitle
            .resolved(in: .english) == "Save changes to “Nightly review”?")
    }

    @Test
    func `the header shows the draft's trimmed name, or none while it is blank`() {
        let editor = Self.newEditor()
        #expect(editor.headerName == nil)
        editor.nameChanged(to: "   ")
        #expect(editor.headerName == nil)
        editor.nameChanged(to: " Nightly review ")
        #expect(editor.headerName == "Nightly review")
    }

    @Test
    func `a saved job's header keeps its saved name while the draft's is blank`() {
        let editor = Self.editor()
        editor.nameChanged(to: " ")
        #expect(editor.headerName == "RSS digest")
    }

    // MARK: - Add Time

    @Test(arguments: [
        ([(Int, Int)](), 9, 0),
        ([(9, 0), (18, 0)], 19, 0),
        ([(23, 30)], 0, 30),
    ])
    func `add Time suggests an hour after the latest time`(
        times: [(Int, Int)],
        hour: Int,
        minute: Int,
    ) {
        var job = Fixture.job()
        job.schedule.times = times.map { Fixture.time($0.0, $0.1) }
        #expect(Self.editor(job).suggestedNewTime == Fixture.time(hour, minute))
    }

    // MARK: - Time pickers

    @Test
    func `a time survives the picker's date and back`() {
        let time = Fixture.time(Self.saturdayEightHour, 45)
        let date = time.pickerDate(in: JobsScreenFixture.calendar)
        #expect(TimeOfDay(pickedFrom: date, in: JobsScreenFixture.calendar) == time)
    }

    @Test
    func `a picked date keeps only its hour and minute`() {
        // 2026-09-29T10:00:00Z is a Tuesday; the day is dropped.
        let picked = TimeOfDay(pickedFrom: JobsScreenFixture.now, in: JobsScreenFixture.calendar)
        #expect(picked == Fixture.time(10, 0))
    }
}
