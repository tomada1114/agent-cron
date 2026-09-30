import AgentCronCore
import Foundation
import os
import Testing

/// The promises ``AgentCronCore/RunNotifying`` makes, checked against any implementation
/// of it (`.claude/rules/testing.md` › One Contract Suite per Port).
///
/// The port answers nothing about what Notification Center holds or what the user does,
/// so the caller supplies both: `delivered` answers the run IDs of the notifications
/// delivered now, and `click` has the user click the delivered notification for a run.
/// `AgentCronCoreTests` answers them from ``FakeRunNotifier`` on every `just test` and in
/// CI; `AgentCronPlatformTests` answers them from the real Notification Center and a
/// person's click for `UserNotificationPoster`, behind an opt-in of its own, since the
/// real center needs an app bundle and a human. Every clause is one the port's `///`
/// states; a new clause is stated there first.
package enum RunNotifyingContract {
    /// Two notifications for two different runs, with run IDs unique to this call so a
    /// notification another run of the contract left behind is never counted as this
    /// one's.
    package static func sampleContents() -> [NotificationContent] {
        [
            NotificationContent(
                runID: UUID(),
                title: "Contract job failed",
                subtitle: "· 22:00",
                body: "RunNotifyingContract: the first of two notifications",
            ),
            NotificationContent(
                runID: UUID(),
                title: "Contract job failed",
                subtitle: "· 22:00",
                body: "RunNotifyingContract: the second of two notifications",
            ),
        ]
    }

    /// A description of every broken promise, empty when `notifier` keeps them all.
    ///
    /// Separate from ``check(_:posting:delivered:click:)`` so a test can hand it a
    /// notifier that breaks a promise and see the contract notice — the proof it is not
    /// vacuous.
    package static func violations(
        of notifier: some RunNotifying,
        posting contents: [NotificationContent],
        delivered: @Sendable () async -> [UUID],
        click: @Sendable (UUID) async -> Void,
    ) async -> [String] {
        var broken = await authorizationViolations(of: notifier)
        let authorized = await notifier.authorizationState() == .authorized

        let stale = OSAllocatedUnfairLock<[UUID]>(initialState: [])
        let clicked = OSAllocatedUnfairLock<[UUID]>(initialState: [])
        notifier.setClickHandler { runID in stale.withLock { $0.append(runID) } }
        notifier.setClickHandler { runID in clicked.withLock { $0.append(runID) } }

        for content in contents {
            do {
                try await notifier.post(content)
                if !authorized {
                    broken.append("post(_:) while not authorized did not throw")
                }
            } catch {
                if authorized {
                    broken.append("post(_:) while authorized threw \(error)")
                } else if error != .notAuthorized {
                    broken.append("post(_:) while not authorized threw \(error), not notAuthorized")
                }
            }
        }

        let posted = contents.map(\.runID)
        let expected = authorized ? posted : []
        let deliveredNow = await delivered().filter(posted.contains)
        if deliveredNow.sorted(by: uuidOrder) != expected.sorted(by: uuidOrder) {
            broken
                .append(
                    "after posting \(posted.count), delivered \(deliveredNow), expected \(expected)",
                )
        }

        if authorized, let first = contents.first {
            await click(first.runID)
            let calls = clicked.withLock { $0 }
            if calls != [first.runID] {
                broken.append("a click on \(first.runID) called the handler with \(calls)")
            }
            let staleCalls = stale.withLock { $0 }
            if !staleCalls.isEmpty {
                broken.append("a replaced click handler was called with \(staleCalls)")
            }
        }
        return broken
    }

    /// Records an issue for every promise `notifier` breaks.
    package static func check(
        _ notifier: some RunNotifying,
        posting contents: [NotificationContent],
        delivered: @Sendable () async -> [UUID],
        click: @Sendable (UUID) async -> Void,
    ) async {
        let broken = await violations(
            of: notifier,
            posting: contents,
            delivered: delivered,
            click: click,
        )
        #expect(broken.isEmpty, "\(type(of: notifier)) breaks the RunNotifying contract: \(broken)")
    }

    /// Clauses 1 and 2: reading the state is stable, and asking settles it.
    private static func authorizationViolations(of notifier: some RunNotifying) async -> [String] {
        var broken: [String] = []
        let first = await notifier.authorizationState()
        let second = await notifier.authorizationState()
        if first != second {
            broken.append("authorizationState() answered \(first), then \(second)")
        }
        let answered = await notifier.requestAuthorizationIfNeeded()
        if first != .notDetermined, answered != first {
            broken
                .append("requestAuthorizationIfNeeded() changed a settled \(first) to \(answered)")
        }
        let afterwards = await notifier.authorizationState()
        if afterwards != answered {
            broken
                .append(
                    "requestAuthorizationIfNeeded() answered \(answered), then the state was \(afterwards)",
                )
        }
        if answered != .notDetermined {
            let again = await notifier.requestAuthorizationIfNeeded()
            if again != answered {
                broken.append("asking again changed a settled \(answered) to \(again)")
            }
        }
        return broken
    }

    private static func uuidOrder(_ lhs: UUID, _ rhs: UUID) -> Bool {
        lhs.uuidString < rhs.uuidString
    }
}
