# 07: "Add Hub" in Settings

**What to build:** Users add, disable and remove CLIProxyAPI hubs from Settings instead of editing `cliproxy.json` by hand.

**Blocked by:** 05

**Status:** ready-for-agent

- [ ] An "Add Hub" form takes Hub URL, Management Key (a secret field) and an optional Label that defaults to the host. Save is enabled only when the URL and the key are filled in.
- [ ] The hub id is `cliproxy-<host-slug>`, then `-2`, `-3`, and so on. A saved hub with the same URL keeps its id.
- [ ] Each hub can be disabled or removed. Saving writes the config and offers the relaunch prompt.
- [ ] A `cliproxy.json` that cannot be read or parsed is shown in Settings as a friendly error (and still logged), instead of only going to the log. Carried over from Issue 02's review-2.md.
- [ ] Copy uses title case, matches the existing design language, and has no tooltips.
- [ ] `docs/settings.md` is updated.
- [ ] A screenshot of the form is ready for the PR.
