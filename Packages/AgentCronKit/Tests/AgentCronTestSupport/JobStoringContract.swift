import AgentCronCore
import Foundation
import Testing

/// The promises ``AgentCronCore/JobStoring`` makes, checked against any implementation of
/// it (`.claude/rules/testing.md` › One Contract Suite per Port).
///
/// `AgentCronCoreTests` runs it against ``FakeJobStore`` and against `FileJobStore` in a
/// temporary folder, on every `just test` and in CI. Every clause is one the port's `///`
/// states; a new clause is stated there first.
package enum JobStoringContract {
    /// 2026-09-28T08:00:00.000Z
    private static let createdSeconds: TimeInterval = 1_790_582_400
    /// 2026-09-29T12:34:56.250Z
    private static let updatedSeconds: TimeInterval = 1_790_685_296.25
    private static let createdAt = Date(timeIntervalSince1970: createdSeconds)
    private static let updatedAt = Date(timeIntervalSince1970: updatedSeconds)

    /// A description of every broken promise, empty when `store` keeps them all.
    ///
    /// `store` must be fresh — nothing ever saved to it — and is saved to. Separate from
    /// ``check(_:)`` so a test can hand it a store that breaks a promise and see the
    /// contract notice — the proof it is not vacuous.
    package static func violations(of store: some JobStoring) -> [String] {
        var broken: [String] = []

        func load(_ moment: String, expecting expected: JobsDocument) {
            do {
                let loaded = try store.load()
                if loaded != expected {
                    broken.append("\(moment): load() answered \(difference(loaded, expected))")
                }
            } catch {
                broken.append("\(moment): load() threw \(error)")
            }
        }

        func save(_ document: JobsDocument, _ moment: String) -> Bool {
            do {
                try store.save(document)
                return true
            } catch {
                broken.append("\(moment): save(_:) threw \(error)")
                return false
            }
        }

        // Clause 1.
        load("before any save", expecting: JobsDocument())
        // Clause 2.
        let full = sampleDocument()
        if save(full, "saving two jobs") {
            load("after saving two jobs", expecting: full)
        }
        // Clause 3: fewer jobs, and no last check where there was one.
        let replacement = JobsDocument(jobs: [full.jobs[1]])
        if save(replacement, "saving one job over two") {
            load("after saving one job over two", expecting: replacement)
        }
        return broken
    }

    /// Records an issue for every promise `store` breaks.
    package static func check(_ store: some JobStoring) {
        let broken = violations(of: store)
        #expect(broken.isEmpty, "\(type(of: store)) breaks the JobStoring contract: \(broken)")
    }

    private static func difference(_ loaded: JobsDocument, _ expected: JobsDocument) -> String {
        let answered = summary(of: loaded)
        let wanted = summary(of: expected)
        guard answered != wanted else {
            return "a document whose jobs differ from those saved"
        }
        return "\(answered), expected \(wanted)"
    }

    private static func summary(of document: JobsDocument) -> String {
        "\(document.jobs.count) jobs, last checked \(document.lastCheckedAt == nil ? "nil" : "set")"
    }

    /// Two jobs — one with every default, one with every option changed — and a last
    /// check, every date a whole number of milliseconds (clause 2's precision).
    private static func sampleDocument() -> JobsDocument {
        let lastMinute = (try? TimeOfDay(
            hour: TimeOfDay.hours.upperBound,
            minute: TimeOfDay.minutes.upperBound,
        )).map { [$0] } ?? []
        let schedule = Schedule(weekdays: [.saturday, .monday], times: lastMinute)
        let plain = Job(
            name: "Contract plain",
            directory: URL(filePath: "/tmp/contract", directoryHint: .isDirectory),
            prompt: "Say hello.",
            schedule: schedule,
            createdAt: createdAt,
        )
        let changed = Job(
            name: "Contract changed",
            directory: URL(filePath: "/tmp/contract dir/ünïcode", directoryHint: .isDirectory),
            prompt: "Line one.\nLine two — \"quoted\".",
            schedule: schedule,
            createdAt: createdAt,
            model: .haiku,
            effort: .max,
            permissionMode: .bypassPermissions,
            timeoutMinutes: Job.timeoutMinutesRange.upperBound,
            notify: .never,
            enabled: false,
            updatedAt: updatedAt,
        )
        return JobsDocument(jobs: [plain, changed], lastCheckedAt: updatedAt)
    }
}
