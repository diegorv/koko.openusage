VERDICT: APPROVED

## Previous findings

| # | Severity | Status | Evidence |
|---|----------|--------|----------|
| 1 | blocker | resolved | `CLIProxyHubCards.claudeRuntimes` (CLIProxyHubCards.swift:40-60) keeps the first enabled hub per lowercased hub id and the first card per card id across all hubs, and logs each skip with `AppLog.error(.config, …)`. `testDuplicateHubsAndAccountsKeepTheFirstCardAndStillBuildTheDataStore` covers a repeated hub, `a.json`/`A.json`/`a.json`, and a hub id that differs only in case. It also builds `ProviderCatalog` and `WidgetDataStore`, which is the call that crashed before. The test passes. |
| 2 | minor | resolved | `hasMultipleClaudeCards` now counts the Claude ids in `registry.historyDescriptorsByProvider` (WidgetDataStore.swift:449-452). Local Claude accounts all carry the `usageTrend…exportingHistory` descriptor (ClaudeProvider.swift:102), so local multi-account counting is unchanged. Only hub cards drop out. `testHubCardsDoNotDropTheLocalClaudeHistoryFromSync` passes. |
| 3 | minor | resolved | `FirstLaunchSetup.connect` skips `CLIProxyClaudeRuntime` cards (FirstLaunchSetup.swift:104). `testConnectLeavesHubCardsAlone` uses a down hub and asserts only `claude` is enabled and the row is `.connected`. Both docs now describe fresh-install behavior correctly (cliproxy-hub.md "Cards", provider-enablement.md). |
| 4 | minor | rejection stands (deferred) | No code change. Deferring the user-facing error for a malformed config to Issue 07 (Settings) is what the first review allowed. The main session still has to record it in Issue 07 or in the ledger (finding 1 below). |
| 5 | minor | rejection stands (owner to confirm) | The per-card 60 s backoff is unchanged. All cards of a down hub fail in the same pass with the shared error, so they back off and retry together. Removing the backoff would bring back the probing on each wake. The decision is recorded in review.md's Resolution. It is still the owner's call. |
| 6 | minor | resolved (injection rejection stands) | `UsageReaderTests.testHubCardLimitsAreServedUnderTheClaudeFamily` sends real `CLIProxyHubCards` runtimes through `UsageReader.read(providerID: "claude")` and checks `session`/`weekly` under the card id. The reason for not injecting the store holds: the non-override path also reads the real Claude and Codex homes through `ProviderAccountAssembly.make`. The production wiring `hubCards:` in UsageReader is still not covered by a test (nit, finding 2). |
| 7 | nit | resolved | `CLIProxyHubSession.Transport` is removed. `CLIProxyHubHTTPClient` now takes `session:` and calls `session.apiCall`, and the runtime uses it (CLIProxyClaudeRuntime.swift:41). The `nonisolated init` on the `@MainActor` session only assigns `let` Sendable values and builds cleanly. Issue 01's adapter tests still assert the same envelope behavior, now through the session. No assertion was removed. |
| 8 | nit | resolved | CLIProxyClaudeRuntimeTests.swift:190-192 asserts `peak <= maxConcurrentCalls` and `peak > 1`. The cap is still checked, and the request count of 10 is still asserted. |
| 9 (smoke) | — | still open, out of scope here | The owner's config has 0 cached accounts. This needs Issue 03 or a hand-written cache, plus the running app. |

## Acceptance criteria re-checked

- [met] A hub-wide failure shows one shared hub error on all its cards. One account failing fails only its own card. At most 4 `api-call`s run at once per hub. — The session code is unchanged except for the adapter move. `testHubWideFailureIsSharedByEveryCardOfThatHub`, `testOneAccountFailingFailsOnlyItsCard` and `testAtMostFourAPICallsRunAtOncePerHub` (now `<= 4` and `> 1`) pass.
- [met] Card ids are stable per hub and account. The account registry is not touched. — The dedup leaves `cardID` alone, so a duplicate card id can no longer crash the data store (new regression test passes). `testCardIDsAreStablePerHubAndAccountAndNamedForTheHub` passes.
- [met] Hub cards appear in the app, the CLI and the local HTTP API. — The wiring is unchanged (AppContainer, UsageReader). The new UsageReader test serves a hub card's limits through `LocalUsageAPI.respond` under the `claude` family.
- [met] `hasLocalCredentials()` is false for hub cards, so first-launch detection and the new-provider seeder ignore them. — Unchanged. Welcome-screen connect now leaves them alone too (`testConnectLeavesHubCardsAlone`). FirstRunSeeder and NewProviderSeeder tests pass.
- [met] `docs/providers/cliproxy-hub.md` exists. `local-http-api.md` mentions hub cards. — The "Cards" section of cliproxy-hub.md now matches what the code does on a fresh install.
- [not met] Smoke test: kill the app, rebuild, relaunch, and see the owner's real hub's Claude account. — Not possible here: the owner's hub has 0 cached accounts. This waits on Issue 03 or a hand-written cache and the owner's running app.

## Findings

1. **minor** — Sources/OpenUsage/Providers/CLIProxyHub/CLIProxyHubCards.swift:27. A malformed `cliproxy.json` is still only logged, deferred to Issue 07. Fix: the main session adds "show the config load error in the hub Settings" to Issue 07's checklist or to the ledger. No change is needed on this branch.
2. **nit** — Sources/OpenUsage/CLI/UsageReader.swift:58. No test covers the production path where `UsageReader` builds hub cards from `CLIProxyHubConfigStore()`. Only the `providers:` override is tested. Fix: optional. Accept this, or test it once Issue 07 or a later issue gives the store a seam.
3. **minor** — Hub cards keep WidgetDataStore's per-card 60 s failure backoff, which departs from plan Q6's wording. The reasoning is recorded. Fix: the owner confirms, or asks for hub cards to skip the per-card backoff.

## Checks run by this review

- Typecheck: `swift build`, exit 0, no warnings.
- Targeted tests, exit 0: filter `CLIProxyClaudeRuntimeTests|CLIProxyHubClientTests|CLIProxyHubConfigStoreTests|FirstLaunchSetupTests|UsageReaderTests|WidgetDataStore|UsageHistory|ICloud|LocalUsageAPITests|LocalLimitsAPITests|FirstRunSeederTests|NewProviderSeederTests|ProviderEnablementEnforcementTests|MultiAccount`. 173 XCTest tests and 23 Swift Testing tests ran, with 0 failures.
- The full suite is deliver's to run.
- No scope creep. The fixes touch only the hub module, `FirstLaunchSetup.connect`, the history ownership count, their tests and the two docs.

## Resolution

1. minor (malformed `cliproxy.json` only logged): no change on this branch, as the finding says. The user-facing config error belongs to Issue 07 (Settings); the main session records it in Issue 07's checklist or the ledger.
2. nit (no test for the `CLIProxyHubConfigStore()` path in `UsageReader`): accepted as is. The store has no seam yet, and the non-override path also reads the real Claude and Codex homes; a test fits once Issue 07 or a later issue gives the store a seam.
3. minor (per-card 60 s backoff kept for hub cards): kept, for the reasons in review.md's Resolution. It is the owner's call to confirm or to ask hub cards to skip it.
4. Smoke test: still open; it waits on Issue 03 or a hand-written cache and the owner's running app.
