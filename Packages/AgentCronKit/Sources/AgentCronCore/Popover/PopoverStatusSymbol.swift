import Foundation

/// The status item's symbol, by priority: running > manual keep-awake hold > idle
/// (plan P22). The failure dot is a separate flag, ``PopoverModel/showsFailureDot``.
public enum PopoverStatusSymbol: Sendable, Equatable {
    /// Nothing runs and no manual hold is in force.
    case idle
    /// A manual keep-awake choice is in force.
    case manualHold
    /// At least one job is running.
    case running

    /// The SF Symbol the status item draws.
    public var symbolName: String {
        switch self {
        case .running:
            "clock.fill"

        case .manualHold:
            "cup.and.saucer"

        case .idle:
            "clock"
        }
    }
}
