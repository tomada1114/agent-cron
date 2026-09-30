import AgentCronCore
import SwiftUI

// Previews of the Jobs screen, one per state the issue names (#21): empty, no selection,
// editing, invalid, running, folder missing, bypass, notifications off — plus dark.
// Each builds its models over an in-memory store; nothing here ships in a code path.

/// A job store for previews: answers `document` and keeps nothing a save hands it, so a
/// preview never touches Application Support.
private struct PreviewJobStore: JobStoring {
    let document: JobsDocument

    func load() -> JobsDocument {
        document
    }

    func save(_: JobsDocument) {
        // A preview keeps nothing.
    }
}

/// A notifier for previews that answers a fixed authorization and posts nothing.
private struct PreviewNotifier: RunNotifying {
    let state: NotificationAuthorizationState

    func authorizationState() -> NotificationAuthorizationState {
        state
    }

    func requestAuthorizationIfNeeded() -> NotificationAuthorizationState {
        state
    }

    func post(_: NotificationContent) {
        // A preview posts nothing.
    }

    func setClickHandler(_: @Sendable (UUID) -> Void) {
        // A preview is never clicked.
    }
}

/// The hours the preview jobs run at.
private enum Hour {
    static let nine = 9
    static let noon = 12
    static let sixPM = 18
    static let tenPM = 22
}

@MainActor
private enum JobsPreview {
    static let digestID = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
    static let reviewID = UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID()
    static let nightlyID = UUID(uuidString: "00000000-0000-0000-0000-000000000003") ?? UUID()
    nonisolated static let missingFolder = URL(
        filePath: "/Volumes/Archive/old-project",
        directoryHint: .isDirectory,
    )
    /// Every folder is there except ``missingFolder``, whatever this Mac holds.
    static let folderExists: @Sendable (URL) -> Bool = { $0 != missingFolder }

    static var jobs: [Job] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var nightly = Job(
            name: "Nightly review",
            directory: home.appending(path: "ghq/agent-cron", directoryHint: .isDirectory),
            prompt: "Review the open pull requests and merge the safe ones.",
            schedule: Schedule(
                weekdays: SchedulePreset.everyDay.weekdays,
                times: times([(Hour.tenPM, 0)]),
            ),
            createdAt: .now,
            id: nightlyID,
            permissionMode: .bypassPermissions,
        )
        nightly.enabled = false
        return [
            Job(
                name: "RSS digest",
                directory: home.appending(path: "ghq/news-digest", directoryHint: .isDirectory),
                prompt: "Run /rss-digest and update news.html.",
                schedule: Schedule(
                    weekdays: SchedulePreset.weekdays.weekdays,
                    times: times([(Hour.nine, 0), (Hour.noon, 0), (Hour.sixPM, 0)]),
                ),
                createdAt: .now,
                id: digestID,
            ),
            Job(
                name: "Dependabot review",
                directory: missingFolder,
                prompt: "Review and merge safe Dependabot pull requests.",
                schedule: Schedule(
                    weekdays: SchedulePreset.everyDay.weekdays,
                    times: times([(Hour.noon, 0)]),
                ),
                createdAt: .now,
                id: reviewID,
                notify: .everyRun,
            ),
            nightly,
        ]
    }

    /// A navigation model on Jobs with `jobID` selected, over a throwaway defaults suite.
    static func navigation(selecting jobID: UUID?) -> MainNavigationModel {
        let navigation = MainNavigationModel.preview(showing: .jobs)
        navigation.select(jobID: jobID)
        return navigation
    }

    /// A loaded list over `jobs` with `jobID` open in the editor.
    static func list(_ jobs: [Job], selecting jobID: UUID?) -> JobListModel {
        let list = JobListModel(
            store: PreviewJobStore(document: JobsDocument(jobs: jobs)),
            calendar: .current,
            directoryExists: folderExists,
        )
        list.load()
        list.select(jobID: jobID)
        return list
    }

    static func screen(
        _ list: JobListModel,
        notifications: RunNotificationController? = nil,
    ) -> some View {
        JobsScreenView(
            navigation: navigation(selecting: list.selectedJobID),
            list: list,
            notifications: notifications,
        )
        .frame(width: DesignLock.mainWindowDefaultWidth - DesignLock.mainWindowSidebarWidth)
        .frame(minHeight: DesignLock.mainWindowDefaultHeight)
    }

    private static func times(_ pairs: [(Int, Int)]) -> [TimeOfDay] {
        pairs.compactMap { try? TimeOfDay(hour: $0.0, minute: $0.1) }
    }
}

#Preview("Empty") {
    JobsPreview.screen(JobsPreview.list([], selecting: nil))
}

#Preview("No selection") {
    JobsPreview.screen(JobsPreview.list(JobsPreview.jobs, selecting: nil))
}

#Preview("Editing") {
    let list = JobsPreview.list(JobsPreview.jobs, selecting: JobsPreview.digestID)
    list.editor?.promptChanged(to: "Run /rss-digest and update news.html and feed.xml.")
    return JobsPreview.screen(list)
}

#Preview("Invalid") {
    let list = JobsPreview.list(JobsPreview.jobs, selecting: JobsPreview.digestID)
    list.editor?.nameChanged(to: "")
    list.editor?.promptChanged(to: " ")
    for day in SchedulePreset.weekdays.weekdays {
        list.editor?.weekdayToggled(day)
    }
    list.editor?.save()
    return JobsPreview.screen(list)
}

#Preview("New job") {
    let list = JobsPreview.list(JobsPreview.jobs, selecting: nil)
    list.newJob()
    return JobsPreview.screen(list)
}

#Preview("Running") {
    let list = JobsPreview.list(JobsPreview.jobs, selecting: JobsPreview.digestID)
    list.runningJobsChanged(to: [JobsPreview.digestID])
    return JobsPreview.screen(list)
}

#Preview("Folder missing") {
    JobsPreview.screen(JobsPreview.list(JobsPreview.jobs, selecting: JobsPreview.reviewID))
}

#Preview("Bypass") {
    JobsPreview.screen(JobsPreview.list(JobsPreview.jobs, selecting: JobsPreview.nightlyID))
}

#Preview("Bypass confirmation") {
    let list = JobsPreview.list(JobsPreview.jobs, selecting: JobsPreview.digestID)
    list.editor?.permissionModeChosen(.bypassPermissions)
    return JobsPreview.screen(list)
}

#Preview("Notifications off") {
    let controller = RunNotificationController(notifier: PreviewNotifier(state: .denied))
    return JobsPreview.screen(
        JobsPreview.list(JobsPreview.jobs, selecting: JobsPreview.reviewID),
        notifications: controller,
    )
    .task {
        await controller.refreshAuthorization()
    }
}

#Preview("Unsaved changes") {
    let list = JobsPreview.list(JobsPreview.jobs, selecting: JobsPreview.digestID)
    list.editor?.nameChanged(to: "Morning digest")
    list.selectionRequested(jobID: JobsPreview.reviewID)
    return JobsPreview.screen(list)
}

#Preview("Delete confirmation") {
    let list = JobsPreview.list(JobsPreview.jobs, selecting: JobsPreview.digestID)
    list.deleteRequested(jobID: JobsPreview.digestID)
    return JobsPreview.screen(list)
}

#Preview("Editing — dark") {
    let list = JobsPreview.list(JobsPreview.jobs, selecting: JobsPreview.nightlyID)
    list.editor?.nameChanged(to: "Nightly PR review")
    return JobsPreview.screen(list)
        .preferredColorScheme(.dark)
}
