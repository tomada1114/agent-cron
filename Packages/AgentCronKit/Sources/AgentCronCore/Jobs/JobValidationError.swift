import Foundation

/// Each message is its own computed property so the resource is built afresh on every
/// read, in the locale current at that moment (`localizing-the-app`). The limits are
/// written into the sentences rather than interpolated from ``Job``'s constants: an
/// interpolated `Int` renders locale-grouped ("1,440") where the catalog's `%lld` does
/// not, so change a limit and its sentence together (`JobTests` holds both).
private enum Messages {
    static var nameEmpty: LocalizedStringResource {
        LocalizedStringResource(
            "jobValidation.nameEmpty",
            defaultValue: "Enter a name.",
            bundle: .module,
            comment: "Error under the job editor's Name field when it is empty.",
        )
    }

    static var nameTooLong: LocalizedStringResource {
        LocalizedStringResource(
            "jobValidation.nameTooLong",
            defaultValue: "Shorten the name to 60 characters or fewer.",
            bundle: .module,
            comment: "Error under the job editor's Name field when it is longer than 60 characters.",
        )
    }

    static var directoryNotLocal: LocalizedStringResource {
        LocalizedStringResource(
            "jobValidation.directoryNotLocal",
            defaultValue: "Choose a folder on this Mac.",
            bundle: .module,
            comment: "Error under the job editor's Directory field when the directory is not a folder on this Mac.",
        )
    }

    static var promptEmpty: LocalizedStringResource {
        LocalizedStringResource(
            "jobValidation.promptEmpty",
            defaultValue: "Enter a prompt.",
            bundle: .module,
            comment: "Error under the job editor's Prompt field when it is empty or only whitespace.",
        )
    }

    static var noWeekdays: LocalizedStringResource {
        LocalizedStringResource(
            "jobValidation.noWeekdays",
            defaultValue: "Choose at least one day.",
            bundle: .module,
            comment: "Error under the job editor's Days chips when no day of the week is selected.",
        )
    }

    static var noTimes: LocalizedStringResource {
        LocalizedStringResource(
            "jobValidation.noTimes",
            defaultValue: "Add at least one time.",
            bundle: .module,
            comment: "Error under the job editor's Times row when the schedule has no time.",
        )
    }

    static var duplicateTimes: LocalizedStringResource {
        LocalizedStringResource(
            "jobValidation.duplicateTimes",
            defaultValue: "Remove the duplicate time.",
            bundle: .module,
            comment: "Error under the job editor's Times row when the same time is listed more than once.",
        )
    }

    static var timeoutOutOfRange: LocalizedStringResource {
        LocalizedStringResource(
            "jobValidation.timeoutOutOfRange",
            defaultValue: "Enter a timeout from 1 to 1,440 minutes.",
            bundle: .module,
            comment: "Error under the job editor's Timeout field when it is outside 1 to 1,440 minutes.",
        )
    }
}

/// A rule a job breaks, as ``Job/validate()`` reports it.
///
/// One case per rule, so the editor can place each message under its own field; the
/// payloads carry only what that placement needs — never the name or prompt text.
public enum JobValidationError: Error, Equatable, Sendable {
    /// The directory is not a local file URL.
    case directoryNotLocal
    /// The schedule names these times more than once each, in ascending order.
    case duplicateTimes([TimeOfDay])
    /// The name is empty or only whitespace.
    case nameEmpty
    /// The name, ignoring surrounding whitespace, is longer than
    /// ``Job/maximumNameLength``; `characterCount` is its length.
    case nameTooLong(characterCount: Int)
    /// The schedule names no time.
    case noTimes
    /// The schedule names no weekday.
    case noWeekdays
    /// The prompt is empty or only whitespace.
    case promptEmpty
    /// The timeout is outside ``Job/timeoutMinutesRange``; `minutes` is the value given.
    case timeoutOutOfRange(minutes: Int)

    /// What the user reads under the field: one sentence saying what to fix.
    public var message: LocalizedStringResource {
        switch self {
        case .directoryNotLocal:
            Messages.directoryNotLocal

        case .duplicateTimes:
            Messages.duplicateTimes

        case .nameEmpty:
            Messages.nameEmpty

        case .nameTooLong:
            Messages.nameTooLong

        case .noTimes:
            Messages.noTimes

        case .noWeekdays:
            Messages.noWeekdays

        case .promptEmpty:
            Messages.promptEmpty

        case .timeoutOutOfRange:
            Messages.timeoutOutOfRange
        }
    }
}
