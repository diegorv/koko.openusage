# 01: Hub Client and Transport Adapter

**What to build:** OpenUsage can talk to a CLIProxyAPI hub's management API and turn a proxied `api-call` into an ordinary HTTP response. The existing Claude and Codex usage clients and mappers then run on top of it unchanged. Source: `docs/research/cliproxy-hub-plan.md` (Hub contract, Design → Hub transport adapter).

**Blocked by:** none

**Status:** ready-for-agent

- [ ] Management calls go to `<hubURL>/v0/management/<path>`, with a trailing slash forced so a hub under a path prefix keeps it. Every call sends `Authorization: Bearer <managementKey>` and times out after 15 s.
- [ ] `auth-files` lists accounts and keeps only enabled `claude`/`codex` entries, with `id`, `auth_index`, `email` and the Codex `id_token` fields.
- [ ] The adapter sends each upstream request as an `api-call`, with `Authorization` replaced by `Bearer $TOKEN$` and the body sent as a JSON string. It unwraps `{ status_code, header, body }` into a response, forwarding the headers.
- [ ] Errors are friendly and categorized: unreachable, timeout, HTTP N, bad key, untrusted certificate. The management key, bodies and headers never appear in errors or logs.
- [ ] Tests (test-first, using the fixtures from t3code's `cliproxyApi.test.ts` and `usage-limits-hub` fixture) cover a prefixed URL, a bad key, a non-2xx envelope, a double-encoded body and key redaction.
- [ ] Unwrapped Claude and Codex bodies produce the same metric lines as the existing local fixtures.
