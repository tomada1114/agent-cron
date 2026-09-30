import Foundation

/// The History screen's fixed wording (`docs/product/ux-flows.md` S3;
/// `docs/design/ux-guidelines.md` › States): buttons, filter labels, detail headings and
/// field labels. Each is a computed property so the resource resolves in the locale
/// current on every read (`localizing-the-app`).
public enum HistoryScreenText {
    /// The empty list's button to the Jobs section.
    public static var openJobs: LocalizedStringResource {
        LocalizedStringResource(
            "history.openJobs",
            defaultValue: "Open Jobs",
            bundle: .module,
            comment: "Button in the empty History list that shows the Jobs section.",
        )
    }

    /// The filtered-to-zero list's button that resets both filters.
    public static var clearFilters: LocalizedStringResource {
        LocalizedStringResource(
            "history.clearFilters",
            defaultValue: "Clear Filters",
            bundle: .module,
            comment: "Button in the History list when the filters hide every run.",
        )
    }

    /// The job filter's option for every job.
    public static var allJobs: LocalizedStringResource {
        LocalizedStringResource(
            "history.jobFilter.all",
            defaultValue: "All Jobs",
            bundle: .module,
            comment: "History job filter option: runs of every job.",
        )
    }

    /// The job filter picker's label.
    public static var jobFilterLabel: LocalizedStringResource {
        LocalizedStringResource(
            "history.jobFilter.label",
            defaultValue: "Job",
            bundle: .module,
            comment: "Label of the History job filter picker.",
        )
    }

    /// The outcome filter picker's label.
    public static var outcomeFilterLabel: LocalizedStringResource {
        LocalizedStringResource(
            "history.outcomeFilter.label",
            defaultValue: "Outcome",
            bundle: .module,
            comment: "Label of the History outcome filter picker.",
        )
    }

    /// The detail pane while no run is selected.
    public static var noSelection: LocalizedStringResource {
        LocalizedStringResource(
            "history.noSelection",
            defaultValue: "Select a run",
            bundle: .module,
            comment: "Detail pane of the History screen while no run is selected.",
        )
    }

    /// The Result section's heading.
    public static var result: LocalizedStringResource {
        LocalizedStringResource(
            "history.detail.result",
            defaultValue: "Result",
            bundle: .module,
            comment: "Heading of the run result in the History detail.",
        )
    }

    /// The toggle between rendered Markdown and raw text.
    public static var raw: LocalizedStringResource {
        LocalizedStringResource(
            "history.detail.raw",
            defaultValue: "Raw",
            bundle: .module,
            comment: "Toggle in the History detail that shows the result as raw monospaced text.",
        )
    }

    /// The button that copies the result text.
    public static var copy: LocalizedStringResource {
        LocalizedStringResource(
            "history.detail.copy",
            defaultValue: "Copy",
            bundle: .module,
            comment: "Button in the History detail that copies the run result.",
        )
    }

    /// The collapsed section holding the prompt the run used.
    public static var prompt: LocalizedStringResource {
        LocalizedStringResource(
            "history.detail.prompt",
            defaultValue: "Prompt",
            bundle: .module,
            comment: "Collapsed section in the History detail with the prompt the run used.",
        )
    }

    /// The running detail's Stop button.
    public static var stop: LocalizedStringResource {
        LocalizedStringResource(
            "history.detail.stop",
            defaultValue: "Stop",
            bundle: .module,
            comment: "Button in the History detail that stops the running run.",
        )
    }

    /// The header link to the run's job.
    public static var openJob: LocalizedStringResource {
        LocalizedStringResource(
            "history.detail.openJob",
            defaultValue: "Open Job",
            bundle: .module,
            comment: "Link in the History detail header that shows the run's job in the Jobs section.",
        )
    }

    /// What the Result section says while the run is running.
    public static var resultPending: LocalizedStringResource {
        LocalizedStringResource(
            "history.detail.resultPending",
            defaultValue: "Result appears when the run finishes",
            bundle: .module,
            comment: "Shown in the History detail while the selected run is still running.",
        )
    }

