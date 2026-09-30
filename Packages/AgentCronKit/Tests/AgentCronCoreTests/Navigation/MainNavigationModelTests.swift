import AgentCronCore
import Foundation
import Testing

/// The main window's navigation: what a first launch shows, what each action selects,
/// and what a relaunch restores from `UserDefaults` (REQ-001, REQ-002, REQ-004).
@MainActor
@Suite("Main navigation")
struct MainNavigationModelTests {
    private static let jobID = UUID(uuidString: "6F1C2A5E-0B7D-4E43-9C1A-2D4B8E6F0A11") ?? UUID()
    private static let otherJobID = UUID(uuidString: "0A9B8C7D-6E5F-4A3B-8C2D-1E0F9A8B7C6D") ??
        UUID()
    private static let runID = UUID(uuidString: "C3D4E5F6-A7B8-4C9D-8E0F-1A2B3C4D5E6F") ?? UUID()

    // MARK: - First launch

    @Test
    func `a first launch shows Jobs with nothing selected`() throws {
        try withScratchDefaults { defaults in
            let model = MainNavigationModel(defaults: defaults)
            #expect(model.section == .jobs)
            #expect(model.selectedJobID == nil)
            #expect(model.selectedRunID == nil)
        }
    }

    // MARK: - Selecting

    @Test(arguments: [MainSection.jobs, .history, .general])
    func `selecting a section shows it and is restored on relaunch`(section: MainSection) throws {
        try withScratchDefaults { defaults in
            let model = MainNavigationModel(defaults: defaults)
            model.select(section: section)
            #expect(model.section == section)
            #expect(MainNavigationModel(defaults: defaults).section == section)
        }
    }

    @Test
    func `a selected job and run are restored on relaunch`() throws {
        try withScratchDefaults { defaults in
            let model = MainNavigationModel(defaults: defaults)
            model.select(jobID: Self.jobID)
            model.select(runID: Self.runID)
            let relaunched = MainNavigationModel(defaults: defaults)
            #expect(relaunched.selectedJobID == Self.jobID)
            #expect(relaunched.selectedRunID == Self.runID)
        }
    }

    @Test
    func `clearing a selection is restored as nothing selected`() throws {
        try withScratchDefaults { defaults in
            let model = MainNavigationModel(defaults: defaults)
            model.select(jobID: Self.jobID)
            model.select(runID: Self.runID)
            model.select(jobID: nil)
            model.select(runID: nil)
            #expect(model.selectedJobID == nil)
            #expect(model.selectedRunID == nil)
            let relaunched = MainNavigationModel(defaults: defaults)
            #expect(relaunched.selectedJobID == nil)
            #expect(relaunched.selectedRunID == nil)
        }
    }

    @Test
    func `switching section keeps each section's selection`() throws {
        try withScratchDefaults { defaults in
            let model = MainNavigationModel(defaults: defaults)
            model.select(jobID: Self.jobID)
            model.select(section: .history)
            model.select(runID: Self.runID)
            model.select(section: .jobs)
            #expect(model.selectedJobID == Self.jobID)
            #expect(model.selectedRunID == Self.runID)
        }
    }

    // MARK: - Stored keys (contract: docs/architecture.md › What is contract)

