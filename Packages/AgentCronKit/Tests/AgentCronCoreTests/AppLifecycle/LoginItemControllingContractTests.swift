import AgentCronCore
import AgentCronTestSupport
import os
import Testing

// MARK: - Login items that each break one promise

/// The OS error every broken login item below throws, when it throws.
private let refusal = LoginItemError.systemFailure(code: 1)

/// Breaks clause 1: every read of the status answers the next state in turn.
private final class FlickeringStatus: LoginItemControlling {
    private let enabled = OSAllocatedUnfairLock(initialState: true)

    var status: LoginItemStatus {
        enabled.withLock { isEnabled in
            defer { isEnabled.toggle() }
            return isEnabled ? .enabled : .notRegistered
        }
    }

    func register() {
        // Never reached: the read-only half of the contract registers nothing.
    }

    func unregister() {
        // Never reached: the read-only half of the contract unregisters nothing.
    }

    func openLoginItemsSettings() {
        // Not part of any clause.
    }
}

/// Breaks clause 3: unregistering leaves the item registered.
private struct UnregisterDoingNothing: LoginItemControlling {
    let inner = FakeLoginItem()

    var status: LoginItemStatus {
        inner.status
    }

    func register() throws(LoginItemError) {
        try inner.register()
    }

    func unregister() {
        // Breaks clause 3.
    }

    func openLoginItemsSettings() {
        inner.openLoginItemsSettings()
    }
}

/// Keeps every promise; the OS merely refuses every registration after the first.
private struct FailingSecondRegistration: LoginItemControlling {
    let inner: FakeLoginItem

    var status: LoginItemStatus {
        inner.status
    }

    func register() throws(LoginItemError) {
        guard inner.registerCalls == 0 else {
            throw refusal
        }
        try inner.register()
    }

    func unregister() throws(LoginItemError) {
        try inner.unregister()
    }

    func openLoginItemsSettings() {
        inner.openLoginItemsSettings()
    }
}

/// The contract half that runs on every `just test`: ``LoginItemControllingContract``,
/// which `AgentCronPlatformTests` runs against `LoginItemController` (the read-only half
/// under `just test-local`, the registration half only behind its own opt-in), runs here
/// against ``FakeLoginItem``, so the fake cannot drift from the port's promises.
@Suite("LoginItemControlling contract, against the fake")
struct LoginItemControllingContractTests {
    @Test(arguments: LoginItemStatus.allCases)
    func `the fake keeps the read-only promises`(status: LoginItemStatus) {
        LoginItemControllingContract.checkStatus(FakeLoginItem(status: status))
    }

    @Test(arguments: [LoginItemStatus.enabled, .requiresApproval])
    func `the fake keeps the registration promises and puts back what it found`(
        registeredStatus: LoginItemStatus,
    ) {
        let unregistered = FakeLoginItem(status: .notRegistered)
        unregistered.registrationLeaves(registeredStatus)
        LoginItemControllingContract.checkRegistration(unregistered)
        #expect(unregistered.status == .notRegistered)

        let registered = FakeLoginItem(status: registeredStatus)
        registered.registrationLeaves(registeredStatus)
        LoginItemControllingContract.checkRegistration(registered)
        #expect(registered.status == registeredStatus)
    }

    // The contract's own oracle: an item that breaks a promise must be reported, or the
    // checks would pass anything, the real adapter included.

    @Test
    func `a status that changes between two reads is reported`() {
        #expect(LoginItemControllingContract.statusViolations(of: FlickeringStatus()) == [
            "status answered enabled, then notRegistered, with nothing changed in between",
        ])
    }

    @Test
    func `a registration that leaves the item unregistered is reported`() {
        let item = FakeLoginItem(status: .notRegistered)
        item.registrationLeaves(.notRegistered)
        #expect(LoginItemControllingContract.registrationViolations(of: item) == [
            "after register(): the status is notRegistered, expected enabled or requiresApproval",
        ])
    }

    @Test
    func `an unregistration that leaves the item registered is reported`() {
        #expect(LoginItemControllingContract
            .registrationViolations(of: UnregisterDoingNothing()) == [
                "after unregister(): the status is enabled, expected notRegistered",
            ])
    }

    @Test
    func `a registration that throws is reported`() {
        let item = FakeLoginItem()
        item.registrationFails(with: [refusal])
        #expect(LoginItemControllingContract.registrationViolations(of: item) == [
            "register() threw systemFailure(code: 1), so the contract could not run",
        ])
    }

    @Test
    func `an unregistration that throws is reported`() {
        let item = FakeLoginItem()
        item.unregistrationFails(with: [refusal])
        #expect(LoginItemControllingContract.registrationViolations(of: item) == [
            "unregister() threw systemFailure(code: 1), so the contract could not run",
        ])
    }

    @Test
    func `failing to put back a registered item is reported`() {
        let item = FakeLoginItem(status: .enabled)
        let failingRestore = FailingSecondRegistration(inner: item)
        #expect(LoginItemControllingContract.registrationViolations(of: failingRestore) == [
            "register() threw systemFailure(code: 1) while putting back a registered item",
        ])
    }

    @Test
    func `the fake counts the settings it was asked to open`() {
        let item = FakeLoginItem()
        item.openLoginItemsSettings()
        item.openLoginItemsSettings()
        #expect(item.openSettingsCalls == 2)
        #expect(item.registerCalls == 0)
        #expect(item.unregisterCalls == 0)
    }
}
