import Foundation
import Observation

/// The General screen (`docs/product/ux-flows.md` S4, requirements §3.7): launch at login
/// through ``LoginItemControlling``, and whether `claude` resolves through
/// ``AgentAvailabilityChecker``.
///
/// It decides what the view shows — the toggle's state, the approval button, the agent
/// row, and when the row's spinner appears (`docs/design/ux-guidelines.md` › Feedback and
/// loading: only after ``spinnerDelay``, then for at least ``spinnerMinimum``, so a quick
/// check never flashes one).
@MainActor
@Observable
public final class GeneralModel {
    /// How long a check runs before the row shows a spinner.
    public static let spinnerDelay: Duration = .milliseconds(spinnerDelayMilliseconds)
    /// How long a spinner, once shown, stays at least.
    public static let spinnerMinimum: Duration = .milliseconds(spinnerMinimumMilliseconds)

    private static let spinnerDelayMilliseconds = 300
    private static let spinnerMinimumMilliseconds = 500

    /// The login item's status as last read from the port.
    public private(set) var loginItemStatus: LoginItemStatus

    /// The last finished check, or `nil` before the first one finishes.
    public private(set) var agent: AgentAvailability?

    /// Whether a check is in flight — including the time a shown spinner is held.
    public private(set) var isChecking = false

    /// Whether the Claude Code row shows its inline spinner.
    public private(set) var showsSpinner = false

    private let loginItem: any LoginItemControlling
    private let checker: AgentAvailabilityChecker
    private let clock: any Clock<Duration>

    /// Whether the toggle reads on: registered, whether or not the user has approved it
    /// yet.
    public var isLaunchAtLoginOn: Bool {
        loginItemStatus == .enabled || loginItemStatus == .requiresApproval
    }

    /// Whether the section shows "Open Login Items".
    public var showsOpenLoginItems: Bool {
        loginItemStatus == .requiresApproval
    }

    /// The note under the toggle, for the two statuses that need explaining.
    public var loginItemNote: LocalizedStringResource? {
        switch loginItemStatus {
        case .enabled, .notRegistered:
            nil

        case .notFound:
            GeneralScreenText.loginItemNotFound

        case .requiresApproval:
            GeneralScreenText.loginItemRequiresApproval
        }
    }

    /// Creates the model and reads the login item's status, which asks the user nothing
    /// (``LoginItemControlling`` clause 1). No check runs until ``checkAgain()``.
    /// - Parameter clock: What the spinner's timings wait on; tests pass a manual clock.
    public init(
        loginItem: any LoginItemControlling,
        checker: AgentAvailabilityChecker,
        clock: any Clock<Duration> = ContinuousClock(),
    ) {
        self.loginItem = loginItem
        self.checker = checker
        self.clock = clock
        loginItemStatus = loginItem.status
    }

    /// The headline the agent row shows instead of a path: why it is marked ✗.
    public static func agentHeadline(for agent: AgentAvailability?) -> LocalizedStringResource? {
        switch agent {
        case .none, .available:
            nil

        case .notFound:
            GeneralScreenText.notFound

        case let .error(reason):
            LocalizedStringResource(
                "generalScreen.agent.error",
                defaultValue: "Check failed: \(reason)",
                bundle: .module,
                comment: "Claude Code row when the check failed. The argument is a short reason, e.g. \"timed out\".",
            )
        }
    }

    /// The secondary line under the agent row's headline or path.
    public static func agentDetail(for agent: AgentAvailability?) -> LocalizedStringResource? {
        switch agent {
        case .none, .error:
            nil

        case .available:
            GeneralScreenText.resolvedViaLoginShell

        case .notFound:
            GeneralScreenText.notFoundHint
        }
    }

    /// The toggle changed: registers or unregisters, then shows whatever status the port
    /// reports — so a refused change puts the toggle back.
    public func setLaunchAtLogin(_ isOn: Bool) {
        do {
            if isOn {
                try loginItem.register()
            } else {
                try loginItem.unregister()
            }
        } catch {
            switch error {
            case let .systemFailure(code):
                AppLog.lifecycle.error(
                    "changing the login item from General failed: code \(code, privacy: .public)",
                )
            }
        }
        refreshLoginItemStatus()
    }

    /// Reads the login item's status again — after the user may have changed it in
    /// System Settings.
    public func refreshLoginItemStatus() {
        loginItemStatus = loginItem.status
    }

    /// Opens System Settings › Login Items through the port.
    public func openLoginItems() {
        loginItem.openLoginItemsSettings()
    }

    /// Checks whether `claude` resolves. A press while a check is in flight starts
    /// nothing.
    public func checkAgain() async {
        guard !isChecking else {
            return
        }
        isChecking = true
        let spinner = Task { [clock] in
            try? await clock.sleep(for: Self.spinnerDelay)
            guard !Task.isCancelled else {
                return
            }
            showsSpinner = true
            try? await clock.sleep(for: Self.spinnerMinimum)
        }
        let result = await checker.check(.claudeCode)
        if showsSpinner {
            await spinner.value
        } else {
            spinner.cancel()
        }
        // A cancelled check (the user left General) ends as "stopped", which says
        // nothing about the agent, so the last real answer stays.
        if !Task.isCancelled {
            agent = result
        }
        showsSpinner = false
        isChecking = false
    }
}
