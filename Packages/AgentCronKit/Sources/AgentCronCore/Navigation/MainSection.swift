import Foundation

/// A section of the main window's sidebar (`docs/product/ux-flows.md` S2–S4); ``allCases``
/// is the order the sidebar lists them and ⌘1–⌘3 select them.
///
/// The raw value is what ``MainNavigationModel`` stores under `mainWindow.section`, so a
/// case's raw value is contract (`docs/architecture.md` › What is contract): renaming one
/// resets every user who last left the window on it.
public enum MainSection: String, CaseIterable, Identifiable, Sendable {
    /// App-wide settings: launch at login, the agent check, keep awake (S4).
    case general
    /// Every run, newest first, and the selected run's detail (S3).
    case history
    /// The saved jobs and the selected job's editor (S2).
    case jobs

    /// Every section in sidebar order. The cases are declared alphabetically (SwiftLint's
    /// `sorted_enum_cases`), so the order is spelled here.
    public static let allCases: [Self] = [.jobs, .history, .general]

    /// The section itself, so a `ForEach` over ``allCases`` needs no key path.
    public var id: Self {
        self
    }

    /// The section's name in the sidebar and in the View menu.
    public var title: LocalizedStringResource {
        switch self {
        case .jobs:
            LocalizedStringResource(
                "mainSection.jobs.title",
                defaultValue: "Jobs",
                bundle: .module,
                comment: "Sidebar section and View menu item that shows the saved jobs.",
            )

        case .history:
            LocalizedStringResource(
                "mainSection.history.title",
                defaultValue: "History",
                bundle: .module,
                comment: "Sidebar section and View menu item that shows past runs.",
            )

        case .general:
            LocalizedStringResource(
                "mainSection.general.title",
                defaultValue: "General",
                bundle: .module,
                comment: "Sidebar section and View menu item that shows the app's settings.",
            )
        }
    }

    /// What the section shows until its screen replaces the placeholder (#21 Jobs,
    /// #24 History, #25 General).
    public var placeholder: LocalizedStringResource {
        switch self {
        case .jobs:
            LocalizedStringResource(
                "mainSection.jobs.placeholder",
                defaultValue: "Your jobs will appear here.",
                bundle: .module,
                comment: "Placeholder in the main window's Jobs section before the job list exists.",
            )

        case .history:
            LocalizedStringResource(
                "mainSection.history.placeholder",
                defaultValue: "Runs will appear here after a job runs.",
                bundle: .module,
                comment: "Placeholder in the main window's History section before the run list exists.",
            )

        case .general:
            LocalizedStringResource(
                "mainSection.general.placeholder",
                defaultValue: "Settings will appear here.",
                bundle: .module,
                comment: "Placeholder in the main window's General section before its settings exist.",
            )
        }
    }
}
