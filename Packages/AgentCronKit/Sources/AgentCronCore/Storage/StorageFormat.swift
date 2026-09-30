import Foundation

/// Just enough of any version's file to read which version it is.
private struct VersionProbe: Decodable {
    let schemaVersion: Int
}

/// `jobs.json`, version 1.
private struct JobsFile: Codable {
    let schemaVersion: Int
    let lastCheckedAt: Date?
    let jobs: [Job]
}

/// A run file, version 1: the run's fields and `schemaVersion` side by side in one
/// object, rather than the run nested under a key.
private struct RunFile: Codable {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion
    }

    let run: Run

    init(run: Run) {
        self.run = run
    }

    /// Reads the run's fields; the caller has already checked `schemaVersion`.
    init(from decoder: any Decoder) throws {
        run = try Run(from: decoder)
    }

    /// Writes `schemaVersion`, then the run's fields into the same object — a
    /// `JSONEncoder` hands both requests for a keyed container the one object.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(StorageFormat.currentSchemaVersion, forKey: .schemaVersion)
        try run.encode(to: encoder)
    }
}

/// The on-disk format ADR-0005 fixes, in one place: how the JSON is written, which
/// `schemaVersion` this build writes and reads, and how run files are named.
///
/// A file format is contract (`docs/architecture.md` › What is contract and what is
/// private): a later build must still read what this one wrote. The checked-in samples
/// under `Tests/AgentCronCoreTests/Fixtures/` pin the bytes; a format change adds a new
/// version here that still decodes the old one, with a test that starts from its sample.
enum StorageFormat {
    /// The `schemaVersion` this build writes, and the newest it reads.
    static let currentSchemaVersion = 1

    /// Dates are ISO-8601 in UTC with milliseconds; a finer fraction is dropped.
    private static let dateStyle = Date.ISO8601FormatStyle(
        includingFractionalSeconds: true,
        timeZone: .gmt,
    )

    /// A run file's name carries its start to the whole second, dropping the fraction.
    private static let fileNameDateStyle = Date.ISO8601FormatStyle(timeZone: .gmt)

    /// The length of `YYYY-MM-DDTHH:MM:SSZ`, the start at the head of a run file's name.
    private static let fileNameDateLength = 20

    /// Pretty-printed with sorted keys, so a file reads well and the same value always
    /// writes the same bytes.
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(dateStyle))
        }
        return encoder
    }

    /// Reads what ``encoder()`` writes, and a date written without a fraction of a second.
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = try? Date(text, strategy: dateStyle) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "not an ISO-8601 date",
                )
            }
            return date
        }
        return decoder
    }

    /// The `schemaVersion` a file declares, or `nil` when it is not a JSON object with a
    /// whole-number one.
    static func schemaVersion(of data: Data) -> Int? {
        try? JSONDecoder().decode(VersionProbe.self, from: data).schemaVersion
    }

    // MARK: - jobs.json

    /// Decodes `jobs.json`, refusing a version this build does not know.
    static func decodeJobs(_ data: Data) throws(StorageError) -> JobsDocument {
        guard let version = schemaVersion(of: data), version >= 1 else {
            throw .corruptJobs
        }
        guard version <= currentSchemaVersion else {
            throw .newerJobsVersion(schemaVersion: version)
        }
        // Version 1 is the only one so far; a version 2 decodes a version-1 file here
        // and migrates it.
        do {
            let file = try decoder().decode(JobsFile.self, from: data)
            return JobsDocument(jobs: file.jobs, lastCheckedAt: file.lastCheckedAt)
        } catch {
            throw .corruptJobs
        }
    }

    /// Encodes `document` as the current version of `jobs.json`.
    static func encodeJobs(_ document: JobsDocument) throws -> Data {
        try encoder().encode(JobsFile(
            schemaVersion: currentSchemaVersion,
            lastCheckedAt: document.lastCheckedAt,
            jobs: document.jobs,
        ))
    }

    // MARK: - Run files

    /// Decodes a run file, or says why it cannot.
    static func decodeRun(_ data: Data) -> Result<Run, SkippedRunFile.Reason> {
        guard let version = schemaVersion(of: data), version >= 1 else {
            return .failure(.undecodable)
        }
        guard version <= currentSchemaVersion else {
            return .failure(.newerVersion(schemaVersion: version))
        }
        do {
            return try .success(decoder().decode(RunFile.self, from: data).run)
        } catch {
            return .failure(.undecodable)
        }
    }

    /// Encodes `run` as the current version of a run file: the run's own fields with
    /// `schemaVersion` beside them.
    static func encodeRun(_ run: Run) throws -> Data {
        try encoder().encode(RunFile(run: run))
    }

    /// The folder a run starting at `date` is filed under: its UTC month, `YYYY-MM`.
    static func monthFolderName(for date: Date) -> String {
        date.formatted(fileNameDateStyle.year().month())
    }

    /// Whether `name` is a month folder's: exactly what ``monthFolderName(for:)`` writes
    /// for the first instant of some month, so `2026-13` and `2026-1` are not.
    static func isMonthFolderName(_ name: String) -> Bool {
        guard let start = try? Date("\(name)-01T00:00:00Z", strategy: fileNameDateStyle) else {
            return false
        }
        return monthFolderName(for: start) == name
    }

    /// `<start, to the second, UTC>-<run id>.json`: sorts by start within a month folder,
    /// and the id keeps two runs started in the same second apart.
    static func fileName(for run: Run) -> String {
        "\(run.startedAt.formatted(fileNameDateStyle))-\(run.id.uuidString).json"
    }

    /// The start a run file's name gives, to the whole second — its run started in the
    /// second that follows — or `nil` when the name does not begin with one.
    static func startSecond(ofFileNamed name: String) -> Date? {
        guard name.count > fileNameDateLength else {
            return nil
        }
        return try? Date(String(name.prefix(fileNameDateLength)), strategy: fileNameDateStyle)
    }
}
