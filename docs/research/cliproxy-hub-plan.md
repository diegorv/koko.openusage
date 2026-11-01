# Plan: Read Claude/Codex Usage From a CLIProxyAPI Hub

Goal: OpenUsage lists the Claude and Codex accounts held by a CLIProxyAPI hub and shows each one's live
limits. The hub's management API is the only source, and tokens never reach the app. The reference
implementation is `t3code-customized/apps/server/src/usage/cliproxyApi.ts`.

## Hub contract (ported from t3code)

- Base: `<hubURL>/` + `v0/management/<path>`, with a trailing slash forced so prefixed hubs work.
  Every call sends `Authorization: Bearer <managementKey>`. Timeout is 15 s per request.
- `GET auth-files` → `{ files: [{ id, auth_index, provider, email?, disabled?, id_token?: {
  chatgpt_account_id?, plan_type?, chatgpt_plan_type? } }] }`. Keep `provider ∈ {claude, codex}`
  and `!disabled`.
- `POST api-call`, request and response:
  - Request: `{ auth_index, method, url, header, data? }`. `header` includes `Authorization: Bearer $TOKEN$`.
    `data` is a JSON string, so the payload is double-encoded.
  - Response: `{ status_code, header, body: "<JSON string>" }`. A live hub check showed `header` is present (t3code ignores it), so the adapter forwards it as the response headers.
  - Claude headers: `anthropic-beta: oauth-2025-04-20`, `User-Agent: claude-code/<ver>` (429 without it).
  - Codex headers: `OpenAI-Beta: codex-1`, `Originator: Codex Desktop`, `Chatgpt-Account-Id` when known.
- `POST reset-quota` with `{ auth_index }` after a Codex reset (`reset` or `already_redeemed`).

## Design

**Hub transport adapter.** `CLIProxyHubHTTPClient: HTTPClient` turns each upstream `HTTPRequest` into an
`api-call`. It swaps `Authorization` for `Bearer $TOKEN$` and unwraps the envelope into an `HTTPResponse`.
`ClaudeUsageClient` and `CodexUsageClient` already take an injected `HTTPClient`, and the mappers take a raw
`HTTPResponse`, so all parsing is reused. `CodexUsageMapper` reads `x-codex-*` headers only as a fallback
when the body lacks `used_percent`/`credits` (CodexUsageMapper.swift:36,146,314), so body-only works.

