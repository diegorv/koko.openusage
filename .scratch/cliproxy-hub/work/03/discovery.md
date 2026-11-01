# 03 Discovery: Background Hub Account Sync

No `spec.md`; contract from `docs/research/cliproxy-hub-plan.md` (line 50, step 4). Builds on `work/01` (`CLIProxyHubClient.listAccounts`, which already drops disabled and non-Claude/Codex entries) and `work/02` (`CLIProxyHubConfigStore.saveAccounts`, cards from cache).

## Files

- New `Sources/OpenUsage/Providers/CLIProxyHub/CLIProxyHubAccountSync.swift`: `static func run(store:http:) async`. Loads the config off-main; for each enabled hub with a valid URL, `listAccounts()`, then `saveAccounts(_:hubID:)` (off-main) when the list differs from the cache. A failure logs `AppLog.error(.config, "The hub could not list accounts. ...")` with the hub id and error copy, and leaves the cache untouched. Hubs run one after another, so the file's load/modify/save never races itself.
- `Sources/OpenUsage/App/AppContainer.swift:72`: after the cards are built, start the sync in a stored `Task` (like `shellEnvironmentSnapshotTask`), so it never sits on the launch path. Not wired into `UsageReader` (the CLI stays read-only).
- `docs/providers/cliproxy-hub.md`: `accounts` is refreshed from the hub in the background after launch; new accounts show from the next launch.
- New `Tests/OpenUsageTests/CLIProxyHubAccountSyncTests.swift`.

## Tests (prior art: `FakeFiles`, `RoutingHTTPClient` in TestSupport.swift; auth-files fixture and `captureLog` in CLIProxyHubClientTests.swift)

- Successful sync replaces the cache with the hub's list; a hub-side disabled account drops out.
- Failure (HTTP 500 / unreachable) keeps the old cache and logs "The hub could not list accounts."
- Write keeps label, url, managementKey, enabled and the other hubs as they were.
- Disabled hub is skipped (no request, cache untouched).

## Defaults taken

- Unchanged list: no write (avoids rewriting the key file every launch).
- Hubs synced sequentially, not in parallel: each call is bounded by the 15 s client timeout and this runs in the background.
- A repeated hub id (hand-edited) is synced once, matching the cards' first-entry-wins rule; `saveAccounts` writes the first match.
- Log category `.config`, level error (loud), message carries the hub id, never the key.

## Risks

- `save` re-encodes the config through `Codable`, so unknown hand-written keys are dropped and absent `enabled` is written out as `true`. Known fields keep their values.
- Smoke test (empty cache, relaunch twice) needs the owner's real hub; not runnable here.
