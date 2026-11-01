VERDICT: APPROVED

## Acceptance criteria

- [met] A dedicated Codex hub runtime sends the Codex headers (`OpenAI-Beta`, `Originator`, and `Chatgpt-Account-Id` when known) through the hub. — `CLIProxyCodexRuntime.usageRequest()` (CLIProxyCodexRuntime.swift:62-73) sets `OpenAI-Beta: codex-1`, `Originator: Codex Desktop`, and `Chatgpt-Account-Id` only for a non-empty `chatgptAccountID`. It sends `GET wham/usage` through `CLIProxyHubHTTPClient`, which swaps `Authorization` for `Bearer $TOKEN$` (CLIProxyHubClient.swift:117-118). `testMapsTheAccountsLimitsThroughTheHubWithTheCodexHeaders` checks the `api-call` payload: `auth_index`, method, URL, all three headers and the token placeholder. `testLeavesOutTheAccountHeaderWhenTheAccountIDIsUnknown` checks that the account header is left out when the id is unknown (case-insensitive check).
- [met] It shows limits only, with metrics copying the Codex family's defaults. There is no history or spend, no token refresh, and no reset-credit claiming (out of scope for v1). — `widgetDescriptors` = `CodexProvider.limitDescriptors(provider:)`, the six limit tiles split out of the local card (CodexProvider.swift:54-73). They keep the same id suffixes, so `DefaultLayout.expandingAccounts` (DefaultLayout.swift:11) gives `codex@…` cards the Codex defaults. `testShowsLimitsOnlyWithTheCodexMetricIDs` asserts the ids, no spend tile, no history resource, and that each suffix exists on the local Codex card. The runtime holds no auth store, scanner or reset-credits fetch, and calls `mapUsageResponse` with no `resetCredits`. It is not a `CodexProvider`, so the `resetClaims` loop (AppContainer.swift:147) skips it, and the resets popover gets no claim service (WidgetGroupedListView.swift:237 looks it up by provider id).
- [met] The plan label comes from the usage body, falling back to the account's `id_token` plan. — `plan: mapped.plan ?? CodexUsageMapper.formatCodexPlan(account.planType)` (CLIProxyCodexRuntime.swift:51). `listAccounts` reads `id_token.plan_type`, then `chatgpt_plan_type` (CLIProxyHubClient.swift:104), which matches the hub contract (docs/research/cliproxy-hub-plan.md:11-12). Tests: body plan "pro" becomes "Pro 200" (the headers test), `testPlanFallsBackToTheAccountsIDTokenPlan` ("plus" becomes "Plus" when the body has no plan), and `CLIProxyHubClientTests.testCodexPlanFallsBackToTheChatGPTPlanClaim`.
- [met] Tests cover the same guarantees as the Claude hub runtime (no refresh on 401, no local scans, `hasLocalCredentials` false). — `testUpstreamUnauthorizedAsksForAHubReloginWithoutRefreshingOrWriting` checks the re-login error text, the `.authExpired` category, exactly 1 request (to the usage URL, so no refresh call) and unchanged `FakeFiles`. `testHubCardsAreNeverLocalCredentials` checks that `hasLocalCredentials()` is false and that `FirstRunSeeder.detectLocalProviders` finds nothing. The no-local-scans guarantee comes from the limits-only descriptors test, and the runtime has no scanner dependency at all. `FirstLaunchSetupTests.testConnectLeavesHubCardsAlone` now has a Codex hub card. The hub-wide-failure and 4-call-cap tests stay on the Claude side; they still cover Codex cards because `testClaudeAndCodexCardsOfOneHubShareItsSession` shows both families use the same `CLIProxyHubSession`.
- [not met] Smoke test against the real hub's Codex account. — Not run. The builder could not run it, and this review cannot either: it needs the owner's real hub, the management key in `~/.config/openusage/cliproxy.json`, and the running app rebuilt and relaunched. Only the owner can check it, so it does not hold back APPROVED (the same call as the smoke tests of Issues 02 and 03).

## Checks run by this review

- `swift build` in the worktree: exit 0, no warnings or errors.
- `swift test --filter 'CLIProxyCodexRuntimeTests|CLIProxyClaudeRuntimeTests|CLIProxyHubClientTests|FirstLaunchSetupTests|CodexProviderTests|UsageReaderTests|CLIProxyHubAccountSyncTests|CLIProxyHubConfigStoreTests|LocalLimitsAPITests|CodexMultiAccountAssemblyTests|CodexDiscoveryGateTests|ProviderLinksTests'`: exit 0. All 12 suites passed: 113 XCTest tests, 0 failures (CLIProxyCodexRuntimeTests 9, CLIProxyClaudeRuntimeTests 15, CLIProxyHubClientTests 20, FirstLaunchSetupTests 9, CodexProviderTests 4, UsageReaderTests 8, among others). My test verdict rests on these files. They are the files the diff adds or changes, the tests of the code it changes (hub cards, hub client, Codex provider, catalog, UsageReader, FirstLaunchSetup), and the catalog consumers.
- No test or doc still uses the old re-login text ("Its Claude sign-in there was rejected") or `loadClaudeRuntimes`.
- I did not run the full suite; deliver runs it.
- The worktree was clean before this review file.

