import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// A runner that answers the resolve and `--version` commands only once the test lets it
/// finish, so a test can hold a check in flight while it moves the clock.
private final class GatedRunner: AgentRunning {
    private static let commandNotFound: Int32 = 127
    private let gate = AsyncStream<Void>.makeStream()
    private let answer: [[String]: ProcessOutcome]

    init(answer: [[String]: ProcessOutcome]) {
        self.answer = answer
    }

    func finish() {
        gate.continuation.yield()
        gate.continuation.finish()
    }

    func run(argv: [String], directory _: URL, timeout _: Duration) async -> ProcessOutcome {
        for await _ in gate.stream {
            break
        }
        return answer[argv] ?? ProcessOutcome(
            stdout: Data(),
            stderr: "",
            exitCode: Self.commandNotFound,
            terminatedBy: .exit,
        )
    }
}

@MainActor
@Suite("GeneralModel")
struct GeneralModelTests {
    private static let resolve = AgentAvailabilityChecker.resolveArguments(for: .claudeCode)
    private static let claudePath = "/Users/me/.local/bin/claude"

    private static func exits(_ code: Int32, _ stdout: String) -> FakeAgentRunner.Behavior {
        .exits(code: code, stdout: Data(stdout.utf8), stderr: "")
    }

    private static func model(
        runner: any AgentRunning,
        loginItem: FakeLoginItem = FakeLoginItem(status: .enabled),
        clock: any Clock<Duration> = ManualClock(start: .now),
    ) -> GeneralModel {
        GeneralModel(
            loginItem: loginItem,
            checker: AgentAvailabilityChecker(
                runner: runner,
                directory: FileManager.default.temporaryDirectory,
                timeout: .milliseconds(10),
            ),
            clock: clock,
        )
    }

    private static func availableRunner() -> FakeAgentRunner {
        FakeAgentRunner(
            behaviors: [
                resolve: exits(0, "\(claudePath)\n"),
                [claudePath, "--version"]: exits(0, "2.1.3 (Claude Code)\n"),
            ],
            otherwise: exits(127, ""),
            clock: ContinuousClock(),
        )
    }

    /// Lets tasks the model started run until they suspend again.
    private static func settle() async {
        for _ in 0 ..< 20 {
            await Task.yield()
        }
    }

    // MARK: - REQ-001 launch at login

    @Test
    func `construction reads the login item's status and checks nothing yet`() {
        let runner = Self.availableRunner()
        let model = Self.model(runner: runner, loginItem: FakeLoginItem(status: .notRegistered))
        #expect(model.loginItemStatus == .notRegistered)
        #expect(!model.isLaunchAtLoginOn)
        #expect(model.agent == nil)
        #expect(!model.isChecking)
        #expect(runner.requests.isEmpty)
    }

    @Test
    func `turning the toggle off unregisters and reflects the new status`() {
        let loginItem = FakeLoginItem(status: .enabled)
        let model = Self.model(runner: Self.availableRunner(), loginItem: loginItem)
        model.setLaunchAtLogin(false)
        #expect(loginItem.unregisterCalls == 1)
        #expect(model.loginItemStatus == .notRegistered)
        #expect(!model.isLaunchAtLoginOn)
    }

    @Test
    func `turning the toggle on registers and reflects the new status`() {
        let loginItem = FakeLoginItem(status: .notRegistered)
        let model = Self.model(runner: Self.availableRunner(), loginItem: loginItem)
        model.setLaunchAtLogin(true)
        #expect(loginItem.registerCalls == 1)
        #expect(model.loginItemStatus == .enabled)
        #expect(model.isLaunchAtLoginOn)
    }

    @Test
    func `a failed register returns the toggle to the port's status`() {
        let loginItem = FakeLoginItem(status: .notRegistered)
        loginItem.registrationFails(with: [.systemFailure(code: 1)])
        let model = Self.model(runner: Self.availableRunner(), loginItem: loginItem)
        model.setLaunchAtLogin(true)
        #expect(loginItem.registerCalls == 1)
        #expect(model.loginItemStatus == .notRegistered)
        #expect(!model.isLaunchAtLoginOn)
    }

    @Test
    func `a failed unregister returns the toggle to the port's status`() {
        let loginItem = FakeLoginItem(status: .enabled)
        loginItem.unregistrationFails(with: [.systemFailure(code: 2)])
        let model = Self.model(runner: Self.availableRunner(), loginItem: loginItem)
        model.setLaunchAtLogin(false)
        #expect(model.loginItemStatus == .enabled)
        #expect(model.isLaunchAtLoginOn)
    }

    @Test
    func `refreshing picks up a change made in System Settings`() {
        let loginItem = FakeLoginItem(status: .requiresApproval)
        let model = Self.model(runner: Self.availableRunner(), loginItem: loginItem)
        loginItem.statusChangedOutsideTheApp(to: .enabled)
        model.refreshLoginItemStatus()
        #expect(model.loginItemStatus == .enabled)
    }

    @Test
    func `the note under the toggle follows the status`() {
        #expect(Self.model(runner: Self.availableRunner()).loginItemNote == nil)
        let notFound = Self.model(
            runner: Self.availableRunner(),
            loginItem: FakeLoginItem(status: .notFound),
        )
        #expect(notFound.loginItemNote?.key == GeneralScreenText.loginItemNotFound.key)
        #expect(!notFound.isLaunchAtLoginOn)
    }

    // MARK: - REQ-002 requires approval

