/// One hold on idle sleep, as a value Core can store and hand back.
///
/// Opaque on purpose: Core never reads `id`, it only returns the token to the
/// ``SleepPreventing`` that issued it. The adapter packs the OS's assertion identifier
/// into it, and a fake packs a counter, so the port never names an IOKit type.
public struct SleepPreventionToken: Hashable, Sendable {
    /// The issuer's own identifier for this hold. Meaningful only to that issuer.
    public let id: UInt64

    /// Creates a token. Only an implementation of ``SleepPreventing`` makes one; the
    /// initializer is public because that implementation lives in another module.
    public init(id: UInt64) {
        self.id = id
    }
}

/// Why idle sleep could not be held off — the OS refused the assertion.
///
/// An enum rather than a message so a caller can switch over it; the payload is the
/// OS status code (an `IOReturn`), which is safe to log and carries no user data.
public enum SleepPreventionError: Error, Equatable, Sendable {
    /// The OS reported a failure the app has no recovery for; `code` is for logs.
    case systemFailure(code: Int32)
}

/// A port: "keep this Mac out of idle sleep until I say otherwise", asked in Core's own
/// vocabulary (ADR-0006).
///
/// Core declares it, `AgentCronPlatform`'s `PowerAssertionSleepPreventer` answers it with
/// an IOKit power assertion, tests substitute `FakeSleepPreventer`, and `App/` — the
/// composition root — decides which one ``KeepAwakeController`` gets. The port only
/// creates and ends holds; *when* to hold is ``KeepAwakeController``'s decision, where
/// the coverage floor sees it.
///
/// It is `Sendable` and takes and returns value types, so an implementation can be
/// handed across actors and Core never reasons about the OS object behind a hold.
///
/// The promises every implementation keeps — `SleepPreventingContract` in
/// `AgentCronTestSupport` checks them against the fake (`just test`) and the real adapter
/// (`just test-local`); a new clause is stated here first, then added there:
///
/// 1. A successful ``hold(reason:)`` is in force from the moment it returns until its
///    token is passed to ``release(_:)``.
/// 2. Holds are independent: every token is distinct from every other outstanding one,
///    and releasing one leaves the others in force.
/// 3. ``release(_:)`` with a token that was already released, or that this
///    implementation never issued, does nothing.
/// 4. A ``hold(reason:)`` that throws holds nothing.
///
/// Holding off idle sleep does not hold off every sleep: closing the lid, choosing Sleep,
/// or a low battery still sleeps the Mac (requirements §3.6).
public protocol SleepPreventing: Sendable {
    /// Starts a hold on idle system sleep and answers the token that ends it.
    ///
    /// `reason` names the hold where a person can see it — `pmset -g assertions` lists
    /// it — so it is app-chosen wording, never user content.
    func hold(reason: String) throws(SleepPreventionError) -> SleepPreventionToken

    /// Ends the hold `token` stands for. A token that is stale or foreign is ignored.
    func release(_ token: SleepPreventionToken)
}
