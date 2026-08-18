#!/bin/sh
# fable-foreman — fixed-argv Grok launcher.
# Transport wrappers run ONLY this script, never a hand-composed grok command:
# argv is pinned here, so pipelines, substitutions, and nested grok invocations
# cannot ride in through the wrapper's shell (SKILL.md hard rail 1 carve-out).
#
# Usage: grok-dispatch.sh <ticket-file> <model> <effort> <read-only|workspace> <artifact-json> [workdir] [resume-session-id] [schema-file]
#
# schema-file: optional path to a JSON Schema. When given, Grok is constrained to
# emit a matching object under `structuredOutput` — a verdict contract that
# cannot hedge in prose. Kept INSIDE the pinned argv on purpose: schema-locked
# review is the recommended pattern, so it must not require a hand-composed
# grok command that bypasses these guards.
#
# Emits a transport envelope (exit code / duration / pid file / seat evidence /
# usage) on stdout; the Grok JSON result goes to <artifact-json>, stderr to
# <artifact-json>.stderr, the child PID to <artifact-json>.pid.
set -eu

# Resolution order matches scripts/probe.sh exactly — $GROK_BIN, then PATH, then
# $GROK_HOME/bin — so Step 0 certifies the same binary that later gets paid.
# probe.sh honors $GROK_BIN for the same reason. If you set it here, set it in
# the environment the probe ran in too. The resolved path is echoed in the
# envelope so the ledger records which binary actually ran.
if [ -n "${GROK_BIN:-}" ]; then
  :
elif command -v grok >/dev/null 2>&1; then
  GROK_BIN=$(command -v grok)
else
  GROK_BIN="${GROK_HOME:-$HOME/.grok}/bin/grok"
fi
# Optional extra deny glob for a path that must never be written even by a
# tool call (e.g. a notes vault). Unset by default: this ships to other
# machines, so no personal path is hardcoded here. The OS sandbox — not this
# glob — is the real boundary (see the note where the denials are assembled).
VAULT_GLOB="${FOREMAN_VAULT_GLOB:-}"

TICKET="$1"; MODEL="$2"; EFFORT="$3"; SANDBOX="$4"; OUT="$5"; WORKDIR="${6:-.}"; RESUME="${7:-}"; SCHEMA="${8:-}"

# `off` is never accepted: a dispatched worker always gets an OS-enforced boundary.
case "$SANDBOX" in read-only|workspace) ;; *) echo "BLOCKED: invalid sandbox '$SANDBOX' (use read-only|workspace)" >&2; exit 64 ;; esac
case "$EFFORT" in low|medium|high|xhigh) ;; *) echo "BLOCKED: invalid effort '$EFFORT'" >&2; exit 64 ;; esac
case "$MODEL" in *[!A-Za-z0-9._-]*|"") echo "BLOCKED: invalid model id" >&2; exit 64 ;; esac
case "$RESUME" in
  -*) echo "BLOCKED: resume session id must not begin with '-' (got '$RESUME') — pass a bare session id, not a flag" >&2; exit 64 ;;
  *[!A-Za-z0-9-]*) echo "BLOCKED: invalid resume session id" >&2; exit 64 ;;
esac

# grok-4.5 has no xhigh: sending it is a hard error (exit 1), not a graceful
# degrade — verified 2026-08-17. Catch it here rather than paying a failed turn.
if [ "$EFFORT" = "xhigh" ]; then
  case "$MODEL" in *4.5*) echo "BLOCKED: model '$MODEL' does not support xhigh (use high|medium|low)" >&2; exit 64 ;; esac
fi

[ -x "$GROK_BIN" ] || { echo "BLOCKED: grok binary not executable: $GROK_BIN" >&2; exit 69; }
[ -f "$TICKET" ] || { echo "BLOCKED: ticket not found: $TICKET" >&2; exit 66; }
[ -d "$WORKDIR" ] || { echo "BLOCKED: workdir not found: $WORKDIR" >&2; exit 66; }

