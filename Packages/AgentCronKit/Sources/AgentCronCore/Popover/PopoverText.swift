import Foundation

/// The popover's fixed copy and the formatting of its row values
/// (`docs/product/ux-flows.md` S1, `docs/design/ux-guidelines.md` › States), so the view
/// renders strings rather than deciding how a time or a price reads.
public enum PopoverText {
    private static let secondsPerMinute = 60
    private static let secondsPerHour = 3_600
    private static let centDigits = 2

    /// The banner's button that shows the failed runs in History.
    public static var view: LocalizedStringResource {
        LocalizedStringResource(
            "popover.banner.view",
            defaultValue: "View",
            bundle: .module,
            comment: "Button in the menu-bar popover's failure banner that opens History.",
        )
    }

    /// The agent-not-found banner's button.
    public static var openGeneral: LocalizedStringResource {
        LocalizedStringResource(
            "popover.banner.openGeneral",
            defaultValue: "Open General",
            bundle: .module,
            comment: "Button in the menu-bar popover's agent-not-found banner that opens General.",
        )
    }

    /// The no-jobs empty state's button.
    public static var createFirstJob: LocalizedStringResource {
        LocalizedStringResource(
            "popover.empty.createFirstJob",
            defaultValue: "Create your first job",
            bundle: .module,
            comment: "Button in the menu-bar popover when no job is saved; opens a new job.",
        )
    }

    /// The all-paused empty state's button.
    public static var openJobs: LocalizedStringResource {
        LocalizedStringResource(
            "popover.empty.openJobs",
            defaultValue: "Open Jobs",
            bundle: .module,
            comment: "Button in the menu-bar popover when every job is paused; opens Jobs.",
        )
    }

    /// The heading above today's rows.
    public static var today: LocalizedStringResource {
        LocalizedStringResource(
            "popover.day.today",
            defaultValue: "Today",
            bundle: .module,
            comment: "Heading above today's rows in the menu-bar popover's timeline.",
        )
    }

    /// The keep-awake control's label.
    public static var keepAwake: LocalizedStringResource {
        LocalizedStringResource(
            "popover.keepAwake.title",
            defaultValue: "Keep awake",
            bundle: .module,
            comment: "Label of the keep-awake menu in the menu-bar popover.",
        )
    }

    /// The footer's button that opens a new job.
    public static var newJob: LocalizedStringResource {
        LocalizedStringResource(
            "popover.footer.newJob",
            defaultValue: "New Job",
            bundle: .module,
            comment: "Button in the menu-bar popover's footer that opens a new job.",
        )
    }

    /// The footer's Quit command.
    public static var quit: LocalizedStringResource {
        LocalizedStringResource(
            "popover.footer.quit",
            defaultValue: "Quit",
            bundle: .module,
            comment: "Button in the menu-bar popover's footer that quits the app.",
        )
    }

    /// The failure banner for `count` unseen failures, plural in the catalog.
    public static func failureBanner(count: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "popover.banner.failures",
            defaultValue: "\(count) failed runs since you last looked.",
            bundle: .module,
            comment: "Menu-bar popover banner for failed runs the user has not seen. The argument is the count.",
        )
    }

    /// The Stop button's accessibility label on a running row.
    public static func stop(jobName: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "popover.row.stop",
            defaultValue: "Stop \(jobName)",
            bundle: .module,
            comment: "Accessibility label of the Stop button on a running row. The argument is the job's name.",
        )
    }

    /// How long a timed keep-awake choice has left, e.g. "(3:59 left)".
    public static func remaining(_ duration: Duration) -> LocalizedStringResource {
        let text = clockText(duration, showsSeconds: false)
        return LocalizedStringResource(
            "popover.keepAwake.remaining",
            defaultValue: "(\(text) left)",
            bundle: .module,
            comment: "Time left on a timed keep-awake choice in the menu-bar popover. The argument is hours:minutes.",
        )
    }

    /// How long a running run has run, `m:ss`, or `h:mm:ss` from an hour.
    public static func elapsed(since start: Date, now: Date) -> String {
        clockText(.seconds(max(now.timeIntervalSince(start), 0)), showsSeconds: true)
    }

    /// A finished run's duration in one narrow unit, e.g. "2m" or "45s".
    public static func duration(_ duration: Duration, locale: Locale) -> String {
        duration.formatted(
            .units(allowed: [.hours, .minutes, .seconds], width: .narrow, maximumUnitCount: 1)
                .locale(locale),
        )
    }

    /// A cost in US dollars with cents, e.g. "$0.12".
    public static func cost(_ amount: Decimal, locale: Locale) -> String {
        amount.formatted(
            .currency(code: "USD").precision(.fractionLength(centDigits)).locale(locale),
        )
    }

    /// `h:mm` (or `h:mm:ss`, or `m:ss` under an hour, when `showsSeconds`).
    private static func clockText(_ duration: Duration, showsSeconds: Bool) -> String {
        let total = Int(duration.components.seconds)
        let hours = total / secondsPerHour
        let minutes = total % secondsPerHour / secondsPerMinute
        let seconds = total % secondsPerMinute
        guard showsSeconds else {
            return String(format: "%d:%02d", hours, minutes)
        }
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
