import AgentCronCore
import Foundation
import os
import Testing

/// A ``FileRunStore`` whose skipped files a test reads back instead of the log.
struct ObservedRunStore {
    let store: FileRunStore
    private let skipped: OSAllocatedUnfairLock<[SkippedRunFile]>

    /// Every file the store has skipped so far, in order.
    var reported: [SkippedRunFile] {
        skipped.withLock { $0 }
    }

    init(root: URL) {
        let recorder = OSAllocatedUnfairLock<[SkippedRunFile]>(initialState: [])
        skipped = recorder
        store = FileRunStore(root: root) { file in
            recorder.withLock { $0.append(file) }
        }
    }
}

/// Fixed inputs and file-system helpers the storage suites share.
///
/// Every date is a literal number of seconds since 1970 worked out by hand from the ISO-8601
/// text beside it, whose fraction is a whole number of milliseconds a `Double` holds
/// exactly — the precision the files keep — so no expected value is computed by the code
/// under test.
enum StorageFixture {
    /// Why a fixture file could not be found.
    struct MissingFixture: Error {
        let name: String
    }

    static let firstJobID = UUID(uuidString: "11111111-2222-3333-4444-555555555555") ?? UUID()
    static let secondJobID = UUID(uuidString: "22222222-3333-4444-5555-666666666666") ?? UUID()
    static let runID = UUID(uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA") ?? UUID()

    /// The fixture jobs' times: 09:00 for the first; 08:30 and 18:15 for the second.
    static let nine = 9
    static let eight = 8
    static let eighteen = 18
    static let fifteen = 15
    static let thirty = 30

    /// The second job's timeout, every option of which differs from a new job's.
    static let customTimeoutMinutes = 90

    /// 2026-09-28T08:00:00.000Z
    static let firstJobCreatedAtSeconds: TimeInterval = 1_790_582_400
    static let firstJobCreatedAt = Date(timeIntervalSince1970: firstJobCreatedAtSeconds)
    /// 2026-09-29T12:34:56.250Z
    static let secondJobUpdatedAtSeconds: TimeInterval = 1_790_685_296.25
    static let secondJobUpdatedAt = Date(timeIntervalSince1970: secondJobUpdatedAtSeconds)
    /// 2026-09-30T06:00:00.500Z
    static let lastCheckedAtSeconds: TimeInterval = 1_790_748_000.5
    static let lastCheckedAt = Date(timeIntervalSince1970: lastCheckedAtSeconds)
    /// 2026-10-05T09:00:00.000Z
    static let scheduledAtSeconds: TimeInterval = 1_791_190_800
    static let scheduledAt = Date(timeIntervalSince1970: scheduledAtSeconds)
    /// 2026-10-05T09:00:02.500Z
    static let startedAtSeconds: TimeInterval = 1_791_190_802.5
    static let startedAt = Date(timeIntervalSince1970: startedAtSeconds)
    /// 2026-10-05T09:02:03.750Z
    static let endedAtSeconds: TimeInterval = 1_791_190_923.75
    static let endedAt = Date(timeIntervalSince1970: endedAtSeconds)

    /// The whole of October 2026, UTC.
    static let octoberStartSeconds: TimeInterval = 1_790_812_800
    static let octoberEndSeconds: TimeInterval = 1_793_491_200
    static let october = DateInterval(
        start: Date(timeIntervalSince1970: octoberStartSeconds),
        end: Date(timeIntervalSince1970: octoberEndSeconds),
    )

    /// 2026-10-05T10:00:00Z
    static let tenOClockSeconds: TimeInterval = 1_791_194_400
    static let tenOClock = Date(timeIntervalSince1970: tenOClockSeconds)
    static let runFileName = "2026-10-05T09:00:02Z-66666666-7777-8888-9999-AAAAAAAAAAAA.json"
    static let otherID = UUID(uuidString: "77777777-8888-9999-AAAA-BBBBBBBBBBBB") ?? UUID()

    /// The two jobs `Fixtures/jobs-v1.json` holds: one with every default, and one with
    /// every option changed, paused, and a directory whose path needs escaping.
    static func jobsDocument() -> JobsDocument {
        let first = Job(
            name: "RSS digest",
            directory: URL(filePath: "/Users/example/news-digest", directoryHint: .isDirectory),
            prompt: "Summarize today's feeds into news.html.",
            schedule: Schedule(
                weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday],
                times: [time(nine, 0)],
            ),
            createdAt: firstJobCreatedAt,
            id: firstJobID,
        )
        let second = Job(
            name: "Dependabot merges",
            directory: URL(filePath: "/Users/example/My Projects/app", directoryHint: .isDirectory),
            prompt: "Review open Dependabot PRs and merge the safe ones.",
            schedule: Schedule(
                weekdays: [.thursday, .monday],
                times: [time(eighteen, fifteen), time(eight, thirty)],
            ),
            createdAt: firstJobCreatedAt,
            id: secondJobID,
            model: .opus,
            effort: .high,
            permissionMode: .acceptEdits,
            timeoutMinutes: customTimeoutMinutes,
            notify: .everyRun,
            enabled: false,
            updatedAt: secondJobUpdatedAt,
        )
        return JobsDocument(jobs: [first, second], lastCheckedAt: lastCheckedAt)
    }

