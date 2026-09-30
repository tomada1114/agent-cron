# ADR-0011: Distribution — local builds first, Developer ID later

- **Status:** Proposed
- **Date:** 2026-09-29
- **Deciders:** the owner

## Context

The owner is the only user for now. The app cannot be on the Mac App Store (ADR-0002).
The template ships `docs/distribution.md` and a release workflow for Developer ID
signing and notarization.

## Decision drivers

- Nothing blocks the owner's own use.
- No signing secrets until someone else installs the app.

## Considered options

1. **Local builds now** (`just run` / a local Release build), **Developer ID + notarized
   DMG** through the template's release workflow when a second person installs it.
2. **Developer ID from the first release.**
3. **Mac App Store** — impossible without the sandbox.

## Decision

Option 1, proposed. No release tag, no signing secrets, no updater in MVP. The app icon
stays a placeholder until then (ADR-0009).

## Consequences

### Positive

- No secrets or Apple Developer account work before the app has proven itself.

### Negative

- Launch at login registers whichever build is installed; moving the app later means
  re-registering (General shows the status).

### Follow-ups

- None for MVP; a Later roadmap line.

## Open questions

- None.

## Sources

- `docs/distribution.md` (in-repo).

## Related

- [ADR-0002](0002-app-sandbox-off.md) — rules out the Mac App Store.
