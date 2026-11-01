VERDICT: APPROVED

## Previous findings

| # | Severity | Status | Evidence |
|---|----------|--------|----------|
| 1 | minor | rejection stands | `CLIProxyHubCards.matches` (CLIProxyHubLocalMatch.swift:71-79) still matches Codex by account id alone when both sides know it. That is the Issue's literal rule ("Codex accounts match by ChatGPT account id, falling back to email"). Matching on id and email would change which cards users see, so it needs the owner's call. It stays an open owner question for deliver to report. |
| 2 | minor | resolved | docs/provider-enablement.md:30 now says a Claude email match hides every local card with that email, in every organization. That matches the code: `localAccounts` gives every Claude account card its email, and `hiddenLocalCardIDs` hides every card that matches. |
| 3 | minor | resolved | docs/provider-enablement.md:33 names the controls (remove the hub from `cliproxy.json`, set `enabled` to `false`, remove or disable the account on the hub) and warns that the Customize toggle does not bring the card back. I checked this against the code. Both call sites (AppContainer.swift:91, UsageReader.swift:66) pass every hub runtime, and no enablement filter runs first, so the Customize warning is accurate. Disabled hub accounts are dropped at listing (CLIProxyHubClient.swift:91). The behaviour itself is unchanged, which is acceptable for a minor. |
| 4 | minor | resolved | `testAssemblyNamesTheClaudeAccountCardsAccounts` (CLIProxyHubLocalMatchTests.swift:112) runs `ProviderAccountAssembly.make` against a Swap fixture. It asserts that there are 2 Claude local accounts, that the Swap card has its lowercased slot email, and that the default org card gets `dev@example.com` from `.claude.json` through the account-UUID join. If the join broke, the org card's email would be nil and the test would fail, so the test does guard the new logic. It passes. |
| 5 | nit | rejection stands | The fix report says no change was needed and passes the layout heads-up to deliver. I agree. |
| 6 | nit | rejection stands | This was an optional nit, and the wiring is still a single argument at each call site. |

## Acceptance criteria re-checked

- [met] `docs/provider-enablement.md` explains the rule. — The section "When a hub holds the same account" (docs/provider-enablement.md:26-33) states the Claude and Codex match rules. It now also says that every organization is hidden on a Claude email match, and it names the exact controls that bring the card back. Each statement agrees with CLIProxyHubLocalMatch.swift and the two launch call sites.
- [met] Tests cover a match, no match, and a disabled hub. — CLIProxyHubLocalMatchTests has match, no-match and disabled-hub cases, plus the new account-card test. `swift test --filter CLIProxyHubLocalMatchTests` exited 0 with 7 tests and 0 failures. No existing test was removed or weakened: the diff since review.md only adds lines to the test file. The full suite is deliver's to run.

## Checks

- `swift build`: exit 0, no warnings.
- `swift test --filter CLIProxyHubLocalMatchTests`: exit 0, 7 tests, 0 failures.
- The fix commit af2eeab2 touches only the test file, docs/provider-enablement.md and the workflow's own review.md. It changes no source code and has no scope creep.
- I did not run the full suite. Deliver runs it.

## Findings

1. minor — Sources/OpenUsage/Providers/CLIProxyHub/CLIProxyHubLocalMatch.swift:73-75 — This is carried over from round 1, finding 1, and is still an owner decision. Codex matching by id alone hides the local card of a different seat in the same ChatGPT Team workspace. Fix: deliver reports the question to the owner. If the owner wants seats counted separately, require the emails to match as well when both sides have one.
