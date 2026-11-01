VERDICT: APPROVED

## Previous findings

| # | Severity | Status | Evidence |
|---|----------|--------|----------|
| 1 | minor | resolved | `CLIProxyHubConfigStore.saveAccounts` (`CLIProxyHubConfigStore.swift:64-71`) now matches `$0.enabled && $0.id.lowercased() == id`. That is the same rule the cards use (`CLIProxyHubCards.swift:42-43`: `filter(\.enabled)`, then a lowercased dedupe) and the same rule the sync uses (`CLIProxyHubAccountSync.swift:22`). `testRepeatedHubIDWritesToTheEnabledEntryThatWasRead` seeds a disabled `one` and then an enabled `one`. It asserts that only `on.example` is requested and that the result is `[[oldAccount], [newAccount]]`. I traced the old code: `firstIndex(where: { $0.id == hubID })` returned index 0, so the test would have produced `[[newAccount], []]` and failed. It passes now. |
| 2 | minor | resolved | `docs/providers/cliproxy-hub.md:32-33` now says that a save rewrites the whole file, drops unknown keys, writes a left-out `enabled` as `true` and normalizes the formatting. The incorrect "the rest of the file stays as it was" line is gone. Keeping unknown keys is left as an owner decision, which the review allowed as a fix. |
| 3 | nit | resolved | The comment at `CLIProxyHubAccountSync.swift:23` is accurate: `CLIProxyHubCards.swift:48` logs an invalid URL at error level. |
| 4 | nit | resolved | `CLIProxyHubAccountSync.swift:16-17` now uses `AppLog.warn` and has a comment. The cards still log the same failure at error level (`CLIProxyHubCards.swift:27`), so the failure is still logged loudly. |

## Acceptance criteria re-checked

- [met] After launch, an `auth-files` call per enabled hub runs off the launch path and writes the cached `accounts` back to the config. The rest of the config, including the key, stays as it was. — The fix changes only which entry gets the write: now the enabled entry that was read. `testWriteKeepsTheKeyAndEveryOtherField` and `testSuccessfulSyncReplacesTheCacheAndDropsAccountsDisabledOnTheHub` still pass. The new test shows that the disabled duplicate's cache is left as it was. Unknown keys are dropped, and that is now documented.
- [met] A failed sync keeps the old cache and is logged loudly ("The hub could not list accounts."). Cards keep working. — The error line at `CLIProxyHubAccountSync.swift:32` is unchanged, and `testFailedSyncKeepsTheOldCacheAndLogsLoudly` passes. Only the separate unreadable-config line was lowered to warn, and the cards still log that one as an error.
- [met] Disabled hubs are skipped. Accounts disabled on the hub drop out of the cache. — The sync's `where hub.enabled` is unchanged. `saveAccounts` now also refuses to write a disabled entry. `testDisabledHubsAreSkipped` and the new duplicate test pass.
- [met] Tests cover a successful sync, a failure keeping the cache, and a write that preserves the other fields. — All of them are still in `CLIProxyHubAccountSyncTests.swift`, along with the new regression test. No test was weakened or deleted: the test diff only adds lines.
- [not met] Smoke test: empty the cache, relaunch twice, and see the cards appear on the second launch. — Still not run. It needs the owner's real hub and a manual relaunch, so only the owner or an e2e run can check it. As in round 1, this does not hold back APPROVED.

## Checks run

- Typecheck: `swift build`, exit 0.
- `swift test --filter "CLIProxy"`, exit 0: 46 tests, 0 failures. This covers `CLIProxyHubAccountSyncTests` (now 7), `CLIProxyHubConfigStoreTests` (`saveAccounts`), `CLIProxyHubClientTests` and `CLIProxyClaudeRuntimeTests`. The full suite is deliver's to run.
- I searched the tests for the changed warning text ("no longer configured"). No test asserts it.
- Scope: the fix commit touches only the sync, the config store, the sync tests, the provider doc and review.md. There is no scope creep.

## Findings

1. nit — `Tests/OpenUsageTests/CLIProxyHubAccountSyncTests.swift:99`: the new regression test uses the same lowercase id for both entries, so the case-insensitive part of the `saveAccounts` match (`CLIProxyHubConfigStore.swift:66`) has no test. Fix (optional): add a case such as an enabled `One` synced under hub id `one`, or a mixed-case duplicate.
