# 01 Discovery: Hub Client and Transport Adapter

No `spec.md` for this feature; vocabulary and contract come from `docs/research/cliproxy-hub-plan.md` ("Hub contract", "Design → Hub transport adapter").

## Files

- New `Sources/OpenUsage/Providers/CLIProxyHub/CLIProxyHubClient.swift`: `CLIProxyHubClient` (URL join, bearer key, 15 s timeout, `listAccounts()` over `GET auth-files`, `apiCall(authIndex:request:)` over `POST api-call`, envelope decoding, error mapping), `CLIProxyHubAccount`, `CLIProxyHubError`.
- New `Sources/OpenUsage/Providers/CLIProxyHub/CLIProxyHubHTTPClient.swift`: the `HTTPClient` adapter bound to one `auth_index`.
- `Sources/OpenUsage/Providers/ErrorCategory.swift` (end of file): `CLIProxyHubError: CategorizedError`, kept with the other conformances.
- `Sources/OpenUsage/Services/HTTPClient.swift:78-79`: `URLSessionHTTPClient` logs a body preview on >= 400; add a `logsErrorBodies` flag (default true) so the hub client's default transport never logs hub bodies.
- New `Tests/OpenUsageTests/CLIProxyHubClientTests.swift`.

## Plan

1. Tests first with `RoutingHTTPClient` (TestSupport.swift:563) faking the hub: prefixed URL, auth header, timeout, auth-files filtering, api-call request shape, envelope unwrap (string body, double-encoded string body, object body), non-2xx envelope passed through as a response, management 401/403 → bad key, management 5xx → HTTP N, URLError mapping (timeout, cert, unreachable), key absent from error text and from the AppLog file (AppLogTests.swift sink pattern).
2. Implement the client and adapter; then the parity test: local fixture bodies (ClaudeProviderTests.swift:180, CodexProviderTests.swift:61) wrapped in an envelope, fetched through `ClaudeUsageClient`/`CodexUsageClient` on the adapter, mapped lines equal the lines of the raw local response.

## Prior-art tests to copy

- `RoutingHTTPClient` / `FakeHTTPClient` in TestSupport.swift; mapper fixtures in ClaudeProviderTests.swift and CodexProviderTests.swift; log-file sink in AppLogTests.swift.

## Defaults taken

- t3code's `cliproxyApi.test.ts` and the `usage-limits-hub` fixture live outside this repo and were not read; fixtures are written from the contract in the plan doc. Worth diffing against t3code in review.
- `auth_index` is decoded as a string (a number is accepted and kept as its text) and sent back as a string.
- Envelope `header` values may be a string or a string array (Go `http.Header`); arrays are joined with ", ", keys lowercased.
- Error categories reuse existing `ErrorCategory` values (no new telemetry strings): unreachable/timeout/untrusted certificate → `network`, bad key → `authInvalid`, HTTP N → `http(N)`, bad envelope → `decoding`.
- Management 401 and 403 both mean "bad key". An envelope `status_code` is never an error here; the mapper or runtime decides.
- The upstream request's own timeout is ignored; every management call uses 15 s.

## Risks

- The `auth_index` type and header shape are from memory of CLIProxyAPI, not checked against a live hub here.
