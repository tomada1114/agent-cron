import AgentCronCore
import Foundation
import Testing

@Suite("FileRunStore")
struct FileRunStoreTests {
    // MARK: - The v1 format

    @Test
    func `a run is written under its UTC month, named by its start second and id`() throws {
        try StorageFixture.withTemporaryRoot { root in
            try FileRunStore(root: root).save(StorageFixture.finishedRun())
            #expect(try StorageFixture.contents(of: root) == ["runs"])
            #expect(try StorageFixture.contents(of: root.appending(path: "runs")) == ["2026-10"])
            #expect(try StorageFixture.contents(of: root.appending(path: "runs/2026-10")) == [
                StorageFixture.runFileName,
            ])
        }
    }

    @Test
    func `saving writes exactly the v1 sample's bytes`() throws {
        try StorageFixture.withTemporaryRoot { root in
            try FileRunStore(root: root).save(StorageFixture.finishedRun())
            let written = try Data(contentsOf: root
                .appending(path: "runs/2026-10/\(StorageFixture.runFileName)"))
            #expect(try written == StorageFixture.fixture(named: "run-v1"))
        }
    }

    @Test
    func `the checked-in v1 sample decodes to the run it describes`() throws {
        try StorageFixture.withTemporaryRoot { root in
            let folder = root.appending(path: "runs/2026-10", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try StorageFixture.fixture(named: "run-v1")
                .write(to: folder.appending(path: StorageFixture.runFileName))
            let observed = ObservedRunStore(root: root)
            #expect(try observed.store
                .runs(in: StorageFixture.october) == [StorageFixture.finishedRun()])
            #expect(observed.reported.isEmpty)
        }
    }

    @Test
    func `a start late on the last day of a month files under that month in UTC`() throws {
        try StorageFixture.withTemporaryRoot { root in
            // 2026-10-31T23:59:59.750Z: the file name keeps the whole second only.
            let run = StorageFixture.run(
                startedAt: Date(timeIntervalSince1970: 1_793_491_199.75),
                id: StorageFixture.runID,
            )
            try FileRunStore(root: root).save(run)
            #expect(try StorageFixture.contents(of: root.appending(path: "runs/2026-10")) == [
                "2026-10-31T23:59:59Z-66666666-7777-8888-9999-AAAAAAAAAAAA.json",
            ])
        }
    }

    @Test
    func `saving a run again replaces its file`() throws {
        try StorageFixture.withTemporaryRoot { root in
            let store = FileRunStore(root: root)
            var run = StorageFixture.run(
                startedAt: StorageFixture.startedAt,
                id: StorageFixture.runID,
            )
            try store.save(run)
            run.outcome = .succeeded
            run.endedAt = StorageFixture.endedAt
            try store.save(run)
            #expect(try StorageFixture.contents(of: root.appending(path: "runs/2026-10"))
                .count == 1)
            #expect(try store.runs(in: StorageFixture.october) == [run])
        }
    }

    @Test
    func `a save the file system refuses throws writeFailed with its code`() throws {
        try StorageFixture.withTemporaryRoot { root in
            try StorageFixture.write("", to: "occupied", under: root)
            let store = FileRunStore(root: root.appending(path: "occupied"))
            #expect(throws: StorageError.writeFailed(code: 512)) {
                try store.save(StorageFixture.finishedRun())
            }
        }
    }

    // MARK: - Reading

    @Test
    func `with no runs folder yet, there are no runs and nothing to delete`() throws {
        try StorageFixture.withTemporaryRoot { (root: URL) throws in
            let store = FileRunStore(root: root)
            #expect(try store.runs(in: StorageFixture.october).isEmpty)
            #expect(try store.deleteRuns(olderThan: StorageFixture.october.end) == 0)
            #expect(!StorageFixture.exists(root))
        }
    }

    @Test
    func `an empty month folder has no runs`() throws {
        try StorageFixture.withTemporaryRoot { root in
            try FileManager.default.createDirectory(
                at: root.appending(path: "runs/2026-10"),
                withIntermediateDirectories: true,
            )
            #expect(try FileRunStore(root: root).runs(in: StorageFixture.october).isEmpty)
        }
    }

    @Test
    func `only runs whose start lies in the interval are read, from every month it spans`() throws {
        try StorageFixture.withTemporaryRoot { root in
            let store = FileRunStore(root: root)
            // 2026-09-30T23:59:59.500Z, 2026-10-01T00:00:00.000Z, 2026-10-05T09:00:02.500Z,
            // 2026-10-31T23:59:59.750Z, 2026-11-01T00:00:00.000Z
            let seconds: [TimeInterval] = [
                1_790_812_799.5, 1_790_812_800, 1_791_190_802.5, 1_793_491_199.75, 1_793_491_200,
            ]
            let runs = seconds
                .map { StorageFixture.run(startedAt: Date(timeIntervalSince1970: $0)) }
            for run in runs.reversed() {
                try store.save(run)
            }
            #expect(try store.runs(in: StorageFixture.october) == Array(runs[1 ... 3]))
            let wide = DateInterval(start: .distantPast, end: .distantFuture)
            #expect(try store.runs(in: wide) == runs)
            let lateSeptember = DateInterval(start: runs[0].startedAt, end: runs[1].startedAt)
            #expect(try store.runs(in: lateSeptember) == [runs[0]])
        }
    }

    @Test
    func `a runs folder the file system will not list throws readFailed with its code`() throws {
        try StorageFixture.withTemporaryRoot { root in
            let store = FileRunStore(root: root)
            try store.save(StorageFixture.finishedRun())
            try StorageFixture.setPermissions(0o000, of: root.appending(path: "runs"))
            #expect(throws: StorageError.readFailed(code: 257)) {
                try store.runs(in: StorageFixture.october)
            }
            #expect(throws: StorageError.readFailed(code: 257)) {
                try store.deleteRuns(olderThan: StorageFixture.october.end)
            }
        }
    }

    @Test
    func `a month folder the file system will not list throws readFailed with its code`() throws {
        try StorageFixture.withTemporaryRoot { root in
            let store = FileRunStore(root: root)
            try store.save(StorageFixture.finishedRun())
            try StorageFixture.setPermissions(0o000, of: root.appending(path: "runs/2026-10"))
            #expect(throws: StorageError.readFailed(code: 257)) {
                try store.runs(in: StorageFixture.october)
            }
        }
    }

    @Test
    func `files and folders that are not runs are ignored`() throws {
        try StorageFixture.withTemporaryRoot { root in
            let store = FileRunStore(root: root)
            try store.save(StorageFixture.finishedRun())
            try StorageFixture.write("notes", to: "runs/2026-10/notes.txt", under: root)
            try StorageFixture.write("", to: "runs/2026-10/.DS_Store", under: root)
            try StorageFixture.write("{not json", to: "runs/misc/x.json", under: root)
            try StorageFixture.write("{not json", to: "runs/2026-13/x.json", under: root)
            try StorageFixture.write("{not json", to: "runs/2026-1x/x.json", under: root)
            try StorageFixture.write("", to: "runs/2026-11", under: root)
            let observed = ObservedRunStore(root: root)
            let wide = DateInterval(start: .distantPast, end: .distantFuture)
            #expect(try observed.store.runs(in: wide) == [StorageFixture.finishedRun()])
            #expect(observed.reported.isEmpty)
        }
    }
}
