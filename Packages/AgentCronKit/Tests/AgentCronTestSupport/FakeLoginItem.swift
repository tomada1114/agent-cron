import AgentCronCore
import os

/// The one fake of ``AgentCronCore/LoginItemControlling``, shared by every test target.
///
/// A fake, not a mock (`.claude/rules/testing.md` › Fakes, not mocks): a real conforming
/// implementation that keeps its status in memory and records what it was asked, which a
/// test reads afterwards. `LoginItemControllingContract` holds it to the same promises as
/// `LoginItemController`.
///
/// Its state sits behind a lock rather than an `@unchecked Sendable`, so the fake is
/// `Sendable` the way the port requires whichever actor a test calls it from.
package final class FakeLoginItem: LoginItemControlling {
    private struct State {
        var status: LoginItemStatus
        var registeredStatus: LoginItemStatus
        var registerFailures: [LoginItemError]
        var unregisterFailures: [LoginItemError]
        var registerCalls = 0
        var unregisterCalls = 0
        var openSettingsCalls = 0
    }

    private let state: OSAllocatedUnfairLock<State>

    /// How many times ``register()`` was called, failed calls included.
    package var registerCalls: Int {
        state.withLock { $0.registerCalls }
    }

    /// How many times ``unregister()`` was called, failed calls included.
    package var unregisterCalls: Int {
        state.withLock { $0.unregisterCalls }
    }

    /// How many times ``openLoginItemsSettings()`` was called.
    package var openSettingsCalls: Int {
        state.withLock { $0.openSettingsCalls }
    }

    package var status: LoginItemStatus {
        state.withLock { $0.status }
    }

    /// A login item that is not registered, and that a ``register()`` enables.
    package convenience init() {
        self.init(status: .notRegistered)
    }

    /// A login item that starts at `status`. Until a test says otherwise, every
    /// ``register()`` and ``unregister()`` succeeds, and a registration enables it.
    package init(status: LoginItemStatus) {
        state = OSAllocatedUnfairLock(initialState: State(
            status: status,
            registeredStatus: .enabled,
            registerFailures: [],
            unregisterFailures: [],
        ))
    }

    /// A successful ``register()`` from now on leaves the status at `status` —
    /// `.requiresApproval` for a user who has to allow the app first.
    package func registrationLeaves(_ status: LoginItemStatus) {
        state.withLock { $0.registeredStatus = status }
    }

    /// The next `failures.count` calls to ``register()`` throw these in order and leave
    /// the status as it was; every later call succeeds.
    package func registrationFails(with failures: [LoginItemError]) {
        state.withLock { $0.registerFailures = failures }
    }

    /// The next `failures.count` calls to ``unregister()`` throw these in order and leave
    /// the status as it was; every later call succeeds.
    package func unregistrationFails(with failures: [LoginItemError]) {
        state.withLock { $0.unregisterFailures = failures }
    }

    /// The status changes outside the app — the user allowed or removed it in System
    /// Settings › Login Items — without any call to the port.
    package func statusChangedOutsideTheApp(to status: LoginItemStatus) {
        state.withLock { $0.status = status }
    }

    package func register() throws(LoginItemError) {
        let failure: LoginItemError? = state.withLock { current in
            current.registerCalls += 1
            if !current.registerFailures.isEmpty {
                return current.registerFailures.removeFirst()
            }
            current.status = current.registeredStatus
            return nil
        }
        if let failure {
            throw failure
        }
    }

    package func unregister() throws(LoginItemError) {
        let failure: LoginItemError? = state.withLock { current in
            current.unregisterCalls += 1
            if !current.unregisterFailures.isEmpty {
                return current.unregisterFailures.removeFirst()
            }
            current.status = .notRegistered
            return nil
        }
        if let failure {
            throw failure
        }
    }

    package func openLoginItemsSettings() {
        state.withLock { $0.openSettingsCalls += 1 }
    }
}
