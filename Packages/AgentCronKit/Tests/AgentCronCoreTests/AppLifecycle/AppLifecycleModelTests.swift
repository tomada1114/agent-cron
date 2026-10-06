import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// Launch at login on first launch (REQ-001, REQ-002, REQ-005) and the activation policy
/// that follows the main window (REQ-003, REQ-004), against the fakes of both ports.
@MainActor
@Suite("App lifecycle")
struct AppLifecycleModelTests {
    /// The contract `UserDefaults` key the first-launch registration is remembered under
    /// (`docs/architecture.md` › What is contract, ADR-0012), spelled out here as the
    /// literal a user's Mac already holds.
    static let flagKey = "didRegisterLoginItemOnFirstLaunch"

    static let refusal = LoginItemError.systemFailure(code: 1)

    static func model(
        _ loginItem: FakeLoginItem,
        _ activationPolicy: FakeActivationPolicy,
        _ defaults: UserDefaults,
    ) -> AppLifecycleModel {
        AppLifecycleModel(
            loginItem: loginItem,
            activationPolicy: activationPolicy,
            defaults: defaults,
        )
    }

    // MARK: - Construction

    @Test
    func `making the model registers nothing, switches nothing, and reads no status`() throws {
        try withScratchDefaults { defaults in
            let loginItem = FakeLoginItem()
            let policy = FakeActivationPolicy()
            let model = Self.model(loginItem, policy, defaults)
            #expect(model.loginItemStatus == nil)
            #expect(model.isMainWindowOpen == false)
            #expect(loginItem.registerCalls == 0)
            #expect(policy.calls.isEmpty)
            #expect(defaults.object(forKey: Self.flagKey) == nil)
        }
    }

    // MARK: - First launch (REQ-001)

    @Test
    func `the first launch registers the login item once and remembers it did`() throws {
        try withScratchDefaults { defaults in
            let loginItem = FakeLoginItem()
            let model = Self.model(loginItem, FakeActivationPolicy(), defaults)
            model.appLaunched()
            #expect(loginItem.registerCalls == 1)
            #expect(defaults.object(forKey: Self.flagKey) as? Bool == true)
            #expect(model.loginItemStatus == .enabled)
        }
    }

    @Test
    func `the launch after a first launch registers nothing more`() throws {
        try withScratchDefaults { defaults in
            let loginItem = FakeLoginItem()
            Self.model(loginItem, FakeActivationPolicy(), defaults).appLaunched()
            Self.model(loginItem, FakeActivationPolicy(), defaults).appLaunched()
            #expect(loginItem.registerCalls == 1)
        }
    }

    @Test
    func `announcing the same launch twice registers once`() throws {
        try withScratchDefaults { defaults in
            let loginItem = FakeLoginItem()
            let model = Self.model(loginItem, FakeActivationPolicy(), defaults)
            model.appLaunched()
            model.appLaunched()
            #expect(loginItem.registerCalls == 1)
        }
    }

    // MARK: - A user who turned it off (REQ-002)

    @Test
    func `a later launch leaves a login item the user turned off unregistered`() throws {
        try withScratchDefaults { defaults in
            defaults.set(true, forKey: Self.flagKey)
            let loginItem = FakeLoginItem(status: .notRegistered)
            let model = Self.model(loginItem, FakeActivationPolicy(), defaults)
            model.appLaunched()
            #expect(loginItem.registerCalls == 0)
            #expect(model.loginItemStatus == .notRegistered)
        }
    }

    @Test
    func `a flag stored as false still counts as a first launch`() throws {
        try withScratchDefaults { defaults in
            defaults.set(false, forKey: Self.flagKey)
            let loginItem = FakeLoginItem()
            Self.model(loginItem, FakeActivationPolicy(), defaults).appLaunched()
            #expect(loginItem.registerCalls == 1)
            #expect(defaults.object(forKey: Self.flagKey) as? Bool == true)
        }
    }

    // MARK: - Status (REQ-005)

    @Test(arguments: LoginItemStatus.allCases)
    func `a later launch exposes whatever status the OS reports`(status: LoginItemStatus) throws {
        try withScratchDefaults { defaults in
            defaults.set(true, forKey: Self.flagKey)
            let model = Self.model(FakeLoginItem(status: status), FakeActivationPolicy(), defaults)
            model.appLaunched()
            #expect(model.loginItemStatus == status)
        }
    }

    @Test
    func `a first launch that needs the user's approval exposes requiresApproval`() throws {
        try withScratchDefaults { defaults in
            let loginItem = FakeLoginItem()
            loginItem.registrationLeaves(.requiresApproval)
            let model = Self.model(loginItem, FakeActivationPolicy(), defaults)
            model.appLaunched()
            #expect(model.loginItemStatus == .requiresApproval)
        }
    }

