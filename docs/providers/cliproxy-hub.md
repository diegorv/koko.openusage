# CLIProxyAPI Hub

Shows the Claude and Codex accounts held by a CLIProxyAPI hub, each as its own account, with live limits read through the hub. On the dashboard they join the other accounts of their family on one merged card (see [Several accounts of one provider](../dashboard.md#several-accounts-of-one-provider)). The hub keeps the account tokens; OpenUsage only ever sends the
hub's management key.

## Setup

Add a hub in Settings → CLIProxyAPI Hubs → Add Hub (see [Settings](../settings.md#cliproxyapi-hubs)). Hubs are
saved in `~/.config/openusage/cliproxy.json`, which can also be edited by hand:

```json
{
  "hubs": [
    {
      "id": "cliproxy-home",
      "label": "Home",
      "url": "https://hub.example.ts.net",
      "managementKey": "…",
      "enabled": true,
      "accounts": [
        { "id": "claude-a.json", "authIndex": "a1b2c3", "provider": "claude", "email": "a@example.com" }
      ]
    }
  ]
}
```

- `accounts` is the hub's account list as OpenUsage last saw it. Cards are built from this list at
  launch, so launch never waits on the hub, and a hub that's down still shows its cards (with an error).
- After launch, OpenUsage asks each enabled hub for its accounts in the background and saves the list
  into `accounts`. Added accounts get cards from the next launch; accounts removed or disabled on the
  hub drop out. Disabled hubs are skipped.
- When that list adds or drops an account, the dashboard shows a "Hub Accounts Changed" notice with
  a Relaunch button, since cards only change on relaunch. A new email or plan on the same accounts,
  or a hub that can't be reached, shows no notice.
- Saving rewrites the whole file: every setting above keeps its value, but keys OpenUsage doesn't know
  are dropped, a left-out `enabled` is written as `true`, and the formatting is normalized.
- If a hub can't list its accounts, the old list is kept and the failure is logged ("The hub could not
  list accounts."). Its cards keep working.
- `enabled` and `accounts` can be left out: a hub is on by default and starts with no cards.
- The file holds management keys and is written readable by your user only.

## Cards

- One Customize entry per Claude or Codex account of each enabled hub, named **Claude: <email> (Hub <label>)** or
  **Codex: <email> (Hub <label>)**. Without a label, the hub's host name is used. Hub entries sit right
  after the local entries of their family; on the dashboard they share their family's merged card.
- A card's id stays the same as long as the hub id and account id do.
- A new hub card turns on the first time it appears. After that, your Customize toggle wins.
- On a fresh install, hub cards start off, like every provider. The welcome screen never finds or
  connects them, since it only looks at sign-ins on this Mac; turn them on in Customize.
- The new-provider check skips hub cards too.
- If the same account is also signed in on this Mac, only the hub card shows: the local card, and its
  spend history, is left out at launch. Claude accounts match by email; Codex accounts match by ChatGPT
  account id, or by email when either side lacks the id. Two seats of one ChatGPT Team workspace share
  the id, so when both sides have an email it must match too. See
  [Which Providers Are On](../provider-enablement.md#when-a-hub-holds-the-same-account).
- Hub cards also appear in the `openusage` CLI and the local HTTP API, as part of the `claude` or
  `codex` family.

## What it tracks

Limits only. Claude hub cards have the same defaults as the Claude card:

| Metric | Meaning |
|---|---|
| Session | 5-hour rolling window usage |
| Weekly | 7-day window usage |
| Fable | Separate weekly Fable limit |
| Sonnet | Separate weekly Sonnet limit (off by default) |
| Extra Usage | Extra-usage credits spent against your monthly cap |

Codex hub cards have the same defaults as the Codex card:

| Metric | Meaning |
|---|---|
| Session | 5-hour rolling window usage |
| Weekly | 7-day window usage |
| Spark / Spark Weekly | Separate GPT-5.3-Codex-Spark limits |
| Extra Usage | Flex credits, as dollars and credits |
| Rate Limit Resets | Reset credits available, as a count without expiry times. They can't be claimed from a hub card |

The Codex plan comes from the usage response, or from the account's sign-in on the hub when the
response has none.

There is no usage trend or spend history: those come from local logs, and this Mac's logs don't belong
to the hub's accounts. For the same reason a Codex hub card has no Cost Estimates section in Customize.
Claude rate limit resets aren't shown.

## Errors

- **Re-login this account on the hub** — Anthropic or OpenAI rejected the hub's login for that account. Sign it
  in again on the hub; OpenUsage never refreshes hub tokens itself.
- **Hub errors** (can't reach the hub, timeout, untrusted certificate, rejected management key, hub
  server error) — shown on every card of that hub at once. A refresh finds the failure once and
  shares it, instead of each card trying the hub separately.
- A problem with one account fails only that account's card.
- When Anthropic rate-limits a Claude account, its card keeps the last limits with an "Updates blocked"
  notice. A rate-limited Codex account shows an error until the next refresh, like the local Codex card.

OpenUsage sends at most 4 requests to a hub at a time.
