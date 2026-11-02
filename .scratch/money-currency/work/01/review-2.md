VERDICT: APPROVED

## Previous findings

| # | Severity | Status | Evidence |
|---|----------|--------|----------|
| 1 | minor | resolved | docs/local-http-api.md:146 now reads `"dollars" (+ "currency" when the provider reports one; absent means USD)`, which matches the mapper storing a reported "USD" as `"USD"` and omitting the key when absent. |
| 2 | nit | resolved | e0b0e6d9 removes the second blank line before `resetDate` (ClaudeUsageMapper.swift:244); one blank line remains. |
| 3 | nit | resolved | LocalLimitsAPI.swift:137-140: the `progressUnit` doc comment is rewrapped to about 100 columns with the same wording. |
| 4 | nit | rejection stands | ClaudeUsageMapper.swift:223 falls back to 2 (cents), the previous behavior, only for an optional field outside 0...4. No payload sending such a value has been seen, so a log path would be speculative. |
| 5 | nit | rejection stands | Zero-decimal currencies are outside the Issue's BRL/USD criteria. Follow-up, not a blocker. |

## Acceptance criteria re-checked

- [met] Docs in `docs/` that describe money or the CLI's `unit` field are updated. — docs/local-http-api.md:104-106 (unit as a lowercase ISO code) and :146 (format `currency`, reworded in e0b0e6d9), plus docs/adding-a-provider.md and docs/providers/claude.md from 2558d567.

## Checks run

- Typecheck: `swift build` in the worktree, exit 0.
- Targeted tests for the code the fixes touch: `swift test --filter 'MoneyCurrencyTests|ClaudeProviderTests|LocalLimitsAPITests|CLIProxyClaudeRuntimeTests'`, exit 0. 49 XCTest tests ran with 0 failures and 1 skipped.
- The fix commit (e0b0e6d9) touches only whitespace, one doc comment, one docs line and review.md's Resolution. It changes no behavior and no tests, so it adds no regression and no scope creep.
- Full suite not run (deliver runs it). The app was not relaunched to check R$ in the menu bar.

## Findings

None open or new.
