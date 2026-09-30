import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

@Suite("AgentAvailability")
struct AgentAvailabilityTests {
    private static let resolve = AgentAvailabilityChecker.resolveArguments(for: .claudeCode)
    private static let claudePath = "/Users/me/.local/bin/claude"
    private static let version = [claudePath, "--version"]

    private static func exits(_ code: Int32, _ stdout: String) -> FakeAgentRunner.Behavior {
        .exits(code: code, stdout: Data(stdout.utf8), stderr: "")
    }

    private static func check(
        _ behaviors: [[String]: FakeAgentRunner.Behavior],
        directory: URL = FileManager.default.temporaryDirectory,
    ) async -> (AgentAvailability, FakeAgentRunner) {
        let runner = FakeAgentRunner(
            behaviors: behaviors,
            otherwise: exits(127, ""),
            clock: ContinuousClock(),
        )
        let checker = AgentAvailabilityChecker(
            runner: runner,
            directory: directory,
            timeout: .milliseconds(10),
        )
        return await (checker.check(.claudeCode), runner)
    }

    @Test
    func `a resolved CLI answers its trimmed path and version`() async {
        let (result, runner) = await Self.check([
            Self.resolve: Self.exits(0, "\(Self.claudePath)\n"),
            Self.version: Self.exits(0, "2.1.0 (Claude Code)\n"),
        ])
        #expect(result == .available(path: Self.claudePath, version: "2.1.0 (Claude Code)"))
        #expect(runner.requests.map(\.argv) == [Self.resolve, Self.version])
        #expect(runner.requests.allSatisfy { $0.timeout == .milliseconds(10) })
    }

    @Test
    func `resolution goes through a shell because command is a builtin`() {
        #expect(Self.resolve == ["/bin/sh", "-c", "command -v \"$1\"", "sh", "claude"])
        #expect(AgentKind.claudeCode.executableName == AgentKind.claudeCode.commandBuilder
            .arguments(for: RunRequest(
                prompt: "x",
                model: .default,
                effort: .default,
                permissionMode: .auto,
            ))
            .first)
    }

    @Test
    func `the default timeout is five seconds`() {
        #expect(AgentAvailabilityChecker.defaultTimeout == .seconds(5))
    }

    @Test
    func `login-shell noise before the output is ignored`() async {
        let (result, _) = await Self.check([
            Self.resolve: Self.exits(
                0,
                "Welcome back!\nnvm: using node 22\n\(Self.claudePath)\n\n",
            ),
            Self.version: Self.exits(0, "Welcome back!\n2.1.0 (Claude Code)\n"),
        ])
        #expect(result == .available(path: Self.claudePath, version: "2.1.0 (Claude Code)"))
    }

    @Test
    func `empty version output is still available`() async {
        let (result, _) = await Self.check([
            Self.resolve: Self.exits(0, Self.claudePath),
            Self.version: Self.exits(0, ""),
        ])
        #expect(result == .available(path: Self.claudePath, version: ""))
    }

    @Test
    func `a CLI the login shell does not find is not found`() async {
        let (result, runner) = await Self.check([Self.resolve: Self.exits(1, "")])
        #expect(result == .notFound)
        #expect(runner.requests.count == 1)
    }

    @Test
    func `a zero exit with only blank output is not found`() async {
        let (result, _) = await Self.check([Self.resolve: Self.exits(0, "\n  \n")])
        #expect(result == .notFound)
    }

    @Test
    func `a failing version command is an error`() async {
        let (result, _) = await Self.check([
            Self.resolve: Self.exits(0, Self.claudePath),
            Self.version: Self.exits(2, "boom"),
        ])
        #expect(result == .error("--version exited with status 2"))
    }

    @Test
    func `a version command that times out is an error`() async {
        let (result, _) = await Self.check([
            Self.resolve: Self.exits(0, Self.claudePath),
            Self.version: .runsUntilTerminated,
        ])
        #expect(result == .error("timed out"))
    }

    @Test
    func `a resolution that times out is an error`() async {
        let (result, runner) = await Self.check([Self.resolve: .runsUntilTerminated])
        #expect(result == .error("timed out"))
        #expect(runner.requests.count == 1)
    }

    @Test
    func `a shell that cannot start is an error, not not-found`() async {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentcron-missing-\(UUID().uuidString)")
        let (result, _) = await Self.check(
            [Self.resolve: Self.exits(0, Self.claudePath)],
            directory: missing,
        )
        #expect(result == .error("could not start the login shell"))
    }

    @Test
    func `a cancelled check is reported as stopped`() async {
        let runner = FakeAgentRunner(
            behaviors: [Self.resolve: .runsUntilTerminated],
            otherwise: Self.exits(127, ""),
            clock: ContinuousClock(),
        )
        let checker = AgentAvailabilityChecker(
            runner: runner,
            directory: FileManager.default.temporaryDirectory,
            timeout: .seconds(60),
        )
        let task = Task { await checker.check() }
        task.cancel()
        #expect(await task.value == .error("stopped"))
    }
}
