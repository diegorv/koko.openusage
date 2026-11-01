# 07: "Add Hub" in Settings

**What to build:** Users add, disable and remove CLIProxyAPI hubs from Settings instead of editing `cliproxy.json` by hand.

**Blocked by:** 05

**Status:** resolved

- [x] An "Add Hub" form takes Hub URL, Management Key (a secret field) and an optional Label that defaults to the host. Save is enabled only when the URL and the key are filled in.
- [x] The hub id is `cliproxy-<host-slug>`, then `-2`, `-3`, and so on. A saved hub with the same URL keeps its id.
- [x] Each hub can be disabled or removed. Saving writes the config and offers the relaunch prompt.
- [x] A `cliproxy.json` that cannot be read or parsed is shown in Settings as a friendly error (and still logged), instead of only going to the log. Carried over from Issue 02's review-2.md.
- [x] Copy uses title case, matches the existing design language, and has no tooltips.
- [x] `docs/settings.md` is updated.
- [x] A screenshot of the form is ready for the PR.

## Comments

- 2026-11-01, branch issue/07-add-hub-settings: Settings gains a CLIProxyAPI Hubs section (add/disable/remove hubs, stable hub ids, friendly cliproxy.json error, relaunch prompt), docs/settings.md updated, screenshots added. Round 1 review: CHANGES_REQUESTED (fixed: error clearing, serialized config writes, single account sync, tests); round 2: APPROVED. Full suite: 1757 tests, 0 failures (4 skipped).
