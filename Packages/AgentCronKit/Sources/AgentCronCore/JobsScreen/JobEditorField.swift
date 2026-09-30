import Foundation

/// A field of the job editor that can show a validation error, in the order the editor
/// lays them out — the order Save looks for the first invalid one to move focus to
/// (`docs/design/ux-guidelines.md` › Forms and validation). Cases are declared
/// alphabetically (SwiftLint's `sorted_enum_cases`); ``allCases`` is the editor's order.
public enum JobEditorField: Sendable, Hashable, CaseIterable {
    /// The Days chips and presets.
    case days
    /// The Directory row.
    case directory
    /// The Name field.
    case name
    /// The Prompt editor.
    case prompt
    /// The Timeout field.
    case timeout
    /// The Times row.
    case times

    /// Every field, top to bottom as the editor shows them.
    public static let allCases: [Self] = [.name, .directory, .prompt, .days, .times, .timeout]

    /// The field's row label in the editor.
    public var title: LocalizedStringResource {
        switch self {
        case .name:
            LocalizedStringResource(
                "jobEditor.label.name",
                defaultValue: "Name",
                bundle: .module,
                comment: "Job editor row label for the job's name.",
            )

        case .directory:
            LocalizedStringResource(
                "jobEditor.label.directory",
                defaultValue: "Directory",
                bundle: .module,
                comment: "Job editor row label for the folder the agent runs in.",
            )

        case .prompt:
            LocalizedStringResource(
                "jobEditor.label.prompt",
                defaultValue: "Prompt",
                bundle: .module,
                comment: "Job editor row label for the prompt the agent is given.",
            )

        case .days:
            LocalizedStringResource(
                "jobEditor.label.days",
                defaultValue: "Days",
                bundle: .module,
                comment: "Job editor row label for the weekday chips.",
            )

        case .times:
            LocalizedStringResource(
                "jobEditor.label.times",
                defaultValue: "Times",
                bundle: .module,
                comment: "Job editor row label for the times of day the job runs at.",
            )

        case .timeout:
            LocalizedStringResource(
                "jobEditor.label.timeout",
                defaultValue: "Timeout",
                bundle: .module,
                comment: "Job editor row label for how long a run may take.",
            )
        }
    }

    /// The field whose row shows `error`.
    public init(showing error: JobValidationError) {
        switch error {
        case .nameEmpty, .nameTooLong:
            self = .name

        case .directoryNotLocal:
            self = .directory

        case .promptEmpty:
            self = .prompt

        case .noWeekdays:
            self = .days

        case .noTimes, .duplicateTimes:
            self = .times

        case .timeoutOutOfRange:
            self = .timeout
        }
    }
}
