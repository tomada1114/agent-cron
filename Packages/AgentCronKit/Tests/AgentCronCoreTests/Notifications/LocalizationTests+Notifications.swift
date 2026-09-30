import AgentCronCore
import Foundation

extension LocalizationTests {
    /// Every resource a notification's text is built from, once per key, with the English
    /// arguments each takes.
    static func notificationCases() -> [Case] {
        let titles = RunOutcome.allCases.compactMap { outcome in
            NotificationPolicy.title(for: outcome, jobName: "Nightly review")
        }
        return titles.map { Case(resource: $0, arguments: ["Nightly review"]) } + [
            Case(resource: NotificationPolicy.subtitle(time: "22:00"), arguments: ["22:00"]),
        ]
    }
}