**Separate hub runtimes, not the local providers.** `ClaudeProvider` and `CodexProvider` hold concrete,
file- and Keychain-bound auth stores. They also refresh tokens on 401 (which would send a fake refresh
token through the hub), scan local logs (which would double-count this Mac's spend), and run Claude reset
grants. `ClaudeProvider.swift` is already 694 LOC. So the plan adds two thin runtimes:
- `CLIProxyClaudeRuntime` / `CLIProxyCodexRuntime` (`ProviderRuntime`), each holding the hub client, an
  `auth_index` and the account metadata. They call the shared usage client and mapper, and nothing else:
  no token refresh, no scanners, no Desktop or Keychain reads, no reset grants.
- A hub `status_code` 401/403 becomes a hub-specific error ("Re-login this account on the hub"), never
  `tokenExpired`.
- `widgetDescriptors` is a reduced set: limits only, with no usage trend or spend tiles. (Q1.)

**Cards without touching the account registry.**
- Ids are minted directly (`ProviderAccountID.make(family:, identityKey: "cliproxy:<hubID>:<authID>")`).
- `ProviderAccountSource.Kind` and `ProviderAccountsStore` reconciliation stay as they are.
- Display name: `"Claude: <email> (Hub <label>)"`.

**Launch never waits on the network.**
- `AppContainer` awaits account assembly before building a fixed provider set (AppContainer.swift:69-76).
  So hub cards are built from the **last-seen account list cached in the hub config**, via
  `ProviderCatalog.make(…, hubCards:)`.
- After launch, a background `auth-files` call updates the cache. If the list changed, the cards are
  rebuilt; the minimum version is a "Hub accounts changed — Relaunch" prompt.
- `ProviderCatalog.make` has two other callers that must pass hub cards too: the CLI
  (`UsageReader.swift:56`) and `OpenUsageApp.swift:104`.

**Enablement.** Hub cards are enabled when their hub is added in Settings, not by detection.
`hasLocalCredentials()` returns false for hub runtimes, so `FirstLaunchSetup` and `NewProviderSeeder`
never treat them as local logins (AGENTS.md: that probe is local-only).

**Settings.**
- The config file `~/.config/openusage/cliproxy.json` holds `{ hubs: [{ id, label?, url, managementKey,
  enabled, accounts: [cached] }] }`. This follows the `UserAPIKeyStore` file precedent. (Q5.)
- The UI is an "Add Hub" form (Hub URL, Management Key, Label) with remove/disable per hub.
- The id comes from t3code's `sourceIdFromUrl`: `cliproxy-<host-slug>`, then `-2`, `-3`, and so on.

**Errors.** These follow the AGENTS.md rule: fail loudly into AppLog/PostHog, with friendly copy.
- `ErrorCategory` values for unreachable, timeout, HTTP N, bad key, untrusted TLS, and account re-login.
- Never log the key, bodies or headers (`LogRedaction`).
- At most 4 `api-call`s in flight per hub.
- One account failing fails only its card. A hub-wide failure is detected once per refresh, and all its
  cards show the same hub error without each entering its own cooldown. (Q6.)

**TLS.** `URLSessionHTTPClient` trusts self-signed certs only on `127.0.0.1`. v1 relies on system trust,
which covers Tailscale `*.ts.net` certs and public CAs. A self-signed hub gets a clear "certificate not
trusted" error. (Q4.)

## Steps (test-first, each step ends green)

1. **Hub client and transport adapter.**
   - `CLIProxyHubClient` handles the management calls, URL join, auth, timeout, envelope decoding and
     error mapping. `CLIProxyHubHTTPClient` is the adapter.
   - Fixtures are copied from t3code's tests and the `usage-limits-hub` fixture.
   - Verify with tests: a prefixed URL, a bad key, a non-2xx envelope, double-encoded bodies, the key
     absent from errors and logs, and the unwrapped Claude/Codex bodies giving the same `MetricLine`s
     as the local fixtures.
2. **`CLIProxyHubConfigStore`** (read/write, id slug, cached account list). Verify with `FakeFiles` tests.
3. **Hub runtimes.** Verify with tests:
   - a 401 envelope gives the re-login error with no refresh call and no disk write;
   - no history or spend lines appear;
   - `hasLocalCredentials` is false;
   - a hub-wide failure gives one shared error.
4. **Catalog and launch wiring.** Hub cards come from the cache, and the background `auth-files` call
   updates it. The CLI and `OpenUsageApp` callers are wired too.
   - Test: launch with the hub unreachable still builds the cached cards and does not wait on the network.
   - **Early smoke test:** kill the app, `swift build`, relaunch. Then run against the t3code fixture hub
     (`node hub.mjs state.json 18517`) and a real hub if one is available.
5. **Settings UI** "Add Hub" section. Verify by adding the fixture hub and seeing its cards. Take a
   screenshot for the PR.
6. **Docs:** add `docs/providers/cliproxy-hub.md`, and update `settings.md`, `provider-enablement.md` and
   `local-http-api.md`.
7. **(v2, optional) Codex reset over the hub.**
   - First check whether `CodexResetClaimService` (a final class tied to `CodexProvider`) can take the hub
     client. Write a hub variant only if it can't.
   - The redeem id is t3code's deterministic UUIDv5 (namespace `6f1c2a9e-2d4b-4c1e-9a7f-3b8d5e0c1a42`,
     name `"<chatgptAccountId|authId>:<creditId>"`, CryptoKit `Insecure.SHA1`).
   - Verify with tests: the pinned UUID `519d5243-011a-5b7b-91f3-44d85f095705` for (`account-b`,
     `credit-b`), the outcome table, a failed `reset-quota` giving a warning, and a 503 retry reusing the id.

Each new file stays under ~500 LOC. There are no new dependencies.

## Decisions (owner)

- **Metrics:** hub cards copy the family's defaults for the limit metrics they show.
- **Dedup:** when a hub account is also signed in locally (same email, or same ChatGPT account id for
  Codex), the hub card wins and the local card is hidden.
- **v1 scope:** limits only. Codex reset over the hub (Step 7) is out of scope.
- **TLS:** system trust is enough. No per-hub certificate option.
- **Key storage:** plain config file, like today's API keys.
- **Account list changes:** prompt a relaunch. No live rebuild.
