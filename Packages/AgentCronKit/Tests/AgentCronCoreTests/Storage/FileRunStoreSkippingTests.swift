import AgentCronCore
import Foundation
import Testing

/// A run file that cannot be read back is skipped and reported, never allowed to hide
/// the runs around it (ADR-0005).
@Suite("FileRunStore skipping bad files")
struct FileRunStoreSkippingTests {
    @Test
    func `a run file that does not decode is skipped and reported by month only`() throws {
        try StorageFixture.withTemporaryRoot { root in
            try FileRunStore(root: root).save(StorageFixture.finishedRun())
            try StorageFixture.write(
                "{not json",
                to: "runs/2026-10/2026-10-05T10:00:00Z-\(StorageFixture.otherID.uuidString).json",
                under: root,
            )
            let observed = ObservedRunStore(root: root)
            #expect(try observed.store
                .runs(in: StorageFixture.october) == [StorageFixture.finishedRun()])
            #expect(observed.reported == [SkippedRunFile(month: "2026-10", reason: .undecodable)])
        }
    }

    @Test
    func `a run file from a newer version is skipped and reported with its version`() throws {
        try StorageFixture.withTemporaryRoot { root in
            try StorageFixture.write(
                #"{"schemaVersion": 2, "startedAt": "2026-10-05T10:00:00.000Z"}"#,
                to: "runs/2026-10/2026-10-05T10:00:00Z-\(StorageFixture.otherID.uuidString).json",
                under: root,
            )
            let observed = ObservedRunStore(root: root)
            #expect(try observed.store.runs(in: StorageFixture.october).isEmpty)
            #expect(observed.reported == [
                SkippedRunFile(month: "2026-10", reason: .newerVersion(schemaVersion: 2)),
            ])
        }
    }

    @Test
    func `a run file the file system will not read is skipped and reported with its code`() throws {
        try StorageFixture.withTemporaryRoot { root in
            let file = try StorageFixture.write(
                "{}",
                to: "runs/2026-10/2026-10-05T10:00:00Z-\(StorageFixture.otherID.uuidString).json",
                under: root,
            )
            try StorageFixture.setPermissions(0o000, of: file)
            let observed = ObservedRunStore(root: root)
            #expect(try observed.store.runs(in: StorageFixture.october).isEmpty)
            #expect(observed.reported == [
                SkippedRunFile(month: "2026-10", reason: .unreadable(code: 257)),
            ])
        }
    }

    @Test
    func `the public store reads past a bad file the same way`() throws {
        try StorageFixture.withTemporaryRoot { root in
            try StorageFixture.write("{not json", to: "runs/2026-10/x.json", under: root)
            #expect(try FileRunStore(root: root).runs(in: StorageFixture.october).isEmpty)
        }
    }

    @Test(arguments: [
        (SkippedRunFile.Reason.undecodable, "does not decode"),
        (.newerVersion(schemaVersion: 3), "written by a newer version (schema 3)"),
        (.unreadable(code: 257), "unreadable (Cocoa error 257)"),
    ])
    func `a skipped file's summary names its month and reason and nothing else`(
        reason: SkippedRunFile.Reason,
        text: String,
    ) {
        let file = SkippedRunFile(month: "2026-10", reason: reason)
        #expect(file.summary == "skipped a run file in 2026-10: \(text)")
    }
}
