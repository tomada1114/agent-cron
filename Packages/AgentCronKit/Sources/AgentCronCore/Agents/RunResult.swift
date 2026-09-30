import Foundation

/// What an agent's output says about how its run went, read back by the
/// ``AgentCommandBuilding`` that built the command line (ADR-0004).
///
/// It judges only the output. Whether the runner timed the process out or the user
/// stopped it is ``ProcessOutcome/terminatedBy``, which the dispatcher weighs first; this
/// is the answer for a process that exited on its own. Every field maps onto a ``Run``
/// field of the same name, so recording a run copies rather than interprets.
public struct RunResult: Sendable, Equatable {
    /// Whether the agent reported success.
    public enum Status: Sendable, Equatable {
        /// The agent finished and reported no error, and exited with status 0.
        case succeeded
        /// The agent reported an error, exited non-zero, or printed no result it could
        /// be read from.
        case failed
    }

    /// What the agent reported about the run besides its outcome, each field `nil` when
    /// the agent did not report it or reported something unusable.
    public struct Report: Sendable, Equatable {
        /// Nothing reported: the output was not a result the agent's parser could read.
        public static let empty = Self(costUSD: nil, sessionID: nil, duration: nil, turnCount: nil)

        /// What the run cost in US dollars — always a finite number when present, so a
        /// run file that stores it stays decodable.
        public let costUSD: Decimal?
        /// The agent's session identifier.
        public let sessionID: String?
        /// How long the agent says the run took.
        public let duration: Duration?
        /// How many turns the agent took.
        public let turnCount: Int?

        /// Makes a report from its parts.
        public init(costUSD: Decimal?, sessionID: String?, duration: Duration?, turnCount: Int?) {
            self.costUSD = costUSD
            self.sessionID = sessionID
            self.duration = duration
            self.turnCount = turnCount
        }
    }

    /// Whether the run succeeded.
    public let status: Status
    /// The agent's final result text; on a failure without one, the output that explains
    /// it — the raw stdout, or else the stderr — so history shows what the agent printed
    /// (requirements §3.4).
    public let resultText: String?
    /// For a failed run, a one-line reason: the agent's error kind and the first line of
    /// its error output. `nil` for a success, and for a failure that printed nothing.
    public let failureReason: String?
    /// What the agent reported besides its outcome.
    public let report: Report

    /// Makes a result from its parts.
    public init(status: Status, resultText: String?, failureReason: String?, report: Report) {
        self.status = status
        self.resultText = resultText
        self.failureReason = failureReason
        self.report = report
    }
}
