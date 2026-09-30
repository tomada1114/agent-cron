import AgentCronCore
import Foundation

/// The `Process`-backed adapter for ``AgentCronCore/AgentRunning`` (ADR-0004): it launches
/// `/bin/zsh -l -c 'exec "$@"' agentcron <argv…>` in the job's directory, collects what
/// the process writes, and terminates it at the timeout or on Stop.
///
/// The login shell reads `/etc/zprofile` and `~/.zprofile`, so the agent sees the PATH,
/// `gh`, `mise`, and the other tools a Terminal window sees (requirements §3.3); `exec "$@"`
/// then replaces the shell with `argv` itself, passed as separate arguments the shell never
/// re-parses, and `agentcron` is only `$0`, the name the shell reports its own errors
/// under. Standard input is `/dev/null`, so nothing can wait on a terminal no one types in.
///
/// Translation only: whether and when to run, and what an outcome means, are Core's
/// decisions, which is why this file sits outside the coverage floor. What is checked here
/// instead is the translation, by the local-machine test `ProcessAgentRunnerTests` against
/// real processes: opt-in, human-run (`just test-local`), and reported as skipped under
/// `just test` and in CI.
///
/// Termination signals the process's whole process group — `Process` starts each child
/// as the leader of a group of its own — so whatever the agent started and left in that
/// group ends with it.
public final class ProcessAgentRunner: AgentRunning {
    private enum Environment {
        case inherited
        case replaced(with: [String: String])
    }

    /// How long a terminated process has to exit after SIGTERM before SIGKILL, and how
    /// long a finished run waits for stragglers still holding its output open (ADR-0004).
    private static let gracePeriodSeconds = 10

    /// A shell's `$?` for a process a signal ended is this plus the signal number.
    private static let signalStatusBase: Int32 = 128

    private static let shell = URL(filePath: "/bin/zsh")
    private static let shellArguments = ["-l", "-c", #"exec "$@""#, "agentcron"]

    private static var gracePeriod: Duration {
        .seconds(gracePeriodSeconds)
    }

    private let environment: Environment

    /// A runner whose login shell starts from the app's own environment — in the app, what
    /// launchd handed it — and builds the PATH on top of it.
    public init() {
        environment = .inherited
    }

    /// A runner whose login shell starts from `environment` instead of the app's. A test
    /// passes a bare one to show that the login shell, not the caller, supplies the PATH.
    public init(environment: [String: String]) {
        self.environment = .replaced(with: environment)
    }

    /// Whichever comes first: the process exits, the timeout passes, or the calling task
    /// is cancelled.
    private static func firstEnd(
        of launched: LaunchedProcess,
        timeout: Duration,
    ) async -> ProcessOutcome.Termination {
        await withTaskGroup(of: ProcessOutcome.Termination?.self) { group in
            group.addTask {
                await launched.wait(for: .exited) ? .exit : nil
            }
            group.addTask {
                do {
                    try await Task.sleep(for: timeout)
                    return .timeout
                } catch {
                    // Task.sleep throws only CancellationError: the caller's Stop, or this
                    // group winding down once the process has exited.
                    return .stopped
                }
            }
            var first: ProcessOutcome.Termination?
            while first == nil, let next = await group.next() {
                first = next
            }
            group.cancelAll()
            return first ?? .stopped
        }
    }

    /// SIGTERM to the process group, then SIGKILL if the group's output is still open a
    /// grace period later.
    private static func terminate(group: pid_t, _ launched: LaunchedProcess) async {
        kill(-group, SIGTERM)
        if await launched.wait(for: .drained, atMost: gracePeriod) {
            return
        }
        kill(-group, SIGKILL)
    }

    /// The status the way a shell's `$?` reports it, so a run reads as it would in
    /// Terminal: the exit status, or 128 plus the signal that ended the process.
    private static func shellStatus(of process: Process) -> Int32 {
        switch process.terminationReason {
        case .exit:
            process.terminationStatus

        case .uncaughtSignal:
            signalStatusBase + process.terminationStatus

        @unknown default:
            process.terminationStatus
        }
    }

    /// `bytes` as UTF-8 text, each invalid sequence replaced by U+FFFD, so stderr that is
    /// not quite UTF-8 still reads rather than vanishing. Spelled out with `transcode`
    /// because SwiftLint's `optional_data_string_conversion` rejects the one-line
    /// `String(decoding:as:)`, and the failable initializer it suggests would drop the
    /// whole stream instead.
    private static func text(from bytes: Data) -> String {
        var scalars = String.UnicodeScalarView()
        _ = transcode(
            bytes.makeIterator(),
            from: UTF8.self,
            to: UTF32.self,
            stoppingOnError: false,
        ) { scalars.append(Unicode.Scalar($0) ?? "\u{FFFD}") }
        return String(scalars)
    }

    /// Runs `argv` through the login shell in `directory` and answers once the process has
    /// ended: on its own, or terminated at `timeout` or when the calling task is cancelled.
    public func run(argv: [String], directory: URL, timeout: Duration) async -> ProcessOutcome {
        let process = Process()
        process.executableURL = Self.shell
        process.arguments = Self.shellArguments + argv
        process.currentDirectoryURL = directory
        if case let .replaced(with: variables) = environment {
            process.environment = variables
        }
        process.standardInput = FileHandle.nullDevice
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        let launched = LaunchedProcess(
            stdout: stdout.fileHandleForReading,
            stderr: stderr.fileHandleForReading,
        )
        process.terminationHandler = { ended in
            launched.exited(with: Self.shellStatus(of: ended))
        }
        do {
            try process.run()
        } catch {
            _ = launched.finish()
            return .notLaunched(errorCode: (error as NSError).code)
        }
        let group = process.processIdentifier

        let endedBy = await Self.firstEnd(of: launched, timeout: timeout)
        if endedBy != .exit {
            await Self.terminate(group: group, launched)
        }
        _ = await launched.wait(for: .drained, atMost: Self.gracePeriod)
        let collected = launched.finish()
        return ProcessOutcome(
            stdout: collected.stdout,
            stderr: Self.text(from: collected.stderr),
            // Only a process that outlived SIGKILL by a whole grace period has no status.
            exitCode: collected.exitCode ?? Self.signalStatusBase + SIGKILL,
            terminatedBy: endedBy,
        )
    }
}