    @Test
    func `refreshing reads the status again, picking up an approval given in System Settings`(
    ) throws {
        try withScratchDefaults { defaults in
            let loginItem = FakeLoginItem()
            loginItem.registrationLeaves(.requiresApproval)
            let model = Self.model(loginItem, FakeActivationPolicy(), defaults)
            model.appLaunched()
            loginItem.statusChangedOutsideTheApp(to: .enabled)
            #expect(model.loginItemStatus == .requiresApproval)
            model.refreshLoginItemStatus()
            #expect(model.loginItemStatus == .enabled)
            #expect(loginItem.registerCalls == 1)
        }
    }

    // MARK: - Registration fails (boundary)

    @Test
    func `a first registration that fails is still remembered and exposes the status that follows`(
    ) throws {
        try withScratchDefaults { defaults in
            let loginItem = FakeLoginItem(status: .notRegistered)
            loginItem.registrationFails(with: [Self.refusal])
            let model = Self.model(loginItem, FakeActivationPolicy(), defaults)
            model.appLaunched()
            #expect(loginItem.registerCalls == 1)
            #expect(defaults.object(forKey: Self.flagKey) as? Bool == true)
            #expect(model.loginItemStatus == .notRegistered)

            Self.model(loginItem, FakeActivationPolicy(), defaults).appLaunched()
            #expect(loginItem.registerCalls == 1)
        }
    }

    @Test
    func `a login item the OS cannot find is exposed unchanged`() throws {
        try withScratchDefaults { defaults in
            let loginItem = FakeLoginItem(status: .notFound)
            loginItem.registrationFails(with: [Self.refusal])
            let model = Self.model(loginItem, FakeActivationPolicy(), defaults)
            model.appLaunched()
            #expect(model.loginItemStatus == .notFound)
        }
    }

    // MARK: - Activation policy (REQ-003, REQ-004)

    @Test
    func `opening the main window makes the app regular`() throws {
        try withScratchDefaults { defaults in
            let policy = FakeActivationPolicy()
            let model = Self.model(FakeLoginItem(), policy, defaults)
            model.mainWindowOpened()
            #expect(model.isMainWindowOpen)
            #expect(policy.calls == [.regular])
            #expect(policy.policy == .regular)
        }
    }

    @Test
    func `opening the main window brings the app to the front`() throws {
        try withScratchDefaults { defaults in
            let policy = FakeActivationPolicy()
            let model = Self.model(FakeLoginItem(), policy, defaults)
            model.mainWindowOpened()
            #expect(policy.activateCalls == 1)
        }
    }

    @Test
    func `an open reported twice activates once, and a close never activates`() throws {
        try withScratchDefaults { defaults in
            let policy = FakeActivationPolicy()
            let model = Self.model(FakeLoginItem(), policy, defaults)
            model.mainWindowOpened()
            model.mainWindowOpened()
            model.mainWindowClosed()
            #expect(policy.activateCalls == 1)
        }
    }

    @Test
    func `closing the main window makes the app an accessory again`() throws {
        try withScratchDefaults { defaults in
            let policy = FakeActivationPolicy()
            let model = Self.model(FakeLoginItem(), policy, defaults)
            model.mainWindowOpened()
            model.mainWindowClosed()
            #expect(model.isMainWindowOpen == false)
            #expect(policy.calls == [.regular, .accessory])
            #expect(policy.policy == .accessory)
        }
    }

    @Test
    func `each open and close alternating calls exactly one setter`() throws {
        try withScratchDefaults { defaults in
            let policy = FakeActivationPolicy()
            let model = Self.model(FakeLoginItem(), policy, defaults)
            for _ in 1 ... 3 {
                model.mainWindowOpened()
                model.mainWindowClosed()
            }
            #expect(policy.calls == [
                .regular,
                .accessory,
                .regular,
                .accessory,
                .regular,
                .accessory,
            ])
        }
    }

    @Test
    func `an open reported twice switches once, and so does a close`() throws {
        try withScratchDefaults { defaults in
            let policy = FakeActivationPolicy()
            let model = Self.model(FakeLoginItem(), policy, defaults)
            model.mainWindowOpened()
            model.mainWindowOpened()
            model.mainWindowClosed()
            model.mainWindowClosed()
            #expect(policy.calls == [.regular, .accessory])
        }
    }

    @Test
    func `a close with no window open switches nothing`() throws {
        try withScratchDefaults { defaults in
            let policy = FakeActivationPolicy()
            let model = Self.model(FakeLoginItem(), policy, defaults)
            model.mainWindowClosed()
            #expect(policy.calls.isEmpty)
            #expect(policy.policy == .accessory)
        }
    }

    @Test
    func `the window and the login item are independent`() throws {
        try withScratchDefaults { defaults in
            let loginItem = FakeLoginItem()
            let policy = FakeActivationPolicy()
            let model = Self.model(loginItem, policy, defaults)
            model.mainWindowOpened()
            #expect(loginItem.registerCalls == 0)
            model.appLaunched()
            #expect(policy.calls == [.regular])
        }
    }
}
