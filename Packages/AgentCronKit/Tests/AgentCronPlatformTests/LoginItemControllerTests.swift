import AgentCronCore
import AgentCronPlatform
import AgentCronTestSupport
import Foundation
import ServiceManagement
import Testing

/// `LoginItemController`'s translation against the real ServiceManagement types — what a
/// Core test with `FakeLoginItem` cannot show: that every `SMAppService.Status` maps to the
/// Core status of the same meaning, that a thrown error crosses the port as its code
/// alone, and that reading `SMAppService.mainApp.status` keeps the read-only half of the
/// port's contract.
///
/// Nothing here registers, unregisters, or opens System Settings: registering changes
/// the user's login items and makes macOS post a "Login Item Added" notification. That
/// half of the contract is `LoginItemControllerRegistrationTests`, behind its own opt-in.
@Suite("LoginItemController against the real ServiceManagement, read-only", .requiresLocalMachine)
struct LoginItemControllerTests {
    static let statuses: [(SMAppService.Status, LoginItemStatus)] = [
        (.enabled, .enabled),
        (.notFound, .notFound),
        (.notRegistered, .notRegistered),
        (.requiresApproval, .requiresApproval),
    ]

    @Test(arguments: statuses)
    func `every SMAppService status maps to the Core status of the same meaning`(
        status: SMAppService.Status,
        expected: LoginItemStatus,
    ) {
        #expect(LoginItemController.status(for: status) == expected)
    }

    @Test
    func `the mapping covers every Core status`() {
        #expect(Set(Self.statuses.map(\.1)) == Set(LoginItemStatus.allCases))
    }

    @Test
    func `a status a later macOS adds is reported as notFound`() throws {
        let unknown = try #require(SMAppService.Status(rawValue: 99))
        #expect(LoginItemController.status(for: unknown) == .notFound)
    }

    @Test
    func `a thrown ServiceManagement error crosses the port as its code alone`() {
        let thrown = NSError(
            domain: "SMAppServiceErrorDomain",
            code: Int(kSMErrorLaunchDeniedByUser),
            userInfo: [NSFilePathErrorKey: "/Users/someone/Applications/AgentCron.app"],
        )
        #expect(LoginItemController
            .error(for: thrown) == .systemFailure(code: Int(kSMErrorLaunchDeniedByUser)))
    }

    @Test
    func `the status is what SMAppService reports for this process`() {
        let status = LoginItemController().status
        #expect(status == LoginItemController.status(for: SMAppService.mainApp.status))
        let host = ProcessInfo.processInfo.processName
        print("LoginItemController().status in this process (\(host)): \(status)")
    }

    @Test
    func `keeps the read-only half of the LoginItemControlling contract the fake is held to`() {
        LoginItemControllingContract.checkStatus(LoginItemController())
    }
}
