import Foundation

/// How the parts hear about one another: the dispatcher's reports, the job list's saves,
/// the main menu's job commands, and the system's events (`docs/architecture.md` › Core
/// flows).
extension AppEnvironment {
    /// The date the timer is armed for: the earliest time any enabled job in `jobs` next
    /// fires after `date`, and never later than ``longestTimerWait`` from it.
    static func timerDate(for jobs: [Job], after date: Date, calendar: Calendar) -> Date {
        let latest = date.addingTimeInterval(longestTimerWait)
        let fireDates = jobs.filter(\.enabled).compactMap { job in
            ScheduleCalendar(schedule: job.schedule, calendar: calendar).nextFireDate(after: date)
        }
        return min(fireDates.min() ?? latest, latest)
    }

    /// Sets every callback the parts report through. Called once, at launch.
    func connect() {
        dispatcher.onRunningJobsChanged = { [weak self] jobIDs in
            self?.runningJobsChanged(jobIDs)
        }
        dispatcher.onRunFinished = { [weak self] run in
            self?.runFinished(run)
        }
        dispatcher.onRunsMissed = { [weak self] runs in
            self?.perform { environment in
                await environment.notifications.runsMissed(runs)
            }
        }
        jobList.onJobsSaved = { [weak self] jobs in
            self?.jobsSaved(jobs)
        }
        navigation.onRunNow = { [weak self] jobID in
            self?.runNow(jobID: jobID)
        }
        navigation.onStop = { [weak self] jobID in
            self?.stopJob(jobID: jobID)
        }
    }

    /// Opens a stream of system events and handles each as it arrives. The stream is
    /// opened before the timer is first armed: it replays nothing, so a timer that fired
    /// before would be lost (``SystemEventsProviding``).
    func listenToSystemEvents() {
        let events = systemEvents.events()
        eventLoop = Task { [weak self] in
            for await event in events {
                self?.handle(event)
            }
        }
    }

    /// Arms the timer for the jobs as saved now. Jobs that cannot be read arm it for
    /// ``longestTimerWait``, so the scheduler looks again later without acting on them.
    func armTimer() {
        let date = now()
        let jobs: [Job]
        do {
            jobs = try jobStore.load().jobs
        } catch {
            jobs = []
            AppLog.scheduler.error(
                "arming the timer without jobs: \(String(describing: error), privacy: .public)",
            )
        }
        arm(for: jobs, after: date)
    }

    /// Reads History afresh, then puts back the runs going now: a run is first saved only
    /// once its agent check has answered, so the store may not hold it yet.
    func reloadHistory() {
        history.reload()
        for run in dispatcher.runningRuns {
            history.runRecorded(run)
        }
    }

    /// Reads the popover afresh, then puts back the runs going now, as ``reloadHistory()``
    /// does.
    func reloadPopover() {
        popover.load()
        popover.runningRunsChanged(to: dispatcher.runningRuns)
    }

    // MARK: - Private

    /// Arms the timer for `jobs` and logs the date, the evidence a run's timing is read
    /// from (`just logs`). A date says nothing about a job's name or prompt.
    private func arm(for jobs: [Job], after date: Date) {
        let fireDate = Self.timerDate(for: jobs, after: date, calendar: calendar)
        systemEvents.armTimer(at: fireDate)
        AppLog.scheduler.info("timer armed for \(fireDate.ISO8601Format(), privacy: .public)")
    }

    private func handle(_ event: SystemEvent) {
        let date = now()
        switch event {
        case .willSleep:
            AppLog.scheduler.debug("the Mac is going to sleep")
            return

        case .didWake:
            dispatcher.didWake(now: date)
            keepAwake.refresh()

        case .clockChanged:
            dispatcher.tick(now: date)
            keepAwake.refresh()

        case .fireDateReached, .timeZoneChanged:
            dispatcher.tick(now: date)
        }
        history.sweepIfDue()
        armTimer()
    }

    private func runningJobsChanged(_ jobIDs: Set<UUID>) {
        keepAwake.runningJobCountChanged(to: jobIDs.count)
        jobList.runningJobsChanged(to: jobIDs)
        let running = dispatcher.runningRuns
        popover.runningRunsChanged(to: running)
        for run in running {
            history.runRecorded(run)
        }
    }

    private func runFinished(_ run: Run) {
        popover.runFinished(run)
        history.runRecorded(run)
        if run.skipReason == .agentNotFound {
            popover.agentAvailabilityChanged(.notFound)
        }
        perform { environment in
            await environment.notifications.runFinished(run)
        }
    }

    /// The user saved or deleted a job: the timer is armed for the jobs as they are now,
    /// the run of a job that is gone is stopped (ux-flows S5), and the screens hear of
    /// it. A run of a job that is still there is left alone, edited or not.
    private func jobsSaved(_ jobs: [Job]) {
        let jobIDs = Set(jobs.map(\.id))
        for run in dispatcher.runningRuns where !jobIDs.contains(run.jobID) {
            dispatcher.stop(runID: run.id)
        }
        history.jobsChanged(to: jobs)
        reloadPopover()
        arm(for: jobs, after: now())
        perform { environment in
            await environment.notifications.jobsChanged(jobs)
        }
    }
}
