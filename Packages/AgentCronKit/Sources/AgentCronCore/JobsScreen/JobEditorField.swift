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
