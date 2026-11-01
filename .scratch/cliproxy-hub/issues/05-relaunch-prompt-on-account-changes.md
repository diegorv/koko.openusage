# 05: Relaunch Prompt When Hub Accounts Change

**What to build:** When the background sync finds a hub account list different from the cached one, OpenUsage tells the user with a "Hub Accounts Changed" notice and a Relaunch action. Owner decision: no live rebuild.

**Blocked by:** 03

**Status:** ready-for-agent

- [ ] A change is detected by comparing the set of accounts (added, removed or disabled) per hub. A change in usage alone never triggers it.
- [ ] The notice matches the existing design language, uses title case for its title, and has a Relaunch action that restarts the app.
- [ ] No notice appears when the list is unchanged or the sync failed.
- [ ] Tests cover change detection.
- [ ] A screenshot of the notice is ready for the PR.
