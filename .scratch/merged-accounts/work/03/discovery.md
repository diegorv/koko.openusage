# Issue 03 discovery: hide Claude's Session row when it has no data

Builds on Issue 01's merged read (`.scratch/merged-accounts/work/01/`): `WidgetDataStore.data(for:in:)`
already folds accounts, and `WidgetData.merging` sets `hasData` when any account has the metric.

Files that change
- `Sources/OpenUsage/Models/WidgetDescriptor.swift:20` add `var hidesWithoutData = false` plus a
  `.hidingWithoutData()` builder (same style as `.exportingLimit`).
- `Sources/OpenUsage/Providers/Claude/ClaudeProvider.swift:82` Session opts in. `limitDescriptors` builds
  every Claude account id (local, Claude Swap, hub cards), so `<id>.session` opts in everywhere.
- New `Sources/OpenUsage/Stores/WidgetDataStore+HiddenRows.swift`: `shownGroup(_:descriptor:)` drops opted-in
  rows whose `data(for:in:)` has no data, then re-applies `LayoutStore.group`'s rule (Always Visible
  empty -> promote On Demand rows). If every row would be hidden it returns the group unchanged, so a card
  never loses all its rows.
- `Sources/OpenUsage/Views/WidgetGroupedListView.swift:31,340` render / reorder over shown groups.
- `Sources/OpenUsage/Support/ShareCardRenderer.swift:74` share card uses the shown group (covers the footer
  Share Screenshot menu in `HeaderView` too).
- Menu bar: `MenuBarContent.swift:65` already filters `hasData`, so no code change; a test pins it.
- Docs: `docs/providers/claude.md` (Session row), `docs/dashboard.md` short note.

Plan (test-first), new `Tests/OpenUsageTests/HiddenEmptyRowTests.swift`
1. Claude descriptors: `claude.session` / `claude@ab12cd34.session` opt in; Weekly etc. do not.
2. Real `ClaudeUsageMapper` body with `five_hour: null` -> Session dropped from the shown group; with
   `five_hour` present -> shown.
3. Merged card, one account with Session data -> shown.
4. Non-opted metric without data (Weekly) still in the group with `hasData == false` ("No data").
5. Session Always Visible + Weekly On Demand, Session hidden -> Weekly promoted to Always Visible.
6. Menu bar with Session + Weekly pinned and no Session data -> Weekly alone.

Prior art: `MergedMenuBarTests.swift` (layout + `TestProviderRuntime` data store),
`MergedProviderGroupTests.swift`, `ClaudeProviderTests.swift:ClaudeUsageMapperTests`.

Defaults taken
- Hiding happens at render time from live data, not in `LayoutStore` (it has no data); Customize still
  lists Session so it can be toggled.
- Only-row case: the row stays (shows "No data") instead of an empty card.
- Drag-lift preview uses the already-shown group passed to it.

Risks: reorder target ids come from the shown group, so a hidden row keeps its saved slot.
