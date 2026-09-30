# ADR-0008: Ship English and Japanese

- **Status:** Accepted 2026-09-29
- **Date:** 2026-09-29
- **Deciders:** the owner

## Context

The template ships English only (`defaultLocalization` `en`, `Localizable.xcstrings` in
Core) and asks for an ADR for any language beyond English. The owner works in Japanese;
the repository is public and written in English.

## Decision drivers

- The owner's daily use; English stays the development language (`AGENTS.md` ›
  Important Reminders).

## Considered options

1. **English + Japanese, following the system language.**
2. **English only.**
3. **Japanese only** — conflicts with the template's English development language.

## Decision

Option 1. English stays `defaultLocalization`; every user-visible string gets a `ja`
translation in `Localizable.xcstrings` (`localizing-the-app`). No in-app language
switch. Japanese copy uses です/ます; the glossary in `docs/design/ux-guidelines.md` ›
Language and copy is translated once and reused.

## Consequences

### Positive

- The owner uses the app in Japanese; contributors read English.

### Negative

- Every string change needs both languages; `LocalizationTests` only checks English.

### Follow-ups

- Add `ja` to the String Catalog and the project's known regions (issue).

## Open questions

- None.

## Sources

- `.agents/skills/localizing-the-app/SKILL.md` (in-repo).

## Related

- None.
