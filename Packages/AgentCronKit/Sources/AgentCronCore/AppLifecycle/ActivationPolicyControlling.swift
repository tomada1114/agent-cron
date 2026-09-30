/// A port: "show the app in the Dock and the menu bar now", or "go back to being only a
/// status item" (ADR-0001).
///
/// AgentCron is a menu-bar agent (`LSUIElement`), so it has no Dock icon and no main menu
/// of its own. While its main window is open it switches to a regular app, so the main
/// menu's commands (`docs/product/ux-flows.md` §4) and its ⌘Tab entry appear, and back to
/// an accessory app when the window closes (`docs/design/ux-guidelines.md` › Platform
/// conventions).
///
/// Core declares it, `AgentCronPlatform`'s `ActivationPolicyController` answers it with
/// `NSApplication.setActivationPolicy(_:)`, tests substitute `FakeActivationPolicy`, and
/// `App/` — the composition root — decides which one ``AppLifecycleModel`` gets. The port
/// decides nothing: *when* to switch is ``AppLifecycleModel``'s decision. Its methods run
/// on the main actor because the application object they change lives there.
///
/// The promises every implementation keeps — `ActivationPolicyControllingContract` in
/// `AgentCronTestSupport` checks them against the fake (`just test`) and the real adapter
/// (`just test-local`); a new clause is stated here first, then added there:
///
/// 1. After ``setRegular()`` returns, the app is a regular app: it has a Dock icon and
///    its own main menu.
/// 2. After ``setAccessory()`` returns, the app is an accessory app: no Dock icon and no
///    main menu, though its windows may still show.
/// 3. Each setter is idempotent: calling it again leaves the same policy.
public protocol ActivationPolicyControlling: Sendable {
    /// Makes the app a regular app, with a Dock icon and a main menu.
    @MainActor
    func setRegular()

    /// Makes the app an accessory app again: a status item, with no Dock icon.
    @MainActor
    func setAccessory()
}
