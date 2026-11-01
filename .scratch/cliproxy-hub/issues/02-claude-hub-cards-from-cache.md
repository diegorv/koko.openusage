# 02: Claude Hub Cards From the Cached Account List

**What to build:** With a hub in `~/.config/openusage/cliproxy.json` and its `accounts` cache filled, OpenUsage shows one card per Claude hub account at launch, named like "Claude: <email> (Hub <label>)", with live limits fetched through the hub. Launch never waits on the network. Source: plan sections "Separate hub runtimes", "Cards without touching the account registry", "Launch never waits on the network", "Errors".

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] The config store reads and writes the hub list and the per-hub cached accounts. Test it with in-memory files.
- [ ] A dedicated Claude hub runtime shows limits only: Session, Weekly, per-model weekly and Extra usage. Its metrics copy the Claude family's defaults (owner decision). It has no usage trend or spend tiles.
- [ ] The runtime never refreshes tokens, scans local logs, reads Desktop/Keychain credentials or checks reset grants. Tests prove that a 401 envelope gives a "Re-login this account on the hub" error with no refresh call and no disk write.
- [ ] `hasLocalCredentials()` is false for hub cards, so first-launch detection and the new-provider seeder ignore them.
- [ ] A hub-wide failure shows one shared hub error on all its cards. One account failing fails only its own card. At most 4 `api-call`s run at once per hub.
- [ ] Card ids are stable per hub and account. The account registry is not touched.
- [ ] Hub cards appear in the app, the CLI and the local HTTP API.
- [ ] A launch test with the hub unreachable still builds the cached cards without waiting.
- [ ] `docs/providers/cliproxy-hub.md` exists. `local-http-api.md` mentions hub cards.
- [ ] Smoke test: kill the app, rebuild, relaunch, and see the owner's real hub's Claude account.
