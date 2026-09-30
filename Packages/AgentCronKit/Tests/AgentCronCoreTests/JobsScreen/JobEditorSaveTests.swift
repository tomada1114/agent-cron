import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// Explicit save (REQ-003, REQ-006) and the store's refusals: nothing is written while a
/// field is invalid, and nothing over a document that could not be read.
@MainActor
@Suite("Job editor save")
struct JobEditorSaveTests {
    private static let other = JobsScreenFixture.job(
        2,
        "Dependabot review",
        days: [.monday],
        times: [(12, 0)],
    )

    private static func document() -> JobsDocument {
        JobsDocument(jobs: [Fixture.job(), other], lastCheckedAt: JobsScreenFixture.lastCheckedAt)
    }

    // MARK: - Invalid drafts

    @Test
    func `save with an empty name and a blank prompt returns the name and writes nothing`() {
        let store = FakeJobStore(document: Self.document())
        let model = JobEditorModel(
            editing: Fixture.job(),
            store: store,
            now: JobsScreenFixture.clock,
        )
        model.nameChanged(to: "")
        model.promptChanged(to: "   ")
        #expect(model.save() == .invalid(firstField: .name))
        #expect(model.errors == [.name: .nameEmpty, .prompt: .promptEmpty])
        #expect(store.savedDocuments.isEmpty)
        #expect(store.loadCount == 0)
        #expect(model.isEdited)
    }

    @Test(arguments: [(60, true), (61, false)])
    func `a name of 60 characters saves and 61 does not`(length: Int, saves: Bool) {
        let store = FakeJobStore(document: Self.document())
        let model = JobEditorModel(
            editing: Fixture.job(),
            store: store,
            now: JobsScreenFixture.clock,
        )
        model.nameChanged(to: String(repeating: "n", count: length))
        let expected: JobEditorSaveResult = saves ? .saved : .invalid(firstField: .name)
        #expect(model.save() == expected)
        #expect(store.savedDocuments.count == (saves ? 1 : 0))
    }

