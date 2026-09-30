import Foundation

/// The one-line status a job list row and the editor's header show
/// (`docs/product/ux-flows.md` S2): running, paused, or when the job next runs.
extension JobListModel {
    /// Foundation numbers weekdays 1 (Sunday) to 7 (Saturday) in every calendar.
    private static let byCalendarWeekday: [Weekday] = [
        .sunday,
        .monday,
        .tuesday,
        .wednesday,
        .thursday,
        .friday,
        .saturday,
    ]

    /// `row`'s status, read against the model's clock and calendar: "Running",
    /// "Paused", "Next: today 18:00", "Next: tomorrow 09:00", "Next: Wed 09:00", or
    /// "Not scheduled" for an enabled job whose schedule never fires.
    ///
    /// Like ``rows``, read at the moment of asking; a view re-reads it on its own
    /// schedule.
    public func status(of row: JobListRow) -> LocalizedStringResource {
        if row.isRunning {
            return OutcomeBadgeKind.running.label
        }
        guard row.isEnabled else {
            return LocalizedStringResource(
                "jobStatus.paused",
                defaultValue: "Paused",
                bundle: .module,
                comment: "Job list row and job editor header status of a job whose Enabled switch is off.",
            )
        }
        guard let nextRun = row.nextRun else {
            return LocalizedStringResource(
                "jobStatus.notScheduled",
                defaultValue: "Not scheduled",
                bundle: .module,
                comment: "Job list row status of an enabled job whose schedule never fires.",
            )
        }
        return nextRunStatus(nextRun)
    }

    private func nextRunStatus(_ nextRun: Date) -> LocalizedStringResource {
        let time = TimeOfDay(pickedFrom: nextRun, in: calendar).hourMinuteText
        let today = calendar.startOfDay(for: now())
        let days = calendar.dateComponents(
            [.day],
            from: today,
            to: calendar.startOfDay(for: nextRun),
        )
        .day ?? 0
        switch days {
        case ...0:
            return LocalizedStringResource(
                "jobStatus.nextToday",
                defaultValue: "Next: today \(time)",
                bundle: .module,
                comment: "Job list row status: the job next runs later today. The argument is the time (\"18:00\").",
            )

        case 1:
            return LocalizedStringResource(
                "jobStatus.nextTomorrow",
                defaultValue: "Next: tomorrow \(time)",
                bundle: .module,
                comment: "Job list row status: the job next runs tomorrow. The argument is the time (\"09:00\").",
            )

        default:
            let index = calendar.component(.weekday, from: nextRun) - 1
            let day = Self.byCalendarWeekday[index % Self.byCalendarWeekday.count].shortName
            return LocalizedStringResource(
                "jobStatus.nextOnDay",
                defaultValue: "Next: \(day) \(time)",
                bundle: .module,
                comment: "Job list row status: the job next runs on a later day (\"Wed\") at a time (\"09:00\").",
            )
        }
    }
}
