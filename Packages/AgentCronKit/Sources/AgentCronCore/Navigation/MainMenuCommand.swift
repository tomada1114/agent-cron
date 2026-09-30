import Foundation

/// An app-specific command in the main menu (`docs/product/ux-flows.md` §4), named here so
/// its words live in Core's String Catalog.
///
/// The View menu's section items reuse ``MainSection/title``; Quit, Close, and Toggle
/// Sidebar are the system's own items and carry the system's words.
public enum MainMenuCommand: CaseIterable, Sendable {
    /// Job › Delete…, which asks first (S5).
    case delete
    /// File › New Job.
    case newJob
    /// Job › Run Now.
    case runNow
    /// AgentCron › Settings…, which opens the main window on General.
    case settings
    /// Job › Stop.
    case stop
    /// Job › Enable / Disable.
    case toggleEnabled

    /// The title of the menu that holds the job commands.
    public static var jobMenuTitle: LocalizedStringResource {
        LocalizedStringResource(
            "mainMenu.job",
            defaultValue: "Job",
            bundle: .module,
            comment: "Title of the main menu that holds the commands acting on the selected job.",
        )
    }

    /// The command's menu item title.
    public var title: LocalizedStringResource {
        switch self {
        case .settings:
            LocalizedStringResource(
                "mainMenu.settings",
                defaultValue: "Settings…",
                bundle: .module,
                comment: "App menu item that opens the main window on its General section.",
            )

        case .newJob:
            LocalizedStringResource(
                "mainMenu.newJob",
                defaultValue: "New Job",
                bundle: .module,
                comment: "File menu item that starts a new job.",
            )

        case .runNow:
            LocalizedStringResource(
                "mainMenu.runNow",
                defaultValue: "Run Now",
                bundle: .module,
                comment: "Job menu item that runs the selected job immediately.",
            )

        case .stop:
            LocalizedStringResource(
                "mainMenu.stop",
                defaultValue: "Stop",
                bundle: .module,
                comment: "Job menu item that stops the selected job's running run.",
            )

        case .toggleEnabled:
            LocalizedStringResource(
                "mainMenu.toggleEnabled",
                defaultValue: "Enable / Disable",
                bundle: .module,
                comment: "Job menu item that pauses the selected job, or resumes it when paused.",
            )

        case .delete:
            LocalizedStringResource(
                "mainMenu.delete",
                defaultValue: "Delete…",
                bundle: .module,
                comment: "Job menu item that asks to delete the selected job.",
            )
        }
    }
}
