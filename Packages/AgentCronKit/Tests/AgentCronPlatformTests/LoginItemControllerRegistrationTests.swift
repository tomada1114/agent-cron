import AgentCronCore
import AgentCronPlatform
import AgentCronTestSupport
import Foundation
import Testing

/// The opt-in that lets a test register and unregister the real login item. Off by
/// default, and never set by `just test-local`: it changes the user's login items and
/// macOS posts a "Login Item Added" notification.
enum LoginItemRegistrationTests {
    static let optInVariable = "RUN_LOGIN_ITEM_REGISTRATION_TESTS"
}

/// The registration half of the port's contract suite: `LoginItemControllingContract`'s
/// clauses 2 and 3, the same function `AgentCronCoreTests` runs against the fake, run
/// against `SMAppService.mainApp`. It registers, unregisters, and puts back what it
/// found.
///
/// Two conditions, both reported as a skip when unmet: the opt-in above, and a host that
/// is an app bundle, since `SMAppService.mainApp` is the process's own bundle and
/// `swift test`'s host is not AgentCron's. So today this suite documents the check the
/// running app owes rather than running it.
@Suite(
    "LoginItemController against the real ServiceManagement, registering",
    .requiresLocalMachine,
    .enabled(
        if: LocalMachineTests.isOptedIn(to: LoginItemRegistrationTests.optInVariable),
        "changes the login items: set \(LoginItemRegistrationTests.optInVariable)=1 to run it",
    ),
    .enabled(
        if: Bundle.main.bundleIdentifier != nil,
        "needs an app-bundle host: SMAppService.mainApp is the host's own bundle",
    ),
)
struct LoginItemControllerRegistrationTests {
    @Test
    func `keeps the registration half of the LoginItemControlling contract`() {
        LoginItemControllingContract.checkRegistration(LoginItemController())
    }
}
