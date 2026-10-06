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
    private static let launchPollMilliseconds: Int64 = 50

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
        // AppKit drops an activation asked for before launch finishes — which is when
        // SwiftUI restores the main window or the launch-error alert opens it (#78) —
        // so the request waits until the app has finished launching.
        guard NSRunningApplication.current.isFinishedLaunching else {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(Self.launchPollMilliseconds))
                activate()
            }
            return
        }
        // A plain `NSApplication.activate()` is declined when no click on this app led
        // here — a LaunchServices launch (Finder, a login item, `open`) restoring the
        // window or showing the launch-error alert — so the request borrows the
        // frontmost app's activation context instead.
        let current = NSRunningApplication.current
        if let frontmost = NSWorkspace.shared.frontmostApplication, frontmost != current {
            if !current.activate(from: frontmost, options: []) {
                AppLog.lifecycle.error("AppKit declined to activate the app")
            }
        }
    }

    @MainActor
    private func set(_ policy: NSApplication.ActivationPolicy, named name: String) {
        if !NSApplication.shared.setActivationPolicy(policy) {
            AppLog.lifecycle
                .error("AppKit refused the \(name, privacy: .public) activation policy")
        }
    }
}
