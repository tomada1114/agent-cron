import AgentCronCore
import Foundation
import SwiftUI

// Previews of the History screen, one per state the issue names (#24): empty,
// filtered to zero, populated, succeeded, failed, skipped, running, and a deleted job —
// plus dark. Each builds its model over an in-memory store; nothing here ships in a code
// path.

/// A run store for previews: answers `saved` and keeps nothing, so a preview never
/// touches Application Support.
private struct PreviewRunStore: RunStoring {
    let saved: [Run]

    func save(_: Run) {
        // A preview keeps nothing.
    }

    func runs(in _: DateInterval) -> [Run] {
        saved
    }

    func deleteRuns(olderThan _: Date) -> Int {
        0
    }
}

@MainActor
private enum HistoryPreview {
    private enum Seconds {
        static let minute: TimeInterval = 60
        static let hour: TimeInterval = 3_600
        static let day: TimeInterval = 86_400
        static let digestRun: TimeInterval = 134
        static let running: TimeInterval = 252
        static let failedRun: TimeInterval = 47
        static let startDelay: TimeInterval = 2
        static let nineAM: TimeInterval = 32_400
        static let sixPM: TimeInterval = 64_800
        static let tenPM: TimeInterval = 79_200
    }

    private enum Cost {
        static let digest = Decimal(string: "0.12") ?? 0
        static let review = Decimal(string: "0.31") ?? 0
    }

    private static let exitFailure: Int32 = 1
    private static let reviewJobIndex = 2

    static let digestID = UUID(uuidString: "00000000-0000-0000-0000-000000000011") ?? UUID()
    static let reviewID = UUID(uuidString: "00000000-0000-0000-0000-000000000012") ?? UUID()
    static let nightlyID = UUID(uuidString: "00000000-0000-0000-0000-000000000013") ?? UUID()
    static let succeededRunID = UUID(uuidString: "00000000-0000-0000-0000-000000000021") ?? UUID()
    static let runningRunID = UUID(uuidString: "00000000-0000-0000-0000-000000000022") ?? UUID()
    static let failedRunID = UUID(uuidString: "00000000-0000-0000-0000-000000000023") ?? UUID()
    static let skippedRunID = UUID(uuidString: "00000000-0000-0000-0000-000000000024") ?? UUID()

