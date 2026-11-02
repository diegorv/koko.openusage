# Issue 01 discovery: one merged card per provider

Files that change
- `Sources/OpenUsage/Models/WidgetData.swift:21` `let used` -> `var used`; add `accountTicks` field.
- new `Sources/OpenUsage/Models/AccountMerge.swift`: `MergedAccount`, `AccountTick`, pure `WidgetData.merging(_:)`.
- `Sources/OpenUsage/Stores/LayoutStoreModels.swift:3` `ProviderGroup` gains `accounts: [MergedAccount]` + `memberIDs`.
- `Sources/OpenUsage/Stores/LayoutStore+Customization.swift:55` `displayGroups` folds a family (`ProviderAccountID.families`) with 2+ enabled accounts into one group.
- `Sources/OpenUsage/Stores/WidgetDataStore.swift:595` add `data(for:in group:)` that maps the base descriptor to each account's descriptor and merges.
- `Sources/OpenUsage/Views/WidgetGroupedListView.swift` rows/lift use the group-aware data; legend row; header actions span all accounts.
- `Sources/OpenUsage/Views/WidgetRowView.swift:451` meter overlays per-account ticks (new small view file to stay under 500 LOC).
- `Sources/OpenUsage/Support/ShareCardRenderer.swift:72` share uses group-aware data.
- `docs/dashboard.md` explains the merged card.

Plan
1. Test-first pure merge: percent = average over accounts with data (`hasData`), dollars/count and `.values` = sum, chart points summed by label, reset = soonest (with that account's period), each account keeps a tick (used/limit, color index, short name). One reading -> returned unchanged.
2. Test-first `displayGroups`: family with 2+ enabled accounts -> one group at the base account's position. Base account = the bare family id (`claude`) when registered, else the family's first provider. Its metric ids drive enabled/order/expanded, even if the base account itself is disabled (then its data is left out of the merge). A family with 0-1 enabled accounts goes through the old per-provider path unchanged.
3. UI: tick overlay + legend (short name: display name minus the family prefix, email local part).
4. Docs + targeted checks.

Prior-art tests: `Tests/OpenUsageTests/LayoutStoreTests.swift:1023` (displayGroups), `CodexSwapAccountTests.swift:95` (asserts every account is its own display group -> updated to the merged group).

Defaults taken
- Merged header name: family name ("Claude"/"Codex"); plan/notice/staleness = first account that has one; Hide/Refresh act on every account.
- Legend goes after the last metric row. Tick colors: a fixed palette of system colors (not blue/yellow/red, which carry severity), by account order.
- Model breakdown popover is dropped on merged rows with 2+ contributing accounts (no per-model sum yet). Badge rows (text overrides) show the first account's text.
- Customize L2 of a non-base account still lists its own metrics; they no longer affect the merged card.
- Menu bar untouched (Issue 02).

Risks: pace verdict on an averaged value with the soonest reset is an approximation.
