import Foundation

extension TimeOfDay {
    /// The time as `HH:mm` on a 24-hour clock — the form requirements §3.2 gives
    /// schedule times in, whatever the reader's locale.
    var hourMinuteText: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

extension Schedule {
    /// The whole schedule in one line, as the job editor shows it under Times:
    /// "Weekdays at 09:00, 12:00, 18:00". `nil` while the schedule has no day or no time,
    /// which the editor reports as a validation error instead.
    public var summary: LocalizedStringResource? {
        guard let days = daysName, !times.isEmpty else {
            return nil
        }
        let timeList = times.map(\.hourMinuteText).joined(separator: ", ")
        return LocalizedStringResource(
            "scheduleSummary.full",
            defaultValue: "\(days) at \(timeList)",
            bundle: .module,
            comment: "Job editor schedule summary: the days (\"Weekdays\") at the times (\"09:00, 12:00\").",
        )
    }

    /// The schedule shortened for a job list row: the days, the first time, and how many
    /// more times follow — "Weekdays 09:00 +2". `nil` while the schedule has no day or no
    /// time.
    public var compactSummary: LocalizedStringResource? {
        guard let days = daysName, let first = times.first?.hourMinuteText else {
            return nil
        }
        let more = times.count - 1
        guard more > 0 else {
            return LocalizedStringResource(
                "scheduleSummary.compact",
                defaultValue: "\(days) \(first)",
                bundle: .module,
                comment: "Job list row schedule with one time: the days (\"Weekdays\"), the time (\"09:00\").",
            )
        }
        return LocalizedStringResource(
            "scheduleSummary.compactMore",
            defaultValue: "\(days) \(first) +\(more)",
            bundle: .module,
            comment: "Job list row schedule: the days, the earliest time (\"09:00\"), how many times follow.",
        )
    }

    /// The preset's name when the days are exactly a preset's, otherwise the days'
    /// abbreviations Monday first; `nil` when there is no day. `package` so the
    /// localization tests can reach the list form's own key.
    package var daysName: LocalizedStringResource? {
        guard !weekdays.isEmpty else {
            return nil
        }
        if let preset = SchedulePreset.allCases.first(where: { $0.weekdays == weekdays }) {
            return preset.title
        }
        let names = weekdays.sorted().map(\.shortName)
        return LocalizedStringResource(
            "scheduleSummary.days",
            defaultValue: "\(names, format: .list(type: .and, width: .narrow))",
            bundle: .module,
            comment: "Days matching no preset in a schedule summary: their abbreviations as a list (\"Mon, Wed\").",
        )
    }
}
