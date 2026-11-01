VERDICT: APPROVED

## Acceptance criteria

- [met] After launch, an `auth-files` call per enabled hub runs off the launch path and writes the cached `accounts` back to the config. The rest of the config, including the key, stays as it was. — `AppContainer.swift:77` starts `CLIProxyHubAccountSync.run()` in an unstructured, stored `Task` after `loadClaudeRuntimes()`, and `init` never awaits it. `run` is a nonisolated async function, and its file load/save go through `loadOffMainActor` (`CLIProxyHubAccountSync.swift:14,27`). `testSuccessfulSyncReplacesTheCacheAndDropsAccountsDisabledOnTheHub` asserts exactly one `GET .../v0/management/auth-files` and the rewritten cache. `testWriteKeepsTheKeyAndEveryOtherField` compares the whole reloaded config: key, label, url, enabled and the second hub are unchanged. Caveat: unknown keys are dropped on a write (finding 2).
- [met] A failed sync keeps the old cache and is logged loudly ("The hub could not list accounts."). Cards keep working. — `CLIProxyHubAccountSync.swift:29` logs at `AppLog.error` with that exact copy, the hub id and the friendly `CLIProxyHubError` text, and never the key. `testFailedSyncKeepsTheOldCacheAndLogsLoudly` asserts the file is byte-identical, the message is in the log and `key-one` is not. `testOneHubFailingStillSyncsTheNext` covers a transport failure. Cards still work: they are built from the cache before the sync starts, with their own session, and the sync never touches them.
- [met] Disabled hubs are skipped. Accounts disabled on the hub drop out of the cache. — The `where hub.enabled` filter is at `CLIProxyHubAccountSync.swift:21`. `testDisabledHubsAreSkipped` asserts no request and an unchanged cache. `listAccounts()` drops `disabled: true` entries (`CLIProxyHubClient.swift`), and the success test's fixture has the cached `claude-old.json` disabled on the hub, so it drops out.
- [met] Tests cover a successful sync, a failure keeping the cache, and a write that preserves the other fields. — `Tests/OpenUsageTests/CLIProxyHubAccountSyncTests.swift` has all three, plus hub-failure isolation, a disabled hub and an unchanged list. I ran it myself: 6/6 pass.
- [not met] Smoke test: empty the cache, relaunch twice, and see the cards appear on the second launch. — Not run. The builder did not run it, and the review cannot: it needs the owner's real hub and a manual relaunch of the app. Only the owner or the e2e can check it, so it does not hold back APPROVED. The code path is consistent with the test: the first launch reads an empty cache and the sync writes it; the second launch's `loadClaudeRuntimes()` reads the written list.

## Checks run by the review

- Typecheck: `swift build`, exit 0.
- `swift test --filter "CLIProxy"`, exit 0, 45 tests, 0 failures. This covers `CLIProxyHubAccountSyncTests` (6, the file the diff adds), `CLIProxyHubConfigStoreTests` (5, for `saveAccounts`, which the sync calls), `CLIProxyHubClientTests` (19, for `listAccounts`) and `CLIProxyClaudeRuntimeTests` (15, cards). My test verdict rests on these four files. No test file covers `AppContainer.swift`; I reviewed its one-line wiring by reading. The full suite is deliver's to run.
- Probe (temporary test file, deleted afterwards and not committed): a config with two hubs that share id `one`, the first disabled and the second enabled. Result: `requests=["on.example"] disabled.accounts=1 enabled.accounts=0 cards=0`. The sync fetches from the enabled entry but writes the list into the disabled one (finding 1).
- Scope: the diff touches the sync, its test, the `AppContainer` wiring, `docs/providers/cliproxy-hub.md` and the workflow's own `work/03/discovery.md`. There is no scope creep. The docs update satisfies the AGENTS.md rule for logic changes.

## Findings

1. minor — `Sources/OpenUsage/Providers/CLIProxyHub/CLIProxyHubAccountSync.swift:19-27`: the comment says "A repeated hub id keeps its first entry, as the cards do; `saveAccounts` writes that one". The code does not hold to that.
   - The cards filter `enabled` first and then dedupe, and the sync does the same, so both use the first *enabled* entry. `saveAccounts` writes to `firstIndex(where: { $0.id == hubID })`, the first entry of any state.
   - With a hand-edited `[{id: one, enabled: false}, {id: one, enabled: true}]`, the list fetched from the enabled hub lands in the disabled entry. The enabled hub's cards never appear, and the file is rewritten on every launch, because the compared `hub.accounts` never changes. The probe above confirms this.
   - Fix: make the write target the entry the sync read. One way is to pass the hub's index from `hubs.enumerated()`. Another is to have `saveAccounts` match the first enabled entry the way the cards do (case-insensitive id). Add a regression test for disabled-then-enabled duplicates.
2. minor — `Sources/OpenUsage/Providers/CLIProxyHub/CLIProxyHubAccountSync.swift:27`, by way of `CLIProxyHubConfigStore.save`: the write re-encodes the whole file through `Codable`.
   - Keys the app doesn't know about are dropped, a missing `enabled` is written out as `true`, and the formatting is normalized. The builder recorded this as a risk.
   - It is now triggered automatically whenever a hub's list changes, with no user action, so the "rest of the config stays as it was" promise holds only for known fields.
   - Fix: either document in `docs/providers/cliproxy-hub.md` that OpenUsage rewrites the file and keeps only known fields, or ask the owner whether the write should preserve unknown keys (for example by patching the JSON object instead of re-encoding the model). Known fields, including the key, are verified preserved.
3. nit — `Sources/OpenUsage/Providers/CLIProxyHub/CLIProxyHubAccountSync.swift:22`: a hub with an invalid URL is skipped silently (`continue`).
   - The cards already log this at error level on every launch, so it is not hidden.
   - Fix: none needed. A one-line comment saying the cards log it would explain the silent skip.
4. nit — `Sources/OpenUsage/Providers/CLIProxyHub/CLIProxyHubAccountSync.swift:16`: an unreadable config is logged twice per launch, once by `CLIProxyHubCards.loadClaudeRuntimes` and once by the sync.
   - The messages differ ("no hub cards this launch" vs. "hub accounts not synced"), so this is harmless.
   - Fix: none needed. Optionally lower the sync's copy to `warn`, since the cards already raised the error.

## Resolution

1. Fixed. `CLIProxyHubConfigStore.saveAccounts` now writes to the first enabled entry whose id matches case-insensitively, the entry the cards and the sync read. Regression test `testRepeatedHubIDWritesToTheEnabledEntryThatWasRead` (disabled `one` then enabled `one`) failed before the fix and passes after. The "not saved" warning now says "no longer configured or enabled".
2. Fixed by documenting: `docs/providers/cliproxy-hub.md` now says a save rewrites the whole file, dropping unknown keys, writing a left-out `enabled` as `true` and normalizing the formatting. Preserving unknown keys is left as an owner decision.
3. Fixed: a one-line comment says the cards log an invalid hub URL.
4. Fixed: the sync's unreadable-config line is now `warn`, with a comment that the cards log it at error level.
