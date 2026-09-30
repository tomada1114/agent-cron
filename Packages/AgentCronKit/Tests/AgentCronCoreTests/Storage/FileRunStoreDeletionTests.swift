import AgentCronCore
import Foundation
import Testing

@Suite("FileRunStore deleting")
struct FileRunStoreDeletionTests {
    @Test
    func `deleting removes strictly older runs, keeps one at the cutoff, and counts`() throws {
        try StorageFixture.withTemporaryRoot { root in
            let store = FileRunStore(root: root)
            // 2026-09-30T12:00:00Z, then StorageFixture.startedAt, then 2026-10-05T10:00:00Z.
            let september = StorageFixture
                .run(startedAt: Date(timeIntervalSince1970: 1_790_769_600))
            let atCutoff = StorageFixture.run(startedAt: StorageFixture.startedAt)
            let later = StorageFixture.run(startedAt: StorageFixture.tenOClock)
            for run in [september, atCutoff, later] {
                try store.save(run)
            }
            #expect(try store.deleteRuns(olderThan: StorageFixture.startedAt) == 1)
            let wide = DateInterval(start: .distantPast, end: .distantFuture)
            #expect(try store.runs(in: wide) == [atCutoff, later])
            #expect(try store.deleteRuns(olderThan: StorageFixture.startedAt) == 0)
            #expect(try StorageFixture.contents(of: root.appending(path: "runs")) == ["2026-10"])
        }
    }

    @Test(arguments: [
        // 2026-10-05T09:00:02.250Z: the run, at .500, is newer.
        (1_791_190_802.25, 0),
        // 2026-10-05T09:00:02.750Z: the run is older.
        (1_791_190_802.75, 1),
    ])
    func `a cutoff inside a run's start second decides by the run's exact start`(
        cutoff: TimeInterval,
        deleted: Int,
    ) throws {
        try StorageFixture.withTemporaryRoot { root in
            let store = FileRunStore(root: root)
            try store.save(StorageFixture.run(startedAt: StorageFixture.startedAt))
            #expect(try store.deleteRuns(olderThan: Date(timeIntervalSince1970: cutoff)) == deleted)
        }
    }

    @Test
    func `a month folder holding something else is kept once its runs are gone`() throws {
        try StorageFixture.withTemporaryRoot { root in
            let store = FileRunStore(root: root)
            try store.save(StorageFixture.finishedRun())
            try StorageFixture.write("", to: "runs/2026-10/.DS_Store", under: root)
            #expect(try store.deleteRuns(olderThan: StorageFixture.october.end) == 1)
            #expect(try StorageFixture
                .contents(of: root.appending(path: "runs/2026-10")) == [".DS_Store"])
        }
    }

    @Test
    func `an unreadable run file is deleted by the start its name gives, when that is plainly older`(
    ) throws {
        try StorageFixture.withTemporaryRoot { root in
            let folder = "runs/2026-10/"
            // Named 09:00:00 and 10:00:00, and a name that gives no start at all.
            try StorageFixture.write(
                "{not json",
                to: folder + "2026-10-05T09:00:00Z-\(UUID()).json",
                under: root,
            )
            try StorageFixture.write(
                "{not json",
                to: folder + "2026-10-05T10:00:00Z-\(UUID()).json",
                under: root,
            )
            try StorageFixture.write("{not json", to: folder + "backup.json", under: root)
            // A cutoff inside the 10:00:00 second cannot tell whether that file is older.
            let cutoff = StorageFixture.tenOClock.addingTimeInterval(0.5)
            #expect(try FileRunStore(root: root).deleteRuns(olderThan: cutoff) == 1)
            let left = try StorageFixture.contents(of: root.appending(path: folder))
            #expect(left.count == 2)
            #expect(left.contains("backup.json"))
            #expect(left.contains { $0.hasPrefix("2026-10-05T10:00:00Z-") })
        }
    }

    @Test
    func `runs in months after the cutoff's are never deleted`() throws {
        try StorageFixture.withTemporaryRoot { root in
            let store = FileRunStore(root: root)
            let november = StorageFixture.run(startedAt: StorageFixture.october.end)
            try store.save(november)
            #expect(try store.deleteRuns(olderThan: StorageFixture.october.end) == 0)
            #expect(try store
                .runs(in: DateInterval(start: .distantPast, end: .distantFuture)) == [november])
        }
    }

    @Test
    func `a deletion the file system refuses throws writeFailed with its code`() throws {
        try StorageFixture.withTemporaryRoot { root in
            let store = FileRunStore(root: root)
            try store.save(StorageFixture.finishedRun())
            try StorageFixture.setPermissions(0o555, of: root.appending(path: "runs/2026-10"))
            #expect(throws: StorageError.writeFailed(code: 513)) {
                try store.deleteRuns(olderThan: StorageFixture.october.end)
            }
        }
    }

    @Test
    func `an emptied month folder the file system will not remove throws writeFailed`() throws {
        try StorageFixture.withTemporaryRoot { root in
            let store = FileRunStore(root: root)
            try FileManager.default.createDirectory(
                at: root.appending(path: "runs/2026-09"),
                withIntermediateDirectories: true,
            )
            try StorageFixture.setPermissions(0o555, of: root.appending(path: "runs"))
            #expect(throws: StorageError.writeFailed(code: 513)) {
                try store.deleteRuns(olderThan: StorageFixture.october.end)
            }
        }
    }
}
