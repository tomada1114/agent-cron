import AgentCronCore
import AgentCronPlatform
import AgentCronTestSupport
import Foundation
import os
import Testing
import UserNotifications

/// `UserNotificationPoster`'s translation against the real UserNotifications types — what
/// a Core test with `FakeRunNotifier` cannot show: that a `NotificationContent` becomes a
/// request the framework accepts, with one identifier and one thread per run; that every
/// authorization status maps to the Core state the Jobs screen's note reads; and that the
/// run ID a request carries comes back out of a click on it (REQ-006's plumbing).
///
/// None of it touches `UNUserNotificationCenter`. `.current()` raises
/// `NSInternalInconsistencyException` ("bundleProxyForCurrentProcess is nil") and ends the
/// process when that process is not an app bundle, and `swift test` runs these tests in
/// `swiftpm-testing-helper`, which is not (checked 2026-09-30 with Swift 6.3.2 on macOS
/// 27). So nothing here reads the authorization status, prompts, or posts; that is
/// `UserNotificationPosterCenterTests`.
@Suite("UserNotificationPoster's translation, without a notification center", .requiresLocalMachine)
struct UserNotificationPosterTests {
    static let statuses: [(UNAuthorizationStatus, NotificationAuthorizationState)] = [
        (.authorized, .authorized),
        (.denied, .denied),
        (.notDetermined, .notDetermined),
        (.provisional, .authorized),
    ]

    static let runID = UUID(uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA") ?? UUID()
    static let otherRunID = UUID(uuidString: "0000AAAA-BBBB-CCCC-DDDD-EEEEFFFF0000") ?? UUID()

    static let content = NotificationContent(
        runID: runID,
        title: "Nightly review timed out",
        subtitle: "· 22:00",
        body: "Timed out after 30 minutes",
    )

    /// A router whose handler records every run it is called with.
    static func recordingRouter() -> (NotificationClickRouter, OSAllocatedUnfairLock<[UUID]>) {
        let clicks = OSAllocatedUnfairLock<[UUID]>(initialState: [])
        let router = NotificationClickRouter()
        router.setHandler { runID in clicks.withLock { $0.append(runID) } }
        return (router, clicks)
    }

    @Test
    func `making a poster touches no notification center`() {
        // In this bundle-less process, touching the center would end the whole run.
        let poster = UserNotificationPoster()
        withExtendedLifetime(poster) {
            #expect(Bundle.main.bundleIdentifier == nil)
        }
    }

    @Test
    func `a request carries the content, identified by its run, and fires at once`() {
        let request = UserNotificationPoster.request(for: Self.content)
        #expect(request.identifier == Self.runID.uuidString)
        #expect(request.trigger == nil)
        #expect(request.content.title == "Nightly review timed out")
        #expect(request.content.subtitle == "· 22:00")
        #expect(request.content.body == "Timed out after 30 minutes")
        #expect(request.content.userInfo[NotificationClickRouter.runIDKey] as? String == Self.runID
            .uuidString)
    }

    @Test
    func `two runs get two identifiers and two threads, so neither replaces nor groups with the other`() {
        let other = NotificationContent(runID: Self.otherRunID, title: "t", subtitle: "s", body: "")
        let first = UserNotificationPoster.request(for: Self.content)
        let second = UserNotificationPoster.request(for: other)
        #expect(first.identifier != second.identifier)
        #expect(first.content.threadIdentifier == Self.runID.uuidString)
        #expect(second.content.threadIdentifier == Self.otherRunID.uuidString)
    }

    @Test
    func `an empty body is still a request`() {
        let empty = NotificationContent(runID: Self.runID, title: "t", subtitle: "s", body: "")
        #expect(UserNotificationPoster.request(for: empty).content.body.isEmpty)
    }

    @Test(arguments: statuses)
    func `every authorization status maps to the state Core reads`(
        status: UNAuthorizationStatus,
        state: NotificationAuthorizationState,
    ) {
        #expect(UserNotificationPoster.state(for: status) == state)
    }

    @Test
    func `opening a notification calls the handler with the run its request carries`() {
        let (router, clicks) = Self.recordingRouter()
        let request = UserNotificationPoster.request(for: Self.content)
        router.route(
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            userInfo: request.content.userInfo,
        )
        #expect(clicks.withLock { $0 } == [Self.runID])
    }

    @Test
    func `the handler set last is the one called`() {
        let (router, stale) = Self.recordingRouter()
        let current = OSAllocatedUnfairLock<[UUID]>(initialState: [])
        router.setHandler { runID in current.withLock { $0.append(runID) } }
        router.route(
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            userInfo: UserNotificationPoster.request(for: Self.content).content.userInfo,
        )
        #expect(stale.withLock { $0 }.isEmpty)
        #expect(current.withLock { $0 } == [Self.runID])
    }

    @Test
    func `a dismissal, or a notification that names no run, calls nothing`() {
        let (router, clicks) = Self.recordingRouter()
        let userInfo = UserNotificationPoster.request(for: Self.content).content.userInfo
        router.route(actionIdentifier: UNNotificationDismissActionIdentifier, userInfo: userInfo)
        router.route(actionIdentifier: UNNotificationDefaultActionIdentifier, userInfo: [:])
        router.route(
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            userInfo: [NotificationClickRouter.runIDKey: "not a run"],
        )
        #expect(clicks.withLock { $0 }.isEmpty)
    }

    @Test
    func `a click before any handler is set is dropped, not a crash`() {
        let router = NotificationClickRouter()
        router.route(
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            userInfo: UserNotificationPoster.request(for: Self.content).content.userInfo,
        )
    }

    @Test
    func `the router answers the center's click and foreground callbacks`() {
        let router = NotificationClickRouter()
        let click = #selector(UNUserNotificationCenterDelegate
            .userNotificationCenter(_:didReceive:withCompletionHandler:))
        let foreground = #selector(UNUserNotificationCenterDelegate
            .userNotificationCenter(_:willPresent:withCompletionHandler:))
        #expect(router.responds(to: click))
        #expect(router.responds(to: foreground))
    }

    @Test
    func `a notification arriving while the app is active still shows as a banner and in the list`() {
        #expect(NotificationClickRouter.foregroundPresentation == [.banner, .list])
    }
}
