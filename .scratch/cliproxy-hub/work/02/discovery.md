# 02 Discovery: Claude Hub Cards From the Cached Account List

No `spec.md`; contract and decisions come from `docs/research/cliproxy-hub-plan.md` (steps 2-4, 6). Builds on `work/01` (client + adapter).

## Files

- New `Providers/CLIProxyHub/CLIProxyHubConfigStore.swift`: `CLIProxyHubConfig { hubs }`, `Hub { id, label?, url, managementKey, enabled, accounts }`, store over `TextFileAccessing` at `~/.config/openusage/cliproxy.json` (`load`, `save`, `saveAccounts(_:hubID:)`). `CLIProxyHubAccount` becomes `Codable`.
- New `Providers/CLIProxyHub/CLIProxyHubSession.swift`: one per hub, shared by its cards. At most 4 `api-call`s in flight (MainActor semaphore); a hub-wide failure (transport, cert, bad key, access denied, management 5xx) is handed to every card that started its refresh before it was recorded, so a pass hits the hub once per slot and all cards show the same error.
- New `Providers/CLIProxyHub/CLIProxyClaudeRuntime.swift`: `ProviderRuntime` calling `ClaudeUsageClient.fetchUsage` over the session + `ClaudeUsageMapper`. Envelope 401/403 → `CLIProxyHubAccountError.reloginRequired`; 429 → last-good + rate-limited note. `hasLocalCredentials()` false. No auth store, files, scanners, reset grants.
- New `Providers/CLIProxyHub/CLIProxyHubCards.swift`: builds runtimes from config (`claude@<hash>` from `cliproxy:<hubID>:<accountID>`, name `Claude: <email> (Hub <label>)`), and enables never-seen hub card ids at launch (so the seeder never probes them).
- `Providers/Claude/ClaudeProvider.swift:80-89`: extract the five limit descriptors to `static func limitDescriptors(provider:)`, reused by the hub runtime (same ids → `DefaultLayout.expandingAccounts` copies Claude's defaults).
- `Providers/ProviderCatalog.swift:7`: `hubCards:` param, appended after the local Claude cards.
- `App/AppContainer.swift:71`, `Services/UsageReader.swift:58`: load config off-main (local file only), pass hub cards; AppContainer enables new hub card ids before `NewProviderSeeder`.
- `ErrorCategory.swift`: `CLIProxyHubAccountError` conformance.
- Docs: new `docs/providers/cliproxy-hub.md`; `docs/local-http-api.md` note.

## Tests (prior art: `FakeFiles`, `RoutingHTTPClient` in TestSupport.swift; envelope helpers in CLIProxyHubClientTests.swift)

- `CLIProxyHubConfigStoreTests`: absent file → empty; round trip; `saveAccounts` keeps other hubs; defaults for missing `enabled`/`accounts`; malformed file throws.
- `CLIProxyClaudeRuntimeTests`: lines mapped from envelope; descriptors limits only (no trend/spend); 401 → relogin error, one request, no refresh URL, files untouched; `hasLocalCredentials` false; hub-wide failure shared (one call); one account's 401 fails only that card; max 4 concurrent; ids stable / registry untouched; launch build with unreachable hub makes no request.

## Defaults taken

- `OpenUsageApp.swift:104` keeps `ProviderCatalog.make()` (it lists one welcome choice per family); hub cards reach the welcome flow through `container.providers` already.
- Hub id slug (`sourceIdFromUrl`) is left to Issue 07 (Add Hub); this Issue reads ids from the file.
- Hub-wide = transport, cert, bad key, access denied, management 5xx. Management 4xx and undecodable envelopes fail only the card.
- Card still enters `WidgetDataStore`'s own 60 s per-card backoff on failure (unchanged).
- Label fallback: hub `label`, else URL host. Email fallback: account id.

## Risks

- Smoke test against the owner's real hub needs a hand-written `cliproxy.json` with cached accounts (sync is Issue 03).
