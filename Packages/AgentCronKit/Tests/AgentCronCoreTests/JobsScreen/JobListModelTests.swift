import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// The job list's rows (REQ-001) and deleting (REQ-007); selection is
/// `JobListSelectionTests`.
@MainActor
@Suite("Job list")
struct JobListModelTests {
    private static let digest = JobsScreenFixture.digest
    private static let review = JobsScreenFixture.review
    /// Weekends at 08:00: next fires Saturday 08:00.
    private static let weekend = JobsScreenFixture.job(
        3,
        "Weekend chores",
        days: [.saturday, .sunday],
        times: [(8, 0)],
    )
    /// Paused, though it would fire soonest.
    private static let paused = JobsScreenFixture.paused(
        JobsScreenFixture.job(4, "Nightly review", days: Set(Weekday.allCases), times: [(10, 30)]),
    )

    private static func document(_ jobs: [Job]) -> JobsDocument {
        JobsScreenFixture.document(jobs)
    }

    private func model(_ store: FakeJobStore) -> JobListModel {
        JobsScreenFixture.list(store)
    }

    private func loaded(_ jobs: [Job]) -> (JobListModel, FakeJobStore) {
        JobsScreenFixture.loadedList(jobs)
    }

    // MARK: - Rows (REQ-001)

    @Test
    func `nothing is read until load`() {
        let store = FakeJobStore(document: Self.document([Self.digest]))
        let list = model(store)
        #expect(store.loadCount == 0)
        #expect(list.rows.isEmpty)
        #expect(list.editor == nil)
    }

    @Test
    func `rows sort enabled jobs by next run and paused jobs last`() {
        let (list, _) = loaded([Self.paused, Self.weekend, Self.review, Self.digest])
        #expect(list.rows.map(\.id) == [
            Self.digest.id,
            Self.review.id,
            Self.weekend.id,
            Self.paused.id,
        ])
        #expect(list.rows.map(\.nextRun) == [
            JobsScreenFixture.tuesdayNoon,
            JobsScreenFixture.wednesdayNine,
            JobsScreenFixture.saturdayEight,
            nil,
        ])
        #expect(list.jobs.map(\.id) == [
            Self.paused.id,
            Self.weekend.id,
            Self.review.id,
            Self.digest.id,
        ])
    }

    @Test
    func `rows summarize each schedule`() {
        let (list, _) = loaded([Self.digest, Self.weekend])
        #expect(list.rows.map { $0.scheduleSummary?.resolved(in: .english) } == [
            "Weekdays 09:00 +2",
            "Weekends 08:00",
        ])
        #expect(list.rows.map(\.name) == ["RSS digest", "Weekend chores"])
    }

    @Test
    func `jobs with the same next run keep the store's order`() {
        let twin = JobsScreenFixture.job(
            5,
            "Twin",
            days: SchedulePreset.weekdays.weekdays,
            times: [(9, 0)],
        )
        let (list, _) = loaded([twin, Self.review])
        #expect(list.rows.map(\.id) == [twin.id, Self.review.id])
        let (reversed, _) = loaded([Self.review, twin])
        #expect(reversed.rows.map(\.id) == [Self.review.id, twin.id])
    }

    @Test
    func `paused jobs keep the store's order among themselves`() {
        let otherPaused = JobsScreenFixture.paused(
            JobsScreenFixture.job(6, "Other paused", days: [.monday], times: [(1, 0)]),
        )
        let (list, _) = loaded([otherPaused, Self.paused])
        #expect(list.rows.map(\.id) == [otherPaused.id, Self.paused.id])
        #expect(list.rows.allSatisfy { !$0.isEnabled && $0.nextRun == nil })
    }

    @Test
    func `an enabled job that never fires sorts after those that do, before paused jobs`() {
        var never = JobsScreenFixture.job(7, "Never", days: [.monday], times: [(9, 0)])
        never.schedule = Schedule(weekdays: [], times: [])
        let (list, _) = loaded([Self.paused, never, Self.weekend])
        #expect(list.rows.map(\.id) == [Self.weekend.id, never.id, Self.paused.id])
        #expect(list.rows[1].nextRun == nil)
        #expect(list.rows[1].scheduleSummary == nil)
    }

    @Test
    func `rows show which jobs run and which bypass permission checks`() {
        var risky = Self.review
        risky.permissionMode = .bypassPermissions
        let (list, _) = loaded([Self.digest, risky])
        list.runningJobsChanged(to: [Self.digest.id])
        let rows = list.rows
        #expect(rows.map(\.isRunning) == [true, false])
        #expect(rows.map(\.usesBypassPermissions) == [false, true])
        #expect(list.runningJobIDs == [Self.digest.id])
    }

    // MARK: - Store refusals

    @Test(arguments: [StorageError.corruptJobs, .newerJobsVersion(schemaVersion: 2)])
    func `an unreadable document lists nothing and is never written by a delete`(
        error: StorageError,
    ) {
        let store = FakeJobStore(loadError: error, saveError: nil)
        let list = model(store)
        list.load()
        #expect(list.storageError == error)
        #expect(list.rows.isEmpty)
        list.delete(jobID: Self.digest.id)
        #expect(list.storageError == error)
        #expect(store.savedDocuments.isEmpty)
    }

    @Test
    func `a refused delete keeps the list as it was`() {
        let store = FakeJobStore(loadError: nil, saveError: .writeFailed(code: 513))
        let list = model(store)
        list.load()
        #expect(list.storageError == nil)
        list.delete(jobID: Self.digest.id)
        #expect(list.storageError == .writeFailed(code: 513))
        #expect(store.savedDocuments.isEmpty)
    }

    // MARK: - Deleting (REQ-007)

    @Test
    func `delete confirmation names the job and adds the running sentence when it runs`() throws {
        let (list, _) = loaded([Self.digest, Self.review])
        let idle = try #require(list.deleteConfirmation(forJobID: Self.digest.id))
        #expect(idle.title.resolved(in: .english) == "Delete “RSS digest”?")
        #expect(idle.message
            .resolved(in: .english) == "Its past runs stay in History for up to 90 days.")
        list.runningJobsChanged(to: [Self.digest.id])
        let running = try #require(list.deleteConfirmation(forJobID: Self.digest.id))
        #expect(running.message.resolved(in: .english)
            .hasSuffix("The running job will be stopped."))
        #expect(list.deleteConfirmation(forJobID: JobsScreenFixture.id(99)) == nil)
    }

    @Test
    func `delete removes the job, keeps the last check, and clears its selection`() {
        let (list, store) = loaded([Self.digest, Self.review])
        list.select(jobID: Self.digest.id)
        list.delete(jobID: Self.digest.id)
        #expect(store.savedDocuments == [Self.document([Self.review])])
        #expect(list.jobs == [Self.review])
        #expect(list.selectedJobID == nil)
        #expect(list.editor == nil)
    }

    @Test
    func `deleting another job keeps the selection`() {
        let (list, _) = loaded([Self.digest, Self.review])
        list.select(jobID: Self.review.id)
        list.delete(jobID: Self.digest.id)
        #expect(list.selectedJobID == Self.review.id)
        #expect(list.editor?.draft.id == Self.review.id)
    }
}
