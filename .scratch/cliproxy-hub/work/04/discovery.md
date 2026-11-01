# 04 Discovery: Codex Hub Cards

No `spec.md`; contract from `docs/research/cliproxy-hub-plan.md` (lines 11-19, 30-40). Repeats the
pattern of `work/02` (Claude hub runtime + cards). Only the differences are listed.

## Files

- New `Providers/CLIProxyHub/CLIProxyCodexRuntime.swift`: `ProviderRuntime` sending
  `GET CodexUsageClient.usageURL` through `CLIProxyHubHTTPClient` with `Accept`, `User-Agent`,
  `OpenAI-Beta: codex-1`, `Originator: Codex Desktop`, and `Chatgpt-Account-Id` when the account has one.
  Maps with `CodexUsageMapper.mapUsageResponse` (no reset-credits fetch, no history, no spend). Envelope
  401/403 → `CLIProxyHubAccountError.reloginRequired`. Plan: `mapped.plan ?? formatCodexPlan(account.planType)`.
- `Providers/Codex/CodexProvider.swift:53-68`: extract the six limit descriptors (session, weekly, spark,
  sparkWeekly, credits, rateLimitResets) to `static func limitDescriptors(provider:)` (like Claude's), so hub
  ids copy the Codex defaults through `DefaultLayout.expandingAccounts`.
- `CLIProxyHubCards.swift`: one pass per hub building both families on one shared session
  (`runtimes(hubs:http:) -> Runtimes { claude, codex, all }`); `claudeRuntimes`/`codexRuntimes` stay as thin
  accessors. `cardID(family:...)`, `displayName` with a family prefix ("Codex: <email> (Hub <label>)").
  `loadClaudeRuntimes` → `loadRuntimes`.
- `CLIProxyClaudeRuntime.swift:11`: relogin copy made family-neutral ("Its sign-in there was rejected.").
- `ProviderCatalog.swift:12,47`: `codexHubCards:` appended after the local Codex cards.
- `AppContainer.swift:74,83,124`, `UsageReader.swift:58`: load both, pass both, enable both.
- `FirstLaunchSetup.swift:104`: skip Codex hub cards too (marker protocol `CLIProxyHubCard`).
- `CLIProxyHubClient.swift:104`: plan also read from `id_token.chatgpt_plan_type` (contract line 12).
- Docs: `docs/providers/cliproxy-hub.md` (Codex cards, metrics, errors).

## Tests (prior art: `CLIProxyClaudeRuntimeTests.swift`, `RoutingHTTPClient`, `FakeFiles`)

New `CLIProxyCodexRuntimeTests`: limits mapped, headers + url + auth_index in payload, no
`Chatgpt-Account-Id` when unknown; descriptors limits only with Codex suffixes; plan from body, fallback to
account plan; 401 → relogin, one request, no refresh URL, files untouched; `hasLocalCredentials` false;
cards named/ids in codex family; Claude+Codex of one hub share a session; catalog order (after local
Codex). Client test: `chatgpt_plan_type` fallback. FirstLaunchSetup: Codex hub card left alone.

## Defaults taken

- Rate Limit Resets count is shown (from the usage body); no claim service is wired, so no claim button.
- 429 follows the local Codex mapper (an error row); no last-good cache (local Codex has none).
- Plan fallback key order: `plan_type`, then `chatgpt_plan_type`.

## Risks

- Smoke test against the real hub needs the owner's hub; not runnable here.
