import AgentCronCore
import AgentCronTestSupport
import Testing

// MARK: - Controllers that each break one promise

/// Breaks clause 2: going back to an accessory app does nothing.
@MainActor
private final class NeverLeavingRegular: ActivationPolicyControlling {
    let inner = FakeActivationPolicy()

    func setRegular() {
        inner.setRegular()
    }

    func setAccessory() {
        // Breaks clause 2.
    }
}

/// Breaks clause 3: a second call in a row flips the policy instead of keeping it.
@MainActor
private final class Toggling: ActivationPolicyControlling {
    let inner = FakeActivationPolicy()

    func setRegular() {
        toggle()
    }

    func setAccessory() {
        toggle()
    }

    private func toggle() {
        if inner.policy == .regular {
            inner.setAccessory()
        } else {
            inner.setRegular()
        }
    }
}

/// The fake half of the `ActivationPolicyControlling` contract suite: the same
/// ``ActivationPolicyControllingContract`` that `AgentCronPlatformTests` runs against the
/// real adapter under `just test-local` runs here against ``FakeActivationPolicy``, on
/// every `just test` and in CI, so the fake cannot drift from the port's promises.
@MainActor
@Suite("ActivationPolicyControlling contract, against the fake")
struct ActivationPolicyControllingContractTests {
    @Test(arguments: [ObservedActivationPolicy.accessory, .other, .regular])
    func `the fake keeps the contract from any starting policy`(start: ObservedActivationPolicy) {
        let controller = FakeActivationPolicy(policy: start)
        ActivationPolicyControllingContract.check(controller) { controller.policy }
        #expect(controller.policy == .accessory)
    }

    // The contract's own oracle: a controller that breaks a promise must be reported, or
    // `check` would pass anything, the real adapter included.

    @Test
    func `a controller that never goes back to accessory is reported`() {
        let controller = NeverLeavingRegular()
        let violations = ActivationPolicyControllingContract.violations(of: controller) {
            controller.inner.policy
        }
        #expect(violations == [
            "after setAccessory(): the policy is regular, expected accessory",
            "after setAccessory() a second time: the policy is regular, expected accessory",
            "after the last setAccessory(): the policy is regular, expected accessory",
        ])
    }

    @Test
    func `a setter that is not idempotent is reported`() {
        let controller = Toggling()
        let violations = ActivationPolicyControllingContract.violations(of: controller) {
            controller.inner.policy
        }
        #expect(violations == [
            "after setRegular() a second time: the policy is accessory, expected regular",
            "after setAccessory(): the policy is regular, expected accessory",
        ])
    }
}
