import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// Deleting with a confirmation (S5), the main menu's commands reaching the list, and the
/// status line each row and the editor's header show.
@MainActor
@Suite("Job list commands and status")
struct JobListCommandTests {
    private static let digest = JobsScreenFixture.digest
    private static let review = JobsScreenFixture.review
    private static let saturdayEightHour = 8
    private static let saturdayNumber = 3
    private static let neverNumber = 4

    // MARK: - Deleting (S5)

    @Test
    func `asking to delete shows the confirmation, and confirming deletes`() {
        let (list, store) = JobsScreenFixture.loadedList([Self.digest, Self.review])
        list.select(jobID: Self.digest.id)
        list.deleteRequested(jobID: Self.digest.id)
        #expect(list.pendingDeletion?.title.resolved(in: .english) == "Delete “RSS digest”?")
        list.deletionConfirmed()
        #expect(list.pendingDeletion == nil)
        #expect(list.jobs == [Self.review])
        #expect(store.document.jobs == [Self.review])
        #expect(list.selectedJobID == nil)
    }

    @Test
    func `cancelling the confirmation keeps the job`() {
        let (list, store) = JobsScreenFixture.loadedList([Self.digest])
        list.deleteRequested(jobID: Self.digest.id)
        list.deletionCancelled()
        #expect(list.pendingDeletion == nil)
        #expect(list.jobs == [Self.digest])
        #expect(store.savedDocuments.isEmpty)
    }

    @Test
    func `a job that is not saved has nothing to confirm`() {
        let (list, store) = JobsScreenFixture.loadedList([Self.digest])
        list.deleteRequested(jobID: Self.review.id)
        #expect(list.pendingDeletion == nil)
        list.deletionConfirmed()
        #expect(list.jobs == [Self.digest])
        #expect(store.savedDocuments.isEmpty)
    }

    @Test
    func `a running job's confirmation says it will be stopped`() {
        let (list, _) = JobsScreenFixture.loadedList([Self.digest])
        list.runningJobsChanged(to: [Self.digest.id])
        list.deleteRequested(jobID: Self.digest.id)
        #expect(list.pendingDeletion?.isRunning == true)
    }

    // MARK: - Menu commands

    @Test
    func `choosing Delete in the menu shows the confirmation`() {
        let (list, _) = JobsScreenFixture.loadedList([Self.digest])
        list.menuCommandRequested(.delete(jobID: Self.digest.id))
        #expect(list.pendingDeletion?.jobID == Self.digest.id)
    }

    @Test
    func `choosing New Job in the menu opens an empty draft`() {
        let (list, _) = JobsScreenFixture.loadedList([Self.digest])
        list.select(jobID: Self.digest.id)
        list.menuCommandRequested(.newJob)
        #expect(list.editor?.isNew == true)
    }

    @Test
    func `choosing Enable or Disable flips the open job's switch, unsaved`() throws {
        let (list, store) = JobsScreenFixture.loadedList([Self.digest])
        list.select(jobID: Self.digest.id)
        let editor = try #require(list.editor)
        list.menuCommandRequested(.toggleEnabled(jobID: Self.digest.id))
        #expect(!editor.draft.enabled)
        #expect(editor.isEdited)
        #expect(store.savedDocuments.isEmpty)
        list.menuCommandRequested(.toggleEnabled(jobID: Self.digest.id))
        #expect(editor.draft.enabled)
    }

    @Test
    func `choosing Enable or Disable for a job the editor does not show changes nothing`() throws {
        let (list, _) = JobsScreenFixture.loadedList([Self.digest, Self.review])
        list.select(jobID: Self.digest.id)
        let editor = try #require(list.editor)
        list.menuCommandRequested(.toggleEnabled(jobID: Self.review.id))
        #expect(!editor.isEdited)
        list.select(jobID: nil)
        list.menuCommandRequested(.toggleEnabled(jobID: Self.digest.id))
        #expect(list.editor == nil)
    }

    // MARK: - Folder check

    @Test
    func `the list hands its folder check to every editor it opens`() {
        let store = FakeJobStore(document: JobsScreenFixture.document([Self.digest]))
        let list = JobListModel(
            store: store,
            calendar: JobsScreenFixture.calendar,
            now: JobsScreenFixture.clock,
            directoryExists: JobsScreenFixture.folderGone,
        )
        list.load()
        list.select(jobID: Self.digest.id)
        #expect(list.editor?.isDirectoryMissing == true)
        list.newJob()
        list.editor?.directoryChosen(Fixture.directory)
        #expect(list.editor?.isDirectoryMissing == true)
    }

    // MARK: - Status

    @Test
    func `the status says when each job next runs`() {
        let saturday = JobsScreenFixture.job(
            Self.saturdayNumber,
            "Weekend sweep",
            days: [.saturday],
            times: [(Self.saturdayEightHour, 0)],
        )
        let (list, _) = JobsScreenFixture.loadedList([Self.digest, Self.review, saturday])
        let statuses = Dictionary(uniqueKeysWithValues: list.rows.map { row in
            (row.id, list.status(of: row).resolved(in: .english))
        })
        #expect(statuses[Self.digest.id] == "Next: today 12:00")
        #expect(statuses[Self.review.id] == "Next: tomorrow 09:00")
        #expect(statuses[saturday.id] == "Next: Sat 08:00")
    }

    @Test
    func `the status of a running, paused, or never-firing job`() {
        var never = JobsScreenFixture.job(Self.neverNumber, "Never", days: [], times: [(9, 0)])
        never.enabled = true
        let (list, _) = JobsScreenFixture.loadedList([
            Self.digest,
            JobsScreenFixture.paused(Self.review),
            never,
        ])
        list.runningJobsChanged(to: [Self.digest.id])
        let statuses = Dictionary(uniqueKeysWithValues: list.rows.map { row in
            (row.id, list.status(of: row).resolved(in: .english))
        })
        #expect(statuses[Self.digest.id] == "Running")
        #expect(statuses[Self.review.id] == "Paused")
        #expect(statuses[never.id] == "Not scheduled")
    }

    @Test
    func `the selected row is the selected saved job's`() {
        let (list, _) = JobsScreenFixture.loadedList([Self.digest, Self.review])
        #expect(list.selectedRow == nil)
        list.select(jobID: Self.review.id)
        #expect(list.selectedRow?.id == Self.review.id)
        list.newJob()
        #expect(list.selectedRow == nil)
    }
}
