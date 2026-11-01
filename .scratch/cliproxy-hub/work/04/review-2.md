VERDICT: APPROVED

## Previous findings

| # | Severity | Status | Evidence |
|---|----------|--------|----------|
| 1 | minor | resolved | `CodexPricingSection.cardIDs(for:among:)` (Sources/OpenUsage/Views/CodexPricingSection.swift:18-24) drops `any CLIProxyHubCard`, keeps the `codex` family, and returns nil when `providerID` is not in that list. CustomizeProviderDetailView.swift:36-38 shows the section only when it is non-nil. That hides it on hub cards and leaves hub card ids out of the refresh list. Moving from `container.registry.providers` to `container.providers` does not change the set: `registry = WidgetRegistry.from(providers)` (AppContainer.swift:86). `CodexPricingSectionTests` (3 tests) covers a local card (ids = local Codex cards only), a hub card (nil) and another family (nil). docs/providers/cliproxy-hub.md was updated. |
| 2 | nit | resolved | CLIProxyHubCard.swift is a new file that holds the marker protocol `CLIProxyHubCard: ProviderRuntime {}` and `CLIProxyHubAccountError`, with the error text unchanged. Both runtimes still conform to it. The only uses are the `is any CLIProxyHubCard` checks (FirstLaunchSetup.swift:104, CodexPricingSection.swift:20). The build passes. |
| 3 | nit | resolved | `claudeRuntimes`/`codexRuntimes` were removed. No reference to them remains in Sources, Tests or docs. The test diffs in CLIProxyClaudeRuntimeTests and CLIProxyCodexRuntimeTests only swap the call for `runtimes(hubs:http:).claude/.codex`. No assertion was removed. |
| 4 | nit | resolved | `UsageReaderTests.testCodexHubCardLimitsAreServedUnderTheCodexFamily` reads a Codex hub card through `UsageReader.read(providerID: "codex")` and checks that there are no warnings and that `session`/`weekly` resources exist. It passes. |
| 5 | nit | rejection stands | The review asked for no change. The code was left as it was. |

## Acceptance criteria re-checked

- [met] It shows limits only, with metrics copying the Codex family's defaults. There is no history or spend, no token refresh, and no reset-credit claiming (out of scope for v1). — The fixes go further: Customize no longer shows the spend-only Cost Estimates section on Codex hub cards (`CodexPricingSectionTests.testHubCodexCardHasNoCostEstimates`). The `widgetDescriptors` and the runtime are unchanged. `CLIProxyCodexRuntimeTests` passes.
- [met] Tests cover the same guarantees as the Claude hub runtime (no refresh on 401, no local scans, `hasLocalCredentials` false). — The only change to CLIProxyCodexRuntimeTests and CLIProxyClaudeRuntimeTests is the call-site swap, so no test was weakened. Both suites pass, and so does `FirstLaunchSetupTests` (which relies on the moved marker protocol).
- [not met] Smoke test against the real hub's Codex account. — Still not run. It needs the owner's real hub, its management key and a rebuilt, relaunched app, which only the owner has. As in round 1, this does not hold back APPROVED.

## Checks run

- `swift build`: exit 0, no warnings.
- `swift test --filter 'CodexPricingSectionTests|UsageReaderTests|CLIProxyClaudeRuntimeTests|CLIProxyCodexRuntimeTests|FirstLaunchSetupTests|CLIProxyHubAccountSyncTests|CLIProxyHubClientTests'`: exit 0, 72 tests, 0 failures.
- Full suite not run; deliver runs it.
- No scope creep: the fix commit 6c559230 only touches the files named in the findings, their tests and docs/providers/cliproxy-hub.md.

## Findings

None open or new.

One question for the owner is still open from round 1, and it is not a finding: should a Codex hub card keep its last good limits after a 429, as the Claude hub card does?
