import Foundation
import Observation

/// The app's life around its main window and the user's login: launch at login on the
/// first launch, and a Dock icon and main menu only while the main window is open
/// (ADR-0001, requirements §3.7, `docs/product/ux-flows.md` F6).
///
/// One instance lives as long as the app, owned by `App/`, which tells it when the app
/// has launched and when the main window opens and closes. It decides; the two ports it
/// holds only carry the decision to the OS.
///
/// The first launch is remembered in `UserDefaults` under
/// `didRegisterLoginItemOnFirstLaunch` (a `Bool`), a key that is contract
/// (`docs/architecture.md` › What is contract, ADR-0012): once it is set the app never
/// registers on its own again, so a user who turned launch at login off stays off.
@MainActor
@Observable
public final class AppLifecycleModel {
    private enum Key {
        static let didRegisterLoginItemOnFirstLaunch = "didRegisterLoginItemOnFirstLaunch"
    }

    /// The login item's status as last read, or `nil` before ``appLaunched()`` or
    /// ``refreshLoginItemStatus()`` first reads it. General (#25) shows it, including
    /// ``LoginItemStatus/requiresApproval`` and ``LoginItemStatus/notFound``.
    public private(set) var loginItemStatus: LoginItemStatus?

    /// Whether the main window is open, as last reported by ``mainWindowOpened()`` and
    /// ``mainWindowClosed()``.
    public private(set) var isMainWindowOpen = false

    private let loginItem: any LoginItemControlling
    private let activationPolicy: any ActivationPolicyControlling
    private let defaults: UserDefaults

    /// Creates the model over its two ports. Construction reads and changes nothing;
    /// ``appLaunched()`` is where the app's launch takes effect.
    public init(
        loginItem: any LoginItemControlling,
        activationPolicy: any ActivationPolicyControlling,
        defaults: UserDefaults = .standard,
    ) {
        self.loginItem = loginItem
        self.activationPolicy = activationPolicy
        self.defaults = defaults
    }

    /// The app finished launching. On the first launch ever it registers the app to open
    /// at login (on by default, requirements §3.7) and remembers that it did — even when
    /// the OS refused, so a refusal is not retried behind the user's back on every launch.
    /// Every launch then reads the login item's status.
    public func appLaunched() {
        if !defaults.bool(forKey: Key.didRegisterLoginItemOnFirstLaunch) {
            registerOnFirstLaunch()
        }
        refreshLoginItemStatus()
    }

    /// Reads the login item's status again — after the user may have allowed or removed
    /// the app in System Settings › Login Items.
    public func refreshLoginItemStatus() {
        loginItemStatus = loginItem.status
    }

    /// The main window opened: the app becomes a regular app, so its main menu, Dock
    /// icon, and ⌘Tab entry appear. A repeated report switches nothing.
    public func mainWindowOpened() {
        guard !isMainWindowOpen else {
            return
        }
        isMainWindowOpen = true
        activationPolicy.setRegular()
    }

    /// The main window closed: the app is only a status item again. A close with no
    /// window open switches nothing.
    public func mainWindowClosed() {
        guard isMainWindowOpen else {
            return
        }
        isMainWindowOpen = false
        activationPolicy.setAccessory()
    }

    // MARK: - Private

    private func registerOnFirstLaunch() {
        do {
            try loginItem.register()
            AppLog.lifecycle.info("registered the login item on first launch")
        } catch {
            switch error {
            case let .systemFailure(code):
                AppLog.lifecycle
                    .error(
                        "registering the login item on first launch failed: code \(code, privacy: .public)",
                    )
            }
        }
        defaults.set(true, forKey: Key.didRegisterLoginItemOnFirstLaunch)
    }
}
