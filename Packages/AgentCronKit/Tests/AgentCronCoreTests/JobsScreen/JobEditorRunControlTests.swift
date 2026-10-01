import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// The header's Run Now / Stop button (`docs/product/ux-flows.md` S2).
@MainActor
@Suite("Job editor run control")
struct JobEditorRunControlTests {
    private static let folderExists: @Sendable (URL) -> Bool = { _ in true }

    private static func editor() -> JobEditorModel {
        JobEditorModel(
            editing: Fixture.job(),
            store: FakeJobStore(),
            now: JobsScreenFixture.clock,
            directoryExists: folderExists,
        )
    }

    @Test
    func `a saved idle job offers Run Now`() {
        let editor = Self.editor()
        #expect(editor.runControl == .runNow)
        #expect(editor.canUseRunControl)
    }

    @Test
    func `a running job offers Stop`() {
        let editor = Self.editor()
        editor.runningStateChanged(isRunning: true)
        #expect(editor.runControl == .stop)
        #expect(editor.canUseRunControl)
        editor.runningStateChanged(isRunning: false)
        #expect(editor.runControl == .runNow)
    }

    @Test
    func `a new draft offers a disabled Run Now`() {
        let editor = JobEditorModel(
            newJobWithID: JobsScreenFixture.id(9),
            store: FakeJobStore(),
            now: JobsScreenFixture.clock,
            directoryExists: Self.folderExists,
        )
        #expect(editor.runControl == .runNow)
        #expect(!editor.canUseRunControl)
    }
}
