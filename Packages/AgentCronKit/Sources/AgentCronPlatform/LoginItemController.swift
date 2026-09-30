import AgentCronCore
import Foundation
import ServiceManagement

/// The ServiceManagement-backed adapter for ``AgentCronCore/LoginItemControlling``
/// (ADR-0001): the app itself as a login item, through `SMAppService.mainApp`.
///
/// Translation only: it maps `SMAppService.Status` into
/// ``AgentCronCore/LoginItemStatus`` (``status(for:)``) and a thrown error into
/// ``AgentCronCore/LoginItemError`` (``error(for:)``). When to register is
/// ``AgentCronCore/AppLifecycleModel``'s decision, which is why this file sits outside
/// the coverage floor. What is checked here instead is the translation, by the
/// local-machine test `LoginItemControllerTests` (`just test-local`), which reads the
/// status but never registers: registering changes the user's login items, so that half
/// of the contract runs only behind a further opt-in.
///
/// It keeps no state: every call asks `SMAppService.mainApp` afresh, so the answer is
/// whatever the OS holds now, including a change the user made in System Settings.
public struct LoginItemController: LoginItemControlling {
    public var status: LoginItemStatus {
        Self.status(for: SMAppService.mainApp.status)
    }

    public init() {
        // Nothing to set up: `SMAppService.mainApp` is asked on every call.
    }

    /// Which Core status an `SMAppService.Status` means. A status a later macOS adds is
    /// reported as `notFound` — a login item the app cannot manage — and logged.
    package static func status(for status: SMAppService.Status) -> LoginItemStatus {
        switch status {
        case .enabled:
            return .enabled

        case .notRegistered:
            return .notRegistered

        case .requiresApproval:
            return .requiresApproval

        case .notFound:
            return .notFound

        @unknown default:
            AppLog.lifecycle
                .error("unknown SMAppService status \(status.rawValue, privacy: .public)")
            return .notFound
        }
    }

    /// Which Core error a thrown ServiceManagement error means. Only the numeric code
    /// crosses the port: the error's description and `userInfo` can hold a path.
    package static func error(for error: any Error) -> LoginItemError {
        .systemFailure(code: (error as NSError).code)
    }

    public func register() throws(LoginItemError) {
        do {
            try SMAppService.mainApp.register()
        } catch {
            throw Self.error(for: error)
        }
    }

    public func unregister() throws(LoginItemError) {
        do {
            try SMAppService.mainApp.unregister()
        } catch {
            throw Self.error(for: error)
        }
    }

    public func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
