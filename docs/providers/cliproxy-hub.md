# CLIProxyAPI Hub

Shows the Claude accounts held by a CLIProxyAPI hub, each on its own card, with live limits read through the hub. The hub keeps the account tokens; OpenUsage only ever sends the
hub's management key.

## Setup

Hubs live in `~/.config/openusage/cliproxy.json`:

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
- `enabled` and `accounts` can be left out: a hub is on by default and starts with no cards.
- The file holds management keys and is written readable by your user only.

## Cards

- One card per Claude account of each enabled hub, named **Claude: <email> (Hub <label>)**. Without a
  label, the hub's host name is used.
- A card's id stays the same as long as the hub id and account id do.
- A new hub card turns on the first time it appears. After that, your Customize toggle wins.
- On a fresh install, hub cards start off, like every provider. The welcome screen never finds or
  connects them, since it only looks at sign-ins on this Mac; turn them on in Customize.
- The new-provider check skips hub cards too.
- Hub cards also appear in the `openusage` CLI and the local HTTP API, as part of the `claude` family.

## What it tracks

Limits only, with the same defaults as the Claude card:

| Metric | Meaning |
|---|---|
| Session | 5-hour rolling window usage |
| Weekly | 7-day window usage |
| Fable | Separate weekly Fable limit |
| Sonnet | Separate weekly Sonnet limit (off by default) |
| Extra Usage | Extra-usage credits spent against your monthly cap |

There is no usage trend or spend history: those come from local logs, and this Mac's logs don't belong
to the hub's accounts. Rate limit resets aren't shown.

## Errors

- **Re-login this account on the hub** — Anthropic rejected the hub's login for that account. Sign it
  in again on the hub; OpenUsage never refreshes hub tokens itself.
- **Hub errors** (can't reach the hub, timeout, untrusted certificate, rejected management key, hub
  server error) — shown on every card of that hub at once. A refresh finds the failure once and
  shares it, instead of each card trying the hub separately.
- A problem with one account fails only that account's card.
- When Anthropic rate-limits an account, its card keeps the last limits with an "Updates blocked"
  notice.

OpenUsage sends at most 4 requests to a hub at a time.
