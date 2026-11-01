VERDICT: APPROVED

## Previous findings

| # | Severity | Status | Evidence |
|---|----------|--------|----------|
| 1 | minor | resolved | `CLIProxyHubRelaunchNotice.relaunch(shell:)` still logs via `AppLog.error(.lifecycle, ...)` and now also sets `relaunchFailed = true` before returning (Sources/OpenUsage/Providers/CLIProxyHub/CLIProxyHubRelaunchNotice.swift:34-39). `HubAccountsChangedCard` swaps its message to "OpenUsage couldn't relaunch itself. Quit and reopen it to show the hub's current accounts." when that flag is set (Sources/OpenUsage/Views/HubAccountsChangedCard.swift:12-14). The production call site still uses the `/bin/sh` default (`notice.relaunch()`, :16). `testRelaunchThatCannotStartTheHelperReportsTheFailure` forces a spawn failure with `/nonexistent/sh` and asserts `relaunchFailed` is true and the card is still pending; it passes. The failure path returns before `NSApp.terminate`, so the test cannot quit the runner. |
| 2 | minor | rejection stands | The Issue's criterion is about the set of accounts. Whether the hub keeps `auth_index` stable is a question for the owner and is recorded under the review's Resolution. Not a criterion failure. |
| 3 | nit | rejection stands | Optional move with no change in behavior. The store is CLIProxy-specific and sits next to the sync that raises it. |
| 4 | nit | rejection stands | Still a manual pre-release check (relaunch process path, `run()` -> `markChanged()` wiring). No code change was expected. |

## Acceptance criteria re-checked

- [met] The notice matches the existing design language, uses title case for its title, and has a Relaunch action that restarts the app. — The fix keeps the same `DismissableHintCard`, the title "Hub Accounts Changed" and the "Relaunch" button. The relaunch command line is the same as before, and only the executable URL became a defaulted parameter (`/bin/sh`). The success path still ends in `NSApp.terminate`. The failure path now tells the user what to do. Not tried in the running app.
- [met] Tests cover change detection. — `swift test --filter CLIProxyHubAccountSyncTests`: exit 0, 18 tests, 0 failures. No existing test was weakened or removed: the diff since 81689eed only adds the one new test.

## Findings

1. nit — docs/providers/cliproxy-hub.md:32-34 — The doc describes the notice but not what happens when the relaunch can't start (the card stays up and asks the user to quit and reopen). AGENTS.md asks for docs to cover logic changes. Fix: add one clause, e.g. "If OpenUsage can't relaunch itself, the notice stays and asks you to quit and reopen it."
2. nit — .scratch/cliproxy-hub/work/05/ — No screenshot shows the failure-state message, and AGENTS.md asks for screenshots of visual changes. The existing light and dark screenshots cover the normal state, which the criterion asks for. Fix (optional): add a screenshot of the failure-state card for the PR.

## Checks run by this review

- Typecheck: `swift build` in the worktree, exit 0.
- Tests: `swift test --filter CLIProxyHubAccountSyncTests`, exit 0, 18 tests, 0 failures. The full suite is deliver's to run.
- Scope: the fix diff (81689eed..HEAD) touches only the notice store, the card, the sync test file and the review file's Resolution. No scope creep.
