import AgentCronCore
import AgentCronPlatform
import AgentCronTestSupport
import AppKit
import Testing

/// `ActivationPolicyController` against the test process's own `NSApplication` — what a
/// Core test with `FakeActivationPolicy` cannot show: that each setter really changes the
/// policy AppKit reports, and keeps doing so when called again.
///
/// An activation policy belongs to the process that sets it, so this changes nothing
/// outside the test run: while it runs, the test host may show a Dock icon of its own,
/// and the policy it started with is put back at the end. Serialized, because the
/// policy is one value per process.
@MainActor
@Suite("ActivationPolicyController against the real AppKit", .requiresLocalMachine, .serialized)
struct ActivationPolicyControllerTests {
    static func observed(_ policy: NSApplication.ActivationPolicy) -> ObservedActivationPolicy {
        switch policy {
        case .regular:
            .regular

        case .accessory:
            .accessory

        case .prohibited:
            .other

        @unknown default:
            .other
        }
    }

    @Test
    func `keeps the ActivationPolicyControlling contract the fake is held to`() {
        let application = NSApplication.shared
        let original = application.activationPolicy()
        defer {
            application.setActivationPolicy(original)
        }
        print("activation policy the test host started with: \(Self.observed(original))")

        ActivationPolicyControllingContract.check(ActivationPolicyController()) {
            Self.observed(application.activationPolicy())
        }
    }
}
