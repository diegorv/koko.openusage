# 04: Merged Rows Show One Slot per Account

**What to build:** On a merged card, each bounded percent row shows the accounts composing the total, replacing the average bar with ticks and the legend (revision in `spec.md`). The prototype is on branch `prototype/merged-card-capacity` (`prototypes/merged-card-capacity.html?scenario=mixed&layout=slots`).

**Blocked by:** none

**Status:** ready-for-agent

- [ ] The bar is split into one equal slot per account, each filled to that account's own value in its `AccountColors` color. An account without the metric gets no slot.
- [ ] The row header shows the combined value, the average of the accounts' values.
- [ ] Under the bar, one line per account shows its color dot, short name, its value and its own reset.
- [ ] Merged percent rows drop the ticks, the card legend and the pace projection ("Limit in …"), and the code those changes orphan is removed.
- [ ] Money, count and chart rows, and single-account cards, render as before.
- [ ] The menu bar item keeps the combined value.
- [ ] Tests (test-first) cover: the account values kept for the slots and lines, each account's own reset, an account missing a metric, and a single-account family unchanged.
- [ ] `docs/dashboard.md` and `docs/menu-bar.md` describe the new row.
- [ ] A screenshot of a merged Claude card is ready for the PR.

## Decisions (owner, 2026-11-05)

- Used/Left: the row follows the global setting (`WidgetDataStore.meterStyle`), so values and fills flip together.
- Low quota: the combined value in the header takes the severity color.