    @Test(arguments: [(0, false), (1, true), (1_440, true), (1_441, false)])
    func `a timeout from 1 to 1,440 minutes saves`(minutes: Int, saves: Bool) {
        let store = FakeJobStore(document: Self.document())
        let model = JobEditorModel(
            editing: Fixture.job(),
            store: store,
            now: JobsScreenFixture.clock,
        )
        model.timeoutChanged(to: minutes)
        let expected: JobEditorSaveResult = saves ? .saved : .invalid(firstField: .timeout)
        #expect(model.save() == expected)
        #expect(store.savedDocuments.count == (saves ? 1 : 0))
        if !saves {
            #expect(
                model.message(for: .timeout)?.resolved(in: .english)
                    == "Enter a timeout from 1 to 1,440 minutes.",
            )
        }
    }

    @Test
    func `no day selected fails on Days with what to fix`() {
        let store = FakeJobStore(document: Self.document())
        let model = JobEditorModel(
            editing: Fixture.job(),
            store: store,
            now: JobsScreenFixture.clock,
        )
        model.presetChosen(.weekdays)
        for day in SchedulePreset.weekdays.weekdays {
            model.weekdayToggled(day)
        }
        #expect(model.save() == .invalid(firstField: .days))
        #expect(model.message(for: .days)?.resolved(in: .english) == "Choose at least one day.")
        #expect(store.savedDocuments.isEmpty)
    }

    @Test
    func `the same time added twice fails on Times`() {
        let store = FakeJobStore(document: Self.document())
        let model = JobEditorModel(
            editing: Fixture.job(),
            store: store,
            now: JobsScreenFixture.clock,
        )
        model.timeAdded(Fixture.time(9, 0))
        #expect(model.save() == .invalid(firstField: .times))
        #expect(model.errors == [.times: .duplicateTimes([Fixture.time(9, 0)])])
        #expect(store.savedDocuments.isEmpty)
    }

    // MARK: - Writing

    @Test
    func `saving an edited job replaces it in place and keeps the last check`() throws {
        let store = FakeJobStore(document: Self.document())
        var told: [JobsDocument] = []
        let model = JobEditorModel(
            editing: Fixture.job(),
            store: store,
            now: JobsScreenFixture.clock,
        ) { document in
            told.append(document)
        }
        model.nameChanged(to: "Morning digest")
        #expect(model.save() == .saved)

        var expectedJob = Fixture.job()
        expectedJob.name = "Morning digest"
        expectedJob.updatedAt = JobsScreenFixture.now
        let expected = JobsDocument(
            jobs: [expectedJob, Self.other],
            lastCheckedAt: JobsScreenFixture.lastCheckedAt,
        )
        #expect(store.savedDocuments == [expected])
        #expect(told == [expected])
        #expect(model.draft == expectedJob)
        #expect(!model.isEdited)
        #expect(!model.canSave)
        #expect(model.storageError == nil)
        #expect(try #require(model.deleteConfirmation).jobName == "Morning digest")
    }

    @Test
    func `saving a new job adds it last, created and updated at the save`() throws {
        let store = FakeJobStore(document: Self.document())
        let id = JobsScreenFixture.id(9)
        let model = JobEditorModel(newJobWithID: id, store: store, now: JobsScreenFixture.clock)
        model.nameChanged(to: "Nightly review")
        model.directoryChosen(Fixture.directory)
        model.promptChanged(to: "Review open PRs.")
        model.presetChosen(.everyDay)
        model.timeAdded(Fixture.time(22, 0))
        #expect(model.save() == .saved)

        let saved = try #require(store.savedDocuments.last)
        #expect(saved.jobs.map(\.id) == [Fixture.jobID, Self.other.id, id])
        #expect(saved.lastCheckedAt == JobsScreenFixture.lastCheckedAt)
        let job = try #require(saved.jobs.last)
        #expect(job.name == "Nightly review")
        #expect(job.createdAt == JobsScreenFixture.now)
        #expect(job.updatedAt == JobsScreenFixture.now)
        #expect(!model.isNew)
        #expect(!model.canSave)
    }

    @Test
    func `saving a new job twice updates it rather than adding it again`() {
        let store = FakeJobStore()
        let model = JobEditorModel(
            newJobWithID: JobsScreenFixture.id(9),
            store: store,
            now: JobsScreenFixture.clock,
        )
        model.nameChanged(to: "Nightly review")
        model.directoryChosen(Fixture.directory)
        model.promptChanged(to: "Review open PRs.")
        model.presetChosen(.everyDay)
        model.timeAdded(Fixture.time(22, 0))
        model.save()
        model.nameChanged(to: "Nightly PR review")
        #expect(model.save() == .saved)
        #expect(store.document.jobs.map(\.name) == ["Nightly PR review"])
    }

    @Test
    func `a job edited while it runs still saves`() {
        let store = FakeJobStore(document: Self.document())
        let model = JobEditorModel(
            editing: Fixture.job(),
            store: store,
            now: JobsScreenFixture.clock,
        )
        model.runningStateChanged(isRunning: true)
        model.timeoutChanged(to: 45)
        #expect(model.save() == .saved)
        #expect(store.document.jobs.first?.timeoutMinutes == 45)
        #expect(model.runningNote != nil)
    }

    // MARK: - Store refusals

    @Test(arguments: [
        StorageError.corruptJobs,
        .newerJobsVersion(schemaVersion: 2),
        .readFailed(code: 257),
    ])
    func `a document that cannot be read is never saved over`(error: StorageError) {
        let store = FakeJobStore(loadError: error, saveError: nil)
        var told = 0
        let model = JobEditorModel(
            editing: Fixture.job(),
            store: store,
            now: JobsScreenFixture.clock,
        ) { _ in told += 1 }
        model.nameChanged(to: "Morning digest")
        #expect(model.save() == .failed(error))
        #expect(model.storageError == error)
        #expect(store.savedDocuments.isEmpty)
        #expect(told == 0)
        #expect(model.isEdited)
        #expect(model.draft.name == "Morning digest")
    }

    @Test
    func `a refused write keeps the draft edited`() {
        let store = FakeJobStore(loadError: nil, saveError: .writeFailed(code: 513))
        let model = JobEditorModel(
            editing: Fixture.job(),
            store: store,
            now: JobsScreenFixture.clock,
        )
        model.nameChanged(to: "Morning digest")
        #expect(model.save() == .failed(.writeFailed(code: 513)))
        #expect(model.storageError == .writeFailed(code: 513))
        #expect(model.isEdited)
        #expect(!model.isNew)
    }
}
