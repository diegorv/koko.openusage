# 08: Codex Hub Match Counts Team Seats Separately

**What to build:** A hub Codex account hides a local Codex card only when it is the same seat. Today the match is on ChatGPT account id alone, so one hub seat of a ChatGPT Team workspace hides the local card of a different seat in the same workspace. Owner decision (2026-11-01): when both sides have an email, the emails must also agree.

**Blocked by:** 06

**Status:** ready-for-agent

- [ ] Codex accounts match when the ChatGPT account ids agree and, if both sides have an email, the emails agree too (case-insensitive). With an email on only one side, the account id alone decides.
- [ ] The email fallback when no account id is available is unchanged.
- [ ] Tests cover: same id and same email (hidden), same id and different email (both shown), same id and email missing on one side (hidden).
- [ ] `docs/provider-enablement.md` explains the seat rule.
