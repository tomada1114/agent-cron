import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// What the list tells the app after the user changed the saved jobs — the hook that
/// re-arms the scheduler's timer (issue #28, `docs/architecture.md` › Core flows).
@MainActor
@Suite("Job list — saved jobs")
struct JobListSavedJobsTests {
    private static let digest = JobsScreenFixture.digest
    private static let review = JobsScreenFixture.review

    @Test
    func `a save in the editor reports the jobs as written`() throws {
        let (list, store) = JobsScreenFixture.loadedList([Self.digest])
        var reported: [[Job]] = []
        list.onJobsSaved = { reported.append($0) }
        list.select(jobID: Self.digest.id)
        let editor = try #require(list.editor)

        editor.nameChanged(to: "Morning digest")
        #expect(editor.save() == .saved)

        #expect(reported.count == 1)
        #expect(reported.first == store.document.jobs)
        #expect(reported.first?.first?.name == "Morning digest")
    }

    @Test
    func `a delete reports the jobs that remain`() {
        let (list, _) = JobsScreenFixture.loadedList([Self.digest, Self.review])
        var reported: [[Job]] = []
        list.onJobsSaved = { reported.append($0) }

        list.delete(jobID: Self.digest.id)

        #expect(reported.map { $0.map(\.id) } == [[Self.review.id]])
    }

    @Test
    func `a read, a refused save, and a refused delete report nothing`() throws {
        let (list, store) = JobsScreenFixture.loadedList([Self.digest])
        var reports = 0
        list.onJobsSaved = { _ in reports += 1 }
        list.load()
        list.select(jobID: Self.digest.id)
        let editor = try #require(list.editor)
        store.loadsFail(with: .corruptJobs)

        editor.nameChanged(to: "Morning digest")
        #expect(editor.save() == .failed(.corruptJobs))
        list.delete(jobID: Self.digest.id)

        #expect(reports == 0)
    }
}
