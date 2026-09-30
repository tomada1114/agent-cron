import AgentCronCore
import Foundation
import Testing

@Suite("FileJobStore")
struct FileJobStoreTests {
    /// Documents `load()` must refuse as corrupt: not JSON, not an object, no or a
    /// malformed version, and a version-1 document whose jobs do not decode.
    static let corruptDocuments = [
        "{not json",
        "",
        "[]",
        #"{"jobs": []}"#,
        #"{"schemaVersion": 0, "jobs": []}"#,
        #"{"schemaVersion": -1, "jobs": []}"#,
        #"{"schemaVersion": "1", "jobs": []}"#,
        #"{"schemaVersion": 1.5, "jobs": []}"#,
        #"{"schemaVersion": 1}"#,
        #"{"schemaVersion": 1, "jobs": [{"name": "half a job"}]}"#,
        #"{"schemaVersion": 1, "jobs": [], "lastCheckedAt": "yesterday"}"#,
    ]

    // MARK: - The v1 format

    @Test
    func `the checked-in v1 sample decodes to the jobs it describes`() throws {
        try StorageFixture.withTemporaryRoot { root in
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try StorageFixture.fixture(named: "jobs-v1")
                .write(to: root.appending(path: "jobs.json"))
            #expect(try FileJobStore(root: root).load() == StorageFixture.jobsDocument())
        }
    }

    @Test
    func `saving writes exactly the v1 sample's bytes`() throws {
        try StorageFixture.withTemporaryRoot { root in
            try FileJobStore(root: root).save(StorageFixture.jobsDocument())
            let written = try Data(contentsOf: root.appending(path: "jobs.json"))
            #expect(try written == StorageFixture.fixture(named: "jobs-v1"))
        }
    }

    @Test
    func `a document with no last-checked time writes only the version and the jobs`() throws {
        try StorageFixture.withTemporaryRoot { root in
            try FileJobStore(root: root).save(JobsDocument())
            let written = try Data(contentsOf: root.appending(path: "jobs.json"))
            let object = try #require(
                try JSONSerialization.jsonObject(with: written) as? [String: Any],
            )
            #expect(object.keys.sorted() == ["jobs", "schemaVersion"])
            #expect(object["schemaVersion"] as? Int == 1)
            #expect((object["jobs"] as? [Any])?.isEmpty == true)
        }
    }

    @Test
    func `a date written without a fraction of a second still decodes`() throws {
        try StorageFixture.withTemporaryRoot { root in
            try StorageFixture.write(
                #"{"schemaVersion": 1, "jobs": [], "lastCheckedAt": "2026-09-30T06:00:00Z"}"#,
                to: "jobs.json",
                under: root,
            )
            let document = try FileJobStore(root: root).load()
            #expect(document.lastCheckedAt == Date(timeIntervalSince1970: 1_790_748_000))
        }
    }

    // MARK: - Saving

    @Test
    func `saving creates the root folder and leaves nothing beside jobs.json`() throws {
        try StorageFixture.withTemporaryRoot { root in
            let nested = root.appending(
                path: "Application Support/AgentCron",
                directoryHint: .isDirectory,
            )
            try FileJobStore(root: nested).save(StorageFixture.jobsDocument())
            #expect(try StorageFixture.contents(of: nested) == ["jobs.json"])
        }
    }

    @Test
    func `saving again replaces the file`() throws {
        try StorageFixture.withTemporaryRoot { root in
            let store = FileJobStore(root: root)
            try store.save(StorageFixture.jobsDocument())
            let smaller = JobsDocument(jobs: [StorageFixture.jobsDocument().jobs[1]])
            try store.save(smaller)
            #expect(try store.load() == smaller)
            #expect(try StorageFixture.contents(of: root) == ["jobs.json"])
        }
    }

    @Test
    func `a save the file system refuses throws writeFailed with its code`() throws {
        try StorageFixture.withTemporaryRoot { root in
            // The root is a file, so no folder, and no jobs.json, can be made inside it.
            try StorageFixture.write("", to: "occupied", under: root)
            let store = FileJobStore(root: root.appending(path: "occupied/store"))
            #expect(throws: StorageError.writeFailed(code: 512)) {
                try store.save(StorageFixture.jobsDocument())
            }
        }
    }

    // MARK: - Loading what is not there, or not readable

    @Test
    func `with no jobs.json yet, load answers an empty document`() throws {
        try StorageFixture.withTemporaryRoot { (root: URL) throws in
            #expect(try FileJobStore(root: root).load() == JobsDocument())
            #expect(!StorageFixture.exists(root))
        }
    }

    @Test
    func `a jobs.json the file system will not read throws readFailed with its code`() throws {
        try StorageFixture.withTemporaryRoot { root in
            let file = try StorageFixture.write("{}", to: "jobs.json", under: root)
            try StorageFixture.setPermissions(0o000, of: file)
            #expect(throws: StorageError.readFailed(code: 257)) {
                try FileJobStore(root: root).load()
            }
        }
    }

    // MARK: - A damaged or newer file is never overwritten

    @Test(arguments: corruptDocuments)
    func `a jobs.json that does not decode throws corruptJobs and is left byte-identical`(
        contents: String,
    ) throws {
        try StorageFixture.withTemporaryRoot { root in
            let file = try StorageFixture.write(contents, to: "jobs.json", under: root)
            #expect(throws: StorageError.corruptJobs) {
                try FileJobStore(root: root).load()
            }
            #expect(try Data(contentsOf: file) == Data(contents.utf8))
        }
    }

    @Test
    func `a job with an impossible time makes the whole file corrupt, not a shorter list`() throws {
        try StorageFixture.withTemporaryRoot { root in
            let sample = try #require(try String(
                bytes: StorageFixture.fixture(named: "jobs-v1"),
                encoding: .utf8,
            ))
            let damaged = sample.replacingOccurrences(of: #""hour" : 18"#, with: #""hour" : 24"#)
            #expect(damaged != sample)
            let file = try StorageFixture.write(damaged, to: "jobs.json", under: root)
            #expect(throws: StorageError.corruptJobs) {
                try FileJobStore(root: root).load()
            }
            #expect(try Data(contentsOf: file) == Data(damaged.utf8))
        }
    }

    @Test(arguments: [2, 99])
    func `a jobs.json from a newer version throws newerJobsVersion and is left byte-identical`(
        version: Int,
    ) throws {
        try StorageFixture.withTemporaryRoot { root in
            let contents = #"{"schemaVersion": \#(version), "jobs": [], "folders": []}"#
            let file = try StorageFixture.write(contents, to: "jobs.json", under: root)
            #expect(throws: StorageError.newerJobsVersion(schemaVersion: version)) {
                try FileJobStore(root: root).load()
            }
            #expect(try Data(contentsOf: file) == Data(contents.utf8))
        }
    }
}
