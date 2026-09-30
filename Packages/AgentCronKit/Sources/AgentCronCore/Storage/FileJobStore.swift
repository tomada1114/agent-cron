import Foundation

/// ``JobStoring`` over `jobs.json` in a folder — Application Support in the app
/// (``StorageLocation``), a temporary folder in a test.
///
/// Foundation file I/O in Core, as ADR-0005 allows: it needs no framework Core may not
/// import, and the coverage floor sees every branch. The file is
/// `{"schemaVersion": 1, "lastCheckedAt": …, "jobs": […]}`, pretty-printed with sorted
/// keys; `lastCheckedAt` is left out until there is one.
public struct FileJobStore: JobStoring {
    /// The folder `jobs.json` lives in; created by the first save.
    public let root: URL

    private var fileURL: URL {
        root.appending(path: "jobs.json", directoryHint: .notDirectory)
    }

    /// A store over `jobs.json` in `root`.
    public init(root: URL) {
        self.root = root
    }

    /// Reads `jobs.json`, answering an empty document when there is none yet.
    ///
    /// A file that does not decode, or that a newer version wrote, throws and is left
    /// exactly as it is: the caller stops rather than saving over the user's jobs.
    public func load() throws(StorageError) -> JobsDocument {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch CocoaError.fileReadNoSuchFile {
            return JobsDocument()
        } catch {
            throw .readFailed(code: (error as NSError).code)
        }
        return try StorageFormat.decodeJobs(data)
    }

    /// Writes `document` atomically — to a temporary file, then moved over `jobs.json` —
    /// so a crash mid-save leaves the previous file whole, never half a new one.
    public func save(_ document: JobsDocument) throws(StorageError) {
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try StorageFormat.encodeJobs(document).write(to: fileURL, options: .atomic)
        } catch {
            throw .writeFailed(code: (error as NSError).code)
        }
    }
}