    static var jobs: [Job] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let schedule = Schedule(weekdays: SchedulePreset.everyDay.weekdays, times: [])
        return [
            Job(
                name: "RSS digest",
                directory: home.appending(path: "ghq/news-digest", directoryHint: .isDirectory),
                prompt: "Run /rss-digest and update news.html.",
                schedule: schedule,
                createdAt: .now,
                id: digestID,
            ),
            Job(
                name: "Dependabot",
                directory: home.appending(path: "ghq/agent-cron", directoryHint: .isDirectory),
                prompt: "Review and merge safe Dependabot pull requests.",
                schedule: schedule,
                createdAt: .now,
                id: reviewID,
            ),
            Job(
                name: "Nightly review",
                directory: home.appending(path: "ghq/agent-cron", directoryHint: .isDirectory),
                prompt: "Review the open pull requests and merge the safe ones.",
                schedule: schedule,
                createdAt: .now,
                id: nightlyID,
            ),
        ]
    }

    static var runs: [Run] {
        let all = jobs
        let today = Calendar.current.startOfDay(for: .now)
        let yesterday = today - Seconds.day
        let nineAM = Seconds.nineAM
        let sixPM = Seconds.sixPM
        let tenPM = Seconds.tenPM

        var succeeded = Run(
            job: all[0],
            trigger: .scheduled,
            startedAt: today + nineAM + Seconds.startDelay,
            scheduledAt: today + nineAM,
            id: succeededRunID,
        )
        succeeded.outcome = .succeeded
        succeeded.endedAt = succeeded.startedAt + Seconds.digestRun
        succeeded.costUSD = Cost.digest
        succeeded.exitCode = 0
        succeeded.sessionID = "3f2a9c1e-7b44-4d0e-9a51-2c6f0e8d1b73"
        succeeded.resultText = """
        ## Today's digest
        - Swift 6.2 released with *approachable concurrency*
        - Xcode beta adds `#Preview` improvements

        ### Merged
        1. Bump actions/checkout
        """

        let running = Run(
            job: all[1],
            trigger: .manual,
            startedAt: .now - Seconds.running,
            id: runningRunID,
        )

        var failed = Run(
            job: all[reviewJobIndex],
            trigger: .scheduled,
            startedAt: yesterday + tenPM,
            scheduledAt: yesterday + tenPM,
            id: failedRunID,
        )
        failed.outcome = .failed
        failed.endedAt = failed.startedAt + Seconds.failedRun
        failed.exitCode = exitFailure
        failed.costUSD = Cost.review
        failed.failureReason = "error_during_execution: gh: authentication required"

        var skipped = Run(
            job: all[0],
            trigger: .scheduled,
            startedAt: yesterday + sixPM + Seconds.hour + Seconds.minute,
            scheduledAt: yesterday + sixPM,
            id: skippedRunID,
        )
        skipped.outcome = .skipped
        skipped.endedAt = skipped.startedAt
        skipped.skipReason = .missed

        return [succeeded, running, failed, skipped]
    }

    /// A loaded model over `runs`, knowing ``jobs`` as the saved jobs, with `runID`
    /// selected.
    static func model(_ runs: [Run], selecting runID: UUID?) -> HistoryModel {
        model(runs, liveJobs: jobs, selecting: runID)
    }

    /// A loaded model over `runs`, knowing `liveJobs` as the saved jobs, with `runID`
    /// selected.
    static func model(
        _ runs: [Run],
        liveJobs: [Job],
        selecting runID: UUID?,
    ) -> HistoryModel {
        let history = HistoryModel(
            store: PreviewRunStore(saved: runs),
            calendar: .current,
            locale: .current,
        )
        history.reload()
        history.jobsChanged(to: liveJobs)
        history.select(runID: runID)
        return history
    }

    static func screen(_ history: HistoryModel) -> some View {
        let navigation = MainNavigationModel.preview(showing: .history)
        navigation.select(runID: history.selectedRunID)
        return HistoryScreenView(navigation: navigation, history: history) { _ in
            // A preview stops nothing.
        }
        .frame(width: DesignLock.mainWindowDefaultWidth - DesignLock.mainWindowSidebarWidth)
        .frame(minHeight: DesignLock.mainWindowDefaultHeight)
    }
}

#Preview("Empty") {
    HistoryPreview.screen(HistoryPreview.model([], selecting: nil))
}

#Preview("Filtered to zero") {
    let history = HistoryPreview.model(HistoryPreview.runs, selecting: nil)
    history.jobFilter = HistoryPreview.nightlyID
    history.outcomeFilter = .succeeded
    return HistoryPreview.screen(history)
}

#Preview("Populated") {
    HistoryPreview.screen(HistoryPreview.model(HistoryPreview.runs, selecting: nil))
}

#Preview("Succeeded") {
    HistoryPreview.screen(
        HistoryPreview.model(HistoryPreview.runs, selecting: HistoryPreview.succeededRunID),
    )
}

#Preview("Failed") {
    HistoryPreview.screen(
        HistoryPreview.model(HistoryPreview.runs, selecting: HistoryPreview.failedRunID),
    )
}

#Preview("Skipped") {
    HistoryPreview.screen(
        HistoryPreview.model(HistoryPreview.runs, selecting: HistoryPreview.skippedRunID),
    )
}

#Preview("Running") {
    HistoryPreview.screen(
        HistoryPreview.model(HistoryPreview.runs, selecting: HistoryPreview.runningRunID),
    )
}

#Preview("Deleted job") {
    let liveJobs = HistoryPreview.jobs.filter { $0.id != HistoryPreview.nightlyID }
    return HistoryPreview.screen(
        HistoryPreview.model(
            HistoryPreview.runs,
            liveJobs: liveJobs,
            selecting: HistoryPreview.failedRunID,
        ),
    )
}

#Preview("Succeeded — dark") {
    HistoryPreview.screen(
        HistoryPreview.model(HistoryPreview.runs, selecting: HistoryPreview.succeededRunID),
    )
    .preferredColorScheme(.dark)
}
