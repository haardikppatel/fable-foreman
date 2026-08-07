#!/bin/sh
# fable-foreman — Step 0 deterministic probe.
# Emits the job-site capability table as plain text for the ledger.
# Read-only: makes no billable calls, changes no state, prints no secrets.
set -u

echo "== foreman probe $(date -u +%Y-%m-%dT%H:%M:%SZ) =="

# Codex CLI
if command -v codex >/dev/null 2>&1; then
  echo "codex: installed ($(command -v codex))"
  if LOGIN_STATUS=$(codex login status 2>&1); then
    echo "codex auth: $LOGIN_STATUS"
  else
    if [ -s "${CODEX_HOME:-$HOME/.codex}/auth.json" ]; then
      echo "codex auth: credentials file present; billing mode UNKNOWN (status command failed)"
    else
      echo "codex auth: NOT authenticated"
    fi
  fi
  CFG="${CODEX_HOME:-$HOME/.codex}/config.toml"
  if [ -f "$CFG" ]; then
    # First matching assignment only — profiles/overrides may change the
    # effective value; treat as a hint, not the resolved configuration.
    echo "codex config model (first assignment, unresolved): $(grep -E '^\s*model\s*=' "$CFG" | head -1 | sed 's/^[[:space:]]*//')"
    echo "codex config effort (first assignment, unresolved): $(grep -E '^\s*model_reasoning_effort\s*=' "$CFG" | head -1 | sed 's/^[[:space:]]*//')"
  fi
else
  echo "codex: NOT installed"
fi

# Native-transport (claudemix-style splitter) facts — reported separately;
# presence of parts does not mean the transport is routable (setup-runbook.md).
if command -v cliproxyapi >/dev/null 2>&1; then
  echo "cliproxyapi binary: present ($(command -v cliproxyapi))"
else
  echo "cliproxyapi binary: absent"
fi
FOUND_CONF="absent"
for P in /opt/homebrew/etc/cliproxyapi.conf /usr/local/etc/cliproxyapi.conf; do
  [ -f "$P" ] && FOUND_CONF="present ($P)"
done
echo "cliproxyapi config: $FOUND_CONF"
echo "native transport: routable only if binary+config+auth+splitter all verified live (setup-runbook.md Part B); this probe checks presence only"

# Gateway detection — redacted to scheme://host:port; URLs can carry tokens
# and this output is pasted into durable ledgers.
if [ -n "${ANTHROPIC_BASE_URL:-}" ]; then
  # scheme = letter followed by letters/digits/+/-/. per RFC 3986; authority
  # ends at /, ?, or #; userinfo (anything@) stripped. Anything that doesn't
  # parse as scheme://... is withheld entirely rather than echoed raw.
  # Regex guard (not a glob — globs let 'h$://' through): only values whose
  # scheme strictly matches RFC 3986 are redacted-and-shown; everything else
  # is withheld entirely. The grep and sed use the same charset, so any value
  # grep admits, sed will rewrite — no fall-through printing the raw value.
  if printf '%s' "$ANTHROPIC_BASE_URL" | grep -Eq '^[A-Za-z][A-Za-z0-9+.-]*://'; then
    REDACTED=$(printf '%s' "$ANTHROPIC_BASE_URL" | sed -E 's#^([A-Za-z][A-Za-z0-9+.-]*://)([^/?#@]*@)?([^/?#]*).*#\1\3#')
    echo "ANTHROPIC_BASE_URL: set — $REDACTED (session is behind a gateway/splitter; full value withheld)"
  else
    echo "ANTHROPIC_BASE_URL: set — unparseable form, value withheld (session may be behind a gateway/splitter)"
  fi
else
  echo "ANTHROPIC_BASE_URL: unset (direct Anthropic connection)"
fi

# Git baseline for the ledger — a failed status is reported as FAILED, never
# rendered as a clean tree.
if git rev-parse --git-dir >/dev/null 2>&1; then
  HASH=$(git rev-parse -q --verify --short HEAD 2>/dev/null) || HASH=""
  [ -n "$HASH" ] || HASH="unborn (no commits yet)"
  if STATUS=$(git status --porcelain 2>/dev/null); then
    DIRTY=$(printf '%s' "$STATUS" | grep -c . || true)
    echo "git: repo — HEAD $HASH, dirty files: $DIRTY"
  else
    echo "git: repo — HEAD $HASH, dirty files: STATUS FAILED (do not treat as clean)"
  fi
else
  echo "git: not a repository (ledger baseline will note this)"
fi

echo "== probe complete. Agent-tool and shell-mode facts come from the harness, not this script =="
