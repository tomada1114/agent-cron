---
name: designing-errors
description: >
  Covers how errors are designed in this Swift 6 repository: error enums declared in
  AgentCronCore, typed throws(SomeError) versus plain throws, what an error payload and an
  AppLog (os.Logger) message may carry, propagating CancellationError instead of
  swallowing it, and how a AgentCronPlatform adapter maps OSStatus, NSError, or AXError into
  a Core error. Use when adding or changing an Error type, a throwing function or port,
  a do/catch, a Task that can be cancelled, or an adapter that calls a failing OS API.
---

# Designing Errors

**Owns:** the shape of an error type, the choice between typed and untyped `throws`,
what an error and its log line may contain, cancellation, and the OS-to-Core error
mapping at the adapter boundary. **Does not own:** writing the failing test first
(`tdd`); the C-callback, refcon, and TCC mechanics of calling a system API
(`integrating-system-apis`); the `os.Logger` basics (`.claude/rules/swift.md` ›
Logging); the error-path test rule (`.claude/rules/testing.md` › What to Test).

## Where an error type lives

- Declare every error a caller can observe in `AgentCronCore`, next to the port or model
  that throws it — `KeepAwake/SleepPreventing.swift` holds `SleepPreventionError`.
  `AgentCronUI` and `App/` switch on it, and a Core test's fake throws it, so it cannot
  live in `AgentCronPlatform` (Core never imports Platform).
- One `enum` per failure domain, `Error, Equatable, Sendable`. Cases name what went
  wrong for the caller (`.permissionDenied`, `.notRunning`), not which API failed.
- Payloads carry only what a caller needs to decide, and are `Sendable` values:
  `Int32` codes, small enums, durations. Never an `NSError`, a `CFTypeRef`, or an
  underlying `any Error` — those are not `Equatable`, often not `Sendable`, and leak
  the adapter's mechanism into Core.

```swift
/// Why idle sleep could not be held off — the OS refused the assertion.
///
/// An enum rather than a message so a caller can switch over it; the payload is the
/// OS status code (an `IOReturn`), which is safe to log and carries no user data.
public enum SleepPreventionError: Error, Equatable, Sendable {
    /// The OS reported a failure the app has no recovery for; `code` is for logs.
    case systemFailure(code: Int32)
}
```

A domain with a recovery per case grows cases, not strings: a port behind a TCC grant
would add `.permissionDenied`, for which the UI offers to open System Settings.

## Typed throws or plain throws

Typed throws (`throws(SleepPreventionError)`, SE-0413) needs Swift 6; this package is
`swift-tools-version: 6.2` in Swift 6 language mode, so it is available everywhere.

- **Use `throws(E)`** when the caller switches over `E`'s cases: a port method, a
  view-model action whose UI shows per-case recovery. The `catch` then binds `error`
  as `E`, the `switch` is exhaustive, and adding a case breaks every caller that must
  handle it — which is the point.
- **Use plain `throws`** when the caller only propagates or reports failure, or when
  the body calls several throwing APIs of unrelated types. Forcing a typed throw there
  means wrapping every inner error for no decision anyone makes.
- Never `throws(any Error)` (it is plain `throws`) and never a catch-all case such as
  `.unknown(any Error)` to make a typed throw compile — map to a real case instead.

```swift
public protocol SleepPreventing: Sendable {
    func hold(reason: String) throws(SleepPreventionError) -> SleepPreventionToken
    func release(_ token: SleepPreventionToken)
}

// In KeepAwakeController: the switch is exhaustive over SleepPreventionError.
do {
    token = try preventer.hold(reason: reason)
} catch {
    switch error {
    case let .systemFailure(code):
        AppLog.keepAwake.error("could not hold idle sleep: IOReturn \(code, privacy: .public)")
    }
}
```

An expected outcome stays a plain return: releasing a stale or foreign token does
nothing rather than throwing. An error is for "could not do it"; do not turn an
expected absence into a throw.

## No user data in errors or logs

- An error payload never holds user content: no app names, window titles, file paths,
  typed text, URLs, or identifiers of the user's documents. Errors travel — into logs,
  crash reports, test output, and `String(describing:)` in a view.
- Log lines follow `.claude/rules/swift.md` › Logging: `AppLog`'s `os.Logger` only.
  Interpolate an OS status code or an enum case with `privacy: .public`; anything that
  came from the user or another app with `privacy: .private` — or leave it out.
  `os.Logger` redacts dynamic strings by default; do not mark one `.public` to make a
  log easier to read.
- Log once, where the error is handled, not at every layer it passes through.

## Cancellation propagates

`CancellationError` means the caller no longer wants the result. It is not a failure
to report.

- Do not catch it into a Core error case, a log line, or an error state. A plain
  `catch` in an `async throws` function must rethrow it:

```swift
do {
    try await Task.sleep(for: .seconds(1))
    try await refresh()
} catch let error as CancellationError {
    throw error  // cancellation is not a failure: never log or map it
} catch {
    AppLog.keepAwake.error("refresh failed")
}
```

- A long loop calls `try Task.checkCancellation()` rather than polling
  `Task.isCancelled` and returning a half result silently.
- Typed throws and cancellation: a function that awaits cancellable work and declares
  `throws(E)` cannot throw `CancellationError`. Keep such functions on plain `throws`,
  or give `E` an explicit `.cancelled` case the caller treats as a no-op — never drop
  the cancellation on the floor.
- A test asserts cancellation with `#expect(throws: CancellationError.self)`.

## Mapping OS errors in an adapter

The adapter translates, never decides (`AGENTS.md` › Architecture). Mapping an OS
error to a Core case is translation; choosing what the app does about it is Core's.

- Convert at the call site, inside `AgentCronPlatform`, into the Core enum the port
  declares. Nothing OS-typed crosses the port.
- `AXError`: switch the known cases (`.apiDisabled`, `.notImplemented`, …) into Core
  cases; everything else becomes `.systemFailure(code: result.rawValue)`.
- `OSStatus` (an `Int32`): compare against the named constants you handle; pass any
  other status through as `.systemFailure(code: status)` — never `noErr` as an error.
- `NSError` / a thrown Foundation error: match on `domain` and `code` (for example
  `NSCocoaErrorDomain` with `NSFileReadNoPermissionError`); carry only the `Int32`
  code, never `localizedDescription` or `userInfo`, which can hold paths and names.
- Log the raw code in the adapter only if Core cannot, and with `privacy: .public`.

```swift
import AgentCronCore
import IOKit.pwr_mgt

// PowerAssertionSleepPreventer.hold(reason:) — translation only: a failing IOReturn
// becomes the Core case, carrying just the code.
let result = IOPMAssertionCreateWithName(
    kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
    IOPMAssertionLevel(kIOPMAssertionLevelOn),
    reason as CFString,
    &id,
)
guard result == kIOReturnSuccess else {
    throw .systemFailure(code: result)
}
```

A test in `Tests/AgentCronPlatformTests` checks this mapping against the real OS under
`.requiresLocalMachine`; a Core test checks the decision with a fake that throws each
Core case.

## Checklist

- The error enum is in `AgentCronCore`, `Error, Equatable, Sendable`, with value payloads.
- `throws(E)` only where a caller switches on `E`; plain `throws` otherwise.
- No user content in a payload; logs use `AppLog` with explicit privacy.
- `CancellationError` is rethrown, never logged or mapped to a failure.
- The adapter maps every OS error to a Core case; nothing OS-typed crosses the port.
- Each case has an error-path test asserting the case and payload.
