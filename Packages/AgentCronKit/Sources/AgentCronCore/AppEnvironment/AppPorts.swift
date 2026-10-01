import Foundation

/// The two ports ``AppLifecycleModel`` carries its decisions through (ADR-0001).
public struct AppLifecyclePorts: Sendable {
    /// Registers the app to open at login.
    public let loginItem: any LoginItemControlling
    /// Switches between a status-item-only app and a regular one.
    public let activationPolicy: any ActivationPolicyControlling

    /// Collects the ports.
    public init(
        loginItem: any LoginItemControlling,
        activationPolicy: any ActivationPolicyControlling,
    ) {
        self.loginItem = loginItem
        self.activationPolicy = activationPolicy
    }
}

/// The OS-facing half of every port the app uses, handed to ``AppEnvironment`` by the
/// composition root.
///
/// `App/` fills it with the `AgentCronPlatform` adapters and a Core test with the fakes in
/// `AgentCronTestSupport`, so nothing in Core knows which one answers
/// (`docs/architecture.md` › Ports and adapters). The job and run stores are not here:
/// they are Core's own file stores (ADR-0005), chosen by ``AppConfiguration``.
public struct AppPorts: Sendable {
    /// Launches a run's command line, and the agent availability checks.
    public let runner: any AgentRunning
    /// The scheduler's timer and the sleep, wake, clock, and time-zone events.
    public let systemEvents: any SystemEventsProviding
    /// Holds idle sleep off while jobs run or the user asks.
    public let sleepPreventer: any SleepPreventing
    /// Posts a finished run's notification and reports its click.
    public let notifier: any RunNotifying
    /// Launch at login and the Dock icon while the main window is open.
    public let lifecycle: AppLifecyclePorts

    /// Collects the ports.
    public init(
        runner: any AgentRunning,
        systemEvents: any SystemEventsProviding,
        sleepPreventer: any SleepPreventing,
        notifier: any RunNotifying,
        lifecycle: AppLifecyclePorts,
    ) {
        self.runner = runner
        self.systemEvents = systemEvents
        self.sleepPreventer = sleepPreventer
        self.notifier = notifier
        self.lifecycle = lifecycle
    }
}
