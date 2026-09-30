/// The manual keep-awake choices the popover offers (ux-flows F5, ADR-0006).
///
/// Cases are declared alphabetically (SwiftLint's `sorted_enum_cases`), so `allCases` is
/// not the menu's order; the view model that builds the menu decides that.
public enum KeepAwakeMode: Equatable, Sendable, CaseIterable {
    /// Keep awake for four hours from the moment it is chosen.
    case fourHours
    /// No manual hold. Running jobs still keep the Mac awake.
    case off
    /// Keep awake for one hour from the moment it is chosen.
    case oneHour
    /// Keep awake until the user chooses ``off``; there is no end time.
    case untilTurnedOff

    private static let secondsInOneHour = 3_600
    private static let secondsInFourHours = 14_400

    /// How long a timed choice lasts from the moment it is chosen, or `nil` for a choice
    /// with no end time (``off`` and ``untilTurnedOff``).
    ///
    /// The lengths are what the choice *means* — "1 hour" is one hour — so they live on
    /// the mode rather than in a tunable.
    public var duration: Duration? {
        switch self {
        case .off, .untilTurnedOff:
            nil

        case .oneHour:
            .seconds(Self.secondsInOneHour)

        case .fourHours:
            .seconds(Self.secondsInFourHours)
        }
    }
}
