import Foundation

/// The manual keep-awake choices the popover offers (ux-flows F5, ADR-0006).
///
/// Cases are declared alphabetically (SwiftLint's `sorted_enum_cases`), so `allCases` is
/// not the menu's order; ``menuOrder`` is.
public enum KeepAwakeMode: Equatable, Sendable, CaseIterable {
    /// Keep awake for four hours from the moment it is chosen.
    case fourHours
    /// No manual hold. Running jobs still keep the Mac awake.
    case off
    /// Keep awake for one hour from the moment it is chosen.
    case oneHour
    /// Keep awake until the user chooses ``off``; there is no end time.
    case untilTurnedOff

    /// The keep-awake choices in the popover's menu order (ux-flows S1, F5).
    public static let menuOrder: [Self] = [.off, .oneHour, .fourHours, .untilTurnedOff]

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

    /// The choice's name in the popover's keep-awake menu.
    public var label: LocalizedStringResource {
        switch self {
        case .off:
            LocalizedStringResource(
                "keepAwake.mode.off",
                defaultValue: "Off",
                bundle: .module,
                comment: "Keep-awake menu choice in the menu-bar popover: no manual hold.",
            )

        case .oneHour:
            LocalizedStringResource(
                "keepAwake.mode.oneHour",
                defaultValue: "1 hour",
                bundle: .module,
                comment: "Keep-awake menu choice in the menu-bar popover: keep awake for one hour.",
            )

        case .fourHours:
            LocalizedStringResource(
                "keepAwake.mode.fourHours",
                defaultValue: "4 hours",
                bundle: .module,
                comment: "Keep-awake menu choice in the menu-bar popover: keep awake for four hours.",
            )

        case .untilTurnedOff:
            LocalizedStringResource(
                "keepAwake.mode.untilTurnedOff",
                defaultValue: "Until turned off",
                bundle: .module,
                comment: "Keep-awake menu choice in the menu-bar popover: keep awake with no end time.",
            )
        }
    }
}
