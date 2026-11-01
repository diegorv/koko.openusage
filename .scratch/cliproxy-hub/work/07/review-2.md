VERDICT: APPROVED

## Previous Findings

| # | Severity | Status | Evidence |
|---|----------|--------|----------|
| 1 | blocker | resolved | work/07/add-hub-form-light.png and add-hub-form-dark.png (f5243328) show the card alone: two hubs (one on, one off) with trash and switch, and the Add Hub form open with Hub URL, a masked Management Key, the Label placeholder "Label (hub.example.ts.net)", Save and Cancel. Both match the caption header and card style of the other Settings sections. The grey switch and Save tint come from the inactive off-screen window, and the fix step disclosed it. |
| 2 | minor | resolved | `reload()` clears `actionError` (CLIProxyHubSettings.swift:35); `clearActionError()` (:71-73) runs from `openForm`/`closeForm` (CLIProxyHubSettingsSection.swift:157,162). `testTheErrorClearsWhenDismissedOrReloaded` covers both paths and passes. `update` still sets the save error after its internal `reload()` (:106-113), so clearing in `reload()` does not hide a failed save (`testAFailedSaveIsAFriendlyErrorWithoutRelaunchOrSync` asserts it). |
| 3 | minor | resolved | `CLIProxyHubConfigStore.exclusively` uses a static `NSLock` (CLIProxyHubConfigStore.swift:62-69). `saveAccounts` (:73-84) and Settings `update` (CLIProxyHubSettings.swift:105-119) each run load/modify/save inside it. These are the only two writers of the file (grep for `saveAccounts`/`store.save` in Sources). `exclusively` never nests, because `reload()` and `save` don't take the lock. `requestSync()` (:128-142) keeps one sync in flight on the main actor and queues one extra pass. `testSavingAccountsWaitsForAnExclusiveChange` and `testSavesDuringASyncQueueOneMorePassInsteadOfAnotherSync` pass. The launch sync can still overlap a Settings sync, but the lock makes that only a repeated network call, as disclosed. |
| 4 | minor | resolved | docs/provider-enablement.md:33 now says "turn the hub off or remove it in Settings → CLIProxyAPI Hubs". |
| 5 | minor | resolved | `testAddingASavedURLKeepsItsOnOffState` seeds a disabled hub and asserts `[false]` after re-adding. `testAFailedSaveIsAFriendlyErrorWithoutRelaunchOrSync` uses an `UnwritableFiles` store and asserts the error, no hub, no notice and no sync (an inverted expectation). Both pass. |
| 6 | nit | rejection stands | The review allowed no code change, and the note for the owner is recorded in review.md's Resolution. |

## Acceptance Criteria

- [met] Each hub can be disabled or removed. Saving writes the config and offers the relaunch prompt. — `update` still saves and calls `notice.markChanged()` only on success (CLIProxyHubSettings.swift:120-123), now under the lock. `testDisablingAndRemovingAHubWriteTheConfig` passes, and the new failed-save test confirms that no prompt appears when the write fails.
- [met] Copy uses title case, matches the existing design language, and has no tooltips. — The screenshots show the title-case "CLIProxyAPI Hubs", "Save" and "Cancel" in the same caption-header card layout as the other Settings sections. The fixes add no copy and no `hoverTooltip`.
- [met] A screenshot of the form is ready for the PR. — .scratch/cliproxy-hub/work/07/add-hub-form-light.png and add-hub-form-dark.png (f5243328), with the form open and filled in.

## Findings

None open or new.

## Checks

- Typecheck: `swift build` in the worktree, exit 0.
- Tests (run by me): `swift test --filter "CLIProxyHubSettingsTests|CLIProxyHubConfigStoreTests|CLIProxyHubAccountSyncTests|PopoverScreenTests"`, exit 0, 42 tests, 0 failures (Settings 14, ConfigStore 6, AccountSync 18, PopoverScreen 4). The full suite is deliver's to run.
- Test integrity: the fix commits only add tests (see `git diff a9620c8f..HEAD -- Tests`); none is deleted or weakened.
- Scope: the fix commits touch only the hub settings model, the config store, the section view, their tests, one docs line and work/07. Nothing goes beyond the findings.
- Not checked: the section in the running app (the owner's instance was left alone). The lock test holds one thread with a 0.2s sleep, which could be timing-sensitive on a very slow CI machine.
