import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// The job list's selection and the editor it opens, kept in step with saves and reloads.
@MainActor
@Suite("Job list selection")
struct JobListSelectionTests {
    private static let digest = JobsScreenFixture.digest
    private static let review = JobsScreenFixture.review

    private static func document(_ jobs: [Job]) -> JobsDocument {
        JobsScreenFixture.document(jobs)
    }

    private func loaded(_ jobs: [Job]) -> (JobListModel, FakeJobStore) {
        JobsScreenFixture.loadedList(jobs)
    }

    @Test
    func `selecting a job opens its editor with its running state`() {
        let (list, _) = loaded([Self.digest, Self.review])
        list.runningJobsChanged(to: [Self.review.id])
        list.select(jobID: Self.review.id)
        #expect(list.selectedJobID == Self.review.id)
        #expect(list.editor?.draft == Self.review)
        #expect(list.editor?.isRunning == true)
        list.runningJobsChanged(to: [])
        #expect(list.editor?.isRunning == false)
    }

    @Test
    func `selecting the selected job again keeps its draft`() throws {
        let (list, _) = loaded([Self.digest])
        list.select(jobID: Self.digest.id)
        let editor = try #require(list.editor)
        editor.nameChanged(to: "Unsaved")
        list.select(jobID: Self.digest.id)
        #expect(list.editor === editor)
        #expect(list.editor?.draft.name == "Unsaved")
    }

    @Test
    func `clearing or missing the selection closes the editor`() {
        let (list, _) = loaded([Self.digest])
        list.select(jobID: Self.digest.id)
        list.select(jobID: nil)
        #expect(list.selectedJobID == nil)
        #expect(list.editor == nil)
        list.select(jobID: JobsScreenFixture.id(99))
        #expect(list.selectedJobID == nil)
        #expect(list.editor == nil)
    }

    @Test
    func `a saved edit shows in the list`() throws {
        let (list, store) = loaded([Self.digest, Self.review])
        list.select(jobID: Self.review.id)
        let editor = try #require(list.editor)
        editor.nameChanged(to: "PR review")
        editor.save()
        #expect(list.rows.map(\.name) == ["RSS digest", "PR review"])
        #expect(store.document.lastCheckedAt == JobsScreenFixture.lastCheckedAt)
    }

    @Test
    func `a new job is selected once saved`() throws {
        let (list, _) = loaded([Self.digest])
        list.select(jobID: Self.digest.id)
        list.newJob()
        #expect(list.selectedJobID == nil)
        let editor = try #require(list.editor)
        #expect(editor.isNew)
        editor.nameChanged(to: "Nightly review")
        editor.directoryChosen(Fixture.directory)
        editor.promptChanged(to: "Review open PRs.")
        editor.presetChosen(.everyDay)
        editor.timeAdded(Fixture.time(22, 0))
        #expect(editor.save() == .saved)
        #expect(list.selectedJobID == editor.draft.id)
        #expect(list.jobs.count == 2)
        #expect(list.editor === editor)
    }

    @Test
    func `a reload that no longer holds the selected job clears the selection`() throws {
        let (list, store) = loaded([Self.digest, Self.review])
        list.select(jobID: Self.digest.id)
        try store.save(Self.document([Self.review]))
        list.load()
        #expect(list.selectedJobID == nil)
        #expect(list.editor == nil)
        #expect(list.jobs == [Self.review])
    }

    @Test
    func `a reload that still holds the selected job keeps its editor`() throws {
        let (list, _) = loaded([Self.digest])
        list.select(jobID: Self.digest.id)
        let editor = try #require(list.editor)
        list.load()
        #expect(list.editor === editor)
    }
}
