# 06: Hub Wins Over the Same Local Account

**What to build:** If an account is signed in both on this Mac and on the hub, only the hub card shows. Owner decision: the hub wins, and the local card's spend history is hidden with it.

**Blocked by:** 04

**Status:** ready-for-agent

- [ ] Claude accounts match by email. Codex accounts match by ChatGPT account id, falling back to email.
- [ ] The matching local card is left out at launch. Other local cards and enablement are unaffected.
- [ ] Removing or disabling the hub brings the local card back on the next launch.
- [ ] Tests cover a match, no match, and a disabled hub.
- [ ] `docs/provider-enablement.md` explains the rule.
