import Foundation

/// A run file ``FileRunStore`` could not read back, as it reports one.
///
/// Only the month folder and the reason: a run file holds the user's prompt, directory,
/// and result, so nothing from inside it — nor its path — reaches a log.
package struct SkippedRunFile: Equatable, Sendable {
    /// Why a run file was skipped.
    package enum Reason: Error, Equatable, Sendable {
        /// A newer version wrote it; `schemaVersion` is the version it declares.
        case newerVersion(schemaVersion: Int)
        /// It is not a run file: not JSON, no usable `schemaVersion`, or a run that does
        /// not decode.
        case undecodable
        /// The file system refused to read it; `code` is the Cocoa error code.
        case unreadable(code: Int)
    }

    /// The `YYYY-MM` folder it is in.
    package let month: String
    /// Why it was skipped.
    package let reason: Reason

    /// The log line for it, safe to write publicly: a month and a reason, nothing more.
    package var summary: String {
        let because = switch reason {
        case let .newerVersion(schemaVersion):
            "written by a newer version (schema \(schemaVersion))"

        case .undecodable:
            "does not decode"

        case let .unreadable(code):
            "unreadable (Cocoa error \(code))"
        }
        return "skipped a run file in \(month): \(because)"
    }

    package init(month: String, reason: Reason) {
        self.month = month
        self.reason = reason
    }

    /// Writes ``summary`` to ``AppLog/storage`` — what the app does with a skipped file.
    package static func log(_ file: Self) {
        AppLog.storage.error("\(file.summary, privacy: .public)")
    }
}

/// ``RunStoring`` over one JSON file per run under `runs/` in a folder — Application
/// Support in the app (``StorageLocation``), a temporary folder in a test.
///
/// A run starting at 2026-10-05T09:00:02.5Z is `runs/2026-10/2026-10-05T09:00:02Z-<id>.json`:
/// filed by its UTC month, named by its start to the second and its id, holding the
/// run's fields beside `schemaVersion`. A file that cannot be read back is skipped and
/// logged, never allowed to hide the runs around it (ADR-0005).
public struct FileRunStore: RunStoring {
    /// The folder `runs/` lives in; created by the first save.
    public let root: URL

    private let reportSkipped: @Sendable (SkippedRunFile) -> Void

    private var runsFolder: URL {
        root.appending(path: "runs", directoryHint: .isDirectory)
    }

    /// A store over `runs/` in `root` that logs each file it skips to ``AppLog/storage``.
    public init(root: URL) {
        self.init(root: root, reportSkipped: SkippedRunFile.log)
    }

    /// A store that hands each file it skips to `reportSkipped` instead of the log.
    package init(root: URL, reportSkipped: @escaping @Sendable (SkippedRunFile) -> Void) {
        self.root = root
        self.reportSkipped = reportSkipped
    }

