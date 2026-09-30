import AgentCronCore
import Foundation
import Testing

/// The main menu's job commands reach the Jobs screen as numbered requests, and Delete…
/// stays off while the editor has focus so ⌘⌫ edits text there (issue #21, S5).
@MainActor
@Suite("Jobs screen requests")
struct JobsScreenRequestTests {
    private static let jobID = UUID(uuidString: "6F1C2A5E-0B7D-4E43-9C1A-2D4B8E6F0A11") ?? UUID()

    @Test
    func `choosing New Job asks the Jobs screen for a draft`() throws {
        try withScratchDefaults { defaults in
            let model = MainNavigationModel(defaults: defaults)
            #expect(model.pendingJobsScreenRequest == nil)
            model.newJob()
            #expect(model.pendingJobsScreenRequest?.command == .newJob)
            #expect(model.pendingJobsScreenRequest?.sequence == 1)
        }
    }

    @Test
    func `the same command twice is two requests`() throws {
        try withScratchDefaults { defaults in
            let model = MainNavigationModel(defaults: defaults)
            model.newJob()
            let first = try #require(model.pendingJobsScreenRequest)
            model.newJob()
            let second = try #require(model.pendingJobsScreenRequest)
            #expect(first != second)
            #expect(second.sequence == 2)
        }
    }

    @Test
    func `a handled request clears, but an older one leaves a newer one pending`() throws {
        try withScratchDefaults { defaults in
            let model = MainNavigationModel(defaults: defaults)
            model.newJob()
            let first = try #require(model.pendingJobsScreenRequest)
            model.newJob()
            model.jobsScreenRequestHandled(first)
            #expect(model.pendingJobsScreenRequest?.sequence == 2)
            let second = try #require(model.pendingJobsScreenRequest)
            model.jobsScreenRequestHandled(second)
            #expect(model.pendingJobsScreenRequest == nil)
        }
    }

    @Test
    func `choosing Enable or Disable and Delete names the selected job`() throws {
        try withScratchDefaults { defaults in
            let model = MainNavigationModel(defaults: defaults)
            model.select(jobID: Self.jobID)
            model.toggleSelectedJobEnabled()
            #expect(model.pendingJobsScreenRequest?.command == .toggleEnabled(jobID: Self.jobID))
            model.deleteSelectedJob()
            #expect(model.pendingJobsScreenRequest?.command == .delete(jobID: Self.jobID))
        }
    }

    @Test
    func `the commands ask nothing without a selected job in Jobs`() throws {
        try withScratchDefaults { defaults in
            let model = MainNavigationModel(defaults: defaults)
            model.toggleSelectedJobEnabled()
            model.deleteSelectedJob()
            #expect(model.pendingJobsScreenRequest == nil)
            model.select(jobID: Self.jobID)
            model.select(section: .history)
            model.toggleSelectedJobEnabled()
            model.deleteSelectedJob()
            #expect(model.pendingJobsScreenRequest == nil)
        }
    }

    @Test
    func `delete is off while the editor has focus, so the field gets the key`() throws {
        try withScratchDefaults { defaults in
            let model = MainNavigationModel(defaults: defaults)
            model.select(jobID: Self.jobID)
            #expect(model.canDeleteSelectedJob)
            model.editorFocusChanged(isFocused: true)
            #expect(model.isEditorFocused)
            #expect(!model.canDeleteSelectedJob)
            #expect(model.canActOnSelectedJob)
            model.deleteSelectedJob()
            #expect(model.pendingJobsScreenRequest == nil)
            model.editorFocusChanged(isFocused: false)
            #expect(model.canDeleteSelectedJob)
            model.deleteSelectedJob()
            #expect(model.pendingJobsScreenRequest?.command == .delete(jobID: Self.jobID))
        }
    }

    @Test
    func `run Now and Stop stay stubs that ask the Jobs screen nothing`() throws {
        try withScratchDefaults { defaults in
            let model = MainNavigationModel(defaults: defaults)
            model.select(jobID: Self.jobID)
            model.runSelectedJobNow()
            model.stopSelectedJob()
            #expect(model.pendingJobsScreenRequest == nil)
        }
    }
}
