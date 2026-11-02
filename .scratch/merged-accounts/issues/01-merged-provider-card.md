# 01: One Merged Card per Provider

**What to build:** In the panel, all accounts of a provider family render as ONE card (layout "H" in `spec.md`): per metric, a single bar filled to the average percentage of the accounts, with a colored tick per account at its own percentage and a small legend mapping colors to accounts. It replaces the per-account cards. Money and count metrics show the sum. Read `.scratch/merged-accounts/spec.md` first; the prototype is on branch `prototype/hub-panel-windows` (`prototypes/hub-panel-windows.html?variant=H`).

**Blocked by:** none

**Status:** resolved

- [x] A pure merge step (no UI) folds the `WidgetData` of a family's accounts into one per metric: percent metrics average over the accounts that have the metric, money and count metrics sum, the reset is the soonest, and each account's own value is kept for its tick.
- [x] The dashboard shows one card per provider family; per-account cards are no longer shown. A family with a single account renders exactly as before (no ticks, no legend).
- [x] Bounded rows of a merged card draw the average fill in the existing severity color plus one tick per account in a per-account color, and the card shows a compact legend (account short name + color).
- [x] Customize, enablement and metric order still work: they act on the family's base metric ids, and disabling an account's provider id removes it from the merge.
- [x] Tests (test-first) cover: two Claude accounts (average and ticks), an account missing a metric, a money metric summed, soonest reset, and a single-account family unchanged.
- [x] Docs in `docs/` that describe accounts or the dashboard explain the merged card.
- [x] A screenshot of a merged Claude card is ready for the PR.

## Comments

- 2026-11-02, branch `issue/01-merged-provider-card`: all accounts of a provider family now render as one merged card (average fill, per-account ticks, legend; money/count summed, soonest reset). Fix round after review 1: merged cards no longer claim reset credits, short names handle Swap display names, docs reworded, extra tests, mixed-currency meters left out of sums, tick overlay split out, `registry` private again. Tests: full suite at f5f612a5 exit=0, 1794 tests, 0 failures. Reviews: round 1 CHANGES_REQUESTED, round 2 APPROVED, round 3 APPROVED. Open for the owner: bounded money/count bars fill as sum(used)/sum(limit).
