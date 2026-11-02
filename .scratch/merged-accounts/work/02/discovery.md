# Issue 02 discovery: menu bar shows the merged value

Repeats Issue 01's pattern (`.scratch/merged-accounts/work/01/`): the family fold in `LayoutStore.displayGroups`
and the merge read in `WidgetDataStore.data(for:in:)`. What differs: the menu bar's input is
`LayoutStore.pinnedGroups` (`[ProviderMetrics]`), not `displayGroups`.

Files that change
- `Sources/OpenUsage/Stores/LayoutStoreModels.swift:43` `ProviderMetrics` gains `accounts: [MergedAccount] = []`.
- `Sources/OpenUsage/Stores/LayoutStore+Customization.swift:185` `pinnedGroups` folds a merged family
  (same `familyMerges`) into one entry at the base account's place: family name, base icon, the base
  account's pins (`claude.weekly`), `accounts` set. Other accounts' pins add nothing. Families with 0-1
  enabled accounts take the old path.
- `Sources/OpenUsage/Stores/WidgetDataStore+MergedAccounts.swift` share the merge read between
  `ProviderGroup` and `ProviderMetrics` (provider id + accounts).
- `Sources/OpenUsage/Models/MenuBarContent.swift:63` `build(groups:data:)`: the data closure also gets the
  group, so the caller can read the merged value.
- `Sources/OpenUsage/App/StatusItemImageUpdater.swift:69` passes `dataStore.data(for:in:)`.
- `docs/menu-bar.md` a short "Several accounts" section.

Plan (test-first)
1. `MenuBarPinTests`-style test in `MergedProviderGroupTests`/new `MergedMenuBarTests`: two Claude accounts
   with base pins -> one pinned group "claude" named "Claude" with the base metric ids; a non-base pin adds
   nothing; single-account family unchanged (provider, display name, own pins).
2. End-to-end: `WidgetDataStore` with two accounts (20%, 60%) + `pinnedGroups` + `MenuBarContentBuilder`
   -> one group, value "40%"; single-account family shows its own value.
3. Wire `StatusItemImageUpdater`; docs; screenshot (rendered strip image via `MenuBarStripRenderer`).

Prior-art tests: `Tests/OpenUsageTests/MenuBarPinTests.swift`, `MenuBarContentTests.swift`,
`MergedProviderGroupTests.swift:testDataStoreMergesEachAccountsReading`.

Defaults taken
- Base account disabled but 2+ others on: the merged item still uses the base account's pins
  (matches the merged card, which uses the base account's metric settings).
- Accessibility text / display name of the merged item is the family name ("Claude").
- Per-provider 2-star cap is unchanged (still counted per account id); non-base pins are kept in
  storage, just not rendered while the family is merged.

Risks: a user who only starred a non-base account's metrics loses those items while merged (by design
per the criteria; documented).
