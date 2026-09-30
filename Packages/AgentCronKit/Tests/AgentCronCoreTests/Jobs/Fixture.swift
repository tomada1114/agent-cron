import AgentCronCore
import Foundation

/// Fixed inputs shared by the Job and Run suites, so no test reads the clock or draws a
/// random identifier.
enum Fixture {
    static let jobID = UUID(uuidString: "11111111-2222-3333-4444-555555555555") ?? UUID()
    static let runID = UUID(uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA") ?? UUID()
    static let createdAtSeconds: TimeInterval = 1_700_000_000
    static let updatedAtSeconds: TimeInterval = 1_700_003_600.25
    static let createdAt = Date(timeIntervalSince1970: createdAtSeconds)
    static let updatedAt = Date(timeIntervalSince1970: updatedAtSeconds)
    static let directory = URL(filePath: "/Users/example/news-digest", directoryHint: .isDirectory)
    static let name = "RSS digest"
    static let prompt = "Summarize today's feeds into news.html."
    static let nineOClock = 9

    /// A schedule every rule accepts: weekdays at 09:00.
    static let schedule = Schedule(
        weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday],
        times: [time(nineOClock, 0)],
    )

    /// A time the test knows is in range; a failure names the bad literal.
    static func time(_ hour: Int, _ minute: Int) -> TimeOfDay {
        do {
            return try TimeOfDay(hour: hour, minute: minute)
        } catch {
            preconditionFailure("fixture time \(hour):\(minute) is out of range")
        }
    }

    /// A job every rule accepts, built with only the required arguments so every other
    /// field takes its default.
    static func job() -> Job {
        Job(
            name: name,
            directory: directory,
            prompt: prompt,
            schedule: schedule,
            createdAt: createdAt,
            id: jobID,
        )
    }

    /// Encodes `value` with a default `JSONEncoder` and decodes it back.
    static func roundTrip<T: Codable>(_ value: T) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
    }
}
