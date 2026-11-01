# 08 Discovery: Codex Hub Match Counts Team Seats Separately

No `spec.md`. Repeats `work/06` (hub wins over the same local account); only the Codex match rule changes.

## Files

- `Sources/OpenUsage/Providers/CLIProxyHub/CLIProxyHubLocalMatch.swift:69-79`: `matches(_:_:)`. When both
  ChatGPT account ids are known: ids equal AND (either email missing OR emails equal, trimmed,
  case-insensitive). No id on either side: email fallback unchanged. Doc comment updated.
- `Tests/OpenUsageTests/CLIProxyHubLocalMatchTests.swift:38-54`: the existing case "same id, different
  email: still the same account" now contradicts the owner rule; it becomes "both shown". Add cases:
  same id + same email (hidden), same id + email missing on one side (hidden, both directions).
- `docs/provider-enablement.md:31`, `docs/providers/cliproxy-hub.md:54-55`: explain the seat rule.

## Plan

1. Write the new test (red), 2. change `matches`, 3. update docs.

## Defaults taken

- An empty or whitespace email counts as missing (same `normalized` helper as today).
- The local plain `codex` card's email is the token email (`codexDefaultEmail`); account cards use
  `card.identity.email`. No assembly change needed.

## Risks

- A seat whose hub email differs only by a renamed address now shows twice; owner rule accepts that.
