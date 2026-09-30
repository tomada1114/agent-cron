import AgentCronCore
import Foundation

extension LocalizationTests {
    /// Every resource the popover model returns, once per key, with the English
    /// arguments each takes.
    static func popoverCases() -> [Case] {
        let next = PopoverRow(
            id: "next",
            date: PopoverFixture.tuesday(PopoverFixture.nineHour, 0, plusDays: 1),
            timeText: "09:00",
            day: .tomorrow,
            badge: .upcoming,
            jobID: PopoverFixture.digest.id,
            jobName: "RSS digest",
            duration: nil,
            costUSD: nil,
            usesBypassPermissions: false,
        )
        let states: [PopoverEmptyState] = [
            .noJobs,
            .allPaused,
            .nothingToday(next: next, dayText: "Tomorrow"),
        ]
        return states.map { state in
            if case .nothingToday = state {
                return Case(resource: state.message, arguments: ["Tomorrow", "09:00", "RSS digest"])
            }
            return Case(resource: state.message, arguments: [])
        } + [
            Case(resource: PopoverBanner.agentNotFound, arguments: []),
            Case(resource: PopoverDay.tomorrow.label ?? PopoverBanner.agentNotFound, arguments: []),
        ] + KeepAwakeMode.menuOrder.map { Case(resource: $0.label, arguments: []) }
    }
}
