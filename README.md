# Memos · RSS fork

A fork of [usememos/memos](https://github.com/usememos/memos) that keeps RSS feed support alive after it was removed upstream in
[usememos#6243](https://github.com/usememos/memos/pull/6243) (commit `5b6d8f87`).

Everything here tracks upstream. The only delta lives on the `with-rss` branch:

- One revert commit — `Revert "refactor(server): remove RSS feed support (#6243)"` — restores the feed service and its tests.
- One frontend commit adds an RSS entry next to the attachments icon in the sidebar.

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

`with-rss` is always `main` plus a small number of replayable commits, so a sync is a rebase:

```bash
git checkout main
git pull origin main                 # fast-forward from upstream

git checkout with-rss
git rebase main                      # replay the RSS patch on top

git push --force-with-lease inchei with-rss
```

Check that the delta is still what you expect:

```bash
git log --oneline main..with-rss     # should list only the RSS commits
```

### When the rebase conflicts

Conflicts happen only where upstream touches the same files the patch does:

| File | Typical conflict |
| --- | --- |
| `server/server.go` | Router wiring moved; re-add the `rss.RegisterRoutes(...)` call next to the other route registrations. |
| `go.mod` / `go.sum` | Dependency lines shifted; keep `github.com/gorilla/feeds`, then run `go mod tidy -go=1.27.0`. |
| `internal/markdown/**` | Markdown API changed; adjust the restored render helpers to the new signatures. |

Resolve, then `git rebase --continue`. If the patch grows beyond simple wiring fixes, consider splitting it into more, smaller commits — the rebase replays each one in order.

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
