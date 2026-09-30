import Foundation
import Observation

/// Where the main window is: its sidebar section and the job and run each section has
/// selected, remembered across launches (`docs/design/ux-guidelines.md` › Navigation).
///
/// One instance lives as long as the app, owned by `App/`, because the main menu's
/// commands act on it whether or not the window is open: Settings… (⌘,) has to pick
/// General before the window it opens has drawn. Each section keeps its own selection, so
/// switching sections and back finds the same job and run.
///
/// Every change is written through to `UserDefaults` at once, under three keys that are
/// contract (`docs/architecture.md` › What is contract, ADR-0012): `mainWindow.section`
/// (a ``MainSection`` raw value), `mainWindow.selectedJobID` and
/// `mainWindow.selectedRunID` (a `UUID` string each, absent when nothing is selected). A
/// value that cannot be read back restores as the first-launch state for that key.
@MainActor
@Observable
public final class MainNavigationModel {
    private enum Key {
        static let section = "mainWindow.section"
        static let selectedJobID = "mainWindow.selectedJobID"
        static let selectedRunID = "mainWindow.selectedRunID"
    }

    /// The section the window shows.
    public private(set) var section: MainSection

    /// The job the Jobs section has selected, or `nil` for none or a new draft.
    public private(set) var selectedJobID: UUID?

    /// The run the History section has selected, or `nil` for none.
    public private(set) var selectedRunID: UUID?

    private let defaults: UserDefaults

    /// Whether the Job menu's commands have a job to act on: a saved job selected while
    /// the Jobs section shows it. A menu item that cannot act is disabled, not hidden.
    public var canActOnSelectedJob: Bool {
        section == .jobs && selectedJobID != nil
    }

    /// Restores the last section and selections from `defaults`, or Jobs with nothing
    /// selected when nothing readable is stored. Writes nothing until an action changes
    /// something.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        section = defaults.string(forKey: Key.section).flatMap(MainSection.init(rawValue:)) ?? .jobs
        selectedJobID = defaults.string(forKey: Key.selectedJobID).flatMap(UUID.init(uuidString:))
        selectedRunID = defaults.string(forKey: Key.selectedRunID).flatMap(UUID.init(uuidString:))
    }

    // MARK: - Navigation

    /// The user picked a section in the sidebar or the View menu (⌘1–⌘3).
    public func select(section: MainSection) {
        self.section = section
        defaults.set(section.rawValue, forKey: Key.section)
    }

    /// The user selected a job in the Jobs list, or cleared the selection with `nil`.
    public func select(jobID: UUID?) {
        selectedJobID = jobID
        store(jobID, forKey: Key.selectedJobID)
    }

    /// The user selected a run in the History list, or cleared the selection with `nil`.
    public func select(runID: UUID?) {
        selectedRunID = runID
        store(runID, forKey: Key.selectedRunID)
    }

    /// The user chose Settings… (⌘,): the window shows General. Opening the window is the
    /// command's, since only SwiftUI can.
    public func openSettings() {
        select(section: .general)
    }

    /// The app read the saved jobs. A selected job that is not among them — deleted since
    /// the selection was stored — is cleared, so the window never restores onto nothing.
    public func knownJobsChanged(to jobIDs: Set<UUID>) {
        if let selectedJobID, !jobIDs.contains(selectedJobID) {
            select(jobID: nil)
        }
    }

    /// The app read the kept runs. A selected run that is not among them — swept by the
    /// 90-day retention since the selection was stored — is cleared.
    public func knownRunsChanged(to runIDs: Set<UUID>) {
        if let selectedRunID, !runIDs.contains(selectedRunID) {
            select(runID: nil)
        }
    }

    // MARK: - Job commands

    /// The user chose New Job (⌘N): the Jobs section shows, with no saved job selected
    /// (`docs/product/ux-flows.md` F1). Opening the empty draft is the Jobs screen's
    /// (#21), through ``JobListModel/newJob()``.
    public func newJob() {
        select(section: .jobs)
        select(jobID: nil)
    }

    /// The user chose Run Now (⌘R). A stub until the Jobs screen (#21) routes it to the
    /// runner; it only records the request.
    public func runSelectedJobNow() {
        requestJobCommand("run now")
    }

    /// The user chose Stop (⌘.). A stub until the Jobs screen (#21) routes it to the
    /// runner; it only records the request.
    public func stopSelectedJob() {
        requestJobCommand("stop")
    }

    /// The user chose Enable / Disable (⌘E). A stub until the Jobs screen (#21) routes it
    /// to ``JobEditorModel/enabledChanged(to:)``; it only records the request.
    public func toggleSelectedJobEnabled() {
        requestJobCommand("enable or disable")
    }

    /// The user chose Delete… (⌘⌫). A stub until the Jobs screen (#21) routes it to
    /// ``JobListModel/deleteConfirmation(forJobID:)``; it only records the request.
    public func deleteSelectedJob() {
        requestJobCommand("delete")
    }

    // MARK: - Private

    private func store(_ id: UUID?, forKey key: String) {
        if let id {
            defaults.set(id.uuidString, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private func requestJobCommand(_ command: String) {
        guard canActOnSelectedJob else {
            AppLog.navigation
                .debug("job command \(command, privacy: .public) ignored: no job selected")
            return
        }
        AppLog.navigation
            .debug(
                "job command \(command, privacy: .public) requested; the Jobs screen does not handle it yet",
            )
    }
}
