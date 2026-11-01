# 06: Hub Wins Over the Same Local Account

**What to build:** If an account is signed in both on this Mac and on the hub, only the hub card shows. Owner decision: the hub wins, and the local card's spend history is hidden with it.

**Blocked by:** 04

**Status:** resolved

- [x] Claude accounts match by email. Codex accounts match by ChatGPT account id, falling back to email.
- [x] The matching local card is left out at launch. Other local cards and enablement are unaffected.
- [x] Removing or disabling the hub brings the local card back on the next launch.
- [x] Tests cover a match, no match, and a disabled hub.
- [x] `docs/provider-enablement.md` explains the rule.

## Comments

- 2026-11-01, branch issue/06-hub-wins-over-local-account: local Claude/Codex cards matching a hub account (Claude by email; Codex by ChatGPT account id, falling back to email) are left out at launch; disabling or removing the hub brings them back. Docs in docs/provider-enablement.md updated (Claude email match spans every org; which controls restore the card). Added a test for Claude account card emails. Tests: swift build exit 0; CLIProxyHubLocalMatchTests 7 passed; full suite at af2eeab2 exit=0, 1742 tests, 4 skipped, 0 failures. Reviews: round 1 APPROVED, round 2 APPROVED (fix round ran between). Open owner question: Codex matches on account id alone, so one hub seat of a ChatGPT Team workspace hides the local card of another seat.
