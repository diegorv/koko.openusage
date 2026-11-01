# 02: Claude Hub Cards From the Cached Account List

**What to build:** With a hub in `~/.config/openusage/cliproxy.json` and its `accounts` cache filled, OpenUsage shows one card per Claude hub account at launch, named like "Claude: <email> (Hub <label>)", with live limits fetched through the hub. Launch never waits on the network. Source: plan sections "Separate hub runtimes", "Cards without touching the account registry", "Launch never waits on the network", "Errors".

**Blocked by:** 01

**Status:** resolved

- [x] The config store reads and writes the hub list and the per-hub cached accounts. Test it with in-memory files.
- [x] A dedicated Claude hub runtime shows limits only: Session, Weekly, per-model weekly and Extra usage. Its metrics copy the Claude family's defaults (owner decision). It has no usage trend or spend tiles.
- [x] The runtime never refreshes tokens, scans local logs, reads Desktop/Keychain credentials or checks reset grants. Tests prove that a 401 envelope gives a "Re-login this account on the hub" error with no refresh call and no disk write.
- [x] `hasLocalCredentials()` is false for hub cards, so first-launch detection and the new-provider seeder ignore them.
- [x] A hub-wide failure shows one shared hub error on all its cards. One account failing fails only its own card. At most 4 `api-call`s run at once per hub.
- [x] Card ids are stable per hub and account. The account registry is not touched.
- [x] Hub cards appear in the app, the CLI and the local HTTP API.
- [x] A launch test with the hub unreachable still builds the cached cards without waiting.
- [x] `docs/providers/cliproxy-hub.md` exists. `local-http-api.md` mentions hub cards.
- [ ] Smoke test: kill the app, rebuild, relaunch, and see the owner's real hub's Claude account.

## Comments

- 2026-11-01, branch `issue/02-claude-hub-cards-from-cache`: Claude hub cards built from the cached account list (config store, limits-only `CLIProxyClaudeRuntime`, shared hub session with a 4-call cap, wiring into the app, CLI and local HTTP API, docs). The fix round deduplicated hubs and cards, kept local Claude history sync when hub cards exist, made welcome-screen connect skip hub cards, routed the adapter through the hub session and added CLI/local API tests. Reviews: round 1 CHANGES_REQUESTED, round 2 APPROVED (remaining findings deferred: malformed config error to Issue 07, store seam test, per-card backoff for the owner). Full suite: 1703 XCTest tests (4 skipped) and 3 Swift Testing tests, 0 failures. The smoke test stays open: the owner's hub has 0 cached accounts (waits on Issue 03).
