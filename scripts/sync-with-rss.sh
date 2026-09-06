#!/usr/bin/env bash
# Sync the with-rss branch with upstream and replay the RSS patch on top.
set -euo pipefail

UPSTREAM_REMOTE="${UPSTREAM_REMOTE:-origin}"
FORK_REMOTE="${FORK_REMOTE:-inchei}"
BASE_BRANCH="${BASE_BRANCH:-main}"
PATCH_BRANCH="${PATCH_BRANCH:-with-rss}"

git fetch "$UPSTREAM_REMOTE" "$BASE_BRANCH"

git checkout "$BASE_BRANCH"
git merge --ff-only "$UPSTREAM_REMOTE/$BASE_BRANCH"

git checkout "$PATCH_BRANCH"
# -X theirs favors the replayed patch on every conflict: the restored RSS code
# always wins over upstream's removal side of the same lines.
if ! git rebase "$BASE_BRANCH" -X theirs; then
  echo "rebase stopped: a patch commit no longer applies cleanly. Fix by hand:" >&2
  echo "  resolve the conflict (keep the RSS restore), then: git rebase --continue" >&2
  echo "  or: git rebase --abort" >&2
  exit 1
fi

go build ./...
go test ./server/router/rss/... ./internal/markdown/...

git push --force-with-lease "$FORK_REMOTE" "$PATCH_BRANCH"
echo "synced $PATCH_BRANCH onto $UPSTREAM_REMOTE/$BASE_BRANCH"
