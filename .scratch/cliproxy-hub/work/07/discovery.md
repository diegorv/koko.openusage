# 07 Discovery: "Add Hub" in Settings

No `spec.md`; contract from `docs/research/cliproxy-hub-plan.md` ("Settings" + Step 5). Builds on `work/05` (`CLIProxyHubRelaunchNotice`) and the config store from `work/02`.

## Files

- New `Sources/OpenUsage/Providers/CLIProxyHub/CLIProxyHubSettings.swift`: `@MainActor @Observable` model over `CLIProxyHubConfigStore`. `reload()` (load error -> `loadError` friendly copy + `AppLog.error`), `addHub(url:managementKey:label:)`, `setEnabled(_:hubID:)`, `remove(hubID:)`, static `hubID(for:existing:)` (`cliproxy-<host-slug>`, `-2`, `-3`, case-insensitive). Same URL (trimmed, no trailing `/`, case-insensitive) updates that hub in place and keeps its id and cached accounts. Every save marks the relaunch notice and starts a background `CLIProxyHubAccountSync.run()` (injectable) so a new hub's accounts are cached before the relaunch.
- New `Sources/OpenUsage/Views/CLIProxyHubSettingsSection.swift`: "CLIProxyAPI Hubs" card: one row per hub (name, host caption, enable toggle, remove button behind a "Remove Hub?" alert), "Add Hub" button opening the form (Hub URL, Management Key `SecureField`, Label with the host as placeholder; Save disabled until URL and key are filled), inline notices for load/save errors, and a Relaunch row while the notice is pending. No tooltips.
- `Sources/OpenUsage/Views/SettingsScreen.swift:57`: insert the section after iCloud Sync (SettingsScreen is 566 LOC, so the section is its own file).
- `docs/settings.md` (new "CLIProxyAPI Hubs" section), `docs/providers/cliproxy-hub.md` "Setup" (point at Settings).
- New `Tests/OpenUsageTests/CLIProxyHubSettingsTests.swift`.

## Tests (prior art: `CLIProxyHubConfigStoreTests`, `CLIProxyHubAccountSyncTests` with `FakeFiles`)

- id slug: `https://hub.example.ts.net` -> `cliproxy-hub-example-ts-net`; taken -> `-2`, then `-3`; case-insensitive.
- add writes the hub (label nil when blank, trimmed fields), marks the notice; same URL keeps id + accounts, updates key/label.
- invalid URL (no scheme/host) -> friendly error, nothing written.
- disable / remove write the config and mark the notice.
- malformed file -> `loadError` set, hubs empty, and add/remove refuse to write (would wipe the file).

## Defaults taken

- Section title "CLIProxyAPI Hubs", placed after iCloud Sync.
- Blank label is stored as no label (cards already fall back to the host); the form shows the host as placeholder.
- Re-adding a saved URL keeps its enabled state.
- Remove asks for confirmation (it deletes the saved key).
- Save starts a background account sync so one relaunch shows the new hub's cards.

## Risks

- Settings save and the background sync both load/modify/save the file; a save that lands mid-sync could be overwritten by the sync's `saveAccounts` (which reloads first, so the window is small).
- Screenshot needs a running app; may not be possible from this agent.
