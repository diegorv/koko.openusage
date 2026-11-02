VERDICT: APPROVED

## Previous findings

| # | Severity | Status | Evidence |
|---|----------|--------|----------|
| 1 | blocker | resolved | `ProviderGroup.resetClaimProviderID` (`LayoutStoreModels.swift:17`) is nil when `accounts` is non-empty; the only consumer of `\.resetClaims` for rows (`WidgetGroupedListView.swift:255`) now goes through it, so a merged popover gets no claim closure (`WidgetRowView.swift:379` maps `resetClaim` to `claim`). No other row path reads `resetClaims`. `testMergedCardClaimsNoResetCredit` covers merged (nil), a plain provider and a family with one account on (base id). Docs note the read-only popover. |
| 2 | major | resolved | `shortName` strips a trailing ` (…)` (searching backwards, so an org name with its own parentheses survives) before the `@` cut. `testShortNameOfEachRealAccountNameFormat` builds names from the real `ClaudeSwapAccount.displayName()`, `CodexSwapAccount.displayName` (alias and bare) and `CLIProxyHubCards.displayName`. Passes. Collisions this exposes are new finding 1. |
| 3 | minor | resolved | `claude.md:95-96`, `codex.md:60-61`, `cliproxy-hub.md:45-47` now say Customize entry / account, and the hub line says the entries share the family's merged card. |
| 4 | minor | resolved (partial, rejection stands for the view fan-out) | Three new tests: missing account descriptor (`MergedProviderGroupTests.testAccountWithoutTheMetricsDescriptorIsLeftOutOfTheMerge`), reorder and On Demand split with the base account off. The Hide/Refresh fan-out is a `for id in group.memberIDs` loop in a SwiftUI view with no view-test harness; `memberIDs` is asserted elsewhere. That holds. |
| 5 | minor | resolved (fill rule left for owner, rejection stands) | `AccountMerge.swift:72-78` sums only meters in the first account's currency and logs a warning; `testMoneyMeterInAnotherCurrencyIsLeftOutOfTheSum` gives 30/200. Keeping sum(used)/sum(limit) for bounded money/count bars follows the spec's "money and count merge as the sum". Criterion 3's "average fill" reads as the percent rule. Reasonable, and the owner can still decide. |
| 6 | nit | resolved | `WidgetRowView.swift` is 500 lines; the overlay is `View.accountTicksOverlay` in `AccountTicksView.swift`, with the same condition as before. |
| 7 | nit | resolved | `testDataStoreMergesEachAccountsReading` is `async throws` with `try`. |
| 8 | nit | resolved | `registry` is `private` again (`WidgetDataStore.swift:15`); narrow `descriptor(id:)` at `:596`. |

## Acceptance criteria re-checked

- [met] A pure merge step (no UI) folds the `WidgetData` of a family's accounts into one per metric: percent metrics average over the accounts that have the metric, money and count metrics sum, the reset is the soonest, and each account's own value is kept for its tick. — `WidgetData.merging` still Foundation-only. The currency guard only removes amounts that can't be added, and the ticks are unchanged. `AccountMergeTests` passes.
- [met] Bounded rows of a merged card draw the average fill in the existing severity color plus one tick per account in a per-account color, and the card shows a compact legend (account short name + color). — The overlay was moved, not changed (`accountTicksOverlay`). Legend short names are now correct for every real name format (`testShortNameOfEachRealAccountNameFormat`). Names can collide (finding 1).
- [met] Customize, enablement and metric order still work: they act on the family's base metric ids, and disabling an account's provider id removes it from the merge. — `testReorderingAMergedCardMovesTheBaseMetrics` and `testOnDemandSplitFollowsTheBaseMetrics` (base account off) pass, as do the earlier enablement tests.
- [met] Tests (test-first) cover: two Claude accounts (average and ticks), an account missing a metric, a money metric summed, soonest reset, and a single-account family unchanged. — Earlier tests are unchanged, plus the store-level missing-descriptor test. Targeted suites pass; the full suite is deliver's to run.
- [met] Docs in `docs/` that describe accounts or the dashboard explain the merged card. — The stale per-card lines are reworded, and `dashboard.md` explains the read-only resets popover.

## Findings

1. **minor** — `Sources/OpenUsage/Models/AccountMerge.swift:19-21`: the legend name drops the email, so two accounts with the same label get the same name. Cases: two Claude Swap accounts in one organization ("Acme Org" twice); two Codex users in one workspace without an alias ("Workspace ab12cd34" twice), which `docs/providers/codex.md` says stay separate accounts; and the same email on two hubs ("alice" twice). In each case only the tick color tells them apart. Fix: when two accounts in a family get the same short name, fall back to the email local part (or append it) for those accounts. Do this in `familyMerges`, where all the names are known, and add a test.
2. **nit** — `Sources/OpenUsage/Models/AccountMerge.swift:75`: `AppLog.warn` runs inside `merging`, which the views call on every render (`WidgetGroupedListView.swift:181,357,362`). A currency mismatch would write the same warning to the log file on every redraw. Fix: log it once per refresh (for example from the data store after a snapshot lands), or remove duplicate messages.

## Checks run

- `swift build`: exit 0.
- `swift test --filter 'AccountMergeTests|MergedProviderGroupTests|LayoutStoreTests|WidgetDataStoreTests|WidgetDataStoreAccountCacheTests|WidgetDataStorePlanTests|ShareCardRendererTests|ClaudeSwapAccountTests|CodexSwapAccountTests|CLIProxyHubAccountSyncTests|ClaudeResetClaimTests|CodexResetClaimTests|WidgetMeterStyleTests|MeterSeverityTests|ProviderHeaderLayoutTests'`: exit 0, 201 tests, 0 failures, 1 skipped (the live dry-run claim test).
- No test was deleted or weakened in the fix commits (`git diff 45e182ea..HEAD -- Tests` only adds tests and changes `try!` to `try`).
- Full suite not run; deliver runs it. The app was not run, so the read-only popover was not checked on screen.

## Resolution

1. **minor (legend name collisions)** — fixed. `MergedAccount.shortNames(displayNames:familyName:)`, called from `familyMerges`, keeps the trailing detail (cut to an email's local part) for names two accounts share: "Acme Org (alice)" / "Acme Org (bob)", "Workspace ab12cd34 (bob)", "carol (Hub lab)". Tests: `MergedProviderGroupTests.testCollidingLegendNamesKeepTheirDetail`, `AccountMergeTests.testShortNameKeepingDetailAddsTheEmailLocalPartOrHubLabel`. `docs/dashboard.md` notes it.
2. **nit (repeated currency warning)** — fixed by removing duplicates: the warning goes through `MergeWarnings.warnOnce`, which writes each distinct message once per run. Test: `AccountMergeTests.testCurrencyMismatchIsLoggedOncePerDistinctMessage`.
