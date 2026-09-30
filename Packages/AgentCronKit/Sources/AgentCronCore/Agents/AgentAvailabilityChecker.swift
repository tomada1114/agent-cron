import Foundation

/// Checks whether an ``AgentKind``'s CLI resolves in the login shell, through the same
/// ``AgentRunning`` port a run uses, so the answer matches what a run would see.
///
/// Resolution runs `/bin/sh -c 'command -v "$1"'` rather than a bare `command -v`: the
/// runner `exec`s its argv, and `command` is a shell builtin, not a program. The `sh`
/// inherits the login shell's PATH. Anything a login profile prints to stdout comes
/// before the command's own output, so only the last non-blank line is read.
public struct AgentAvailabilityChecker: Sendable {
    /// How long each of the two commands may take (plan P08).
    public static let defaultTimeout: Duration = .seconds(defaultTimeoutSeconds)

    private static let defaultTimeoutSeconds = 5

    private let runner: any AgentRunning
    private let directory: URL
    private let timeout: Duration

    /// A checker that runs its commands through `runner` in `directory` (any directory
    /// that exists; the user's home in the app), allowing each `timeout`.
    public init(
        runner: any AgentRunning,
        directory: URL = FileManager.default.homeDirectoryForCurrentUser,
        timeout: Duration = Self.defaultTimeout,
    ) {
        self.runner = runner
        self.directory = directory
        self.timeout = timeout
    }

    /// The `argv` that prints where `kind`'s CLI resolves, exiting non-zero when it does
    /// not.
    public static func resolveArguments(for kind: AgentKind) -> [String] {
        ["/bin/sh", "-c", "command -v \"$1\"", "sh", kind.executableName]
    }

    /// The error an outcome means whichever command produced it, or `nil` when the
    /// process ran and exited on its own.
    private static func failure(of outcome: ProcessOutcome) -> AgentAvailability? {
        switch outcome.terminatedBy {
        case .timeout:
            return .error("timed out")

        case .stopped:
            return .error("stopped")

        case .exit:
            if outcome.exitCode == ProcessOutcome.notLaunchedExitCode {
                return .error("could not start the login shell")
            }
            return nil
        }
    }

    /// The last non-blank line of `data`, trimmed; lines that are not UTF-8 are skipped.
    private static func lastLine(of data: Data) -> String {
        data.split(separator: UInt8(ascii: "\n"))
            .compactMap { String(bytes: $0, encoding: .utf8) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .last { !$0.isEmpty } ?? ""
    }

    /// Resolves `kind`'s CLI, then asks the resolved program for `--version`.
    public func check(_ kind: AgentKind = .claudeCode) async -> AgentAvailability {
        let resolved = await runner.run(
            argv: Self.resolveArguments(for: kind),
            directory: directory,
            timeout: timeout,
        )
        if let failure = Self.failure(of: resolved) {
            return failure
        }
        let path = Self.lastLine(of: resolved.stdout)
        guard resolved.exitCode == 0, !path.isEmpty else {
            return .notFound
        }

        let versioned = await runner.run(
            argv: [path, "--version"],
            directory: directory,
            timeout: timeout,
        )
        if let failure = Self.failure(of: versioned) {
            return failure
        }
        guard versioned.exitCode == 0 else {
            return .error("--version exited with status \(versioned.exitCode)")
        }
        return .available(path: path, version: Self.lastLine(of: versioned.stdout))
    }
}
