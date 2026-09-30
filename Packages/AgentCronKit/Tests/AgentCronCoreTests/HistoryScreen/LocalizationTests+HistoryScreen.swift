import AgentCronCore
import Foundation

extension LocalizationTests {
    /// Every resource the History screen's model returns, once per key, with the English
    /// arguments each takes.
    static func historyScreenCases() -> [Case] {
        let start = Date(timeIntervalSince1970: 0)
        let short = TimeInterval(HistoryFixture.shortSeconds)
        let long = TimeInterval(
            HistoryFixture.longMinutes * HistoryFixture.secondsPerMinute + HistoryFixture
                .longRemainder,
        )
        var cases = HistoryOutcomeFilter.allCases.map { Case(resource: $0.title, arguments: []) }
        cases += RunTrigger.allCases.map { trigger in
            Case(resource: HistoryFormatting.trigger(trigger), arguments: [])
        }
        cases += SkipReason.allCases.map { Case(resource: $0.title, arguments: []) }
        cases += screenTextCases()
        return cases + [
            Case(
                resource: HistoryJobFilterOption(id: UUID(), name: "Digest", isDeleted: true).title,
                arguments: ["Digest"],
            ),
            Case(
                resource: HistoryJobFilterOption(id: UUID(), name: "Digest", isDeleted: false)
                    .title,
                arguments: ["Digest"],
            ),
            Case(resource: HistoryEmptyState.noRuns.message, arguments: []),
            Case(resource: HistoryEmptyState.noMatches.message, arguments: []),
            Case(
                resource: HistoryFormatting.duration(from: start, to: start + short),
                arguments: [HistoryFixture.shortSeconds],
            ),
            Case(
                resource: HistoryFormatting.duration(from: start, to: start + long),
                arguments: [HistoryFixture.longMinutes, HistoryFixture.longRemainder],
            ),
        ] + dayTitleCases()
    }

    /// The screen's fixed wording.
    private static func screenTextCases() -> [Case] {
        [
            HistoryScreenText.openJobs, HistoryScreenText.clearFilters, HistoryScreenText.allJobs,
            HistoryScreenText.jobFilterLabel, HistoryScreenText.outcomeFilterLabel,
            HistoryScreenText.noSelection, HistoryScreenText.result, HistoryScreenText.raw,
            HistoryScreenText.copy, HistoryScreenText.prompt, HistoryScreenText.stop,
            HistoryScreenText.openJob, HistoryScreenText.resultPending,
            HistoryScreenText.noResult, HistoryScreenText.reason, HistoryScreenText.trigger,
            HistoryScreenText.scheduled, HistoryScreenText.started, HistoryScreenText.duration,
            HistoryScreenText.elapsed, HistoryScreenText.cost, HistoryScreenText.exitCode,
            HistoryScreenText.directory, HistoryScreenText.model, HistoryScreenText.effort,
            HistoryScreenText.permission, HistoryScreenText.session,
        ].map { Case(resource: $0, arguments: []) }
    }

    /// A day group title for today, yesterday, and an older day.
    private static func dayTitleCases() -> [Case] {
        let calendar = HistoryFixture.calendar
        let now = HistoryFixture.now
        let days: [(Date, [any CVarArg])] = [
            (calendar.startOfDay(for: now), []),
            (HistoryFixture.yesterday, []),
            (HistoryFixture.olderDay, ["Sep 1, 2026"]),
        ]
        return days.map { day, arguments in
            Case(
                resource: HistoryFormatting.dayTitle(
                    day,
                    now: now,
                    calendar: calendar,
                    locale: .english,
                ),
                arguments: arguments,
            )
        }
    }
}
