# 02: Menu Bar Shows the Merged Value

**What to build:** The menu bar shows one item per provider family instead of one per account, with the merged (average) value from Issue 01's merge step for each pinned metric. Read `.scratch/merged-accounts/spec.md`.

**Blocked by:** 01

**Status:** resolved

- [x] A family with several accounts shows one menu-bar item: the provider mark plus the merged value of each pinned metric (stacked when two are pinned, as today).
- [x] Pins are read from the family's base metric ids; per-account pins no longer add extra items.
- [x] A single-account family looks exactly as before.
- [x] Tests (test-first) cover two accounts merged into one item and a single-account family unchanged.
- [x] Docs describing the menu bar are updated.
- [x] A screenshot of the menu bar with merged Claude accounts is ready for the PR.

## Comments

- 2026-11-02, branch issue/02-merged-menu-bar: the menu bar shows one item per provider family with the merged value of each pinned base metric; single-account families unchanged; docs and render screenshots added. Fix round added a test for two stacked base pins in one merged item. Tests: `swift build` exit 0; MergedMenuBarTests 4 tests, 0 failures; full `swift test` exit 0 (1798 tests, 4 skipped, 0 failures; CLI 4 tests, 0 failures). Reviews: round 1 APPROVED, round 2 APPROVED. Open for the owner: confirm in the running app with two Claude accounts; starring a non-base account while merged does nothing (follow-up decision).