    /// What the Result section says when a finished run kept no text.
    public static var noResult: LocalizedStringResource {
        LocalizedStringResource(
            "history.detail.noResult",
            defaultValue: "The agent reported no result.",
            bundle: .module,
            comment: "Shown in the History detail's Result section when a finished run has no text.",
        )
    }

    /// The heading over a skipped run's reason.
    public static var reason: LocalizedStringResource {
        LocalizedStringResource(
            "history.detail.reason",
            defaultValue: "Reason",
            bundle: .module,
            comment: "Heading of a skipped run's reason in the History detail.",
        )
    }

    /// Field label: how the run was started.
    public static var trigger: LocalizedStringResource {
        LocalizedStringResource(
            "history.field.trigger",
            defaultValue: "Trigger",
            bundle: .module,
            comment: "History detail field label: how the run was started.",
        )
    }

    /// Field label: the scheduled time.
    public static var scheduled: LocalizedStringResource {
        LocalizedStringResource(
            "history.field.scheduled",
            defaultValue: "Scheduled",
            bundle: .module,
            comment: "History detail field label: the time the run was scheduled for.",
        )
    }

    /// Field label: when the run started.
    public static var started: LocalizedStringResource {
        LocalizedStringResource(
            "history.field.started",
            defaultValue: "Started",
            bundle: .module,
            comment: "History detail field label: when the run started.",
        )
    }

    /// Field label: how long the run took.
    public static var duration: LocalizedStringResource {
        LocalizedStringResource(
            "history.field.duration",
            defaultValue: "Duration",
            bundle: .module,
            comment: "History detail field label: how long the run took.",
        )
    }

    /// Field label: how long a running run has run so far.
    public static var elapsed: LocalizedStringResource {
        LocalizedStringResource(
            "history.field.elapsed",
            defaultValue: "Elapsed",
            bundle: .module,
            comment: "History detail field label: how long the running run has run so far.",
        )
    }

    /// Field label: the run's cost.
    public static var cost: LocalizedStringResource {
        LocalizedStringResource(
            "history.field.cost",
            defaultValue: "Cost",
            bundle: .module,
            comment: "History detail field label: what the run cost in US dollars.",
        )
    }

    /// Field label: the agent's exit status.
    public static var exitCode: LocalizedStringResource {
        LocalizedStringResource(
            "history.field.exitCode",
            defaultValue: "Exit Code",
            bundle: .module,
            comment: "History detail field label: the agent process's exit status.",
        )
    }

    /// Field label: the folder the run ran in.
    public static var directory: LocalizedStringResource {
        LocalizedStringResource(
            "history.field.directory",
            defaultValue: "Directory",
            bundle: .module,
            comment: "History detail field label: the folder the run ran in.",
        )
    }

    /// Field label: the model.
    public static var model: LocalizedStringResource {
        LocalizedStringResource(
            "history.field.model",
            defaultValue: "Model",
            bundle: .module,
            comment: "History detail field label: the model the run used.",
        )
    }

    /// Field label: the effort level.
    public static var effort: LocalizedStringResource {
        LocalizedStringResource(
            "history.field.effort",
            defaultValue: "Effort",
            bundle: .module,
            comment: "History detail field label: the effort level the run used.",
        )
    }

    /// Field label: the permission mode.
    public static var permission: LocalizedStringResource {
        LocalizedStringResource(
            "history.field.permission",
            defaultValue: "Permission",
            bundle: .module,
            comment: "History detail field label: the permission mode the run used.",
        )
    }

    /// Field label: the agent's session identifier.
    public static var session: LocalizedStringResource {
        LocalizedStringResource(
            "history.field.session",
            defaultValue: "Session",
            bundle: .module,
            comment: "History detail field label: the agent's session identifier.",
        )
    }
}
