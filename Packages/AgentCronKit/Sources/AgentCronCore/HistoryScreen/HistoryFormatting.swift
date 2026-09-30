import Foundation

/// The History screen's text for durations, costs, triggers, and day titles.
public enum HistoryFormatting {
    private static let secondsPerMinute = 60
    private static let secondsPerHour = 3_600

    /// A running run's elapsed time as a clock: "4:12", or "1:04:12" from an hour on.
    /// Fractions of a second are dropped, and a start in the future reads "0:00".
    public static func elapsed(from start: Date, to now: Date) -> String {
        let total = max(0, Int(now.timeIntervalSince(start)))
        let hours = total / secondsPerHour
        let minutes = total % secondsPerHour / secondsPerMinute
        let seconds = total % secondsPerMinute
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// `date`'s time of day, "09:00", in `locale` and `calendar`'s time zone.
    public static func time(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        style.locale = locale
        return date.formatted(style)
    }

    /// `date` with its time to the second, "Sep 30, 2026 at 9:00:02 AM" in English, in
    /// `locale` and `calendar`'s time zone.
    public static func dateTime(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        var style = Date.FormatStyle(date: .abbreviated, time: .standard)
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        style.locale = locale
        return date.formatted(style)
    }

    /// "2m 14s" for 134 seconds, "42s" under a minute; fractions of a second are dropped.
    public static func duration(from start: Date, to end: Date) -> LocalizedStringResource {
        let total = max(0, Int(end.timeIntervalSince(start)))
        let minutes = total / secondsPerMinute
        let seconds = total % secondsPerMinute
        if minutes == 0 {
            return LocalizedStringResource(
                "history.duration.seconds",
                defaultValue: "\(seconds)s",
                bundle: .module,
                comment: "A run's duration under a minute. The argument is seconds.",
            )
        }
        return LocalizedStringResource(
            "history.duration.minutesSeconds",
            defaultValue: "\(minutes)m \(seconds)s",
            bundle: .module,
            comment: "A run's duration. The arguments are minutes and seconds.",
        )
    }

    /// `amount` as US dollars in `locale`, "$0.42" in English.
    public static func cost(_ amount: Decimal, locale: Locale) -> String {
        amount.formatted(.currency(code: "USD").locale(locale))
    }

    /// How a run was started, for the detail pane.
    public static func trigger(_ trigger: RunTrigger) -> LocalizedStringResource {
        switch trigger {
        case .scheduled:
            LocalizedStringResource(
                "history.trigger.scheduled",
                defaultValue: "Scheduled",
                bundle: .module,
                comment: "History detail: the run was started by its schedule.",
            )

        case .manual:
            LocalizedStringResource(
                "history.trigger.manual",
                defaultValue: "Run Now",
                bundle: .module,
                comment: "History detail: the run was started by the user with Run Now.",
            )

        case .catchUp:
            LocalizedStringResource(
                "history.trigger.catchUp",
                defaultValue: "Catch-up",
                bundle: .module,
                comment: "History detail: the run made up a time missed while the Mac slept.",
            )
        }
    }

    /// "Today", "Yesterday", or the date of the day starting at `day`, relative to `now`;
    /// the date is formatted in `locale` and `calendar`'s time zone.
    public static func dayTitle(
        _ day: Date,
        now: Date,
        calendar: Calendar,
        locale: Locale,
    ) -> LocalizedStringResource {
        let today = calendar.startOfDay(for: now)
        if day == today {
            return LocalizedStringResource(
                "history.group.today",
                defaultValue: "Today",
                bundle: .module,
                comment: "History day group title for today's runs.",
            )
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), day == yesterday {
            return LocalizedStringResource(
                "history.group.yesterday",
                defaultValue: "Yesterday",
                bundle: .module,
                comment: "History day group title for yesterday's runs.",
            )
        }
        var style = Date.FormatStyle(date: .abbreviated, time: .omitted)
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        style.locale = locale
        let date = day.formatted(style)
        return LocalizedStringResource(
            "history.group.date",
            defaultValue: "\(date)",
            bundle: .module,
            comment: "History day group title for an older day. The argument is the date.",
        )
    }
}
