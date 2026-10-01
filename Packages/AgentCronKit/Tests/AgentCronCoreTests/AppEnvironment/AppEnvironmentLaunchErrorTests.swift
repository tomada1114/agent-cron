import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// Jobs that cannot be read at launch hold the scheduler, show the alert, and are never
/// written (issue #28 REQ-006, ADR-0005).
@MainActor
@Suite("AppEnvironment — unreadable jobs")
struct AppEnvironmentLaunchErrorTests {
    private static let corrupt = Data("{".utf8)

    @Test(arguments: [
        StorageError.corruptJobs,
        .newerJobsVersion(schemaVersion: 2),
        .readFailed(code: 257),
    ])
    func `unreadable jobs hold the scheduler and ask for the main window`(
        error: StorageError,
    ) async {
        let fixture = AppEnvironmentFixture()
        fixture.jobStore.loadsFail(with: error)

        await fixture.launch()

        #expect(fixture.environment.launchError == error)
        #expect(fixture.environment.isMainWindowRequested)
        #expect(!fixture.environment.isSchedulerRunning)
        #expect(fixture.jobStore.savedDocuments.isEmpty)
        #expect(fixture.events.openStreamCount == 0)
        #expect(fixture.events.armedDates.isEmpty)
        #expect(fixture.recorded.isEmpty)
        await fixture.cleanUp()
    }

    @Test
    func `try again starts the scheduler once the jobs read`() async {
        let fixture = AppEnvironmentFixture()
        fixture.jobStore.loadsFail(with: .corruptJobs)
        await fixture.launch()

        fixture.environment.tryAgain()
        await fixture.environment.waitForPendingWork()
        #expect(fixture.environment.launchError == .corruptJobs)
        #expect(!fixture.environment.isSchedulerRunning)

        fixture.jobStore.loadsFail(with: nil)
        fixture.environment.tryAgain()
        #expect(fixture.environment.launchError == nil)
        await fixture.environment.waitForPendingWork()

        #expect(fixture.environment.isSchedulerRunning)
        #expect(fixture.events.openStreamCount == 1)
        #expect(fixture.events.armedDates == [DispatcherFixture.at(DispatcherFixture.tenHour, 0)])
        // The click handler and the login item are set once, at launch, not again.
        #expect(fixture.loginItem.registerCalls == 1)
        await fixture.cleanUp()
    }

    @Test
    func `try again with no error showing does nothing`() async {
        let fixture = AppEnvironmentFixture()
        await fixture.launch()

        fixture.environment.tryAgain()
        await fixture.environment.waitForPendingWork()

        #expect(fixture.events.openStreamCount == 1)
        #expect(fixture.events.armedDates.count == 1)
        await fixture.cleanUp()
    }

    @Test
    func `a corrupt jobs.json on disk keeps its bytes through launch, retries, and edits`(
    ) async throws {
        let root = DispatcherFixture.makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "jobs.json")
        try Self.corrupt.write(to: file)
        let fixture = AppEnvironmentFixture()
        let environment = AppEnvironment(
            ports: fixture.ports,
            configuration: AppConfiguration(
                jobStore: FileJobStore(root: root),
                runStore: FileRunStore(root: root),
                defaults: fixture.defaults,
            ),
        )

        environment.launch()
        environment.tryAgain()
        await environment.waitForPendingWork()
        environment.jobList.load()
        environment.jobList.newJob()
        environment.jobList.editor?.nameChanged(to: "New")
        environment.jobList.editor?.save()
        environment.runNow(jobID: Fixture.jobID)

        #expect(environment.launchError == .corruptJobs)
        #expect(try Data(contentsOf: file) == Self.corrupt)
        await fixture.cleanUp()
    }

    @Test
    func `a missing data folder is created by the first save`() async {
        let root = DispatcherFixture.makeDirectory().appending(path: "AgentCron")
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        let fixture = AppEnvironmentFixture()
        let environment = AppEnvironment(
            ports: fixture.ports,
            configuration: AppConfiguration(
                jobStore: FileJobStore(root: root),
                runStore: FileRunStore(root: root),
                defaults: fixture.defaults,
            ),
        )

        environment.launch()
        await environment.waitForPendingWork()

        #expect(environment.isSchedulerRunning)
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "jobs.json").path))
        await fixture.cleanUp()
    }

    @Test
    func `the app's configuration keeps jobs and runs together in the data root`() {
        let root = DispatcherFixture.makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let configuration = AppConfiguration.files(at: root)

        #expect((configuration.jobStore as? FileJobStore)?.root == root)
        #expect((configuration.runStore as? FileRunStore)?.root == root)
        #expect(configuration.defaults == .standard)
    }
}
