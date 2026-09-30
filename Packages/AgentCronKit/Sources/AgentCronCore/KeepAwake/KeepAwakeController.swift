import Foundation
import Observation

/// Decides when the Mac is kept out of idle sleep: while any job runs, and while a manual
/// keep-awake choice is in force (ADR-0006, requirements §3.6).
///
/// It holds **exactly one** assertion through ``SleepPreventing`` while
/// `runningJobCount > 0 || manualUntil > now` (or the manual choice is
/// ``KeepAwakeMode/untilTurnedOff``), and none otherwise, so running jobs and the manual
/// timer never fight: a job starting inside a manual hour rides the same assertion, and
/// the hour ending while the job runs leaves it in place. The assertion keeps the name it
/// was created with — ``runningJobsReason`` or ``manualReason`` — for as long as it
/// lives, since renaming it would mean a moment with two assertions or with none.
///
/// Time comes in two injected forms, both defaulting to the real thing: `now` answers
/// what time it is (``manualUntil`` is a wall-clock `Date`, and the remaining time is
/// measured against it), and `clock` only *waits* for a timed choice to end. The
/// controller ends it itself, so nothing outside can forget to; ``refresh()`` lets a
/// caller that knows time jumped (a wake from sleep) look again sooner.
///
/// If the OS refuses a hold, the controller logs it, reports ``isHoldingAssertion`` as
/// `false`, and tries again on the next change or ``refresh()``.
@MainActor
@Observable
public final class KeepAwakeController {
    /// The assertion name while jobs run, as `pmset -g assertions` shows it.
    public static let runningJobsReason = "AgentCron: running jobs"

    /// The assertion name while only a manual choice keeps the Mac awake.
    public static let manualReason = "AgentCron: kept awake by you"

    /// How many jobs are running, as last reported by ``runningJobCountChanged(to:)``.
    public private(set) var runningJobCount = 0

    /// The manual choice in force. A timed choice returns to ``KeepAwakeMode/off`` when it
    /// ends.
    public private(set) var manualMode = KeepAwakeMode.off

    /// When the timed manual choice ends, or `nil` when there is none — including for
    /// ``KeepAwakeMode/untilTurnedOff``, which has no end.
    public private(set) var manualUntil: Date?

    /// Whether the one assertion is held right now.
    public var isHoldingAssertion: Bool {
        token != nil
    }

    /// How long the timed manual choice has left, never below zero, or `nil` when no
    /// timed choice is in force.
    ///
    /// Read from `now` at the moment of asking; observation does not tick with the
    /// clock, so a view showing a countdown re-reads it on its own schedule.
    public var remainingManualTime: Duration? {
        guard let manualUntil else {
            return nil
        }
        return .seconds(max(manualUntil.timeIntervalSince(now()), 0))
    }

    private var token: SleepPreventionToken?
    @ObservationIgnored private var manualTimer: Task<Void, Never>?

    private let preventer: any SleepPreventing
    private let clock: any Clock<Duration>
    private let now: @Sendable () -> Date

    private var wantsHold: Bool {
        if runningJobCount > 0 || manualMode == .untilTurnedOff {
            return true
        }
        guard let manualUntil else {
            return false
        }
        return manualUntil > now()
    }

    /// Creates a controller over `preventer` that reads the real time and waits on a
    /// `ContinuousClock` — which keeps counting while the Mac sleeps, so an hour chosen
    /// before a sleep is over after the hour, not after an hour of being awake.
    ///
    /// Holds nothing until told something: construction has no side effect.
    public convenience init(preventer: any SleepPreventing) {
        self.init(preventer: preventer, clock: ContinuousClock()) { Date.now }
    }

    /// Creates a controller over `preventer`, reading "now" from `now` and waiting on
    /// `clock`. Tests pass a manually advanced clock and a `now` derived from it.
    public init(
        preventer: any SleepPreventing,
        clock: any Clock<Duration>,
        now: @escaping @Sendable () -> Date,
    ) {
        self.preventer = preventer
        self.clock = clock
        self.now = now
    }

    /// The app saw the number of running jobs change. A negative count is a caller's
    /// mistake; it is logged and treated as none.
    public func runningJobCountChanged(to count: Int) {
        if count < 0 {
            AppLog.keepAwake
                .error("negative running job count \(count, privacy: .public); treated as 0")
        }
        runningJobCount = max(count, 0)
        updateHold()
    }

    /// The user chose a manual keep-awake mode. A timed choice runs from now, even when
    /// the same one was already in force; ``KeepAwakeMode/off`` ends the manual hold.
    public func chooseManualMode(_ mode: KeepAwakeMode) {
        manualMode = mode
        manualUntil = mode.duration.map { now().addingTimeInterval($0 / .seconds(1)) }
        startManualTimer()
        updateHold()
    }

    /// Looks at the time again: ends a timed manual choice that has run out, and retries
    /// a hold the OS refused.
    public func refresh() {
        if let manualUntil, manualUntil <= now() {
            manualMode = .off
            self.manualUntil = nil
            manualTimer?.cancel()
            manualTimer = nil
        }
        updateHold()
    }

    /// Returns once the timer for the current timed choice has ended it or been
    /// cancelled; returns at once when there is none. For tests: the timer only fires
    /// once `clock` reaches ``manualUntil``, so a caller advances the clock first.
    package func waitForManualTimer() async {
        await manualTimer?.value
    }

    private func startManualTimer() {
        manualTimer?.cancel()
        guard let until = manualUntil else {
            manualTimer = nil
            return
        }
        manualTimer = Task { [weak self, clock, now] in
            // Re-read `now` after every wake: the wall clock can move differently from
            // `clock` (a manual time change), and only `now` decides when the choice ends.
            var remaining = until.timeIntervalSince(now())
            while remaining > 0 {
                do {
                    try await clock.sleep(for: .seconds(remaining))
                } catch {
                    // A Clock throws only CancellationError: a newer choice replaced this
                    // timer, and the newer one decides what happens next.
                    return
                }
                remaining = until.timeIntervalSince(now())
            }
            self?.refresh()
        }
    }

    private func updateHold() {
        switch (wantsHold, token) {
        case (true, nil):
            let reason = runningJobCount > 0 ? Self.runningJobsReason : Self.manualReason
            do {
                token = try preventer.hold(reason: reason)
                AppLog.keepAwake.info("held idle sleep: \(reason, privacy: .public)")
            } catch {
                switch error {
                case let .systemFailure(code):
                    AppLog.keepAwake
                        .error("could not hold idle sleep: IOReturn \(code, privacy: .public)")
                }
            }

        case let (false, held?):
            preventer.release(held)
            token = nil
            AppLog.keepAwake.info("released idle sleep")

        case (true, _?), (false, nil):
            break
        }
    }
}
