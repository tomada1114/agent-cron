import Foundation

/// The Jobs screen's fixed wording (`docs/product/ux-flows.md` S2, S5, S6;
/// `docs/design/ux-guidelines.md` › States, Feedback and loading): section headings,
/// row labels, buttons, and the notes and alerts that carry no argument.
///
/// Each is a computed property so the resource is built afresh, in the locale current at
/// that moment, on every read (`localizing-the-app`). Wording that depends on a job lives
/// on the model that knows the job.
public enum JobsScreenText {
    // MARK: - States

    /// The empty list's title (ux-guidelines › States, first-run empty).
    public static var emptyTitle: LocalizedStringResource {
        LocalizedStringResource(
            "jobsScreen.empty.title",
            defaultValue: "No jobs yet",
            bundle: .module,
            comment: "Title of the Jobs list while no job exists.",
        )
    }

    /// What a job is, under the empty list's title.
    public static var emptyDescription: LocalizedStringResource {
        LocalizedStringResource(
            "jobsScreen.empty.description",
            defaultValue: "A job runs an agent prompt in a folder on a schedule.",
            bundle: .module,
            comment: "Line under the empty Jobs list's title, saying what a job is.",
        )
    }

    /// The detail pane while no job is selected.
    public static var noSelection: LocalizedStringResource {
        LocalizedStringResource(
            "jobsScreen.noSelection",
            defaultValue: "Select a job",
            bundle: .module,
            comment: "Detail pane of the Jobs screen while no job is selected.",
        )
    }

    /// Why the list is empty when the saved jobs could not be read.
    public static var loadFailed: LocalizedStringResource {
        LocalizedStringResource(
            "jobsScreen.loadFailed",
            defaultValue: "Your jobs could not be read.",
            bundle: .module,
            comment: "Shown in the Jobs list when the saved jobs file could not be read.",
        )
    }

    /// Why the last save did not happen when the store refused it.
    public static var saveFailed: LocalizedStringResource {
        LocalizedStringResource(
            "jobsScreen.saveFailed",
            defaultValue: "The job could not be saved. Your changes are still here.",
            bundle: .module,
            comment: "Note in the job editor's header when saving failed at the store.",
        )
    }

    /// The Directory row while a new job has no folder chosen yet.
    public static var noFolderChosen: LocalizedStringResource {
        LocalizedStringResource(
            "jobEditor.noFolder",
            defaultValue: "No folder chosen",
            bundle: .module,
            comment: "Job editor Directory row while a new job has no folder chosen yet.",
        )
    }

    // MARK: - Sections

    /// The editor's Task section: name, folder, prompt.
    public static var taskSection: LocalizedStringResource {
        LocalizedStringResource(
            "jobEditor.section.task",
            defaultValue: "Task",
            bundle: .module,
            comment: "Job editor section heading over the name, folder, and prompt.",
        )
    }

    /// The editor's Schedule section: days and times.
    public static var scheduleSection: LocalizedStringResource {
        LocalizedStringResource(
            "jobEditor.section.schedule",
            defaultValue: "Schedule",
            bundle: .module,
            comment: "Job editor section heading over the days and times.",
        )
    }

    /// The editor's Agent section: agent, model, effort, permission, timeout.
    public static var agentSection: LocalizedStringResource {
        LocalizedStringResource(
            "jobEditor.section.agent",
            defaultValue: "Agent",
            bundle: .module,
            comment: "Job editor section heading over the agent and its options.",
        )
    }

    /// The editor's Notifications section.
    public static var notificationsSection: LocalizedStringResource {
        LocalizedStringResource(
            "jobEditor.section.notifications",
            defaultValue: "Notifications",
            bundle: .module,
            comment: "Job editor section heading over the Notify setting.",
        )
    }

    // MARK: - Row labels without a validation error

    /// The read-only Agent row's label.
    public static var agentLabel: LocalizedStringResource {
        LocalizedStringResource(
            "jobEditor.label.agent",
            defaultValue: "Agent",
            bundle: .module,
            comment: "Job editor row label for the agent that runs the job.",
        )
    }

    /// The Model menu's label.
    public static var modelLabel: LocalizedStringResource {
        LocalizedStringResource(
            "jobEditor.label.model",
            defaultValue: "Model",
            bundle: .module,
            comment: "Job editor row label for the model menu.",
        )
    }

    /// The Effort menu's label.
    public static var effortLabel: LocalizedStringResource {
        LocalizedStringResource(
            "jobEditor.label.effort",
            defaultValue: "Effort",
            bundle: .module,
            comment: "Job editor row label for the reasoning effort menu.",
        )
    }

    /// The Permission menu's label.
    public static var permissionLabel: LocalizedStringResource {
        LocalizedStringResource(
            "jobEditor.label.permission",
            defaultValue: "Permission",
            bundle: .module,
            comment: "Job editor row label for the permission mode menu.",
        )
    }

    /// The Notify menu's label.
    public static var notifyLabel: LocalizedStringResource {
        LocalizedStringResource(
            "jobEditor.label.notify",
            defaultValue: "Notify",
            bundle: .module,
            comment: "Job editor row label for which finished runs post a notification.",
        )
    }

