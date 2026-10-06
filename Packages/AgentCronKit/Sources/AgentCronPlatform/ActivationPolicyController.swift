import AgentCronCore
import AppKit

/// The AppKit-backed adapter for ``AgentCronCore/ActivationPolicyControlling``
/// (ADR-0001): `NSApplication.setActivationPolicy(_:)` on the running app.
///
/// Translation only: ``setRegular()`` and ``setAccessory()`` each set one
/// `NSApplication.ActivationPolicy`. When to switch is
/// ``AgentCronCore/AppLifecycleModel``'s decision, which is why this file sits outside
/// the coverage floor. What is checked here instead is the translation, by the
/// local-machine test `ActivationPolicyControllerTests` (`just test-local`), which runs
/// the port's contract against the test process's own `NSApplication`.
///
/// AppKit answers whether a switch took with a `Bool`; the port promises the switch
/// rather than reporting it, so a refusal is logged here, the only place that sees it.
public struct ActivationPolicyController: ActivationPolicyControlling {
    public init() {
        // Nothing to set up: the shared application is asked on every call.
    }

    public func setRegular() {
        set(.regular, named: "regular")
    }

    public func setAccessory() {
        set(.accessory, named: "accessory")
    }

    public func activate() {
        NSApplication.shared.activate()
    }

    @MainActor
    private func set(_ policy: NSApplication.ActivationPolicy, named name: String) {
        if !NSApplication.shared.setActivationPolicy(policy) {
            AppLog.lifecycle
                .error("AppKit refused the \(name, privacy: .public) activation policy")
        }
    }
}
