import AgentCronCore
import SwiftUI

// Previews of the popover, one per state the issue names (#27): populated, no jobs,
// nothing today, all paused, agent not found, keep-awake on — plus dark. Each builds
// its model over in-memory stores and a throwaway defaults suite.

private struct PreviewJobStore: JobStoring {
    let jobs: [Job]

    func load() -> JobsDocument {
        JobsDocument(jobs: jobs)
    }

    func save(_: JobsDocument) {
        // A preview keeps nothing.
    }
}

private struct PreviewRunStore: RunStoring {
    let runs: [Run]

    func save(_: Run) {
        // A preview keeps nothing.
    }

    func runs(in interval: DateInterval) -> [Run] {
        runs.filter { interval.contains($0.startedAt) }
    }

    func deleteRuns(olderThan _: Date) -> Int {
        0
    }
}

/// Holds nothing: a preview never keeps the Mac awake.
private struct PreviewSleepPreventer: SleepPreventing {
    func hold(reason _: String) -> SleepPreventionToken {
        SleepPreventionToken(id: 1)
    }

    func release(_: SleepPreventionToken) {
        // Nothing was held.
    }
}

/// The times the preview jobs and runs fall on.
private enum Hour {
    static let three = 3
    static let two = 2
    static let nine = 9
    static let noon = 12
    static let sixPM = 18
    static let tenPM = 22
    static let nowMinute = 4
    static let nowSecond = 12
    static let digestMinutes = 2
}

@MainActor
private enum PopoverPreview {
    static let calendar = Calendar.current
    /// Today at 12:04, so the populated preview has finished, running, and upcoming rows.
    static let now = calendar.date(
        bySettingHour: Hour.noon,
        minute: Hour.nowMinute,
        second: Hour.nowSecond,
        of: .now,
    ) ?? .now

    static let digest = job("RSS digest", times: [(Hour.nine, 0), (Hour.sixPM, 0)])
    static let review = job("Dependabot review", times: [(Hour.noon, 0)])
    static let nightly = job("Nightly review", times: [(Hour.tenPM, 0)], bypass: true)

    static var populated: PopoverModel {
        var finished = run(
            digest,
            at: at(Hour.nine, 0),
            ended: at(Hour.nine, Hour.digestMinutes),
            outcome: .succeeded,
        )
        finished.costUSD = Decimal(string: "0.12")
        let failed = run(nightly, at: at(Hour.three, 0), ended: at(Hour.three, 1), outcome: .failed)
        let running = run(review, at: at(Hour.noon, 0), ended: nil, outcome: .running)
        return model(
            jobs: [digest, review, nightly],
            runs: [finished, failed, running],
            running: [running],
            seenAt: at(Hour.two, 0),
        )
    }

    static func at(_ hour: Int, _ minute: Int) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
    }

    static func job(_ name: String, times: [(Int, Int)], bypass: Bool = false) -> Job {
        Job(
            name: name,
            directory: FileManager.default.homeDirectoryForCurrentUser,
            prompt: "Preview",
            schedule: Schedule(
                weekdays: SchedulePreset.everyDay.weekdays,
                times: times.compactMap { try? TimeOfDay(hour: $0.0, minute: $0.1) },
            ),
            createdAt: now,
            permissionMode: bypass ? .bypassPermissions : .default,
        )
    }

    static func run(_ job: Job, at start: Date, ended end: Date?, outcome: RunOutcome) -> Run {
        var run = Run(job: job, trigger: .scheduled, startedAt: start, scheduledAt: start)
        run.endedAt = end
        run.outcome = outcome
        return run
    }

    static func model(
        jobs: [Job],
        runs: [Run] = [],
        running: [Run] = [],
        seenAt: Date? = nil,
    ) -> PopoverModel {
        let defaults = UserDefaults(suiteName: "PopoverPreview.\(UUID().uuidString)") ?? .standard
        defaults.set(seenAt, forKey: PopoverModel.lastPopoverOpenedAtKey)
        let fixedNow = now
        let model = PopoverModel(
            jobStore: PreviewJobStore(jobs: jobs),
            runStore: PreviewRunStore(runs: runs),
            keepAwake: KeepAwakeController(preventer: PreviewSleepPreventer()),
            calendar: calendar,
            defaults: defaults,
        ) { fixedNow }
        model.load()
        model.runningRunsChanged(to: running)
        return model
    }

    static func popover(_ model: PopoverModel) -> some View {
        PopoverView(
            model: model,
            navigation: .preview(showing: .jobs),
            stop: { _ in
                // A preview stops nothing.
            },
            quit: {
                // A preview does not quit.
            },
            mainWindowRequested: {
                // A preview activates nothing.
            },
        )
    }
}

#Preview("Populated") {
    PopoverPreview.popover(PopoverPreview.populated)
}

#Preview("Populated — dark") {
    PopoverPreview.popover(PopoverPreview.populated)
        .preferredColorScheme(.dark)
}

#Preview("No jobs") {
    PopoverPreview.popover(PopoverPreview.model(jobs: []))
}

#Preview("Nothing today") {
    let tomorrowOnly = PopoverPreview.job("RSS digest", times: [(Hour.nine, 0)])
    let model = PopoverPreview.model(jobs: [tomorrowOnly])
    return PopoverPreview.popover(model)
}

#Preview("All paused") {
    var paused = PopoverPreview.digest
    paused.enabled = false
    return PopoverPreview.popover(PopoverPreview.model(jobs: [paused]))
}

#Preview("Agent not found") {
    let model = PopoverPreview.model(jobs: [PopoverPreview.digest, PopoverPreview.nightly])
    model.agentAvailabilityChanged(.notFound)
    return PopoverPreview.popover(model)
}

#Preview("Keep awake on") {
    let model = PopoverPreview.model(jobs: [PopoverPreview.digest])
    model.chooseKeepAwake(.fourHours)
    return PopoverPreview.popover(model)
}

#Preview("Status item") {
    HStack(spacing: DesignLock.spacingM) {
        StatusItemLabel(model: PopoverPreview.model(jobs: []))
        StatusItemLabel(model: PopoverPreview.populated)
        StatusItemLabel(model: {
            let model = PopoverPreview.model(jobs: [PopoverPreview.digest])
            model.chooseKeepAwake(.oneHour)
            return model
        }())
    }
    .padding()
}
