import Foundation

/// Which finished runs post a notification, and what it says (requirements §3.5,
/// ADR-0007, docs/product/ux-flows.md › S7).
///
/// Pure: it reads no clock, locale, or time zone of its own, so every rule is a Core test
/// away. The setting that decides is the one the run started with (its
/// ``JobSnapshot/notify``) — an edit saved while a job runs applies from its next run, and
/// a run of a job deleted since still knows its setting.
public enum NotificationPolicy {
    /// The most characters a notification's body keeps of the reason's or result's first
    /// line (docs/product/ux-flows.md › S7).
    public static let maximumBodyLength = 120

    /// Whether a finished run notifies under the setting it started with: every run under
    /// ``NotifyPolicy/everyRun``; a failed, timed-out, or skipped one under
    /// ``NotifyPolicy/failuresOnly``; none under ``NotifyPolicy/never``. A run still
    /// going has not finished, so it never does.
    public static func shouldNotify(for run: Run) -> Bool {
        switch run.outcome {
        case .running:
            false

        case .failed, .skipped, .timedOut:
            run.snapshot.notify != .never

        case .stopped, .succeeded:
            run.snapshot.notify == .everyRun
        }
    }

    /// The notification for `run`, whether or not ``shouldNotify(for:)`` says to post
    /// it, or `nil` while it is still running and so has nothing to report.
    ///
    /// - Parameters:
    ///   - locale: The language the title and subtitle are written in.
    ///   - calendar: Whose time zone the subtitle's time is told in.
    public static func content(
        for run: Run,
        locale: Locale,
        calendar: Calendar,
    ) -> NotificationContent? {
        guard let title = title(for: run.outcome, jobName: run.jobName) else {
            return nil
        }
        // A catch-up or skipped run is recorded after the time it was for; that time is
        // the one the user scheduled, and so the one that names the run.
        let time = run.scheduledAt ?? run.startedAt
        let clock = String(
            format: "%02d:%02d",
            calendar.component(.hour, from: time),
            calendar.component(.minute, from: time),
        )
        return NotificationContent(
            runID: run.id,
            title: resolved(title, in: locale),
            subtitle: resolved(subtitle(time: clock), in: locale),
            body: body(of: run),
        )
    }

    /// The title for a run of `jobName` that ended with `outcome`, one whole sentence per
    /// outcome so a translation can reorder it; `nil` for ``RunOutcome/running``.
    /// `package` so the localization tests can reach every key.
    package static func title(
        for outcome: RunOutcome,
        jobName: String,
    ) -> LocalizedStringResource? {
        switch outcome {
        case .running:
            nil

        case .failed:
            LocalizedStringResource(
                "notification.title.failed",
                defaultValue: "\(jobName) failed",
                bundle: .module,
                comment: "Notification title for a run that failed. The argument is the job's name.",
            )

        case .skipped:
            LocalizedStringResource(
                "notification.title.skipped",
                defaultValue: "\(jobName) was skipped",
                bundle: .module,
                comment: "Notification title for a scheduled run that did not start. The argument is the job's name.",
            )

        case .stopped:
            LocalizedStringResource(
                "notification.title.stopped",
                defaultValue: "\(jobName) was stopped",
                bundle: .module,
                comment: "Notification title for a run the user stopped. The argument is the job's name.",
            )

        case .succeeded:
            LocalizedStringResource(
                "notification.title.succeeded",
                defaultValue: "\(jobName) succeeded",
                bundle: .module,
                comment: "Notification title for a run that succeeded. The argument is the job's name.",
            )

        case .timedOut:
            LocalizedStringResource(
                "notification.title.timedOut",
                defaultValue: "\(jobName) timed out",
                bundle: .module,
                comment: "Notification title for a run stopped by its timeout. The argument is the job's name.",
            )
        }
    }

    /// The subtitle naming the time a run was for, `time` being "22:00". `package` so the
    /// localization tests can reach its key.
    package static func subtitle(time: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "notification.subtitle",
            defaultValue: "· \(time)",
            bundle: .module,
            comment: "Notification subtitle: the time the run was for, 24-hour (\"22:00\"), after a middle dot.",
        )
    }

    /// The first line of the run's reason, or of its result when it has no reason, cut
    /// to ``maximumBodyLength`` characters; empty when it has neither.
    private static func body(of run: Run) -> String {
        let text = [run.failureReason, run.resultText]
            .lazy
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
        let firstLine = text.prefix { !$0.isNewline }
            .trimmingCharacters(in: .whitespaces)
        return String(firstLine.prefix(maximumBodyLength))
    }

    private static func resolved(_ resource: LocalizedStringResource, in locale: Locale) -> String {
        var resource = resource
        resource.locale = locale
        return String(localized: resource)
    }
}
