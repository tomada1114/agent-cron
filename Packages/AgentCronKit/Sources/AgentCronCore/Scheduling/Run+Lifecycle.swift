import Foundation

/// How a started ``Run`` becomes the record history keeps (requirements §3.3, §3.4).
///
/// A run starts ``RunOutcome/running`` (``Run/init(job:trigger:startedAt:scheduledAt:id:)``)
/// and leaves that state through exactly one of these. They are pure, so the
/// ``Dispatcher`` decides *when* a run ends and these decide *what* its record says.
extension Run {
    /// The record of a run that never launched, for `reason`, recorded at `date`.
    package func skipped(_ reason: SkipReason, at date: Date) -> Self {
        var run = ended(at: date)
        run.outcome = .skipped
        run.skipReason = reason
        return run
    }

    /// The record of a run the user stopped before its process launched: there is no exit
    /// status and no output to keep.
    package func stopped(at date: Date) -> Self {
        var run = ended(at: date)
        run.outcome = .stopped
        return run
    }

    /// The record of a run whose process ended with `outcome`, which `result` — the run's
    /// agent reading that outcome's output — describes.
    ///
    /// What ended the process decides first: a timeout or a Stop is that whatever the
    /// output says, and only a process that exited on its own takes the agent's verdict.
    /// The reported fields are copied either way, so a timed-out run still shows what the
    /// agent printed; a failure reason is kept only for a failed run.
    package func finished(with outcome: ProcessOutcome, result: RunResult, at date: Date) -> Self {
        var run = ended(at: date)
        run.exitCode = outcome.exitCode
        run.resultText = result.resultText
        run.costUSD = result.report.costUSD
        run.sessionID = result.report.sessionID
        switch outcome.terminatedBy {
        case .exit:
            switch result.status {
            case .succeeded:
                run.outcome = .succeeded

            case .failed:
                run.outcome = .failed
                run.failureReason = result.failureReason
            }

        case .timeout:
            run.outcome = .timedOut

        case .stopped:
            run.outcome = .stopped
        }
        return run
    }

    /// This run with its end set; its outcome is each caller's to decide.
    private func ended(at date: Date) -> Self {
        var run = self
        run.endedAt = date
        return run
    }
}