    /// The header switch that pauses or resumes the job.
    public static var enabledLabel: LocalizedStringResource {
        LocalizedStringResource(
            "jobEditor.label.enabled",
            defaultValue: "Enabled",
            bundle: .module,
            comment: "Label of the switch in the job editor's header that pauses or resumes the job.",
        )
    }

    /// The unit after the Timeout field.
    public static var timeoutUnit: LocalizedStringResource {
        LocalizedStringResource(
            "jobEditor.timeoutUnit",
            defaultValue: "minutes",
            bundle: .module,
            comment: "Unit shown after the job editor's Timeout field.",
        )
    }

    // MARK: - Buttons

    /// Opens the folder picker for the Directory row.
    public static var chooseFolder: LocalizedStringResource {
        LocalizedStringResource(
            "jobEditor.chooseFolder",
            defaultValue: "Choose…",
            bundle: .module,
            comment: "Button on the job editor's Directory row that opens a folder picker.",
        )
    }

    /// Adds a time to the Times row.
    public static var addTime: LocalizedStringResource {
        LocalizedStringResource(
            "jobEditor.addTime",
            defaultValue: "Add Time",
            bundle: .module,
            comment: "Button under the job editor's times that adds another time.",
        )
    }

    /// Returns the editor to the saved job.
    public static var revert: LocalizedStringResource {
        LocalizedStringResource(
            "jobEditor.revert",
            defaultValue: "Revert",
            bundle: .module,
            comment: "Button in the job editor's header that throws away unsaved edits.",
        )
    }

    /// Saves the draft; also the unsaved-changes alert's saving button.
    public static var save: LocalizedStringResource {
        LocalizedStringResource(
            "jobEditor.save",
            defaultValue: "Save",
            bundle: .module,
            comment: "Button that saves the job, in the job editor's header and the unsaved-changes alert.",
        )
    }

    /// The label beside Revert and Save while the draft differs from the saved job.
    public static var edited: LocalizedStringResource {
        LocalizedStringResource(
            "jobEditor.edited",
            defaultValue: "Edited",
            bundle: .module,
            comment: "Label in the job editor's header while the job has unsaved edits.",
        )
    }

    /// Asks to delete the job (S5).
    public static var deleteJob: LocalizedStringResource {
        LocalizedStringResource(
            "jobEditor.deleteJob",
            defaultValue: "Delete Job…",
            bundle: .module,
            comment: "Button at the bottom of the job editor that asks to delete the job.",
        )
    }

    /// The delete alert's destructive button.
    public static var delete: LocalizedStringResource {
        LocalizedStringResource(
            "jobDelete.confirm",
            defaultValue: "Delete",
            bundle: .module,
            comment: "Destructive button of the alert that confirms deleting a job.",
        )
    }

    /// Every alert's button that changes nothing.
    public static var cancel: LocalizedStringResource {
        LocalizedStringResource(
            "jobsScreen.cancel",
            defaultValue: "Cancel",
            bundle: .module,
            comment: "Button of the Jobs screen's alerts that closes the alert and changes nothing.",
        )
    }

    /// The unsaved-changes alert's button that throws the edits away.
    public static var dontSave: LocalizedStringResource {
        LocalizedStringResource(
            "jobUnsaved.dontSave",
            defaultValue: "Don’t Save",
            bundle: .module,
            comment: "Button of the unsaved-changes alert that throws the job's edits away.",
        )
    }

    // MARK: - Bypass (S6)

    /// The bypass confirmation's title.
    public static var bypassAlertTitle: LocalizedStringResource {
        LocalizedStringResource(
            "jobBypass.title",
            defaultValue: "Run without any permission checks?",
            bundle: .module,
            comment: "Title of the alert shown when Bypass Permissions is chosen for a job.",
        )
    }

    /// The bypass confirmation's message.
    public static var bypassAlertMessage: LocalizedStringResource {
        LocalizedStringResource(
            "jobBypass.message",
            defaultValue: "The agent can run any command and change any file without asking, while nobody is watching.",
            bundle: .module,
            comment: "Message of the alert shown when Bypass Permissions is chosen for a job.",
        )
    }

    /// The bypass confirmation's button that applies it.
    public static var useBypass: LocalizedStringResource {
        LocalizedStringResource(
            "jobBypass.confirm",
            defaultValue: "Use Bypass",
            bundle: .module,
            comment: "Destructive button of the alert that confirms Bypass Permissions for a job.",
        )
    }

    /// The red note under the Permission row while the job bypasses every check.
    public static var bypassNote: LocalizedStringResource {
        LocalizedStringResource(
            "jobBypass.note",
            defaultValue: "No permission checks: the agent can run any command and change any file.",
            bundle: .module,
            comment: "Warning under the job editor's Permission row while Bypass Permissions is chosen.",
        )
    }

    // MARK: - Notifications

    /// The button beside the notifications-off note.
    public static var openSystemSettings: LocalizedStringResource {
        LocalizedStringResource(
            "jobEditor.openSystemSettings",
            defaultValue: "Open System Settings",
            bundle: .module,
            comment: "Button beside the note saying notifications are off, which opens System Settings.",
        )
    }
}