# Schema is taken as a FILE PATH rather than an inline argv blob from the caller,
# and validated as real JSON here before use. Be precise about what that buys:
# the contents are still expanded onto grok's argv below (`--json-schema "$(cat
# ...)"`), because that is the only interface the binary offers. What the file
# indirection removes is caller-side quoting hazard and unvalidated text; it does
# not keep the schema off the command line.
if [ -n "$SCHEMA" ]; then
  [ -f "$SCHEMA" ] || { echo "BLOCKED: schema file not found: $SCHEMA" >&2; exit 66; }
  [ -L "$SCHEMA" ] && { echo "BLOCKED: schema path is a symlink: $SCHEMA" >&2; exit 64; }
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$SCHEMA" 2>/dev/null \
      || { echo "BLOCKED: schema file is not valid JSON: $SCHEMA" >&2; exit 64; }
  fi
fi

# The read-only profile does NOT contain writes under /tmp (verified 2026-08-17:
# a file was created in a /private/tmp workdir under --sandbox read-only). A
# read-only reviewer sited there is not isolated, so refuse it outright.
if [ "$SANDBOX" = "read-only" ]; then
  ABS_WD=$(cd "$WORKDIR" 2>/dev/null && pwd -P) || { echo "BLOCKED: cannot resolve workdir" >&2; exit 66; }
  case "$ABS_WD" in
    /tmp|/tmp/*|/private/tmp|/private/tmp/*|/var/tmp|/var/tmp/*|/private/var/tmp|/private/var/tmp/*)
      echo "BLOCKED: read-only sandbox does not contain writes under /tmp ($ABS_WD) — site the reviewer elsewhere" >&2; exit 64 ;;
  esac
fi

# Artifact-path constraints: never a symlink, never the ticket itself.
case "$OUT" in *.json) ;; *) echo "BLOCKED: artifact path must end in .json: $OUT" >&2; exit 64 ;; esac
for P in "$OUT" "$OUT.stderr" "$OUT.pid"; do
  [ -L "$P" ] && { echo "BLOCKED: artifact path is a symlink: $P" >&2; exit 64; }
  [ -e "$P" ] && [ ! -f "$P" ] && { echo "BLOCKED: artifact path exists and is not a regular file: $P" >&2; exit 64; }
  [ -e "$P" ] && [ "$P" -ef "$TICKET" ] && { echo "BLOCKED: artifact path aliases the ticket: $P" >&2; exit 64; }
done
[ "$OUT" = "$TICKET" ] && { echo "BLOCKED: artifact path equals ticket path" >&2; exit 64; }
# A mistyped artifact path (say, a repo's package.json) would be truncated at
# spawn. Refuse any pre-existing NON-EMPTY file: fresh artifacts and empty
# placeholders are fine, real files are not ours to destroy.
[ -s "$OUT" ] && { echo "BLOCKED: artifact path already exists and is non-empty: $OUT (refusing to truncate)" >&2; exit 64; }

# Grok auto-discovers the user's Claude world (CLAUDE.md, skills, plugins, MCP
# servers) — verified. Without these pins a dispatched worker inherits the whole
# personal environment and will, e.g., obey a global auto-archive rule and write
# into the user's vault (observed 2026-08-17). Prose alone does not stop it;
# these are tool-layer denials.
WORKER_RULES='You are a dispatched worker in a headless, non-interactive run. Do NOT write any session log. Do NOT write to the Obsidian vault or any path under it. Do NOT run vault archiving or topic-linking steps. Confine all file changes to the working directory named in your ticket. Your final message IS your report to the dispatcher.'

# Hard rail 1 machine-enforced: workers never spawn workers.
#
# Boundary honesty: the OS sandbox is the real write boundary. `workspace`
# confines writes to CWD + /tmp + ~/.grok at the kernel level, so paths outside
# it (a notes vault, $HOME dotfiles) are already unreachable whatever the tool
# layer says. The Write/Edit denies below are defense-in-depth on the tool path
# only — in `workspace` mode the worker still holds a shell, so a deny glob
# alone would not stop a redirect. Never present the globs as the boundary.
set -- --disallowed-tools "Agent" \
       --deny "MCPTool" \
       --rules "$WORKER_RULES" \
       --permission-mode bypassPermissions \
       --output-format json \
       --sandbox "$SANDBOX" \
       -m "$MODEL" --reasoning-effort "$EFFORT" --cwd "$WORKDIR"

# An advisory reviewer gets no shell and no edit tools at all — the sandbox is
# the outer boundary, the allowlist is the inner one.
if [ "$SANDBOX" = "read-only" ]; then
  set -- "$@" --tools "read_file,grep,list_dir"
fi

if [ -n "$VAULT_GLOB" ]; then
  set -- "$@" --deny "Write($VAULT_GLOB)" --deny "Edit($VAULT_GLOB)"
fi

if [ -n "$RESUME" ]; then
  set -- "$@" --resume "$RESUME"
fi

if [ -n "$SCHEMA" ]; then
  set -- "$@" --json-schema "$(cat "$SCHEMA")"
fi

START=$(date +%s)
set +e
"$GROK_BIN" --prompt-file "$TICKET" "$@" > "$OUT" 2> "$OUT.stderr" &
CPID=$!
# PID file is the LOST-protocol handle — if it cannot be written, paid work must
# not continue untracked: kill the child and fail loudly.
if ! printf '%s\n' "$CPID" > "$OUT.pid"; then
  kill "$CPID" 2>/dev/null; wait "$CPID" 2>/dev/null
  echo "BLOCKED: could not write pid file $OUT.pid; grok child killed — no untracked spend" >&2
  exit 74
fi
trap 'kill "$CPID" 2>/dev/null; wait "$CPID" 2>/dev/null; echo "BLOCKED: launcher terminated; grok child $CPID killed and reaped" >&2; exit 143' INT TERM
wait "$CPID"
CODE=$?
trap - INT TERM
set -e
END=$(date +%s)

echo "exit code: $CODE"
echo "duration: $((END - START))s"
echo "pid file: $OUT.pid (child $CPID, reaped)"
echo "binary: $GROK_BIN"
echo "sandbox: $SANDBOX | tools: $([ "$SANDBOX" = read-only ] && echo 'read_file,grep,list_dir' || echo default) | Agent: blocked | MCP: denied | schema: ${SCHEMA:-none}"

# Seat provenance + reactive context measurement. modelUsage is BILLED-tier
# evidence (verification.md): it names what was charged, not the weights that
# answered. Never print it as `seat: verified`.
if command -v python3 >/dev/null 2>&1; then
  python3 - "$OUT" <<'PYEOF'
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding="utf-8", errors="replace"))
except Exception as e:
    print(f"seat evidence: NONE (unparsable artifact: {e})"); sys.exit(0)
if not isinstance(d, dict):
    print("seat evidence: NONE (artifact is not a JSON object)"); sys.exit(0)
if d.get("type") == "error":
    print(f'GROK ERROR: {d.get("message","(no message)")}'); sys.exit(0)
mu = d.get("modelUsage")
if isinstance(mu, dict) and mu:
    print(f'seat: billed-tier evidence — modelUsage {", ".join(sorted(mu))} (NOT served-tier; not `verified`)')
else:
    print("seat evidence: NONE (no modelUsage in envelope)")
print(f'session id: {d.get("sessionId","(none)")}')
print(f'stop reason: {d.get("stopReason","(none)")}  turns: {d.get("num_turns","(none)")}')
u = d.get("usage") or {}
inp = u.get("input_tokens"); tot = u.get("total_tokens")
print(f'usage: input={inp} total={tot} cost_usd={d.get("total_cost_usd")}')
# Reactive context rule (routing.md): the 200K repricing cliff applies to the
# WHOLE request, so measure what actually happened instead of guessing ahead.
try:
    if inp is not None and int(inp) > 200000:
        print("CONTEXT ALERT: input exceeded 200000 — request was repriced at the 2x tier; "
              "Grok is ineligible for equal-or-larger tickets this run")
    elif inp is not None and int(inp) > 150000:
        print("CONTEXT WARN: input above 150000 — approaching the 200000 repricing cliff")
except (TypeError, ValueError):
    pass
PYEOF
fi

exit "$CODE"
