# 06 Discovery: Hub Wins Over the Same Local Account

No `spec.md`; contract from `docs/research/cliproxy-hub-plan.md` ("Dedup" decision). Builds on `work/02`
and `work/04` (hub cards from the cache, `CLIProxyHubCards.Runtimes`).

## Files

- `Providers/DefaultAccountObserver.swift:75-109`: `observeClaudeAccount()` returns the outcome plus the
  state file's `emailAddress`; `observeClaude()` keeps its signature and returns the outcome only.
- `Services/ProviderAccountDiscoveryReadout.swift:4-9,66-101`: `Claude.defaultEmail` (defaulted, so
  existing inits compile), filled by `readClaude`.
- `Services/ProviderAccountAssembly.swift:20-27,110-273`: stores `claudeEmailsByUser` (account UUID →
  email, from the default login and Swap slots) and `codexDefaultEmail` (the plain Codex outcome label,
  which is exactly the token email). Computed `localAccounts: [CLIProxyHubLocalAccount]` lists every local
  Claude/Codex card id with its email (Claude) or ChatGPT account id + email (Codex), including the plain
  `claude`/`codex` card when no account cards exist.
- New `Providers/CLIProxyHub/CLIProxyHubLocalMatch.swift`: `CLIProxyHubLocalAccount` and
  `hiddenLocalCardIDs(local:hubAccounts:)`. Claude: emails equal (trimmed, case-insensitive). Codex: both
  ids known → ids equal; otherwise emails equal. Logs each hidden card id (no email in the log).
- `CLIProxyHubCards.swift:9-14`: `Runtimes.accounts` (hub accounts of the built cards = enabled hubs only).
- `Providers/ProviderCatalog.swift:7-14,97`: `hiddenLocalCardIDs: Set<String> = []`, filtered out of the result.
- `App/AppContainer.swift:85`, `Services/UsageReader.swift:59`: compute and pass the hidden set.
- `docs/provider-enablement.md`, `docs/providers/cliproxy-hub.md`: explain the rule.

## Plan

The local card is simply not built at launch; its enablement, layout and known-id entries are left as they
are, so removing/disabling the hub (no enabled hub → no hub accounts → nothing hidden) restores it next launch.

## Tests (prior art: `ProviderAccountAssemblyTests` FakeFiles observer, `CLIProxyClaudeRuntimeTests` catalog)

- Match: Claude same email (case differs); Codex same account id; Codex hub without id falls back to email.
- No match: different email; Codex ids differ though emails equal.
- Disabled hub: runtimes of a disabled hub hide nothing.
- Catalog drops only the hidden id; assembly `localAccounts` carries the default Claude email and Codex id.

## Defaults taken

- A Claude email matches every local card of that email (all of its orgs), per "match by email".
- Desktop-org cards get the email of the default login or Swap slot with the same account UUID; none → no match.
- Plain Codex that only resolves from a sibling home / pi has no identity at assembly → never hidden.

## Risks

- Hiding all orgs of one email may hide a Team org the hub doesn't hold; owner rule says email.
