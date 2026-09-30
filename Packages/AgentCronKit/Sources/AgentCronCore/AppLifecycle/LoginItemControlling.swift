/// Whether the app is registered to open at login, as the OS reports it (ADR-0001).
///
/// Mirrors the four states the OS distinguishes, so General (#25) can show each one:
/// `requiresApproval` needs the user to allow the app in System Settings › Login Items,
/// and `notFound` means the OS cannot find the app to register at all.
///
/// Cases are declared alphabetically (SwiftLint's `sorted_enum_cases`).
public enum LoginItemStatus: Sendable, Hashable, CaseIterable {
    /// Registered and allowed: the app opens at login.
    case enabled
    /// The OS cannot find the app to register — for example a copy it does not track.
    case notFound
    /// Not registered: the app does not open at login.
    case notRegistered
    /// Registered, but the user has to allow it in System Settings before it opens at
    /// login.
    case requiresApproval
}

/// Why the login item could not be registered or unregistered.
///
/// An enum rather than a message so the payload stays a value that is safe to log: the
/// OS's error code, which carries no user data.
public enum LoginItemError: Error, Equatable, Sendable {
    /// The OS refused the change for a reason the app has no recovery for; `code` is for
    /// logs.
    case systemFailure(code: Int)
}

/// A port: "open this app at login, or stop doing so, and tell me which it is", asked in
/// Core's own vocabulary (ADR-0001, requirements §3.7).
///
/// Core declares it, `AgentCronPlatform`'s `LoginItemController` answers it with
/// `SMAppService.mainApp`, tests substitute `FakeLoginItem`, and `App/` — the composition
/// root — decides which one ``AppLifecycleModel`` gets. The port decides nothing: when to
/// register is ``AppLifecycleModel``'s decision, where the coverage floor sees it.
///
/// The promises every implementation keeps — `LoginItemControllingContract` in
/// `AgentCronTestSupport` checks them against the fake (`just test`) and the real adapter
/// (clause 1 under `just test-local`; clauses 2 and 3 only behind a further opt-in,
/// because they change the user's login items); a new clause is stated here first, then
/// added there:
///
/// 1. Reading ``status`` asks the user nothing and changes nothing: read twice with
///    nothing changed in between, it answers the same status.
/// 2. After ``register()`` returns, ``status`` is ``LoginItemStatus/enabled`` or
///    ``LoginItemStatus/requiresApproval``.
/// 3. After ``unregister()`` returns, ``status`` is ``LoginItemStatus/notRegistered``.
public protocol LoginItemControlling: Sendable {
    /// Whether the app is registered to open at login right now.
    var status: LoginItemStatus { get }

    /// Registers the app to open at login. The OS may still need the user's approval,
    /// which ``status`` then reports as ``LoginItemStatus/requiresApproval``.
    func register() throws(LoginItemError)

    /// Stops the app opening at login.
    func unregister() throws(LoginItemError)

    /// Opens System Settings › Login Items, where the user approves a login item whose
    /// ``status`` is ``LoginItemStatus/requiresApproval``.
    func openLoginItemsSettings()
}
