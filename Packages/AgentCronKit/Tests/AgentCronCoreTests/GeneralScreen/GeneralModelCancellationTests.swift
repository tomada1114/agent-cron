import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

@MainActor
@Suite("GeneralModel cancellation")
struct GeneralModelCancellationTests {
    @Test
    func `a cancelled check keeps the previous answer`() async {
        let runner = FakeAgentRunner(
            behaviors: [:],
            otherwise: .runsUntilTerminated,
            clock: ContinuousClock(),
        )
        let model = GeneralModel(
            loginItem: FakeLoginItem(status: .enabled),
            checker: AgentAvailabilityChecker(
                runner: runner,
                directory: FileManager.default.temporaryDirectory,
                timeout: .seconds(60),
            ),
            clock: ManualClock(start: .now),
        )
        var reported: [AgentAvailability] = []
        model.onAgentChecked = { reported.append($0) }
        let check = Task { await model.checkAgain() }
        for _ in 0 ..< 20 {
            await Task.yield()
        }
        #expect(model.isChecking)
        check.cancel()
        await check.value
        #expect(model.agent == nil)
        #expect(reported.isEmpty)
        #expect(!model.isChecking)
        #expect(!model.showsSpinner)
    }
}
