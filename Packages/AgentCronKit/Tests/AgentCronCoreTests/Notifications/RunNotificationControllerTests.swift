import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// When authorization is asked for (REQ-005), and which finished runs reach the port —
/// the worked examples against ``FakeRunNotifier``, including a denied authorization,
/// under which nothing is posted and the state is exposed for the Jobs screen's note.
@MainActor
@Suite("RunNotificationController")
struct RunNotificationControllerTests {
    private static func controller(over notifier: FakeRunNotifier) -> RunNotificationController {
        RunNotificationController(
            notifier: notifier,
            locale: .english,
            calendar: NotificationFixture.calendar,
        )
    }

    // MARK: - Construction

    @Test
    func `constructing it asks the port nothing, and the state is unknown until read`() {
        let notifier = FakeRunNotifier()
        let controller = Self.controller(over: notifier)
        let convenience = RunNotificationController(notifier: notifier)
        #expect(controller.authorizationState == nil)
        #expect(convenience.authorizationState == nil)
        #expect(notifier.authorizationRequests == 0)
        #expect(notifier.stateReads == 0)
    }

    @Test(arguments: NotificationAuthorizationState.allCases)
    func `refreshing reads the state without asking the user`(
        state: NotificationAuthorizationState,
    ) async {
        let notifier = FakeRunNotifier(authorization: state, promptAnswer: .authorized)
        let controller = Self.controller(over: notifier)
        await controller.refreshAuthorization()
        #expect(controller.authorizationState == state)
        #expect(notifier.authorizationRequests == 0)
        #expect(notifier.promptsShown == 0)
    }

    // MARK: - Asking for authorization (REQ-005)

    @Test
    func `jobs that never notify ask for nothing`() async {
        let notifier = FakeRunNotifier()
        let controller = Self.controller(over: notifier)
        await controller.jobsChanged([])
        await controller.jobsChanged([NotificationFixture.job(notify: .never)])
        #expect(notifier.authorizationRequests == 0)
        #expect(controller.authorizationState == nil)
    }

    @Test(arguments: [NotifyPolicy.failuresOnly, .everyRun])
    func `the first job that notifies asks for authorization once`(setting: NotifyPolicy) async {
        let notifier = FakeRunNotifier()
        let controller = Self.controller(over: notifier)
        await controller.jobsChanged([
            NotificationFixture.job(notify: .never),
            NotificationFixture.job(notify: setting),
        ])
        #expect(notifier.authorizationRequests == 1)
        #expect(notifier.promptsShown == 1)
        #expect(controller.authorizationState == .authorized)
    }

    @Test
    func `later changes never ask again, even after every job stopped notifying`() async {
        let notifier = FakeRunNotifier()
        let controller = Self.controller(over: notifier)
        await controller.jobsChanged([NotificationFixture.job(notify: .failuresOnly)])
        await controller.jobsChanged([NotificationFixture.job(notify: .everyRun)])
        await controller.jobsChanged([NotificationFixture.job(notify: .never)])
        await controller.jobsChanged([NotificationFixture.job(notify: .failuresOnly)])
        #expect(notifier.authorizationRequests == 1)
    }

    @Test
    func `a user who denies leaves the state denied, for the Notify row's note`() async {
        let notifier = FakeRunNotifier(authorization: .notDetermined, promptAnswer: .denied)
        let controller = Self.controller(over: notifier)
        await controller.jobsChanged([NotificationFixture.job(notify: .everyRun)])
        #expect(controller.authorizationState == .denied)
        #expect(notifier.authorizationRequests == 1)
    }

    // MARK: - Posting a finished run

    @Test
    func `the timed-out nightly review is posted as the worked example says`() async {
        let notifier = FakeRunNotifier(authorization: .authorized, promptAnswer: .authorized)
        let controller = Self.controller(over: notifier)
        await controller.runFinished(NotificationFixture.nightlyReviewTimedOut())
        let expected = NotificationContent(
            runID: Fixture.runID,
            title: "Nightly review timed out",
            subtitle: "· 22:00",
            body: "Timed out after 30 minutes",
        )
        #expect(notifier.posted == [expected])
        #expect(controller.authorizationState == .authorized)
    }

