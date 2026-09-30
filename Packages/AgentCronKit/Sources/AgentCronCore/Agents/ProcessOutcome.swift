import Foundation

/// How one agent process ended and what it wrote: the one-shot answer of
/// ``AgentRunning/run(argv:directory:timeout:)`` (ADR-0004).
///
/// Values only, so the port never names a `Process` or a pipe. stdout stays raw bytes
/// because the agent's JSON result is decoded from it; stderr is text because it is only
/// ever shown, as the reason a run failed.
public struct ProcessOutcome: Sendable, Equatable {
    /// What ended the process — the difference between a run that failed, one that timed
    /// out, and one the user stopped.
    public enum Termination: Sendable, Equatable {
        /// The process exited on its own, whatever its status.
        case exit
        /// The task awaiting the run was cancelled — the user chose Stop — and the runner
        /// terminated the process.
        case stopped
        /// The run's timeout passed and the runner terminated the process.
        case timeout
    }

    /// The status of a process that could not be started at all: `-1`, which no process
    /// can exit with (a status is `0 ... 255`), so "never ran" is told apart from every
    /// real status — including the shell's `127`, "command not found".
    public static let notLaunchedExitCode: Int32 = -1

    /// Every byte the process wrote to standard output.
    public let stdout: Data
    /// What the process wrote to standard error, decoded as UTF-8 with any invalid bytes
    /// replaced.
    public let stderr: String
    /// The status as a shell reports it in `$?`: what the process exited with, or 128 plus
    /// the signal number when a signal ended it — 143 after SIGTERM, 137 after SIGKILL.
    public let exitCode: Int32
    /// What ended the process.
    public let terminatedBy: Termination

    /// Creates an outcome. Only an implementation of ``AgentRunning`` makes one; the
    /// initializer is public because that implementation lives in another module.
    public init(stdout: Data, stderr: String, exitCode: Int32, terminatedBy: Termination) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
        self.terminatedBy = terminatedBy
    }

    /// The outcome of a run whose process could not be started — most often because the
    /// job's directory no longer exists: it wrote nothing, it "exited" with
    /// ``notLaunchedExitCode``, and stderr says why, the way a shell would.
    ///
    /// - Parameter errorCode: The OS's code for why the launch failed. Only the number is
    ///   kept, never the OS's message, which can name paths.
    public static func notLaunched(errorCode: Int) -> Self {
        Self(
            stdout: Data(),
            stderr: "agentcron: could not start the process (error \(errorCode)); "
                + "check that the job's directory exists\n",
            exitCode: notLaunchedExitCode,
            terminatedBy: .exit,
        )
    }
}