    /// Writes `run` atomically to its file, replacing an earlier save of the same run.
    public func save(_ run: Run) throws(StorageError) {
        let folder = runsFolder.appending(
            path: StorageFormat.monthFolderName(for: run.startedAt),
            directoryHint: .isDirectory,
        )
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try StorageFormat.encodeRun(run).write(
                to: folder.appending(path: StorageFormat.fileName(for: run)),
                options: .atomic,
            )
        } catch {
            throw .writeFailed(code: (error as NSError).code)
        }
    }

    /// Reads only the month folders `interval` spans, and within them only the files
    /// whose names say they could have started in it.
    public func runs(in interval: DateInterval) throws(StorageError) -> [Run] {
        let firstMonth = StorageFormat.monthFolderName(for: interval.start)
        let lastMonth = StorageFormat.monthFolderName(for: interval.end)
        var found: [Run] = []
        for month in try monthFolders() where firstMonth <= month && month <= lastMonth {
            for file in try runFiles(inMonth: month) where mayStart(file, in: interval) {
                switch read(file) {
                case let .success(run):
                    if interval.start <= run.startedAt, run.startedAt < interval.end {
                        found.append(run)
                    }

                case let .failure(reason):
                    reportSkipped(SkippedRunFile(month: month, reason: reason))
                }
            }
        }
        return found.sorted { lhs, rhs in
            (lhs.startedAt, lhs.id.uuidString) < (rhs.startedAt, rhs.id.uuidString)
        }
    }

    /// Removes the older run files month by month, then any month folder left empty.
    ///
    /// A file's name decides unless the cutoff falls inside the second it names, when
    /// its contents do. So a file that no longer decodes is still removed once its name
    /// shows it is plainly past the cutoff, and is kept whenever that is in doubt.
    public func deleteRuns(olderThan cutoff: Date) throws(StorageError) -> Int {
        let lastMonth = StorageFormat.monthFolderName(for: cutoff)
        var removed = 0
        for month in try monthFolders() where month <= lastMonth {
            for file in try runFiles(inMonth: month) where startedBefore(cutoff, file: file) {
                try remove(file)
                removed += 1
            }
            try removeIfEmpty(runsFolder.appending(path: month, directoryHint: .isDirectory))
        }
        return removed
    }

    // MARK: - Folders and files

    /// The month folders under `runs/`, oldest first; none when there is no `runs/` yet.
    private func monthFolders() throws(StorageError) -> [String] {
        let entries: [URL]
        do {
            entries = try FileManager.default.contentsOfDirectory(
                at: runsFolder,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsHiddenFiles,
            )
        } catch CocoaError.fileReadNoSuchFile {
            return []
        } catch {
            throw .readFailed(code: (error as NSError).code)
        }
        return entries
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map(\.lastPathComponent)
            .filter(StorageFormat.isMonthFolderName)
            .sorted()
    }

    /// The `.json` files in a month folder.
    private func runFiles(inMonth month: String) throws(StorageError) -> [URL] {
        do {
            return try FileManager.default.contentsOfDirectory(
                at: runsFolder.appending(path: month, directoryHint: .isDirectory),
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles,
            )
            .filter { $0.pathExtension == "json" }
        } catch {
            throw .readFailed(code: (error as NSError).code)
        }
    }

    private func read(_ file: URL) -> Result<Run, SkippedRunFile.Reason> {
        let data: Data
        do {
            data = try Data(contentsOf: file)
        } catch {
            return .failure(.unreadable(code: (error as NSError).code))
        }
        return StorageFormat.decodeRun(data)
    }

    /// Whether the run in `file` could have started in `interval`, judging by its name
    /// alone: `false` only when the second it names lies wholly outside. A name that
    /// gives no start cannot rule the file out.
    private func mayStart(_ file: URL, in interval: DateInterval) -> Bool {
        guard let second = StorageFormat.startSecond(ofFileNamed: file.lastPathComponent) else {
            return true
        }
        return second < interval.end && interval.start < second.addingTimeInterval(1)
    }

    private func startedBefore(_ cutoff: Date, file: URL) -> Bool {
        if let second = StorageFormat.startSecond(ofFileNamed: file.lastPathComponent) {
            if second.addingTimeInterval(1) <= cutoff {
                return true
            }
            if cutoff <= second {
                return false
            }
        }
        guard case let .success(run) = read(file) else {
            return false
        }
        return run.startedAt < cutoff
    }

    private func remove(_ item: URL) throws(StorageError) {
        do {
            try FileManager.default.removeItem(at: item)
        } catch {
            throw .writeFailed(code: (error as NSError).code)
        }
    }

    /// Removes `folder` when nothing at all — hidden files included — is left in it.
    private func removeIfEmpty(_ folder: URL) throws(StorageError) {
        let leftovers: [String]
        do {
            leftovers = try FileManager.default.contentsOfDirectory(
                atPath: folder.path(percentEncoded: false),
            )
        } catch {
            throw .readFailed(code: (error as NSError).code)
        }
        if leftovers.isEmpty {
            try remove(folder)
        }
    }
}
