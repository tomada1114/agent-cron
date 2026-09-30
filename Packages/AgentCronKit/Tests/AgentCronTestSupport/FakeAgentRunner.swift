import AgentCronCore
import Foundation
import os

/// The one fake of ``AgentCronCore/AgentRunning``, shared by every test target.
///
/// A fake, not a mock (`.claude/rules/testing.md` › Fakes, not mocks): a real conforming
/// implementation that "runs" a command line by looking up the ``Behavior`` the test
/// handed it for that exact `argv`, and records every request it received. What it does
/// itself is what the port promises whatever runs: it refuses a missing directory, waits
/// out the timeout on its clock, and turns a cancelled task into a stopped run.
/// `AgentRunningContract` holds it to the same promises as `ProcessAgentRunner`.
///
/// Its record sits behind a lock rather than an `@unchecked Sendable`, so the fake is
/// `Sendable` the way the port requires whichever task a test runs it from.
package final class FakeAgentRunner: AgentRunning {
    /// What a scripted command line does once the fake "starts" it.
    package enum Behavior: Sendable, Equatable {
        /// It exits on its own at once, having written `stdout` and `stderr`.
        case exits(code: Int32, stdout: Data, stderr: String)
        /// It runs until it is terminated — by the timeout or by a Stop — and then ends
        /// as SIGTERM leaves a process, with ``FakeAgentRunner/terminatedExitCode``.
        case runsUntilTerminated
    }

    /// One call to ``run(argv:directory:timeout:)``, as the fake received it.
    package struct Request: Sendable, Equatable {
        /// The command line it was asked to run.
        package let argv: [String]
        /// The directory it was asked to run it in.
        package let directory: URL
        /// How long the run was allowed to take.
        package let timeout: Duration
    }

    /// The status a terminated ``Behavior/runsUntilTerminated`` run reports: 128 + 15,
    /// what a shell's `$?` says of a process SIGTERM ended.
    package static let terminatedExitCode: Int32 = 143

    private let behaviors: [[String]: Behavior]
    private let otherwise: Behavior
    private let clock: any Clock<Duration>
    private let received = OSAllocatedUnfairLock<[Request]>(initialState: [])

    /// Every request so far, oldest first.
    package var requests: [Request] {
        received.withLock { $0 }
    }

    /// A runner that does `behaviors[argv]` for a command line it was scripted for, and
    /// `otherwise` for any other, waiting out timeouts on `clock`.
    package init(
        behaviors: [[String]: Behavior],
        otherwise: Behavior,
        clock: any Clock<Duration>,
    ) {
        self.behaviors = behaviors
        self.otherwise = otherwise
        self.clock = clock
    }

    package func run(argv: [String], directory: URL, timeout: Duration) async -> ProcessOutcome {
        received.withLock { $0.append(Request(argv: argv, directory: directory, timeout: timeout)) }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            return .notLaunched(errorCode: NSFileNoSuchFileError)
        }
        switch behaviors[argv] ?? otherwise {
        case let .exits(code, stdout, stderr):
            return ProcessOutcome(
                stdout: stdout,
                stderr: stderr,
                exitCode: code,
                terminatedBy: .exit,
            )

        case .runsUntilTerminated:
            let endedBy: ProcessOutcome.Termination
            do {
                try await clock.sleep(for: timeout)
                endedBy = .timeout
            } catch {
                // A clock's sleep throws only CancellationError, which is the port's Stop.
                endedBy = .stopped
            }
            return ProcessOutcome(
                stdout: Data(),
                stderr: "",
                exitCode: Self.terminatedExitCode,
                terminatedBy: endedBy,
            )
        }
    }
}
