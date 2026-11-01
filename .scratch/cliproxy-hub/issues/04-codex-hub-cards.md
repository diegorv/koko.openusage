# 04: Codex Hub Cards

**What to build:** Codex accounts on the hub get their own cards, named like "Codex: <email> (Hub <label>)", showing the same limit windows as a local Codex card.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] A dedicated Codex hub runtime sends the Codex headers (`OpenAI-Beta`, `Originator`, and `Chatgpt-Account-Id` when known) through the hub.
- [ ] It shows limits only, with metrics copying the Codex family's defaults. There is no history or spend, no token refresh, and no reset-credit claiming (out of scope for v1).
- [ ] The plan label comes from the usage body, falling back to the account's `id_token` plan.
- [ ] Tests cover the same guarantees as the Claude hub runtime (no refresh on 401, no local scans, `hasLocalCredentials` false).
- [ ] Smoke test against the real hub's Codex account.
