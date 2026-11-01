# Ledger: cliproxy-hub

This file is the source of truth for the progress of the cliproxy-hub Issues. Read it before working on any of them. It is written only by `/relay-lite:run`, through `relay ledger`: never edit it by hand.

## Continue

```text
/relay-lite:run cliproxy-hub
```

Add Issue numbers to force them; `--all` runs every available Issue in sequence; `--all --parallel` runs the ones that touch different files at the same time.

## Process

The `relay-lite:workflow` workflow, one worktree per Issue at `<repo>.worktrees/issue-NN-slug`: build (discovery + implement), review (Claude or Codex), fix and re-review while changes are requested, deliver. Only deliver runs the full suite. Formats: relay-lite's `docs/format.md`.

## Statuses

| Status | Meaning |
|---|---|
| `todo` | Not started. |
| `in-progress` | Set by `/relay-lite:run` on `base` before it launches the Issue; still there after a run means it was interrupted (the worktree and branch may exist). `/relay-lite:run` asks what to do about it only when run with no Issue numbers (`--all` too), or when it is one of the named Issues or in the "Blocked by" of one; skip records nothing (no status change, no Log line, no commit), so the question comes back on the next such run. |
| `blocked` | Nothing was delivered: the build refused the Issue or returned nothing, the suite failing, a review or re-review that returned nothing, a re-review that still requests changes, a rebase conflict in source files, a failed push. The reason is in the Log; the worktree is kept. `/relay-lite:run` asks what to do about it only when run with no Issue numbers (`--all` too), or when it is one of the named Issues or in the "Blocked by" of one; skip records nothing (no status change, no Log line, no commit), so the question comes back on the next such run. |
| `in-review` | `pr` delivery: the PR is open, not merged yet; its URL is in Branch / PR. The next run checks it and sets `done` or `todo`. relay-lite does not delete the remote branch `issue/NN-slug` when the PR is merged or closed (GitHub does on merge if the repository auto-deletes head branches); after a close, delete it or renumber the Issue before the Issue runs again, or its push is rejected. |
| `done` | Delivered, and the Issue file says `Status: resolved`. |
| `wontfix` | Closed without work. |

## Next up

An Issue can start when its status is `todo` and every Issue in its "Blocked by" is `done`. Among those, take the lowest number.

## Issues

**Branch / PR**: in `merge` delivery `issue/NN-slug (<short sha>)`, the short sha of the Issue's squash commit on `base` (the `sha` deliver returns), written by `/relay-lite:run` in its `done` commit; in `pr` delivery the PR URL while `in-review`, then `<PR URL> (<short merge sha>)` once `/relay-lite:run` finds it merged; cleared when it finds the PR closed and sets the row back to `todo` (the URL stays in the `pr closed` Log line). **Merged**: always a date (YYYY-MM-DD); in `merge` delivery the date `/relay-lite:run` wrote the row, after the squash commit; in `pr` delivery the date `/relay-lite:run` recorded the merge. Both cells stay empty on a row `/relay-lite:ledger` created as `done` from an Issue file already `Status: resolved`.

| # | Issue | Blocked by | Status | Branch / PR | Merged |
|---|---|---|---|---|---|
| 01 | [Hub Client and Transport Adapter](issues/01-hub-client-and-transport.md) | none | done | issue/01-hub-client-and-transport (eb275dcb) | 2026-11-01 |
| 02 | [Claude Hub Cards From the Cached Account List](issues/02-claude-hub-cards-from-cache.md) | 01 | done | issue/02-claude-hub-cards-from-cache (9844ad69) | 2026-11-01 |
| 03 | [Background Hub Account Sync](issues/03-background-account-sync.md) | 02 | done | issue/03-background-account-sync (66215e80) | 2026-11-01 |
| 04 | [Codex Hub Cards](issues/04-codex-hub-cards.md) | 02 | done | issue/04-codex-hub-cards (917b9011) | 2026-11-01 |
| 05 | [Relaunch Prompt When Hub Accounts Change](issues/05-relaunch-prompt-on-account-changes.md) | 03 | done | issue/05-relaunch-prompt-on-account-changes (1906e77b) | 2026-11-01 |
| 06 | [Hub Wins Over the Same Local Account](issues/06-hub-wins-over-local-account.md) | 04 | done | issue/06-hub-wins-over-local-account (a05266f2) | 2026-11-01 |
| 07 | ["Add Hub" in Settings](issues/07-add-hub-settings.md) | 05 | done | issue/07-add-hub-settings (de2f497b) | 2026-11-01 |
| 08 | [Codex Hub Match Counts Team Seats Separately](issues/08-codex-team-seat-match.md) | 06 | done | issue/08-codex-team-seat-match (af9268fc) | 2026-11-01 |

## Log

- 2026-11-01 16:30 — ledger created (7 Issues)
- 2026-11-01 16:36 — 01 — start — launched by /relay-lite:run — ee197746
- 2026-11-01 16:54 — 01 — deliver — squash-merged as eb275dcb; reviews CHANGES_REQUESTED → APPROVED → APPROVED; full suite 1681 tests 0 failures; one criterion unticked (fixtures not ported verbatim from t3code) — eb275dcb
- 2026-11-01 16:54 — 02 — start — launched by /relay-lite:run — 0bd9f66c
- 2026-11-01 17:20 — 02 — deliver — squash-merged as 9844ad69; reviews CHANGES_REQUESTED → APPROVED; full suite 1703 tests 0 failures; smoke test unticked (no cached hub accounts); broken cliproxy.json surfacing deferred to 07 — 9844ad69
- 2026-11-01 17:20 — 03 — start — launched by /relay-lite:run — e12c082b
- 2026-11-01 17:30 — 03 — deliver — squash-merged as 66215e80; reviews APPROVED → APPROVED; full suite 1710+4 tests 0 failures; manual smoke test unticked — 66215e80
- 2026-11-01 17:30 — 04 — start — launched by /relay-lite:run — c5d6c84d
- 2026-11-01 17:49 — 04 — deliver — squash-merged as 917b9011; reviews APPROVED → APPROVED; full suite 1724 tests 0 failures; live-hub smoke test unticked — 917b9011
- 2026-11-01 17:49 — 05 — start — launched by /relay-lite:run — 2fcd9707
- 2026-11-01 18:00 — 05 — deliver — squash-merged as 1906e77b; reviews APPROVED → APPROVED; full suite 1735+4 tests 0 failures; relaunch not tried in running app — 1906e77b
- 2026-11-01 18:00 — 06 — start — launched by /relay-lite:run — b23f3dc0
- 2026-11-01 18:13 — 06 — deliver — squash-merged as a05266f2; reviews APPROVED → APPROVED; full suite 1742 tests 0 failures; open: Codex match by account id hides other Team seats — a05266f2
- 2026-11-01 18:14 — 07 — start — launched by /relay-lite:run — 84375894
- 2026-11-01 18:36 — 07 — deliver — squash-merged; reviews CHANGES_REQUESTED → APPROVED; full suite 1757 tests 0 failures; UI not checked by hand — de2f497b
- 2026-11-01 18:38 — ledger updated (added 08)
- 2026-11-01 18:41 — 08 — start — launched by /relay-lite:run — 161e75de
- 2026-11-01 18:49 — 08 — deliver — squash-merged as af9268fc; reviews APPROVED → APPROVED; full suite 1758+4 tests 0 failures; Codex match now requires emails to agree when both present — af9268fc
