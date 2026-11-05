# Merged Accounts

**Problem:** A provider with several accounts (local, Claude Swap, CLIProxy hub) shows one card and one menu-bar item per account. With two Claude accounts the panel repeats every metric twice and the menu bar shows two Claude icons. The owner wants one view per provider that folds the accounts together.

**Decisions (owner, 2026-11-02):**
- Layout "H" from the prototype: per metric, ONE bar whose fill is the average of the accounts' percentages (in the usual severity color), with a thin vertical tick per account at that account's own percentage, colored per account, and a small legend naming each account's color. Prototype: branch `prototype/hub-panel-windows`, file `prototypes/hub-panel-windows.html`, `?variant=H`.
- Every account of the same provider family is merged: local, Claude Swap and hub alike (family = `ProviderAccountID.family(of:)`).
- The merged card **replaces** the per-account cards in the panel. A family with one account looks as it does today (no ticks, no legend).
- The menu bar shows one item per family with the merged (average) value.
- Extra Usage stays hidden when it is off (no "Disabled" row).

**Revision (owner, 2026-11-05), replaces layout "H" for bounded percent rows:** with the average bar the owner could not read each account's quota. A merged row now shows one bar split into an equal slot per account, each slot filled by its own account in that account's color, with the combined value in the row header and one line per account under the bar (name, its value, its own reset). No ticks, no legend, no pace projection on these rows. A single-account card does not change. Prototype: branch `prototype/merged-card-capacity`, `prototypes/merged-card-capacity.html?scenario=mixed&layout=slots`. See Issue 04.

A merged row follows the global Used/Left setting, and its combined value takes the severity color, since bar colors now identify accounts.

**Defaults chosen by the main session (flag if wrong):**
- Percent metrics merge as the average of the accounts that have the metric; an account without the metric is left out of that metric's average and gets no tick.
- Money and count metrics (spend today, last 30 days, credits) merge as the sum.
- A merged metric's reset text is the soonest reset among the accounts.
- Metrics, their enablement, order, Always Visible / On Demand and pins keep using the family's base metric ids (`claude.weekly`, …); no new metric is added.

**Out of scope:** the quota-window timeline and the Extra Usage "Disabled" status from the first prototype round (rejected as too busy).
