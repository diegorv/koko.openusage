# 02: Menu Bar Shows the Merged Value

**What to build:** The menu bar shows one item per provider family instead of one per account, with the merged (average) value from Issue 01's merge step for each pinned metric. Read `.scratch/merged-accounts/spec.md`.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] A family with several accounts shows one menu-bar item: the provider mark plus the merged value of each pinned metric (stacked when two are pinned, as today).
- [ ] Pins are read from the family's base metric ids; per-account pins no longer add extra items.
- [ ] A single-account family looks exactly as before.
- [ ] Tests (test-first) cover two accounts merged into one item and a single-account family unchanged.
- [ ] Docs describing the menu bar are updated.
- [ ] A screenshot of the menu bar with merged Claude accounts is ready for the PR.

## Comments