    @Test
    func `a successful RSS digest under failures only posts nothing`() async {
        let notifier = FakeRunNotifier(authorization: .authorized, promptAnswer: .authorized)
        let controller = Self.controller(over: notifier)
        await controller.runFinished(NotificationFixture.rssDigestSucceeded())
        #expect(notifier.posted.isEmpty)
        #expect(notifier.stateReads == 0)
    }

    @Test
    func `a run with an empty reason and result is still posted, with an empty body`() async {
        let notifier = FakeRunNotifier(authorization: .authorized, promptAnswer: .authorized)
        let controller = Self.controller(over: notifier)
        var run = NotificationFixture.nightlyReviewTimedOut()
        run.failureReason = nil
        await controller.runFinished(run)
        #expect(notifier.posted.map(\.body) == [""])
    }

    @Test
    func `each finished run is its own notification`() async {
        let notifier = FakeRunNotifier(authorization: .authorized, promptAnswer: .authorized)
        let controller = Self.controller(over: notifier)
        let first = NotificationFixture.nightlyReviewTimedOut()
        var second = NotificationFixture.finishedRun(
            of: NotificationFixture.job(named: "Nightly review", notify: .failuresOnly),
            outcome: .failed,
            startedAt: NotificationFixture.tenPM,
            id: NotificationFixture.otherRunID,
        )
        second.failureReason = "Exit 1"
        await controller.runFinished(first)
        await controller.runFinished(second)
        #expect(notifier.posted.map(\.runID) == [Fixture.runID, NotificationFixture.otherRunID])
    }

    @Test
    func `after the user denies, later runs post nothing`() async {
        let notifier = FakeRunNotifier(authorization: .notDetermined, promptAnswer: .denied)
        let controller = Self.controller(over: notifier)
        await controller.jobsChanged([NotificationFixture.job(notify: .everyRun)])
        await controller.runFinished(NotificationFixture.nightlyReviewTimedOut())
        #expect(notifier.posted.isEmpty)
        #expect(notifier.postAttempts == 0)
        #expect(controller.authorizationState == .denied)
    }

    @Test
    func `before the user has answered, a finished run is not posted`() async {
        let notifier = FakeRunNotifier(authorization: .notDetermined, promptAnswer: .authorized)
        let controller = Self.controller(over: notifier)
        await controller.runFinished(NotificationFixture.nightlyReviewTimedOut())
        #expect(notifier.postAttempts == 0)
        #expect(notifier.promptsShown == 0)
        #expect(controller.authorizationState == .notDetermined)
    }

    @Test
    func `a permission turned off in System Settings is seen at the next run`() async {
        let notifier = FakeRunNotifier(authorization: .authorized, promptAnswer: .authorized)
        let controller = Self.controller(over: notifier)
        await controller.refreshAuthorization()
        notifier.userChangedAuthorization(to: .denied)
        await controller.runFinished(NotificationFixture.nightlyReviewTimedOut())
        #expect(notifier.postAttempts == 0)
        #expect(controller.authorizationState == .denied)
    }

    @Test(arguments: [NotificationPostError.notAuthorized, .systemFailure(code: 7)])
    func `a post the OS refuses is logged and leaves nothing posted`(
        failure: NotificationPostError,
    ) async {
        let notifier = FakeRunNotifier(failingPostsWith: [failure])
        let controller = Self.controller(over: notifier)
        await controller.runFinished(NotificationFixture.nightlyReviewTimedOut())
        #expect(notifier.postAttempts == 1)
        #expect(notifier.posted.isEmpty)
        await controller.runFinished(NotificationFixture.nightlyReviewTimedOut())
        #expect(notifier.posted.count == 1)
    }
}
