import AgentCronCore

/// The one fake of ``AgentCronCore/ActivationPolicyControlling``, shared by every test
/// target.
///
/// A fake, not a mock (`.claude/rules/testing.md` › Fakes, not mocks): a real conforming
/// implementation that keeps the policy in memory and records every setter it was asked
/// for, which a test reads afterwards. `ActivationPolicyControllingContract` holds it to
/// the same promises as `ActivationPolicyController`.
///
/// It lives on the main actor, where the port's methods run, which is what makes it
/// `Sendable` without a lock.
@MainActor
package final class FakeActivationPolicy: ActivationPolicyControlling {
    /// The policy the app has right now, as far as this fake knows.
    package private(set) var policy: ObservedActivationPolicy

    /// Every setter called, in order: `.regular` for ``setRegular()``, `.accessory` for
    /// ``setAccessory()``.
    package private(set) var calls: [ObservedActivationPolicy] = []

    /// A fake app that starts as an accessory app, as AgentCron does (`LSUIElement`).
    package convenience init() {
        self.init(policy: .accessory)
    }

    /// A fake app that starts with `policy`.
    package init(policy: ObservedActivationPolicy) {
        self.policy = policy
    }

    package func setRegular() {
        calls.append(.regular)
        policy = .regular
    }

    package func setAccessory() {
        calls.append(.accessory)
        policy = .accessory
    }
}
