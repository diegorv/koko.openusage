VERDICT: APPROVED

## Acceptance criteria

- [met] Codex accounts match when the ChatGPT account ids agree and, if both sides have an email, the emails agree too (case-insensitive). With an email on only one side, the account id alone decides. — `Sources/OpenUsage/Providers/CLIProxyHub/CLIProxyHubLocalMatch.swift:75-80`: with both ids known, `guard localID == hubID else { return false }`, then `guard let localEmail = normalized(local.email), let hubEmail = normalized(hub.email) else { return true }` and `return localEmail == hubEmail`. `normalized` trims and lowercases, so the comparison ignores case, and a missing (or blank) email on either side leaves the id to decide.
- [met] The email fallback when no account id is available is unchanged. — The two fallback lines after the `if` block (`guard let localEmail = normalized(local.email) else { return false }` / `return localEmail == normalized(hub.email)`) are untouched in `git diff main...HEAD`. The existing test case "The hub doesn't know the id: email decides" (`b.json`, hidden `codex-b`) still passes.
- [met] Tests cover: same id and same email (hidden), same id and different email (both shown), same id and email missing on one side (hidden). — `Tests/OpenUsageTests/CLIProxyHubLocalMatchTests.swift:45-46` covers same id with the same email, differing only in case (`codex-a` hidden). `:56-75` (`testCodexTeamSeatsWithTheSameAccountIDMatchOnlyWithTheSameEmail`) covers same id with a different email (`codex-other-seat` not hidden), and email missing on the local side (`codex-no-email` hidden) and on the hub side (`codex-hub-no-email` hidden). Against the old id-only code, `codex-other-seat` would have been hidden, so this test catches the bug. `swift test --filter CLIProxyHubLocalMatchTests`: 8 tests, 0 failures, exit 0 (run by this review).
- [met] `docs/provider-enablement.md` explains the seat rule. — `docs/provider-enablement.md:32` adds the "Codex Team seats" bullet: same id, matching emails required when both sides have one, case ignored, and the id alone decides when only one side has an email. `docs/providers/cliproxy-hub.md:55-56` gets the same rule in short form.

## Checks run by this review

- Typecheck: `swift build`, exit 0, no errors.
- Tests: `swift test --filter CLIProxyHubLocalMatchTests`, exit 0, 8 tests, 0 failures. My test verdict rests on this file only: it is the test file of the one source file the branch changes (`CLIProxyHubLocalMatch.swift`), and it is the only test file the branch changes. No other test calls `CLIProxyHubCards.matches` / `hiddenLocalCardIDs` (grep over `Sources` and `Tests`). The full suite is deliver's to run.
- Worktree clean, 3 commits on top of main (`d2fdad4e`, `b3124cd2`, `5cd93296`).
- Scope: the diff touches only the match function and its doc comment, its test file, the two docs, and the workflow's own `work/08/discovery.md`. No scope creep.
- The local plain `codex` card carries `codexDefaultEmail` and the account cards carry `card.identity.email` (`CLIProxyHubLocalMatch.swift:33-44`), so the email side of the rule applies to both kinds of local card. No change to the assembly was needed.

## Findings

1. nit — `docs/provider-enablement.md:31`: the "Codex" bullet still opens with "Codex accounts are the same when their ChatGPT account id matches." Read alone, that is now incomplete, and only the next bullet adds the email condition. Fix (optional): fold the rule into line 31, e.g. "…when their ChatGPT account id matches and, when both sides have an email, the email matches too", or add "(but see Team seats below)".

## Resolution

1. Fixed: `docs/provider-enablement.md:31` now points to the Team seats rule ("Team seats also need a matching email, see below").
