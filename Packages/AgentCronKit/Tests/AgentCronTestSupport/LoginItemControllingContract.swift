import AgentCronCore
import Testing

/// The promises ``AgentCronCore/LoginItemControlling`` makes, checked against any
/// implementation of it (`.claude/rules/testing.md` › One Contract Suite per Port).
///
/// Split in two because only the first half is safe to run against the real
/// `SMAppService` on someone's Mac:
///
/// - ``statusViolations(of:)`` only reads (clause 1). `AgentCronPlatformTests` runs it
///   against `LoginItemController` under `just test-local`.
/// - ``registrationViolations(of:)`` registers and unregisters (clauses 2 and 3), which
///   changes the user's login items and makes macOS post a "Login Item Added"
///   notification. `AgentCronPlatformTests` runs it only behind a further opt-in that
///   `just test-local` never sets.
///
/// `AgentCronCoreTests` runs both against ``FakeLoginItem`` on every `just test` and in
/// CI. Every clause is one the port's `///` states; a new clause is stated there first.
package enum LoginItemControllingContract {
    /// The statuses clause 2 allows once ``AgentCronCore/LoginItemControlling/register()``
    /// has returned.
    package static let registeredStatuses: Set<LoginItemStatus> = [.enabled, .requiresApproval]

    /// A description of every broken promise among the read-only ones, empty when `item`
    /// keeps them all.
    package static func statusViolations(of item: some LoginItemControlling) -> [String] {
        let first = item.status
        let second = item.status
        guard first == second else {
            return ["status answered \(first), then \(second), with nothing changed in between"]
        }
        return []
    }

    /// A description of every broken promise among the ones that register and
    /// unregister, empty when `item` keeps them all.
    ///
    /// Registers, then unregisters, then puts back what it found: an item that started
    /// registered is registered again. A throw ends the run, since what follows depends
    /// on the change having happened. Separate from ``checkRegistration(_:)`` so a test
    /// can hand it an item that breaks a promise and see the contract notice — the proof
    /// it is not vacuous.
    package static func registrationViolations(of item: some LoginItemControlling) -> [String] {
        let original = item.status
        var broken: [String] = []

        do {
            try item.register()
        } catch {
            return ["register() threw \(error), so the contract could not run"]
        }
        let registered = item.status
        if !registeredStatuses.contains(registered) {
            broken
                .append(
                    "after register(): the status is \(registered), expected enabled or requiresApproval",
                )
        }

        do {
            try item.unregister()
        } catch {
            return broken + ["unregister() threw \(error), so the contract could not run"]
        }
        let unregistered = item.status
        if unregistered != .notRegistered {
            broken
                .append("after unregister(): the status is \(unregistered), expected notRegistered")
        }

        if registeredStatuses.contains(original) {
            do {
                try item.register()
            } catch {
                broken.append("register() threw \(error) while putting back a registered item")
            }
        }
        return broken
    }

    /// Records an issue for every read-only promise `item` breaks.
    package static func checkStatus(_ item: some LoginItemControlling) {
        let broken = statusViolations(of: item)
        #expect(
            broken.isEmpty,
            "\(type(of: item)) breaks the LoginItemControlling contract: \(broken)",
        )
    }

    /// Records an issue for every registration promise `item` breaks.
    package static func checkRegistration(_ item: some LoginItemControlling) {
        let broken = registrationViolations(of: item)
        #expect(
            broken.isEmpty,
            "\(type(of: item)) breaks the LoginItemControlling contract: \(broken)",
        )
    }
}
