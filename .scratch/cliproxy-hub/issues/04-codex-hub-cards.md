# 04: Codex Hub Cards

**What to build:** Codex accounts on the hub get their own cards, named like "Codex: <email> (Hub <label>)", showing the same limit windows as a local Codex card.

**Blocked by:** 02

**Status:** resolved

- [x] A dedicated Codex hub runtime sends the Codex headers (`OpenAI-Beta`, `Originator`, and `Chatgpt-Account-Id` when known) through the hub.
- [x] It shows limits only, with metrics copying the Codex family's defaults. There is no history or spend, no token refresh, and no reset-credit claiming (out of scope for v1).
- [x] The plan label comes from the usage body, falling back to the account's `id_token` plan.
- [x] Tests cover the same guarantees as the Claude hub runtime (no refresh on 401, no local scans, `hasLocalCredentials` false).
- [ ] Smoke test against the real hub's Codex account.

## Comments

- 2026-11-01, branch `issue/04-codex-hub-cards`: added a dedicated Codex hub runtime (Codex headers through the hub, limits-only metrics, plan label from usage body with `id_token` fallback); fix round kept cost estimates off Codex hub cards and tidied hub card types. Full suite passed at 6c559230 (1724 XCTest tests, 4 skipped, 0 failures; +4 and 3 Swift Testing passed). Reviews: round 1 APPROVED, round 2 APPROVED. Real-hub smoke test not done.
