import AgentCronCore
import Foundation

extension LocalizationTests {
    /// Every resource a notification's text is built from, once per key, with the English
    /// arguments each takes.
    static func notificationCases() -> [Case] {
        let missedCount = 14
        let titles = RunOutcome.allCases.compactMap { outcome in
            NotificationPolicy.title(for: outcome, jobName: "Nightly review")
        }
        return titles.map { Case(resource: $0, arguments: ["Nightly review"]) } + [
            Case(resource: NotificationPolicy.subtitle(time: "22:00"), arguments: ["22:00"]),
            Case(
                resource: NotificationPolicy.missedTitle(
                    count: missedCount,
                    jobName: "Nightly review",
                ),
                arguments: [missedCount, "Nightly review"],
            ),
        ]
    }
}
