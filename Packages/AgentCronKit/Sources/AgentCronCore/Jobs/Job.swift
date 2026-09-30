import Foundation

/// A saved chore: which agent to run, in which directory, with which prompt and options,
/// and when.
///
/// Agent-neutral by design (docs/architecture.md › Principles): the agent is an
/// ``AgentKind``, and only that agent's command builder turns the options into flags.
/// The type holds any values so an editor can hold a half-filled job; ``validate()``
/// says whether it may be saved.
public struct Job: Sendable, Equatable, Codable, Identifiable {
    /// The most characters a name may have, ignoring surrounding whitespace.
    public static let maximumNameLength = 60
    /// The timeouts a job may set, in minutes: at least a minute, at most a day.
    public static let timeoutMinutesRange = 1 ... 1_440
    /// The timeout a new job starts with, in minutes.
    public static let defaultTimeoutMinutes = 30

    /// Stable across renames; runs refer to their job by it.
    public let id: UUID
    /// What the user calls the job in lists, history, and notifications.
    public var name: String
    /// Which agent CLI runs the prompt.
    public var agent: AgentKind
    /// The working directory the agent runs in.
    public var directory: URL
    /// What the agent is asked to do, exactly as typed.
    public var prompt: String
    /// When the job fires.
    public var schedule: Schedule
    /// The model the run asks for.
    public var model: ModelChoice
    /// The reasoning effort the run asks for.
    public var effort: EffortChoice
    /// What the agent may do without asking.
    public var permissionMode: PermissionMode
    /// How long a run may take before it is stopped and recorded as timed out.
    public var timeoutMinutes: Int
    /// Which finished runs post a notification.
    public var notify: NotifyPolicy
    /// Whether the scheduler fires the job; a paused job can still be run by hand.
    public var enabled: Bool
    /// When the job was first saved.
    public let createdAt: Date
    /// When the job was last saved.
    public var updatedAt: Date

    /// Makes a job; every option not given takes the default a new job starts with
    /// (requirements §3.1).
    /// - Parameter updatedAt: When the job was last saved; `nil`, for a job being
    ///   created, means `createdAt`.
    public init(
        name: String,
        directory: URL,
        prompt: String,
        schedule: Schedule,
        createdAt: Date,
        id: UUID = UUID(),
        agent: AgentKind = .claudeCode,
        model: ModelChoice = .default,
        effort: EffortChoice = .default,
        permissionMode: PermissionMode = .auto,
        timeoutMinutes: Int = Self.defaultTimeoutMinutes,
        notify: NotifyPolicy = .failuresOnly,
        enabled: Bool = true,
        updatedAt: Date? = nil,
    ) {
        self.id = id
        self.name = name
        self.agent = agent
        self.directory = directory
        self.prompt = prompt
        self.schedule = schedule
        self.model = model
        self.effort = effort
        self.permissionMode = permissionMode
        self.timeoutMinutes = timeoutMinutes
        self.notify = notify
        self.enabled = enabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    /// The schedule rules a saved job must meet, in the editor's order: days, then times.
    private static func violations(of schedule: Schedule) -> [JobValidationError] {
        var errors: [JobValidationError] = []
        if schedule.weekdays.isEmpty {
            errors.append(.noWeekdays)
        }
        if schedule.times.isEmpty {
            errors.append(.noTimes)
        }
        // `times` is sorted, so a repeated time sits next to its twin.
        let times = schedule.times
        let repeated = zip(times, times.dropFirst()).filter { $0 == $1 }.map(\.0)
        var duplicates: [TimeOfDay] = []
        for time in repeated where duplicates.last != time {
            duplicates.append(time)
        }
        if !duplicates.isEmpty {
            errors.append(.duplicateTimes(duplicates))
        }
        return errors
    }

    /// Every rule this job breaks, in the order the editor shows its fields, so Save can
    /// show all of them at once and move focus to the first. Empty means it may be saved.
    ///
    /// Pure: it touches no file system. Whether the directory still exists is checked
    /// again when a run starts, since it can vanish after the job was saved.
    public func validate() -> [JobValidationError] {
        var errors: [JobValidationError] = []
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            errors.append(.nameEmpty)
        } else if trimmedName.count > Self.maximumNameLength {
            errors.append(.nameTooLong(characterCount: trimmedName.count))
        }
        if !directory.isFileURL {
            errors.append(.directoryNotLocal)
        }
        if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.promptEmpty)
        }
        errors += Self.violations(of: schedule)
        if !Self.timeoutMinutesRange.contains(timeoutMinutes) {
            errors.append(.timeoutOutOfRange(minutes: timeoutMinutes))
        }
        return errors
    }
}
