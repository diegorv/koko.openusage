# 08: Codex Hub Match Counts Team Seats Separately

**What to build:** A hub Codex account hides a local Codex card only when it is the same seat. Today the match is on ChatGPT account id alone, so one hub seat of a ChatGPT Team workspace hides the local card of a different seat in the same workspace. Owner decision (2026-11-01): when both sides have an email, the emails must also agree.

**Blocked by:** 06

**Status:** resolved

- [x] Codex accounts match when the ChatGPT account ids agree and, if both sides have an email, the emails agree too (case-insensitive). With an email on only one side, the account id alone decides.
- [x] The email fallback when no account id is available is unchanged.
- [x] Tests cover: same id and same email (hidden), same id and different email (both shown), same id and email missing on one side (hidden).
- [x] `docs/provider-enablement.md` explains the seat rule.

## Comments

- 2026-11-01, branch `issue/08-codex-team-seat-match`: Codex hub match now requires matching emails (case-insensitive) when both sides have one, so Team seats sharing a ChatGPT account id are shown separately; email-only fallback unchanged; tests added; `docs/provider-enablement.md` explains the seat rule. swift build exit 0; `swift test` at c9ae8805 exit=0 (OpenUsageTests 1758, 4 skipped, 0 failures; OpenUsageCLITests 4, 0 failures). Reviews: round 1 APPROVED (doc pointer fix applied), round 2 APPROVED.
