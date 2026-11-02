# 03: Hide Claude's Session Row When It Has No Data

**What to build:** Anthropic removed Claude's 5-hour limit: `/api/oauth/usage` now returns `five_hour: null` and `limits` lists only weekly kinds, so the Claude Session row (`Sources/OpenUsage/Providers/Claude/ClaudeProvider.swift:82`, `claude.session`) shows "— / No data" on every Claude card, merged or not. Owner decision (2026-11-02): keep the metric, but hide its row while no account has data for it, so it comes back by itself if Anthropic restores the window. Defaults (enabled, pinned, order) stay as they are.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] A descriptor can opt in to "hide while it has no data"; Claude's Session (`<id>.session` for every Claude account id) opts in, and no other metric changes behavior.
- [ ] On the dashboard, an opted-in row with no real data (`WidgetData` not backed by a provider metric) is not rendered, in single-account and merged cards alike; with data it renders as today.
- [ ] In the menu bar, a pinned opted-in metric without data is skipped, so a provider with Weekly pinned shows Weekly alone, as it does today.
- [ ] A provider card never ends up with no Always Visible row because of the hidden row (the caret/expansion still works).
- [ ] Tests (test-first) cover: Session hidden with `five_hour: null`, Session shown with `five_hour` present, a merged card where one account has Session data (shown), and another metric with no data still showing "No data".
- [ ] `docs/` notes that Claude's Session row hides while Anthropic reports no 5-hour window.

## Comments