## Findings

1. minor — Sources/OpenUsage/Views/CustomizeProviderDetailView.swift:36 — Customize shows the Codex "Cost Estimates" section (Fallback Model picker) on Codex hub cards, which have no spend. Its `providerIDs` (line 37-39) also include the hub card ids, so changing the fallback model force-refreshes every Codex hub card, one extra hub `api-call` each. Fix: skip the section for hub cards (e.g. check `container.providers` for `any CLIProxyHubCard`), and leave hub card ids out of `providerIDs`. Not part of an acceptance criterion; it can be a follow-up.
2. nit — Sources/OpenUsage/Providers/CLIProxyHub/CLIProxyClaudeRuntime.swift:16-21 — The shared `CLIProxyHubCard` protocol (and `CLIProxyHubAccountError`) lives in the Claude runtime's file even though both runtimes use it. Its `account`/`session` requirements are never used through the protocol: the only use is the `is any CLIProxyHubCard` check in FirstLaunchSetup.swift:104. Fix: move both into their own file (e.g. `CLIProxyHubCard.swift`), and keep the protocol a plain marker unless something needs those requirements.
3. nit — Sources/OpenUsage/Providers/CLIProxyHub/CLIProxyHubCards.swift:45-57 — `claudeRuntimes(hubs:http:)` and `codexRuntimes(hubs:http:)` are production wrappers that only tests call, and they lost their doc comment. Fix: either drop them and have tests use `runtimes(hubs:http:).claude/.codex`, or keep them on purpose with a one-line comment.
4. nit — Sources/OpenUsage/Services/UsageReader.swift:58-65 — The CLI path now passes `codexHubCards`, but `UsageReaderTests` only covers Claude hub cards (UsageReaderTests.swift:146). The wiring is trivial and the catalog order test covers `ProviderCatalog.make`. Fix (optional): add a Codex hub card to the existing UsageReader hub test.
5. nit — Sources/OpenUsage/Providers/CLIProxyHub/CLIProxyCodexRuntime.swift:62-73 — The runtime builds its own `wham/usage` request instead of going through `CodexUsageClient` as the plan describes ("They call the shared usage client"). The local `fetchUsage` lacks the `OpenAI-Beta`/`Originator` headers, so this is a reasonable choice. It does mean the usage URL and the base headers are now kept in two places. No change needed; noted for whoever touches `CodexUsageClient.fetchUsage` next.

## Spec and scope

- There is no `.scratch/cliproxy-hub/spec.md`. The decisions in docs/research/cliproxy-hub-plan.md hold:
  - separate thin runtimes;
  - 401/403 becomes a hub re-login error, never `tokenExpired`;
  - limits-only descriptors;
  - card ids from `ProviderAccountID.make(family:, identityKey: "cliproxy:<hub>:<auth>")`, so Claude card ids are unchanged (family `claude`, same identity key);
  - cards built from the cache with no network call at launch;
  - `hasLocalCredentials` false.
- No scope creep. The re-login copy is now neutral across families, and the `chatgpt_plan_type` fallback follows the hub contract. The docs edits (cliproxy-hub.md, local-http-api.md, provider-enablement.md) are what AGENTS.md "Documentation" requires.
- The defaults the builder took are documented in discovery.md and docs/providers/cliproxy-hub.md:
  - a reset count with no claim button;
  - a 429 shows an error row, with no last-good cache;
  - the plan is read from `plan_type`, then `chatgpt_plan_type`.

  They are consistent with the local Codex card. The owner may still want to confirm the 429 behavior, since the Claude hub card keeps its last-good limits.

## Resolution

1. Fixed. `CodexPricingSection.cardIDs(for:among:)` lists only local Codex cards (hub cards filtered out by `CLIProxyHubCard`) and returns nil for any other card, so a Codex hub card shows no Cost Estimates section and changing the fallback model refreshes only local Codex cards. Covered by `CodexPricingSectionTests`; docs/providers/cliproxy-hub.md says so.
2. Fixed. `CLIProxyHubCard` (now a plain marker protocol) and `CLIProxyHubAccountError` moved to `CLIProxyHub/CLIProxyHubCard.swift`.
3. Fixed. `claudeRuntimes`/`codexRuntimes` dropped; tests call `runtimes(hubs:http:).claude/.codex`.
4. Fixed. `UsageReaderTests.testCodexHubCardLimitsAreServedUnderTheCodexFamily` serves a Codex hub card under the `codex` family.
5. No change, as the review says.