    /// The finished run `Fixtures/run-v1.json` holds: every optional field set but the
    /// skip reason.
    static func finishedRun() -> Run {
        let job = jobsDocument().jobs[1]
        var run = Run(
            job: job,
            trigger: .scheduled,
            startedAt: startedAt,
            scheduledAt: scheduledAt,
            id: runID,
        )
        run.endedAt = endedAt
        run.outcome = .failed
        run.failureReason = "error_max_turns"
        run.exitCode = 1
        run.costUSD = Decimal(string: "0.1234")
        run.sessionID = "5f2c9a1e-0000-4000-8000-000000000001"
        run.resultText = "## Result\nMerged 2 PRs; skipped 1 (major bump)."
        return run
    }

    /// A running run of the first fixture job that started at `startedAt`.
    static func run(startedAt: Date) -> Run {
        run(startedAt: startedAt, id: UUID())
    }

    /// A running run of the first fixture job, with a known id.
    static func run(startedAt: Date, id: UUID) -> Run {
        Run(job: jobsDocument().jobs[0], trigger: .manual, startedAt: startedAt, id: id)
    }

    /// A time the test knows is in range; a failure names the bad literal.
    static func time(_ hour: Int, _ minute: Int) -> TimeOfDay {
        do {
            return try TimeOfDay(hour: hour, minute: minute)
        } catch {
            preconditionFailure("fixture time \(hour):\(minute) is out of range")
        }
    }

    /// The bytes of a checked-in file under `Fixtures/`, without the newline that ends it
    /// on disk: the stores write none, and the fixture keeps one so it reads as text.
    static func fixture(named name: String) throws -> Data {
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: "json",
            subdirectory: "Fixtures",
        ) else {
            throw MissingFixture(name: name)
        }
        var data = try Data(contentsOf: url)
        if data.last == UInt8(ascii: "\n") {
            data.removeLast()
        }
        return data
    }

    /// Runs `body` with a fresh directory under the temporary directory, and removes it
    /// afterwards: tests never touch the real Application Support, and parallel tests
    /// never share a path. The directory itself is not created, so a store's first write
    /// is what creates it.
    static func withTemporaryRoot<T>(_ body: (URL) throws -> T) throws -> T {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "AgentCronTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer {
            // A test may leave a file or folder without permissions; give them back so
            // the whole tree can be removed.
            restorePermissions(under: root)
            try? FileManager.default.removeItem(at: root)
        }
        return try body(root)
    }

    /// Writes `contents` to `path` under `root`, creating the folders on the way.
    @discardableResult
    static func write(_ contents: String, to path: String, under root: URL) throws -> URL {
        let url = root.appending(path: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        try Data(contents.utf8).write(to: url)
        return url
    }

    /// The names inside `folder`, sorted, hidden ones included.
    static func contents(of folder: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))
            .sorted()
    }

    /// Whether anything exists at `url`.
    static func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    /// Sets the POSIX permissions of `url`, e.g. `0o000` to make it unreadable.
    static func setPermissions(_ permissions: Int, of url: URL) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: permissions],
            ofItemAtPath: url.path(percentEncoded: false),
        )
    }

    private static func restorePermissions(under root: URL) {
        let manager = FileManager.default
        let rootPath = root.path(percentEncoded: false)
        try? manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: rootPath)
        guard let enumerator = manager.enumerator(atPath: rootPath) else {
            return
        }
        for case let relative as String in enumerator {
            let path = root.appending(path: relative).path(percentEncoded: false)
            try? manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        }
    }
}
