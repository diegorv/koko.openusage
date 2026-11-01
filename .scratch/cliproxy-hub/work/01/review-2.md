VERDICT: APPROVED

## Previous findings

| # | Severity | Status | Evidence |
|---|----------|--------|----------|
| 1 | major | resolved | `send` maps 401 to `.badKey` and 403 to a new `.accessDenied` (CLIProxyHubClient.swift:161-162). `.accessDenied` has its own copy (line 45) and maps to `.authInvalid` (ErrorCategory.swift:275). `testInvalidOrMissingKeyIsReportedAsBadKey` and `testForbiddenManagementIsReportedAsAccessDenied` cover both statuses and pass. |
| 2 | major | rejection stands | The `authFiles` fixture now has the shape of a real `ListAuthFiles` response (`observed_at`, `name`, `type`, `status`, ..., and an `id_token` with only `chatgpt_account_id`/`plan_type`), Tests/OpenUsageTests/CLIProxyHubClientTests.swift:10-25. The verbatim t3code port is still missing. The fix step's reason holds: the fixtures live outside this repository, no path was given, and the user's rules forbid searching outside the working directory. Another fix round can't close this. The owner has to give the path or waive the provenance clause, so the criterion stays `[not met]` for deliver to report. |
| 3 | major | resolved | `testDefaultTransportNeverLogsErrorBodies` unwraps the default `http` as `URLSessionHTTPClient` and asserts `logsErrorBodies == false`. It would fail if the default went back to `URLSessionHTTPClient()`. It passes. |
| 4 | minor | resolved | `testErrorsMapToTheirCategories` covers every case, including `.accessDenied`, `.httpStatus(404)` → `.http4xx` and `.httpStatus(502)` → `.http5xx`. It passes. |
| 5 | minor | resolved | A 4xx `.httpStatus` now gets its own copy, which points at the hub URL and the hub account (CLIProxyHubClient.swift:38-39). 5xx keeps "Try again later". Covered by `testClientErrorCopyPointsAtTheHubNotARetry`. The redaction test's error list now includes 404 and `.accessDenied`. |
| 6 | minor | resolved | `provider` falls back to `type` (CLIProxyHubClient.swift:89-91), so a disk-fallback entry with no `id`/`auth_index` now counts toward the "skipped N entries" warning. `testDiskFallbackEntriesWithoutAnIDAreCountedInTheWarning` asserts the log line and passes. The `codex-n.json` entry has only `type` and is still listed. |
| 7 | nit | resolved | The NOTE in HTTPClient.swift:25-30 now mentions `logsErrorBodies = false`. |

## Acceptance criteria

- [met] Errors are friendly and categorized: unreachable, timeout, HTTP N, bad key, untrusted certificate. The management key, bodies and headers never appear in errors or logs. — Each case has friendly copy, and the 401/403 split is correct (finding 1). Categories are tested (`testErrorsMapToTheirCategories`). Redaction is covered by `testKeyBodiesAndHeadersNeverReachErrorsOrLogs` (now also over 404 and `.accessDenied` copy) and by `testDefaultTransportNeverLogsErrorBodies` for the production transport. `swift test --filter CLIProxyHubClientTests`: exit 0, 19 tests, 0 failures.
- [not met] Tests (test-first, using the fixtures from t3code's `cliproxyApi.test.ts` and `usage-limits-hub` fixture) cover a prefixed URL, a bad key, a non-2xx envelope, a double-encoded body and key redaction. — All five scenarios are covered and pass, and the new tests came before the fix (the `accessDenied` case did not exist yet, so they could not compile). The fixtures are still not ported from t3code: they are hand-built to match CLIProxyAPI's source. This needs an owner decision (finding 1 below).
- [met] `auth-files` lists accounts and keeps only enabled `claude`/`codex` entries, with `id`, `auth_index`, `email` and the Codex `id_token` fields. — The `type` fallback leaves `provider` taking precedence. Disabled and non-Claude/Codex entries are still dropped. `testAuthFilesKeepsOnlyEnabledClaudeAndCodexAccounts` passes on the realistic fixture.

## Findings

1. **minor** (owner decision, carried from previous finding 2): Tests/OpenUsageTests/CLIProxyHubClientTests.swift:10-25. The fixtures are not t3code's verbatim. Fix: the owner gives the path to t3code's `cliproxyApi.test.ts` / `usage-limits-hub` fixtures so they can be ported, or waives the provenance clause of the criterion.
2. **nit**: Sources/OpenUsage/Providers/CLIProxyHub/CLIProxyHubClient.swift:17,106. The fixture no longer sends `chatgpt_plan_type`, since CLIProxyAPI's `id_token` has only `chatgpt_account_id`/`plan_type`. So `chatgptPlanType` is now parsed but no test covers it, and the real hub probably never fills it. Fix: drop the field, or keep it and add a fixture entry that carries it if some hub version emits it.
3. **nit**: Tests/OpenUsageTests/CLIProxyHubClientTests.swift:237-249. `testKeyBodiesAndHeadersNeverReachErrorsOrLogs` still sets up the log sink inline, which duplicates the new `captureLog` helper (line 337). Fix: use `captureLog` there.

## Other checks

- Typecheck: `swift build` exit 0.
- `swift test --filter CLIProxyHubClientTests`: exit 0, 19 tests, 0 failures.
- `swift test --filter 'HTTPClient|LogRedactionTests|AppLogTests|ErrorCategory'`: exit 0, 32 tests, 0 failures.
- Full suite not run; deliver runs it.
- Regressions and scope: no tests were weakened or deleted. The old 401/403 test was split into two stricter tests. The only source changes are in CLIProxyHubClient.swift, ErrorCategory.swift and one comment in HTTPClient.swift, all tied to findings 1, 4, 6 and 7. Adding the `CLIProxyHubError.accessDenied` case left no switch non-exhaustive (the build passes).

## Resolution

1. Rejected (not fixable in this run): porting t3code's fixtures verbatim needs their path, which lives outside this repository, and the user's rules forbid searching outside the working directory. The owner must give the path or waive the provenance clause; the criterion stays `[not met]`.
2. Fixed: dropped `CLIProxyHubAccount.chatgptPlanType` and its `chatgpt_plan_type` parse, since CLIProxyAPI's `id_token` carries only `chatgpt_account_id`/`plan_type`.
3. Fixed: `testKeyBodiesAndHeadersNeverReachErrorsOrLogs` now uses the `captureLog` helper instead of setting up the log sink inline.
