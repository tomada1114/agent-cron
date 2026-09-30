import Foundation

/// The wording of the alert shown when the saved jobs cannot be read at launch
/// (`docs/design/ux-guidelines.md` › Feedback and loading: a blocking app error is an alert
/// with the reason and [Quit] / [Try Again]; ADR-0005: the file is never overwritten).
///
/// Each is a computed property or function so the resource is built afresh, in the
/// locale current at that moment, on every read (`localizing-the-app`).
public enum LaunchErrorText {
    /// The alert's title.
    public static var title: LocalizedStringResource {
        LocalizedStringResource(
            "launchError.title",
            defaultValue: "AgentCron can’t read your jobs",
            bundle: .module,
            comment: "Title of the alert shown at launch when jobs.json cannot be read.",
        )
    }

    /// The button that quits the app, leaving the file as it is.
    public static var quit: LocalizedStringResource {
        LocalizedStringResource(
            "launchError.quit",
            defaultValue: "Quit",
            bundle: .module,
            comment: "Button in the unreadable-jobs alert that quits the app.",
        )
    }

    /// The button that reads the file again.
    public static var tryAgain: LocalizedStringResource {
        LocalizedStringResource(
            "launchError.tryAgain",
            defaultValue: "Try Again",
            bundle: .module,
            comment: "Button in the unreadable-jobs alert that reads jobs.json again.",
        )
    }

    /// Why the file could not be read, and what the user can do about it. One whole
    /// sentence per reason, so a translation can reorder each.
    public static func message(for error: StorageError) -> LocalizedStringResource {
        switch error {
        case .corruptJobs:
            LocalizedStringResource(
                "launchError.message.corrupt",
                defaultValue: "jobs.json is damaged and was left unchanged. Fix or restore it, then try again.",
                bundle: .module,
                comment: "Unreadable-jobs alert message: jobs.json is not a valid jobs document.",
            )

        case .newerJobsVersion:
            LocalizedStringResource(
                "launchError.message.newerVersion",
                defaultValue: "jobs.json is from a newer AgentCron and was left unchanged. Update, then try again.",
                bundle: .module,
                comment: "Unreadable-jobs alert message: a newer app version wrote jobs.json.",
            )

        case let .readFailed(code), let .writeFailed(code):
            LocalizedStringResource(
                "launchError.message.unreadable",
                defaultValue: "jobs.json could not be read (error \(code)). Check its permissions, then try again.",
                bundle: .module,
                comment: "Unreadable-jobs alert message: the read was refused. The argument is an error code.",
            )
        }
    }
}
