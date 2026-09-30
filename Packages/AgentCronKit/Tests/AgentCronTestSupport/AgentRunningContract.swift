import AgentCronCore
import Foundation
import Testing

/// The promises ``AgentCronCore/AgentRunning`` makes, checked against any implementation of
/// it (`.claude/rules/testing.md` › One Contract Suite per Port).
///
/// It runs a handful of real command lines — the tools every Mac ships in `/bin` and
/// `/usr/bin` — and compares what came back with what those tools do. `AgentCronCoreTests`
/// runs it against ``FakeAgentRunner`` scripted with ``fakeBehaviors`` on every
/// `just test` and in CI; `AgentCronPlatformTests` runs it against `ProcessAgentRunner`
/// under `.requiresLocalMachine` (`just test-local`), where the processes are real. Every
/// clause is one the port's `///` states; a new clause is stated there first.
package enum AgentRunningContract {
    /// Prints every argument after the format on a bracketed line of its own — `printf`
    /// reuses its format per argument — so the output shows where each argument ends
    /// (clause 2). One argument holds a space, one holds quotes, `$`, and `*`.
    package static let argumentEchoArgv = [
        "/usr/bin/printf", #"[%s]\n"#, "hello world", #"it's "quoted" $HOME *"#,
    ]

    /// What ``argumentEchoArgv`` writes to stdout when no shell re-parses its arguments.
    package static let argumentEchoOutput = Data(#"""
    [hello world]
    [it's "quoted" $HOME *]

    """#.utf8)

    /// Writes `oops` to stderr and exits 3: an exit status and stderr passed back (clause 1).
    package static let failingArgv = ["/bin/sh", "-c", "printf oops >&2; exit 3"]

    /// What ``failingArgv`` writes to stderr.
    package static let failingStderr = "oops"

    /// The status ``failingArgv`` exits with.
    package static let failingExitCode: Int32 = 3

    /// Outlives any timeout the contract sets: only the runner can end it (clauses 3–4).
    package static let hangingArgv = ["/bin/sleep", "30"]

    /// The timeout of every run the contract expects to end before it.
    package static var ampleTimeout: Duration {
        .seconds(ampleTimeoutSeconds)
    }

    /// What a shell's `$?` is for a command it cannot find.
    package static let commandNotFoundExitCode: Int32 = 127

    private static let ampleTimeoutSeconds = 30

    /// ``FakeAgentRunner``'s script: what the command lines above do when a real process
    /// runs them. Anything else is scripted as ``unknownCommand``.
    package static let fakeBehaviors: [[String]: FakeAgentRunner.Behavior] = [
        argumentEchoArgv: .exits(code: 0, stdout: argumentEchoOutput, stderr: ""),
        failingArgv: .exits(code: failingExitCode, stdout: Data(), stderr: failingStderr),
        hangingArgv: .runsUntilTerminated,
    ]

    /// What ``FakeAgentRunner`` does for a command line outside ``fakeBehaviors``: what a
    /// shell does for a command it cannot find.
    package static let unknownCommand = FakeAgentRunner.Behavior.exits(
        code: commandNotFoundExitCode,
        stdout: Data(),
        stderr: "agentcron: command not found\n",
    )

    /// A description of every broken promise, empty when `runner` keeps them all.
    ///
    /// `directory` must exist; the runs change nothing in it. `timeout` is the one given
    /// to the run that must time out — short for a real process, and anything at all for
    /// a fake whose clock does not wait. Separate from ``check(_:in:timeout:)`` so a test
    /// can hand it a runner that breaks a promise and see the contract notice — the proof
    /// it is not vacuous.
    package static func violations(
        of runner: some AgentRunning,
        in directory: URL,
        timeout: Duration,
    ) async -> [String] {
        var broken: [String] = []
        func expect(_ actual: ProcessOutcome, _ expected: ProcessOutcome, _ what: String) {
            if actual != expected {
                broken.append("\(what) answered \(actual), expected \(expected)")
            }
        }
        func expectTerminated(_ actual: ProcessOutcome, by expected: ProcessOutcome.Termination) {
            if actual.terminatedBy != expected || actual.exitCode == 0 {
                broken.append("a run ended by \(expected) answered \(actual)")
            }
        }

        let echoed = await runner.run(
            argv: argumentEchoArgv,
            directory: directory,
            timeout: ampleTimeout,
        )
        expect(echoed, exited(0, stdout: argumentEchoOutput, stderr: ""), "the argument echo")

        let failed = await runner.run(
            argv: failingArgv,
            directory: directory,
            timeout: ampleTimeout,
        )
        expect(failed, exited(failingExitCode, stdout: Data(), stderr: failingStderr), "exit 3")

        let timedOut = await runner.run(argv: hangingArgv, directory: directory, timeout: timeout)
        expectTerminated(timedOut, by: .timeout)

        let stopping = Task {
            await runner.run(argv: hangingArgv, directory: directory, timeout: ampleTimeout)
        }
        stopping.cancel()
        await expectTerminated(stopping.value, by: .stopped)

        let missing = directory.appending(
            path: "missing-\(UUID().uuidString)",
            directoryHint: .isDirectory,
        )
        let notLaunched = await runner.run(
            argv: argumentEchoArgv,
            directory: missing,
            timeout: ampleTimeout,
        )
        let reportedNotLaunched = notLaunched.terminatedBy == .exit
            && notLaunched.exitCode == ProcessOutcome.notLaunchedExitCode
            && notLaunched.stdout.isEmpty
            && !notLaunched.stderr.isEmpty
        if !reportedNotLaunched {
            broken.append("a run in a missing directory answered \(notLaunched)")
        }
        return broken
    }

    /// Records an issue for every promise `runner` breaks.
    package static func check(
        _ runner: some AgentRunning,
        in directory: URL,
        timeout: Duration,
    ) async {
        let broken = await violations(of: runner, in: directory, timeout: timeout)
        #expect(broken.isEmpty, "\(type(of: runner)) breaks the AgentRunning contract: \(broken)")
    }

    private static func exited(_ code: Int32, stdout: Data, stderr: String) -> ProcessOutcome {
        ProcessOutcome(stdout: stdout, stderr: stderr, exitCode: code, terminatedBy: .exit)
    }
}