    @Test
    func `requires approval shows Open Login Items, which calls the port once`() {
        let loginItem = FakeLoginItem(status: .notRegistered)
        loginItem.registrationLeaves(.requiresApproval)
        let model = Self.model(runner: Self.availableRunner(), loginItem: loginItem)
        #expect(!model.showsOpenLoginItems)
        model.setLaunchAtLogin(true)
        #expect(model.loginItemStatus == .requiresApproval)
        #expect(model.isLaunchAtLoginOn)
        #expect(model.showsOpenLoginItems)
        #expect(model.loginItemNote?.key == GeneralScreenText.loginItemRequiresApproval.key)
        model.openLoginItems()
        #expect(loginItem.openSettingsCalls == 1)
    }

    // MARK: - REQ-003 Check Again

    @Test
    func `pressing Check Again exposes the resolved path and version`() async {
        let model = Self.model(runner: Self.availableRunner())
        await model.checkAgain()
        #expect(model.agent == .available(path: Self.claudePath, version: "2.1.3 (Claude Code)"))
        #expect(!model.isChecking)
        #expect(!model.showsSpinner)
    }

    @Test
    func `pressing Check Again exposes not found`() async {
        let runner = FakeAgentRunner(
            behaviors: [:],
            otherwise: Self.exits(1, ""),
            clock: ContinuousClock(),
        )
        let model = Self.model(runner: runner)
        await model.checkAgain()
        #expect(model.agent == .notFound)
    }

    @Test
    func `pressing Check Again exposes an error such as a timeout`() async {
        let runner = FakeAgentRunner(
            behaviors: [:],
            otherwise: .runsUntilTerminated,
            clock: ContinuousClock(),
        )
        let model = Self.model(runner: runner)
        await model.checkAgain()
        #expect(model.agent == .error("timed out"))
    }

    @Test
    func `a second Check Again while one is in flight starts nothing`() async {
        let runner = GatedRunner(answer: [:])
        let model = Self.model(runner: runner)
        let first = Task { await model.checkAgain() }
        await Self.settle()
        #expect(model.isChecking)
        await model.checkAgain()
        #expect(model.isChecking)
        runner.finish()
        await first.value
        #expect(model.agent == .notFound)
        #expect(!model.isChecking)
    }

    // MARK: - REQ-004 spinner timing

    @Test
    func `a check that finishes before 300 ms shows no spinner`() async {
        let clock = ManualClock(start: .now)
        let runner = GatedRunner(answer: [:])
        let model = Self.model(runner: runner, clock: clock)
        let check = Task { await model.checkAgain() }
        await Self.settle()
        clock.advance(by: .milliseconds(299))
        await Self.settle()
        #expect(model.isChecking)
        #expect(!model.showsSpinner)
        runner.finish()
        await check.value
        #expect(!model.showsSpinner)
        #expect(model.agent == .notFound)
    }

    @Test
    func `a check that runs 800 ms shows the spinner from 300 ms until it finishes`() async {
        let clock = ManualClock(start: .now)
        let runner = GatedRunner(answer: [:])
        let model = Self.model(runner: runner, clock: clock)
        let check = Task { await model.checkAgain() }
        await Self.settle()
        clock.advance(by: .milliseconds(300))
        await Self.settle()
        #expect(model.showsSpinner)
        clock.advance(by: .milliseconds(500))
        await Self.settle()
        #expect(model.showsSpinner)
        runner.finish()
        await check.value
        #expect(!model.showsSpinner)
        #expect(model.agent == .notFound)
    }

    @Test
    func `a spinner that appears is kept at least 500 ms`() async {
        let clock = ManualClock(start: .now)
        let runner = GatedRunner(answer: [:])
        let model = Self.model(runner: runner, clock: clock)
        let check = Task { await model.checkAgain() }
        await Self.settle()
        clock.advance(by: .milliseconds(300))
        await Self.settle()
        #expect(model.showsSpinner)
        runner.finish()
        await Self.settle()
        clock.advance(by: .milliseconds(100))
        await Self.settle()
        #expect(model.showsSpinner)
        #expect(model.isChecking)
        #expect(model.agent == nil)
        clock.advance(by: .milliseconds(400))
        await check.value
        #expect(!model.showsSpinner)
        #expect(model.agent == .notFound)
    }

    @Test
    func `the spinner timings are 300 ms and 500 ms`() {
        #expect(GeneralModel.spinnerDelay == .milliseconds(300))
        #expect(GeneralModel.spinnerMinimum == .milliseconds(500))
    }

    // MARK: - Row text

    @Test
    func `the agent row's text follows each state`() {
        #expect(GeneralModel.agentDetail(for: nil) == nil)
        #expect(GeneralModel.agentDetail(for: .available(path: "/p", version: "v"))?.key ==
            GeneralScreenText.resolvedViaLoginShell.key)
        #expect(GeneralModel.agentDetail(for: .notFound)?.key == GeneralScreenText.notFoundHint.key)
        #expect(GeneralModel.agentDetail(for: .error("x")) == nil)
        #expect(GeneralModel.agentHeadline(for: .notFound)?.key == GeneralScreenText.notFound.key)
        #expect(GeneralModel.agentHeadline(for: .error("timed out"))?
            .key == "generalScreen.agent.error")
        #expect(GeneralModel.agentHeadline(for: .available(path: "/p", version: "v")) == nil)
        #expect(GeneralModel.agentHeadline(for: nil) == nil)
    }
}
