import Foundation

/// What the job editor shows beyond the draft itself: the notes a row carries, the words
/// an alert or VoiceOver reads, and the time a new Times row starts at.
extension JobEditorModel {
    /// The file system's answer to whether `url` is a folder that is there — the default
    /// behind ``isDirectoryMissing``.
    public static let folderExists: @Sendable (URL) -> Bool = { url in
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: url.path(percentEncoded: false),
            isDirectory: &isDirectory,
        )
        return exists && isDirectory.boolValue
    }

    /// The hour of 09:00, the time the first Add Time suggests.
    private static let firstSuggestedHour = 9

    /// 09:00, the time the first Add Time suggests.
    private static let firstSuggestedTime = TimeOfDay(checkedHour: firstSuggestedHour, minute: 0)

    /// Whether the chosen folder is no longer there (`docs/design/ux-guidelines.md` ›
    /// States, folder missing). The job can still be saved; its runs fail with that
    /// reason. Read afresh on every render, so choosing the folder again clears it.
    public var isDirectoryMissing: Bool {
        guard let chosenDirectory else {
            return false
        }
        return !directoryExists(chosenDirectory)
    }

    /// The warning on the Directory row while ``isDirectoryMissing``, or `nil`.
    public var directoryMissingNote: LocalizedStringResource? {
        guard isDirectoryMissing else {
            return nil
        }
        return LocalizedStringResource(
            "jobEditor.directoryMissing",
            defaultValue: "This folder no longer exists.",
            bundle: .module,
            comment: "Warning on the job editor's Directory row when the chosen folder is gone.",
        )
    }

    /// The chosen folder's path as the Directory row shows it, the home folder written
    /// `~`, or `nil` while a new job has none (the row then shows
    /// ``JobsScreenText/noFolderChosen``).
    public var directoryPath: String? {
        guard let chosenDirectory else {
            return nil
        }
        let path = chosenDirectory.path(percentEncoded: false)
        let home = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        let homeFolder = home.hasSuffix("/") ? String(home.dropLast()) : home
        if path == homeFolder || path == homeFolder + "/" {
            return "~"
        }
        if path.hasPrefix(homeFolder + "/") {
            return "~" + path.dropFirst(homeFolder.count)
        }
        return path
    }

    /// The header's run button: Run Now, turning into Stop while this job runs
    /// (`docs/product/ux-flows.md` S2). It acts through the Job menu's command of the
    /// same name, so its title is that command's.
    public var runControl: MainMenuCommand {
        isRunning ? .stop : .runNow
    }

    /// Whether the header's run button can act: only a saved job has anything to run.
    public var canUseRunControl: Bool {
        !isNew
    }

    /// The name the editor's header shows: the draft's, trimmed; while that is blank, a
    /// saved job's saved name, or `nil` for a new job — whose header then reads New Job.
    public var headerName: String? {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty else {
            return name
        }
        return deleteConfirmation?.jobName
    }

    /// The title of the alert that asks before unsaved edits are left
    /// (`docs/design/ux-guidelines.md` › Feedback and loading): the saved name for a
    /// saved job, the draft's name for a new one, and a sentence without a name when a
    /// new job has none yet.
    public var saveChangesTitle: LocalizedStringResource {
        let name = (deleteConfirmation?.jobName ?? draft.name)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return LocalizedStringResource(
                "jobUnsaved.titleNewJob",
                defaultValue: "Save the new job?",
                bundle: .module,
                comment: "Title of the alert asking whether to save a new job that has no name yet.",
            )
        }
        return LocalizedStringResource(
            "jobUnsaved.title",
            defaultValue: "Save changes to “\(name)”?",
            bundle: .module,
            comment: "Alert asking whether to save a job's edits before leaving it. The argument is the job's name.",
        )
    }

    /// The time Add Time adds: 09:00 when there is none, otherwise an hour after the
    /// latest, wrapping past midnight. A time already listed is still suggested, and
    /// validation then says so.
    public var suggestedNewTime: TimeOfDay {
        let hoursInDay = TimeOfDay.hours.count
        guard let latest = draft.schedule.times.last,
              let next = try? TimeOfDay(hour: (latest.hour + 1) % hoursInDay, minute: latest.minute)
        else {
            return Self.firstSuggestedTime
        }
        return next
    }

    /// The note under the Notify row while the user has turned notifications off and
    /// this job would post some (`docs/design/ux-guidelines.md` › States), or `nil`.
    /// `authorization` is ``RunNotificationController/authorizationState``; `nil`, not
    /// yet read, shows nothing.
    public func notificationsOffNote(
        authorization: NotificationAuthorizationState?,
    ) -> LocalizedStringResource? {
        guard authorization == .denied, draft.notify != .never else {
            return nil
        }
        return LocalizedStringResource(
            "jobEditor.notificationsOff",
            defaultValue: "Notifications are off for AgentCron in System Settings.",
            bundle: .module,
            comment: "Note under the job editor's Notify row when the user turned notifications off.",
        )
    }

    /// What VoiceOver reads for `field`: its label, followed by its error while it shows
    /// one (`docs/design/ux-guidelines.md` › Forms and validation).
    public func accessibilityLabel(for field: JobEditorField) -> LocalizedStringResource {
        guard let message = message(for: field) else {
            return field.title
        }
        let title = field.title
        return LocalizedStringResource(
            "jobEditor.fieldWithError",
            defaultValue: "\(title), \(message)",
            bundle: .module,
            comment: "Accessibility label of a job editor field showing an error: the field's label, then the error.",
        )
    }

    /// The accessibility label of the button that removes `time` from the Times row.
    public func removeTimeLabel(for time: TimeOfDay) -> LocalizedStringResource {
        let text = time.hourMinuteText
        return LocalizedStringResource(
            "jobEditor.removeTime",
            defaultValue: "Remove \(text)",
            bundle: .module,
            comment: "Accessibility label of the − button beside a time in the job editor. The argument is the time.",
        )
    }

    /// The user gave up on, or the system refused, the folder picker: the draft keeps
    /// its folder, and the refusal is logged.
    public func directoryChoiceFailed(_ error: any Error) {
        let kind = String(describing: type(of: error))
        AppLog.jobsScreen.error("folder choice failed: \(kind, privacy: .public)")
    }
}
