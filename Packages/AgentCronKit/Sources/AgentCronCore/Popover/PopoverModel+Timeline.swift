import Foundation

extension PopoverModel {
    /// Foundation numbers weekdays 1 (Sunday) to 7 (Saturday) in every calendar.
    private static let byCalendarWeekday: [Weekday] = [
        .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday,
    ]

    /// Today's rows — finished runs, running runs, and upcoming fire dates — sorted by
    /// time; then, when no enabled job fires again today, the next run.
    ///
    /// Read from `now` at the moment of asking; observation does not tick with the clock.
    public var rows: [PopoverRow] {
        let date = now()
        let today = todayRows(at: date)
        let upcoming = upcomingToday(after: date)
        var result = (today + upcoming).sorted(by: Self.inOrder)
        if upcoming.isEmpty {
            result += nextRuns(after: date)
        }
        return result
    }

    /// The one empty state, or `nil` when today has something to show.
    public var emptyState: PopoverEmptyState? {
        if jobs.isEmpty {
            return .noJobs
        }
        if !jobs.contains(where: \.enabled) {
            return .allPaused
        }
        let date = now()
        guard todayRows(at: date).isEmpty, upcomingToday(after: date).isEmpty else {
            return nil
        }
        // An enabled job always fires again unless its schedule is invalid, which saving
        // refuses; with no next run there is nothing to say.
        guard let next = nextRuns(after: date).first else {
            return nil
        }
        return .nothingToday(next: next, dayText: dayText(next.day))
    }

    private static func inOrder(_ lhs: PopoverRow, _ rhs: PopoverRow) -> Bool {
        (lhs.date, lhs.jobName, lhs.id) < (rhs.date, rhs.jobName, rhs.id)
    }

    /// Finished runs started today, and every running run of a job reported running.
    private func todayRows(at date: Date) -> [PopoverRow] {
        runs.compactMap { run in
            if run.outcome == .running {
                return runningJobIDs.contains(run.jobID) ? row(for: run, at: date) : nil
            }
            return calendar.isDate(run.startedAt, inSameDayAs: date) ? row(for: run, at: date) : nil
        }
    }

    private func upcomingToday(after date: Date) -> [PopoverRow] {
        let end = startOfTomorrow(after: date)
        return jobs.filter(\.enabled).flatMap { job in
            let schedule = ScheduleCalendar(schedule: job.schedule, calendar: calendar)
            var fires: [Date] = []
            var cursor = date
            while let fire = schedule.nextFireDate(after: cursor), fire < end {
                fires.append(fire)
                cursor = fire
            }
            return fires.map { upcomingRow(for: job, at: $0, today: date) }
        }
    }

    /// The earliest next fire date among enabled jobs, one row per job that fires then.
    private func nextRuns(after date: Date) -> [PopoverRow] {
        let candidates = jobs.filter(\.enabled).compactMap { job in
            ScheduleCalendar(schedule: job.schedule, calendar: calendar)
                .nextFireDate(after: date)
                .map { (job: job, fire: $0) }
        }
        guard let earliest = candidates.map(\.fire).min() else {
            return []
        }
        return candidates.filter { $0.fire == earliest }
            .map { upcomingRow(for: $0.job, at: $0.fire, today: date) }
            .sorted(by: Self.inOrder)
    }

    private func row(for run: Run, at date: Date) -> PopoverRow {
        let duration = run.endedAt.map { Duration.seconds($0.timeIntervalSince(run.startedAt)) }
        return PopoverRow(
            id: run.id.uuidString,
            date: run.startedAt,
            timeText: timeText(run.startedAt),
            day: day(of: run.startedAt, today: date),
            badge: OutcomeBadgeKind(run.outcome),
            jobID: run.jobID,
            jobName: run.jobName,
            duration: run.outcome == .running ? nil : duration,
            costUSD: run.costUSD,
            usesBypassPermissions: run.snapshot.permissionMode == .bypassPermissions,
        )
    }

    private func upcomingRow(for job: Job, at fire: Date, today: Date) -> PopoverRow {
        PopoverRow(
            id: "\(job.id.uuidString)@\(fire.timeIntervalSince1970)",
            date: fire,
            timeText: timeText(fire),
            day: day(of: fire, today: today),
            badge: .upcoming,
            jobID: job.id,
            jobName: job.name,
            duration: nil,
            costUSD: nil,
            usesBypassPermissions: job.permissionMode == .bypassPermissions,
        )
    }

    private func timeText(_ date: Date) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    private func day(of date: Date, today: Date) -> PopoverDay {
        let startOfDay = calendar.startOfDay(for: date)
        if startOfDay <= calendar.startOfDay(for: today) {
            return .today
        }
        if startOfDay == startOfTomorrow(after: today) {
            return .tomorrow
        }
        let index = calendar.component(.weekday, from: date) - 1
        return .weekday(Self.byCalendarWeekday[index])
    }

    private func dayText(_ day: PopoverDay) -> String {
        guard var label = day.label else {
            return ""
        }
        label.locale = locale
        return String(localized: label)
    }
}
