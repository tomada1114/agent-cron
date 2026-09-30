import Foundation

/// The selected run's detail pane (`docs/product/requirements.md` §3.4).
public struct HistoryRunDetail: Sendable {
    /// What the detail shows below its fields (`docs/product/ux-flows.md` S3).
    public enum Body: Sendable, Equatable {
        /// The run is still going: elapsed time, Stop, and a note that the result follows.
        case running
        /// The run never started, and why.
        case skipped(SkipReason?)
        /// The run ended with this text: the result, or a failed run's error output.
        case output(String)
        /// The run ended and kept no text.
        case noOutput
    }

    /// The run itself: job name, trigger, scheduled/start/end times, outcome, exit code,
    /// session id, result, and the prompt snapshot.
    public let run: Run
    /// The run's status badge.
    public let badge: OutcomeBadgeKind
    /// How the run was started.
    public let trigger: LocalizedStringResource
    /// "2m 14s", or `nil` while the run has not ended.
    public let duration: LocalizedStringResource?
    /// The cost in US dollars, or `nil` when the agent reported none, so the pane omits it.
    public let cost: String?
    /// The start date and time to the second, in the model's locale and time zone.
    public let startedText: String
    /// The scheduled date and time, or `nil` for a manual run.
    public let scheduledText: String?
    /// Whether the run's job has since been deleted, so there is no job to open.
    public let isJobDeleted: Bool

    /// The job's name, with "(deleted)" after it once the job is gone.
    public var jobTitle: LocalizedStringResource {
        HistoryJobFilterOption(id: run.jobID, name: run.jobName, isDeleted: isJobDeleted).title
    }

    /// Whether the header offers Open Job.
    public var canOpenJob: Bool {
        !isJobDeleted
    }

    /// What shows below the fields. A failed run shows its error output ahead of any
    /// result text; every other ended run shows its result.
    public var body: Body {
        switch run.outcome {
        case .running:
            .running

        case .skipped:
            .skipped(run.skipReason)

        case .failed:
            (run.failureReason ?? run.resultText).map(Body.output) ?? .noOutput

        case .succeeded, .stopped, .timedOut:
            (run.resultText ?? run.failureReason).map(Body.output) ?? .noOutput
        }
    }

    /// The text [Copy] puts on the pasteboard, or `nil` when there is none.
    public var copyableText: String? {
        if case let .output(text) = body {
            return text
        }
        return nil
    }
}
