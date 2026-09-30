import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// Leaving a job with unsaved edits asks first (REQ-005;
/// `docs/design/ux-guidelines.md` › Feedback and loading): Save, Don't Save, or Cancel.
@MainActor
@Suite("Job list unsaved changes")
struct JobListUnsavedChangesTests {
    /// A loaded list with `selected` open in its editor.
    private struct Opened {
        let list: JobListModel
        let store: FakeJobStore
        let editor: JobEditorModel
    }

    private static let digest = JobsScreenFixture.digest
    private static let review = JobsScreenFixture.review

    private func editing(_ jobs: [Job], selected: Job) throws -> Opened {
        let (list, store) = JobsScreenFixture.loadedList(jobs)
        list.select(jobID: selected.id)
        return try Opened(list: list, store: store, editor: #require(list.editor))
    }

    @Test
    func `without edits, a selection switches at once`() {
        let (list, _) = JobsScreenFixture.loadedList([Self.digest, Self.review])
        list.selectionRequested(jobID: Self.digest.id)
        list.selectionRequested(jobID: Self.review.id)
        #expect(list.pendingSelection == nil)
        #expect(list.selectedJobID == Self.review.id)
        list.selectionRequested(jobID: nil)
        #expect(list.selectedJobID == nil)
        #expect(list.editor == nil)
    }

    @Test
    func `with edits, a selection waits for an answer and the editor stays`() throws {
        let opened = try editing([Self.digest, Self.review], selected: Self.digest)
        let list = opened.list
        let editor = opened.editor
        editor.nameChanged(to: "Renamed")
        list.selectionRequested(jobID: Self.review.id)
        #expect(list.pendingSelection == .job(Self.review.id))
        #expect(list.selectedJobID == Self.digest.id)
        #expect(list.editor === editor)
    }

    @Test
    func `reselecting the edited job asks nothing`() throws {
        let opened = try editing([Self.digest], selected: Self.digest)
        let list = opened.list
        let editor = opened.editor
        editor.nameChanged(to: "Renamed")
        list.selectionRequested(jobID: Self.digest.id)
        #expect(list.pendingSelection == nil)
        #expect(list.editor?.draft.name == "Renamed")
    }

    @Test
    func `choosing Save writes the edits, then follows the selection`() throws {
        let opened = try editing([Self.digest, Self.review], selected: Self.digest)
        let list = opened.list
        let store = opened.store
        let editor = opened.editor
        editor.nameChanged(to: "Morning digest")
        list.selectionRequested(jobID: Self.review.id)
        #expect(list.unsavedChangesSaved() == .saved)
        #expect(list.pendingSelection == nil)
        #expect(list.selectedJobID == Self.review.id)
        #expect(store.document.jobs.map(\.name) == ["Morning digest", "Dependabot review"])
    }

    @Test
    func `a refused Save keeps the editor and its errors and drops the selection`() throws {
        let opened = try editing([Self.digest, Self.review], selected: Self.digest)
        let list = opened.list
        let store = opened.store
        let editor = opened.editor
        editor.nameChanged(to: "")
        list.selectionRequested(jobID: Self.review.id)
        #expect(list.unsavedChangesSaved() == .invalid(firstField: .name))
        #expect(list.pendingSelection == nil)
        #expect(list.selectedJobID == Self.digest.id)
        #expect(list.editor === editor)
        #expect(editor.errors == [.name: .nameEmpty])
        #expect(store.savedDocuments.isEmpty)
    }

    @Test
    func `choosing Don't Save throws the edits away, then follows the selection`() throws {
        let opened = try editing([Self.digest, Self.review], selected: Self.digest)
        let list = opened.list
        let store = opened.store
        let editor = opened.editor
        editor.nameChanged(to: "Renamed")
        list.selectionRequested(jobID: nil)
        #expect(list.pendingSelection == .nothing)
        list.unsavedChangesDiscarded()
        #expect(list.pendingSelection == nil)
        #expect(list.selectedJobID == nil)
        #expect(list.editor == nil)
        #expect(editor.draft == Self.digest)
        #expect(store.savedDocuments.isEmpty)
    }

    @Test
    func `choosing Cancel keeps the editor with its edits`() throws {
        let opened = try editing([Self.digest, Self.review], selected: Self.digest)
        let list = opened.list
        let editor = opened.editor
        editor.nameChanged(to: "Renamed")
        list.selectionRequested(jobID: Self.review.id)
        list.unsavedChangesCancelled()
        #expect(list.pendingSelection == nil)
        #expect(list.selectedJobID == Self.digest.id)
        #expect(list.editor?.draft.name == "Renamed")
    }

    @Test
    func `an answer with nothing pending changes nothing`() throws {
        let opened = try editing([Self.digest], selected: Self.digest)
        let list = opened.list
        let store = opened.store
        let editor = opened.editor
        editor.nameChanged(to: "Renamed")
        #expect(list.unsavedChangesSaved() == nil)
        list.unsavedChangesDiscarded()
        #expect(list.editor?.draft.name == "Renamed")
        #expect(store.savedDocuments.isEmpty)
    }

    @Test
    func `a new job with edits asks first, then opens an empty draft`() throws {
        let opened = try editing([Self.digest], selected: Self.digest)
        let list = opened.list
        let editor = opened.editor
        editor.nameChanged(to: "Renamed")
        list.newJobRequested()
        #expect(list.pendingSelection == .newJob)
        #expect(list.editor === editor)
        list.unsavedChangesDiscarded()
        #expect(list.editor?.isNew == true)
        #expect(list.selectedJobID == nil)
    }

    @Test
    func `a new job without edits opens an empty draft at once`() {
        let (list, _) = JobsScreenFixture.loadedList([Self.digest])
        list.newJobRequested()
        #expect(list.pendingSelection == nil)
        #expect(list.editor?.isNew == true)
    }

    @Test
    func `a typed-in new job asks before a selection and saves as a new job`() throws {
        let (list, store) = JobsScreenFixture.loadedList([Self.digest])
        list.newJobRequested()
        let editor = try #require(list.editor)
        editor.nameChanged(to: "Nightly review")
        editor.directoryChosen(Fixture.directory)
        editor.promptChanged(to: "Review open PRs.")
        editor.presetChosen(.everyDay)
        editor.timeAdded(Fixture.time(22, 0))
        list.selectionRequested(jobID: Self.digest.id)
        #expect(list.pendingSelection == .job(Self.digest.id))
        #expect(list.unsavedChangesSaved() == .saved)
        #expect(list.selectedJobID == Self.digest.id)
        #expect(store.document.jobs.map(\.name) == ["RSS digest", "Nightly review"])
    }

    // MARK: - Appearing

    @Test
    func `appearing loads the jobs and restores the remembered selection`() {
        let store = FakeJobStore(document: JobsScreenFixture.document([Self.digest, Self.review]))
        let list = JobsScreenFixture.list(store)
        list.screenAppeared(restoringSelection: Self.review.id)
        #expect(list.jobs == [Self.digest, Self.review])
        #expect(list.selectedJobID == Self.review.id)
        #expect(list.editor?.draft == Self.review)
    }

    @Test
    func `appearing keeps an open new draft the navigation does not know`() throws {
        let (list, _) = JobsScreenFixture.loadedList([Self.digest])
        list.newJob()
        let draft = try #require(list.editor)
        draft.nameChanged(to: "Half typed")
        list.screenAppeared(restoringSelection: nil)
        #expect(list.editor === draft)
        #expect(list.pendingSelection == nil)
    }

    @Test
    func `appearing on another remembered job asks first about edits`() throws {
        let opened = try editing([Self.digest, Self.review], selected: Self.digest)
        let list = opened.list
        let editor = opened.editor
        editor.nameChanged(to: "Renamed")
        list.screenAppeared(restoringSelection: Self.review.id)
        #expect(list.pendingSelection == .job(Self.review.id))
        #expect(list.editor === editor)
    }

    @Test
    func `appearing on a remembered job that is gone selects nothing`() {
        let store = FakeJobStore(document: JobsScreenFixture.document([Self.digest]))
        let list = JobsScreenFixture.list(store)
        list.screenAppeared(restoringSelection: Self.review.id)
        #expect(list.selectedJobID == nil)
        #expect(list.editor == nil)
        #expect(list.jobIDs == [Self.digest.id])
    }

    // MARK: - A failed read

    @Test
    func `a failed read keeps an edited draft and its selection`() throws {
        let opened = try editing([Self.digest, Self.review], selected: Self.digest)
        opened.editor.nameChanged(to: "Renamed")
        opened.store.loadsFail(with: .readFailed(code: 257))
        opened.list.screenAppeared(restoringSelection: Self.digest.id)
        #expect(opened.list.storageError == .readFailed(code: 257))
        #expect(opened.list.selectedJobID == Self.digest.id)
        #expect(opened.list.editor === opened.editor)
        #expect(opened.editor.draft.name == "Renamed")
        #expect(opened.list.pendingSelection == nil)
        #expect(opened.list.jobs.isEmpty)
        #expect(!opened.list.areJobsKnown)
    }

    @Test
    func `a failed read drops an unedited editor, and a later read is known again`() throws {
        let opened = try editing([Self.digest], selected: Self.digest)
        opened.store.loadsFail(with: .corruptJobs)
        opened.list.load()
        #expect(opened.list.selectedJobID == nil)
        #expect(opened.list.editor == nil)
        #expect(!opened.list.areJobsKnown)
        opened.store.loadsFail(with: nil)
        opened.list.load()
        #expect(opened.list.storageError == nil)
        #expect(opened.list.areJobsKnown)
        #expect(opened.list.jobIDs == [Self.digest.id])
    }
}
