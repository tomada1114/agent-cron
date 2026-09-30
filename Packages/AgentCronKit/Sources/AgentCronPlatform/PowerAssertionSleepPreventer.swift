import AgentCronCore
import IOKit.pwr_mgt
import os

/// The IOKit-backed adapter for ``AgentCronCore/SleepPreventing`` (ADR-0006): each hold is
/// one `kIOPMAssertionTypePreventUserIdleSystemSleep` power assertion — what
/// `caffeinate -i` takes, and like it, one that needs no admin rights.
///
/// Translation only: it creates and releases assertions and maps a failing `IOReturn`
/// into ``AgentCronCore/SleepPreventionError``. When to hold is
/// ``AgentCronCore/KeepAwakeController``'s decision, which is why this file sits outside
/// the coverage floor. What is checked here instead is the translation, by the
/// local-machine test `PowerAssertionSleepPreventerTests` against `pmset -g assertions`:
/// opt-in, human-run (`just test-local`), and reported as skipped under `just test` and
/// in CI.
///
/// It remembers the assertions it created, so a stale or foreign token is ignored rather
/// than passed to IOKit — which could otherwise end an assertion that reused the number
/// (the port's clause 3). Any still held when the preventer goes away are released then,
/// and IOKit releases the rest if the process exits.
public final class PowerAssertionSleepPreventer: SleepPreventing {
    private let held = OSAllocatedUnfairLock<Set<IOPMAssertionID>>(initialState: [])

    public init() {
        // Nothing to set up: an assertion is created on the first hold.
    }

    /// Creates a named idle-sleep assertion; `pmset -g assertions` lists it under
    /// `reason` until ``release(_:)``.
    public func hold(reason: String) throws(SleepPreventionError) -> SleepPreventionToken {
        var id = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &id,
        )
        guard result == kIOReturnSuccess else {
            throw .systemFailure(code: result)
        }
        let created = id
        held.withLock { _ = $0.insert(created) }
        return SleepPreventionToken(id: UInt64(created))
    }

    /// Releases the assertion `token` stands for, if this preventer created it and has
    /// not released it yet; anything else is ignored.
    public func release(_ token: SleepPreventionToken) {
        guard let id = IOPMAssertionID(exactly: token.id),
              held.withLock({ $0.remove(id) != nil })
        else {
            return
        }
        let result = IOPMAssertionRelease(id)
        if result != kIOReturnSuccess {
            AppLog.keepAwake
                .error("IOPMAssertionRelease failed: IOReturn \(result, privacy: .public)")
        }
    }

    deinit {
        for id in held.withLock({ $0 }) {
            IOPMAssertionRelease(id)
        }
    }
}
