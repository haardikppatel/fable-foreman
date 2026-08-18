#!/bin/sh
# fable-foreman — ledger bootstrap.
# Usage: init-ledger.sh "<task title>" [ledger-dir]
# Idempotent: refuses to overwrite an existing ledger (resume runs must
# reconcile, not reset — delegation.md). Fails loudly and nonzero on any error;
# creation is atomic (noclobber) so concurrent invocations cannot clobber.
set -eu

RAW_TITLE="${1:-untitled run}"
DIR="${2:-.foreman}"
LEDGER="$DIR/ledger.md"

# Strip control characters (incl. newlines) so a title cannot forge ledger
# sections that get trusted after compaction.
TITLE=$(printf '%s' "$RAW_TITLE" | tr -d '\000-\037\177')

if [ -f "$LEDGER" ]; then
  echo "EXISTS: $LEDGER — reconcile against the tree before dispatching (delegation.md). Not overwriting."
  exit 0
fi

mkdir -p "$DIR/scratch"

if git rev-parse --git-dir >/dev/null 2>&1; then
  HASH=$(git rev-parse -q --verify HEAD 2>/dev/null) || HASH=""
  [ -n "$HASH" ] || HASH="unborn (no commits yet)"
  STATUS=$(git status --porcelain)   # set -e aborts here if git fails
  DIRTY=$(printf '%s' "$STATUS" | grep -c . || true)
else
  HASH="no git repository"
  STATUS=""
  DIRTY=0
fi

TMP=$(mktemp "$DIR/.ledger-tmp.XXXXXX")
{
  printf '# Foreman Ledger — %s\n' "$TITLE"
  printf 'BASELINE: %s | %s dirty files | %s\n' "$HASH" "$DIRTY" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '\n### Baseline worktree state (git status --porcelain, verbatim)\n```\n%s\n```\n' "$STATUS"
  printf '\n## Plan\n\n## Routing\n\n## Tasks\n\n## Attempts\n\n## Decisions\n<Codex billing mode; seat changes; degradations>\n\n## Scratch\n%s/scratch/\n' "$DIR"
} > "$TMP"

# Atomic exclusive create via hard link: the full content is already safely in
# TMP (same directory, same filesystem), and link(2) either publishes it whole
# under the ledger name or fails because the name exists — there is no partial-
# ledger state and no way to mistake our own failed write for a concurrent
# creation (the failure mode Codex round-3 finding 9 identified in the
# noclobber approach).
if ln "$TMP" "$LEDGER" 2>/dev/null; then
  rm -f "$TMP"
  echo "CREATED: $LEDGER (baseline: $HASH, $DIRTY dirty files)"
  # The ledger lives in the project being worked on. If it is not ignored there,
  # the verifier's clean-tree check can never pass (verification.md).
  if git rev-parse --git-dir >/dev/null 2>&1; then
    git check-ignore -q "$DIR" 2>/dev/null \
      || echo "NOTE: $DIR is not gitignored — add '$DIR/' to .gitignore or .git/info/exclude so the verifier's clean-tree check stays meaningful (delegation.md)"
  fi
elif [ -e "$LEDGER" ]; then
  rm -f "$TMP"
  echo "EXISTS (created concurrently): $LEDGER — reconcile, do not overwrite."
  exit 0
else
  rm -f "$TMP"
  echo "ERROR: could not create $LEDGER (link failed, file absent — permissions or I/O)" >&2
  exit 1
fi
