# 01: Hub Client and Transport Adapter

**What to build:** OpenUsage can talk to a CLIProxyAPI hub's management API and turn a proxied `api-call` into an ordinary HTTP response. The existing Claude and Codex usage clients and mappers then run on top of it unchanged. Source: `docs/research/cliproxy-hub-plan.md` (Hub contract, Design → Hub transport adapter).

**Blocked by:** none

**Status:** resolved

- [x] Management calls go to `<hubURL>/v0/management/<path>`, with a trailing slash forced so a hub under a path prefix keeps it. Every call sends `Authorization: Bearer <managementKey>` and times out after 15 s.
- [x] `auth-files` lists accounts and keeps only enabled `claude`/`codex` entries, with `id`, `auth_index`, `email` and the Codex `id_token` fields.
- [x] The adapter sends each upstream request as an `api-call`, with `Authorization` replaced by `Bearer $TOKEN$` and the body sent as a JSON string. It unwraps `{ status_code, header, body }` into a response, forwarding the headers.
- [x] Errors are friendly and categorized: unreachable, timeout, HTTP N, bad key, untrusted certificate. The management key, bodies and headers never appear in errors or logs.
- [x] Tests (test-first, using the fixtures from t3code's `cliproxyApi.test.ts` and `usage-limits-hub` fixture) cover a prefixed URL, a bad key, a non-2xx envelope, a double-encoded body and key redaction. (Fixture port waived by the owner on 2026-11-01; the existing tests cover these cases.)
- [x] Unwrapped Claude and Codex bodies produce the same metric lines as the existing local fixtures.

## Comments

- 2026-11-01, branch `issue/01-hub-client-and-transport`: added the hub management client (`/v0/management/` calls, bearer key, 15 s timeout, `auth-files` filtering) and the `api-call` transport adapter with categorized, redacted errors. Fix round: split 403 from bad key, read disk-fallback auth entries, dropped unused `chatgpt_plan_type`, reused `captureLog`. Tests: `swift build` exit 0; `CLIProxyHubClientTests` 19 tests, 0 failures; full `swift test` at 51b973a3 exit 0, 1681 tests, 4 skipped, 0 failures. Reviews: round 1 CHANGES_REQUESTED, round 2 APPROVED, round 3 APPROVED. Open: fixtures not ported verbatim from t3code (owner decision: supply the path or waive the provenance clause).
