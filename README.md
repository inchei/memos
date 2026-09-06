# Memos · RSS fork

A fork of [usememos/memos](https://github.com/usememos/memos) that keeps RSS feed support alive after it was removed upstream in
[usememos#6243](https://github.com/usememos/memos/pull/6243) (commit `5b6d8f87`).

Everything here tracks upstream. The only delta lives on the `with-rss` branch:

- One revert commit — `Revert "refactor(server): remove RSS feed support (#6243)"` — restores the feed service and its tests.
- One frontend commit adds an RSS entry next to the attachments icon in the sidebar.
- `scripts/sync-with-rss.sh` replays both on top of every upstream sync.

## What the patch provides

- `GET /explore/rss.xml` — feed of the latest public memos.
- `GET /u/<username>/rss.xml` — per-user feed of that user's public memos.
- Feeds respond only when the instance access mode is **public** (`GET /api/v1/instance/profile` → `accessMode = PUBLIC`); otherwise they return 404, matching upstream behavior before removal.
- Sidebar: an RSS icon beside the attachments icon (signed-in nav rail) linking to the global feed.

## Remote setup

```
origin   git@github.com:usememos/memos.git   # upstream, read-only
inchei   git@github.com:inchei/memos.git     # fork, writable
```

## Syncing with upstream

`with-rss` is always `main` plus a small number of replayable commits. The provided script runs the whole flow:

```bash
scripts/sync-with-rss.sh
```

It fast-forwards `main` from upstream, rebases `with-rss` on top with `-X theirs`, then builds and runs the RSS/markdown tests before force-pushing to the fork. On conflict, `-X theirs` resolves every shared line in favor of the replayed patch — the restored RSS code simply wins, so syncs stay hands-off.

`-X theirs` is syntactic, not semantic. If upstream refactored something the patch hooks into (for example renamed the route group in `server/server.go`), the rebase finishes but `go build` fails; fix that file by hand, `git rebase --continue`, and rerun the script. When you intervene, the goal is always the same: keep the RSS restore, take everything else from `main`.

Manual equivalent:

```bash
git checkout main && git pull origin main
git checkout with-rss
git rebase main -X theirs
go build ./... && go test ./server/router/rss/... ./internal/markdown/...
git push --force-with-lease inchei with-rss
```

### Files the patch owns

Conflicts surface in a small, stable set of places:

| File | Patch side |
| --- | --- |
| `server/router/rss/rss.go`, `rss_test.go` | Whole files restored from before the removal. |
| `server/server.go` | Two lines: the `rss` import and `rss.NewRSSService(...).RegisterRoutes(rootGroup)`. |
| `internal/markdown/**` | RSS-only render helpers (`gfm`, `mention`, `tag` extensions). |
| `go.mod` / `go.sum` | `github.com/gorilla/feeds`; run `go mod tidy -go=1.27.0` after manual edits. |
| `web/src/components/AppSidebar/AppSidebar.tsx` | The RSS nav pill beside the attachments icon. |

## Verify after each sync

```bash
go build ./...
go test ./server/router/rss/... ./internal/markdown/...
cd web && pnpm lint && pnpm test
```

## Deploy

Build as upstream (the frontend output is embedded from `server/router/frontend/dist`):

```bash
cd web && pnpm release
cd .. && go build ./cmd/memos
```

Or build the Docker image from `scripts/Dockerfile` as upstream does.
