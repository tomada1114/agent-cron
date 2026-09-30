import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

// MARK: - Runners that each break one promise

/// ``FakeAgentRunner`` scripted with what the contract's command lines really do.
private func scriptedFake() -> FakeAgentRunner {
    FakeAgentRunner(
        behaviors: AgentRunningContract.fakeBehaviors,
        otherwise: AgentRunningContract.unknownCommand,
        clock: ContinuousClock(),
    )
}

/// A directory that exists and that no run writes to.
private let existingDirectory = FileManager.default.temporaryDirectory

private struct Reparsing: AgentRunning {
    let inner = scriptedFake()

    func run(argv: [String], directory: URL, timeout: Duration) async -> ProcessOutcome {
        // Breaks clause 2: the command line is joined and split again on spaces, as
        // `sh -c "$*"` would.
        let reparsed = argv.joined(separator: " ").split(separator: " ").map(String.init)
        return await inner.run(argv: reparsed, directory: directory, timeout: timeout)
    }
}

private struct NeverTerminating: AgentRunning {
    let inner = scriptedFake()

    func run(argv: [String], directory: URL, timeout: Duration) async -> ProcessOutcome {
        // Breaks clauses 3 and 4: a process that would run on is reported as exiting.
        guard argv != AgentRunningContract.hangingArgv else {
            return ProcessOutcome(stdout: Data(), stderr: "", exitCode: 0, terminatedBy: .exit)
        }
        return await inner.run(argv: argv, directory: directory, timeout: timeout)
    }
}

private struct SwappingTimeoutAndStop: AgentRunning {
    let inner = scriptedFake()

    func run(argv: [String], directory: URL, timeout: Duration) async -> ProcessOutcome {
        // Breaks clauses 3 and 4: each termination is reported as the other.
        let outcome = await inner.run(argv: argv, directory: directory, timeout: timeout)
        let swapped: ProcessOutcome.Termination = switch outcome.terminatedBy {
        case .exit:
            .exit

        case .stopped:
            .timeout

        case .timeout:
            .stopped
        }
        return ProcessOutcome(
            stdout: outcome.stdout,
            stderr: outcome.stderr,
            exitCode: outcome.exitCode,
            terminatedBy: swapped,
        )
    }
}

private struct TerminatingWithStatusZero: AgentRunning {
    let inner = scriptedFake()

    func run(argv: [String], directory: URL, timeout: Duration) async -> ProcessOutcome {
        // Breaks clauses 3 and 4: a terminated process is reported as a success.
        let outcome = await inner.run(argv: argv, directory: directory, timeout: timeout)
        guard outcome.terminatedBy != .exit else {
            return outcome
        }
        return ProcessOutcome(
            stdout: outcome.stdout,
            stderr: outcome.stderr,
            exitCode: 0,
            terminatedBy: outcome.terminatedBy,
        )
    }
}

private struct IgnoringDirectory: AgentRunning {
    let inner = scriptedFake()

    func run(argv: [String], directory _: URL, timeout: Duration) async -> ProcessOutcome {
        // Breaks clause 5: every run happens somewhere, even when its directory is gone.
        await inner.run(argv: argv, directory: existingDirectory, timeout: timeout)
    }
}

/// The fake half of the `AgentRunning` contract suite: the same ``AgentRunningContract``
/// that `AgentCronPlatformTests` runs against the real adapter under `just test-local` runs
/// here against ``FakeAgentRunner``, on every `just test` and in CI, so the fake cannot
/// drift from the port's promises.
@Suite("AgentRunning contract, against the fake")
struct AgentRunningContractTests {
    @Test
    func `the fake keeps the contract`() async {
        // The fake's clock waits out a zero timeout at once, so nothing here waits.
        await AgentRunningContract.check(scriptedFake(), in: existingDirectory, timeout: .zero)
    }

    @Test
    func `the fake records what it was asked to run, where, and for how long`() async {
        let runner = scriptedFake()
        _ = await runner.run(
            argv: AgentRunningContract.failingArgv,
            directory: existingDirectory,
            timeout: .seconds(90),
        )
        let requests = runner.requests
        #expect(requests.count == 1)
        #expect(requests.first?.argv == ["/bin/sh", "-c", "printf oops >&2; exit 3"])
        #expect(requests.first?.directory == existingDirectory)
        #expect(requests.first?.timeout == .seconds(90))
    }

    @Test
    func `the fake answers a command line it was not scripted for with its fallback`() async {
        let outcome = await scriptedFake().run(
            argv: ["claude", "-p", "hello"],
            directory: existingDirectory,
            timeout: .seconds(1),
        )
        #expect(outcome == ProcessOutcome(
            stdout: Data(),
            stderr: "agentcron: command not found\n",
            exitCode: 127,
            terminatedBy: .exit,
        ))
    }

    @Test
    func `the fake treats a file where the directory should be as missing`() async throws {
        let file = FileManager.default.temporaryDirectory
            .appending(path: "AgentCronTests-\(UUID().uuidString)")
        try Data().write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let outcome = await scriptedFake().run(
            argv: AgentRunningContract.argumentEchoArgv,
            directory: file,
            timeout: .seconds(1),
        )
        #expect(outcome == .notLaunched(errorCode: NSFileNoSuchFileError))
    }

    // The contract's own oracle: a runner that breaks a promise must be reported, or
    // `check` would pass anything, the real adapter included.

    @Test
    func `a runner whose arguments are re-parsed is reported`() async {
        let violations = await AgentRunningContract.violations(
            of: Reparsing(),
            in: existingDirectory,
            timeout: .zero,
        )
        #expect(violations.count == 2)
        #expect(violations.first?.hasPrefix("the argument echo answered") == true)
        #expect(violations.last?.hasPrefix("exit 3 answered") == true)
    }

    @Test
    func `a runner that never terminates a process is reported`() async {
        let violations = await AgentRunningContract.violations(
            of: NeverTerminating(),
            in: existingDirectory,
            timeout: .zero,
        )
        #expect(violations.map { $0.prefix(26) } == [
            "a run ended by timeout ans",
            "a run ended by stopped ans",
        ])
    }

    @Test
    func `a runner that confuses a timeout with a stop is reported`() async {
        let violations = await AgentRunningContract.violations(
            of: SwappingTimeoutAndStop(),
            in: existingDirectory,
            timeout: .zero,
        )
        #expect(violations.map { $0.prefix(26) } == [
            "a run ended by timeout ans",
            "a run ended by stopped ans",
        ])
    }

    @Test
    func `a runner that reports a terminated process as a success is reported`() async {
        let violations = await AgentRunningContract.violations(
            of: TerminatingWithStatusZero(),
            in: existingDirectory,
            timeout: .zero,
        )
        #expect(violations.count == 2)
    }

    @Test
    func `a runner that runs in a missing directory is reported`() async {
        let violations = await AgentRunningContract.violations(
            of: IgnoringDirectory(),
            in: existingDirectory,
            timeout: .zero,
        )
        #expect(violations.count == 1)
        #expect(violations.first?.hasPrefix("a run in a missing directory answered") == true)
    }
}
