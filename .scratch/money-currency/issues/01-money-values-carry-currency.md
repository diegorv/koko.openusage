# 01: Money Values Carry Their Currency

**What to build:** Money metrics are assumed to be USD everywhere (`MetricKind.dollars`, `ProgressFormat.dollars`, `MetricFormatter`, and the CLI's `unit: "usd"`). Claude's `/api/oauth/usage` returns `extra_usage.currency` (for example `"BRL"`, with `decimal_places: 2`), so a R$ 20,00 cap shows as $20. Add an optional ISO 4217 currency code to money values, defaulting to USD when absent so every other provider and every persisted snapshot keep working, and have the Claude mapper (`Sources/OpenUsage/Providers/Claude/ClaudeUsageMapper.swift`, `appendExtraUsage`) fill it from `extra_usage.currency`. Owner decision (2026-11-01): the currency travels with the value rather than being a Claude-only display patch.

**Blocked by:** none

**Status:** ready-for-agent

- [ ] Money values (progress and plain values) can carry an optional currency code; a missing code means USD, and snapshots persisted before this change still decode as USD.
- [ ] Claude's "Extra usage spent" line uses `extra_usage.currency` (and `decimal_places` for the minor-unit conversion when present); an absent or empty currency stays USD.
- [ ] `MetricFormatter` formats money in its currency (BRL shows as R$, USD as $), in the dashboard, the menu bar and the compact forms.
- [ ] The CLI JSON for Claude `extraUsage` reports the real currency as its `unit` (lowercase ISO code, such as `"brl"`); other providers still report `"usd"`.
- [ ] Tests (test-first) cover a BRL payload, a USD payload, a payload without `currency`, and decoding an old snapshot without a currency.
- [ ] Docs in `docs/` that describe money or the CLI's `unit` field are updated.

## Comments
