# 05: Relaunch Prompt When Hub Accounts Change

**What to build:** When the background sync finds a hub account list different from the cached one, OpenUsage tells the user with a "Hub Accounts Changed" notice and a Relaunch action. Owner decision: no live rebuild.

**Blocked by:** 03

**Status:** resolved

- [x] A change is detected by comparing the set of accounts (added, removed or disabled) per hub. A change in usage alone never triggers it.
- [x] The notice matches the existing design language, uses title case for its title, and has a Relaunch action that restarts the app.
- [x] No notice appears when the list is unchanged or the sync failed.
- [x] Tests cover change detection.
- [x] A screenshot of the notice is ready for the PR.

## Comments

- 2026-11-01, branch `issue/05-relaunch-prompt-on-account-changes`: added a "Hub Accounts Changed" notice with a Relaunch action, raised when the background sync finds a changed account set per hub (added, removed or disabled; usage-only changes and failed syncs never raise it). Fix round: a relaunch that cannot start now keeps the notice and tells the user to quit and reopen. Tests: `swift build` exit 0; `CLIProxyHubAccountSyncTests` 18 tests, 0 failures; full suite at 74a80a07 exit=0 (OpenUsageTests 1735 tests, 4 skipped, 0 failures; OpenUsageCLITests 4 tests, 0 failures). Reviews: round 1 APPROVED, round 2 APPROVED (two nits left: doc clause on relaunch failure, failure-state screenshot).
