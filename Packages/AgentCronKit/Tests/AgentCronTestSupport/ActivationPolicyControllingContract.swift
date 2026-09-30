import AgentCronCore
import Testing

/// The activation policy an app has, as a contract run observes it.
///
/// `other` stands for any policy the port never sets — a bundle-less process such as
/// `swift test`'s starts out `.prohibited`. Cases are declared alphabetically (SwiftLint's
/// `sorted_enum_cases`).
package enum ObservedActivationPolicy: Sendable, Equatable {
    /// No Dock icon and no main menu; windows may still show.
    case accessory
    /// A policy the port never sets.
    case other
    /// A Dock icon and a main menu.
    case regular
}

/// The promises ``AgentCronCore/ActivationPolicyControlling`` makes, checked against any
/// implementation of it (`.claude/rules/testing.md` › One Contract Suite per Port).
///
/// The port answers nothing about the policy in force, so the caller supplies that
/// observation: `currentPolicy()` reads it right now. `AgentCronCoreTests` answers it from
/// ``FakeActivationPolicy`` on every `just test` and in CI; `AgentCronPlatformTests`
/// answers it from `NSApplication.activationPolicy()` for `ActivationPolicyController`
/// under `.requiresLocalMachine` (`just test-local`). Every clause is one the port's `///`
/// states; a new clause is stated there first.
@MainActor
package enum ActivationPolicyControllingContract {
    /// A description of every broken promise, empty when `controller` keeps them all.
    ///
    /// Walks the path the app takes — the main window opens, closes, and opens and closes
    /// again — calling each setter twice in a row once (clause 3), and leaves the app an
    /// accessory app. Separate from ``check(_:currentPolicy:)`` so a test can hand it a
    /// controller that breaks a promise and see the contract notice — the proof it is
    /// not vacuous.
    package static func violations(
        of controller: some ActivationPolicyControlling,
        currentPolicy: () -> ObservedActivationPolicy,
    ) -> [String] {
        var broken: [String] = []
        func expectPolicy(_ expected: ObservedActivationPolicy, _ moment: String) {
            let actual = currentPolicy()
            if actual != expected {
                broken.append("\(moment): the policy is \(actual), expected \(expected)")
            }
        }

        controller.setRegular()
        expectPolicy(.regular, "after setRegular()")
        controller.setRegular()
        expectPolicy(.regular, "after setRegular() a second time")
        controller.setAccessory()
        expectPolicy(.accessory, "after setAccessory()")
        controller.setAccessory()
        expectPolicy(.accessory, "after setAccessory() a second time")
        controller.setRegular()
        expectPolicy(.regular, "after setRegular() following setAccessory()")
        controller.setAccessory()
        expectPolicy(.accessory, "after the last setAccessory()")
        return broken
    }

    /// Records an issue for every promise `controller` breaks.
    package static func check(
        _ controller: some ActivationPolicyControlling,
        currentPolicy: () -> ObservedActivationPolicy,
    ) {
        let broken = violations(of: controller, currentPolicy: currentPolicy)
        #expect(
            broken.isEmpty,
            "\(type(of: controller)) breaks the ActivationPolicyControlling contract: \(broken)",
        )
    }
}
