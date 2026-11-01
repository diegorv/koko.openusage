# 05 Discovery: Relaunch Prompt When Hub Accounts Change

No `spec.md`; contract from `docs/research/cliproxy-hub-plan.md:51` ("Hub accounts changed — Relaunch" prompt, no live rebuild). Builds on `work/03` (`CLIProxyHubAccountSync.run`).

## Files

- `Sources/OpenUsage/Providers/CLIProxyHub/CLIProxyHubAccountSync.swift:8-35`: `run` returns `Bool` (`@discardableResult`): true when some hub's cached account set changed and was saved. New `static func accountSetChanged(cached:fetched:) -> Bool` compares `Set(account.id)` (the card identity is `cliproxy:<hub>:<account.id>`). Reorder or metadata-only change (email, plan) still rewrites the cache (as today) but is not a change. A failed list or failed save is never a change.
- New `Sources/OpenUsage/Providers/CLIProxyHub/CLIProxyHubRelaunchNotice.swift`: `@MainActor @Observable` store, `isPending` (in memory, this launch only), `markChanged()`, `dismiss()`, and `relaunch()` (waits for this PID to exit, then reopens the bundle, so `SingleInstanceGuard`'s lowest-PID rule doesn't make the new copy yield; then `NSApp.terminate`).
- `Sources/OpenUsage/App/AppContainer.swift:71`: container owns the notice; the sync task marks it when `run` returns true.
- New `Sources/OpenUsage/Views/HubAccountsChangedCard.swift`: `DismissableHintCard`, title "Hub Accounts Changed", button "Relaunch".
- `Sources/OpenUsage/Views/DashboardContentView.swift:27`: show the card (with the update banner's transition/animation).
- `docs/providers/cliproxy-hub.md:29`: mention the notice.
- `Tests/OpenUsageTests/CLIProxyHubAccountSyncTests.swift`: change-detection tests.

## Tests (prior art: the existing sync tests, `NewVersionNoticeTests`)

- Added, removed, or hub-disabled account -> true. Unchanged list -> false. Reordered / email-only change -> false (cache still written). Failure (500, unreachable) -> false. Disabled hub -> false.
- Notice store: `markChanged` sets pending, `dismiss` clears.

## Defaults taken

- "Set of accounts" = set of account ids per hub. Usage isn't cached, so it can't trigger.
- Dismiss (x) hides the notice for this launch only; the next sync re-raises it only if the list differs again (the cache was already saved, so normally it won't).
- Neutral (untinted) card, glyph `arrow.clockwise.circle`, like the update banner.

## Risks

- Relaunch spawns `/bin/sh` to wait on the PID then `open` the bundle; unbundled `swift run` relaunches the executable directly. Not unit-testable; checked by hand.
- Screenshot needs the owner's hub (or a hand-edited cache) and a running app; may not be possible here.