    @Test
    func `the state is written under its documented UserDefaults keys`() throws {
        try withScratchDefaults { defaults in
            let model = MainNavigationModel(defaults: defaults)
            model.select(section: .history)
            model.select(jobID: Self.jobID)
            model.select(runID: Self.runID)
            #expect(defaults.string(forKey: "mainWindow.section") == "history")
            #expect(
                defaults.string(forKey: "mainWindow.selectedJobID")
                    == "6F1C2A5E-0B7D-4E43-9C1A-2D4B8E6F0A11",
            )
            #expect(
                defaults.string(forKey: "mainWindow.selectedRunID")
                    == "C3D4E5F6-A7B8-4C9D-8E0F-1A2B3C4D5E6F",
            )
        }
    }

    @Test
    func `a state stored under the documented keys is restored`() throws {
        try withScratchDefaults { defaults in
            defaults.set("general", forKey: "mainWindow.section")
            defaults.set("6F1C2A5E-0B7D-4E43-9C1A-2D4B8E6F0A11", forKey: "mainWindow.selectedJobID")
            defaults.set("C3D4E5F6-A7B8-4C9D-8E0F-1A2B3C4D5E6F", forKey: "mainWindow.selectedRunID")
            let model = MainNavigationModel(defaults: defaults)
            #expect(model.section == .general)
            #expect(model.selectedJobID == Self.jobID)
            #expect(model.selectedRunID == Self.runID)
        }
    }

    @Test
    func `an unreadable stored state falls back to Jobs with nothing selected`() throws {
        try withScratchDefaults { defaults in
            defaults.set("settings", forKey: "mainWindow.section")
            defaults.set("not-a-uuid", forKey: "mainWindow.selectedJobID")
            defaults.set(42, forKey: "mainWindow.selectedRunID")
            let model = MainNavigationModel(defaults: defaults)
            #expect(model.section == .jobs)
            #expect(model.selectedJobID == nil)
            #expect(model.selectedRunID == nil)
        }
    }

    // MARK: - Settings (REQ-004)

    @Test
    func `choosing Settings opens General, which is restored on relaunch`() throws {
        try withScratchDefaults { defaults in
            let model = MainNavigationModel(defaults: defaults)
            model.select(section: .history)
            model.openSettings()
            #expect(model.section == .general)
            #expect(MainNavigationModel(defaults: defaults).section == .general)
        }
    }

    // MARK: - A restored selection that no longer exists

    @Test
    func `a restored job that no longer exists is cleared once the jobs are known`() throws {
        try withScratchDefaults { defaults in
            MainNavigationModel(defaults: defaults).select(jobID: Self.jobID)
            let model = MainNavigationModel(defaults: defaults)
            model.knownJobsChanged(to: [Self.otherJobID])
            #expect(model.selectedJobID == nil)
            #expect(MainNavigationModel(defaults: defaults).selectedJobID == nil)
        }
    }

    @Test
    func `a restored job that still exists stays selected`() throws {
        try withScratchDefaults { defaults in
            MainNavigationModel(defaults: defaults).select(jobID: Self.jobID)
            let model = MainNavigationModel(defaults: defaults)
            model.knownJobsChanged(to: [Self.jobID, Self.otherJobID])
            #expect(model.selectedJobID == Self.jobID)
        }
    }

    @Test
    func `known jobs leave an empty job selection empty`() throws {
        try withScratchDefaults { defaults in
            let model = MainNavigationModel(defaults: defaults)
            model.knownJobsChanged(to: [Self.jobID])
            #expect(model.selectedJobID == nil)
        }
    }

    @Test
    func `a restored run that no longer exists is cleared once the runs are known`() throws {
        try withScratchDefaults { defaults in
            MainNavigationModel(defaults: defaults).select(runID: Self.runID)
            let model = MainNavigationModel(defaults: defaults)
            model.knownRunsChanged(to: [])
            #expect(model.selectedRunID == nil)
            #expect(MainNavigationModel(defaults: defaults).selectedRunID == nil)
        }
    }

    @Test
    func `a restored run that still exists stays selected`() throws {
        try withScratchDefaults { defaults in
            MainNavigationModel(defaults: defaults).select(runID: Self.runID)
            let model = MainNavigationModel(defaults: defaults)
            model.knownRunsChanged(to: [Self.runID])
            #expect(model.selectedRunID == Self.runID)
        }
    }

    // MARK: - Job commands (REQ-005)

    @Test
    func `choosing New Job shows Jobs with no saved job selected`() throws {
        try withScratchDefaults { defaults in
            let model = MainNavigationModel(defaults: defaults)
            model.select(jobID: Self.jobID)
            model.select(section: .general)
            model.newJob()
            #expect(model.section == .jobs)
            #expect(model.selectedJobID == nil)
            let relaunched = MainNavigationModel(defaults: defaults)
            #expect(relaunched.section == .jobs)
            #expect(relaunched.selectedJobID == nil)
        }
    }

    @Test
    func `the job commands need a selected job in the Jobs section`() throws {
        try withScratchDefaults { defaults in
            let model = MainNavigationModel(defaults: defaults)
            #expect(!model.canActOnSelectedJob)
            model.select(jobID: Self.jobID)
            #expect(model.canActOnSelectedJob)
            model.select(section: .history)
            #expect(!model.canActOnSelectedJob)
        }
    }

    @Test
    func `the job commands leave the navigation where it was`() throws {
        try withScratchDefaults { defaults in
            let model = MainNavigationModel(defaults: defaults)
            model.select(jobID: Self.jobID)
            model.select(runID: Self.runID)
            model.runSelectedJobNow()
            model.stopSelectedJob()
            model.toggleSelectedJobEnabled()
            model.deleteSelectedJob()
            #expect(model.section == .jobs)
            #expect(model.selectedJobID == Self.jobID)
            #expect(model.selectedRunID == Self.runID)
        }
    }

    @Test
    func `the job commands do nothing without a selected job`() throws {
        try withScratchDefaults { defaults in
            let model = MainNavigationModel(defaults: defaults)
            model.select(section: .history)
            model.runSelectedJobNow()
            model.stopSelectedJob()
            model.toggleSelectedJobEnabled()
            model.deleteSelectedJob()
            #expect(model.section == .history)
            #expect(model.selectedJobID == nil)
        }
    }
}

/// Runs `body` against a `UserDefaults` suite of its own, removed afterwards, so parallel
/// tests never read one another's state or the developer's.
@MainActor
func withScratchDefaults(_ body: (UserDefaults) throws -> Void) throws {
    let name = "AgentCronTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer {
        defaults.removePersistentDomain(forName: name)
    }
    try body(defaults)
}
