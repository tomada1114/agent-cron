import Foundation

/// Which finished runs of a job post a notification.
///
/// A failure, for ``failuresOnly``, is a run that failed, timed out, or was skipped
/// (requirements §3.5). Cases are declared alphabetically (SwiftLint's
/// `sorted_enum_cases`); ``allCases`` is the order the editor lists them in. The raw
/// value is what `jobs.json` and each run file store, so changing it is a file-format
/// change.
public enum NotifyPolicy: String, Sendable, Codable, CaseIterable {
    /// Every finished run posts one.
    case everyRun = "every_run"
    /// Only a run that did not succeed posts one. The default for a new job.
    case failuresOnly = "failures_only"
    /// No run posts a notification. Named `never` rather than `none`, which a reader of
    /// an optional policy could take for `Optional.none`.
    case never

    /// Every policy, in the order the editor lists them: least to most.
    public static let allCases: [Self] = [.never, .failuresOnly, .everyRun]

    /// The policy's title in the job editor's Notify menu.
    public var title: LocalizedStringResource {
        switch self {
        case .never:
            LocalizedStringResource(
                "notifyPolicy.never",
                defaultValue: "None",
                bundle: .module,
                comment: "Notify menu item in the job editor: no finished run posts a notification.",
            )

        case .failuresOnly:
            LocalizedStringResource(
                "notifyPolicy.failuresOnly",
                defaultValue: "Failures Only",
                bundle: .module,
                comment: "Notify menu item in the job editor: only a run that did not succeed posts a notification.",
            )

        case .everyRun:
            LocalizedStringResource(
                "notifyPolicy.everyRun",
                defaultValue: "Every Run",
                bundle: .module,
                comment: "Notify menu item in the job editor: every finished run posts a notification.",
            )
        }
    }
}
