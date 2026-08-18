# Grok workers: probe, invoke, read back

xAI's Grok CLI is an optional accelerator, alongside Codex — never a requirement. When present, it adds a third family of worker seats. Everything below is sourced from direct execution on this machine (`.foreman/scratch/grok-transport-verified.md`, verified 2026-08-17), the launcher script (`scripts/grok-dispatch.sh`), and the cost/capability tables in [model-matrix.md](model-matrix.md) — nothing here is asserted from general knowledge of Grok.

## The probe (once per session, cache the result)

```bash
command -v grok || ls "$HOME/.grok/bin/grok"   # 1. installed?
"$HOME/.grok/bin/grok" --version               # 2. binary alive — which build?
grok models                                    # 3. authenticated? which models does THIS account see?
```

- Honor `GROK_BIN` if the environment sets it — the launcher does (`${GROK_BIN:-$HOME/.grok/bin/grok}`). Verified path on this machine: `~/.grok/bin/grok -> ~/.grok/downloads/grok-macos-aarch64`.
- Step 3 does two jobs at once — it is both the auth check and the tier-discovery call. `grok models` reported "logged in with grok.com" together with the model list (`grok-4.6` default, `grok-4.5`) in one output. No separate `grok auth status` equivalent has been verified on this build; don't invent one.
- Verified build: Grok CLI 1.0.5 (5115b46bc909), macOS arm64, OAuth/OIDC session auth against grok.com — a subscription, not an API key (see Billing).
- Same GNU-`timeout` caveat as Codex: it doesn't exist on stock macOS or Windows. Use your shell tool's own timeout, set generously (60s+) — a slow response is latency, not absence.

## Billing (subscription session — ordinary budget discipline applies)

The verified account on this machine authenticates via an OAuth/OIDC session against grok.com, not an API key — a subscription, the same shape as a ChatGPT-subscription Codex login, not metered per call against a card. **Unlike Codex, Grok has not been given a standing-pre-approval exception** — SKILL.md's budget-discipline exception is scoped explicitly to Codex ("Exception — Codex: this budget-discipline section does not apply to Codex"). Treat Grok spend under the ordinary rule: journal it, and step a Grok dispatch down or stop under budget pressure exactly as for any other seat.

What "spend" means concretely: every `--output-format json` call returns a `total_cost_usd` field in the envelope, which the launcher parses and prints. Real dispatches observed this session: a trivial echo ~$0.010; a one-file schema review ~$0.015; writing a module plus tests and running them ~$0.021 (20s, 4 turns); resuming a session to add validation and re-run tests ~$0.014 (26s, 4 turns). Treat published list prices (model-matrix.md Table 1) as an **upper bound**, not the bill — a real 6-turn Grok 4.6 review on this account billed ~3.5x below what list pricing predicted (model-matrix.md). Where the envelope reports a real cost, that number wins over any table.

Functional check before the first real dispatch of a session: one tiny low-effort call (e.g. `grok -p "Reply with exactly: ok" --reasoning-effort low --output-format json`) to confirm the session is live before committing a real ticket to it.

## Discovering the account's tiers

`grok models` is authoritative and, on this build, sufficient by itself — no account-mode ID-splitting (the kind that bit Codex, where ChatGPT-login and API-key IDs differ) has been observed for Grok. This account sees exactly two models: `grok-4.6` (default) and `grok-4.5`.

Effort levels are **per-model**, not universal, and this matters for dispatch safety:

- `grok-4.6`: `low`, `medium`, `high`, `xhigh` (models_cache.json marks both `high` and `xhigh` `default: true`; treat `xhigh` as the effective default when unspecified).
- `grok-4.5`: `low`, `medium`, `high` only — **no `xhigh`**. Sending `xhigh` to `grok-4.5` is a hard error (exit 1, `unknown effort level 'xhigh'; use one of: high, medium, low`), not a silent downgrade. This **disproves** a third-party claim (surfaced by research, flagged unverified) that Grok 4.5 silently downgrades an `xhigh` request. The launcher enforces this itself before spending a turn (see Transport).
- Both models report a 500,000-token context window and an 80% `auto_compact_threshold_percent`.

Map verified tiers to routing classes per model-matrix.md rather than duplicating its tables here: Grok 4.6 is the first-choice **FRONTIER-advisory** seat (adversarial review / second opinion) and a first-choice **WORKHORSE** seat for well-specified implementation, both bounded by the 200K-token context cliff (Table 3) — above that, route to a Claude seat instead of paying the Grok surcharge. Grok 4.5 is a lower-capability fallback (index 56, no `xhigh`) — reach for it only when 4.6 is unavailable.

As general hygiene (routing.md's Currency rule), verify a tier with one tiny call before leaning on it for a long run — this build has shown no entitlement surprises so far, but that is not the same guarantee as "verified this run."

## Transport: visible subagent wrapper first, direct launcher call as fallback

Grok gets the same wrapper-first transport pattern v0.3 gave Codex, via the bundled `scripts/grok-dispatch.sh` launcher and the `foreman-grok-wrapper` agent.

**When the Agent tool is available, dispatch Grok through the wrapper subagent** — a FAST-seat Claude subagent whose entire job is to run the fixed-argv launcher once and relay the result. Stated honestly, this buys the same three things the Codex wrapper buys: user visibility (a named crew member in the harness UI, not an invisible shell-out), notification-driven collection instead of hand-rolled polling, and a foreman that stays free while the worker runs. Direct launcher invocation from the foreman's own Bash remains correct in Agent-tool-less modes and for sub-minute advisory calls where wrapper overhead exceeds the benefit.

**The launcher's real argument list** (read from `scripts/grok-dispatch.sh` — never hand-compose a `grok` call):

```
grok-dispatch.sh <ticket-file> <model> <effort> <read-only|workspace> <artifact-json> [workdir] [resume-session-id] [schema-file]
```

**Eight positional slots: five required** (ticket, model, effort, sandbox, artifact path) **and three optional** (`workdir`, defaulting to `.`; a resume session id, defaulting to none — a fresh session; a schema file, defaulting to none). Optional slots are positional — to pass a schema without resuming, pass an empty string for the resume slot. Note the sandbox spelling: **`workspace`, not Codex's `workspace-write`** — don't cross-copy the two launchers' argv.

Before spending anything, the launcher validates and refuses (`BLOCKED` on stderr, nonzero exit) on:

- `sandbox` not exactly `read-only` or `workspace` — **`off` (Grok's own CLI default) and `strict` are both refused.** Grok itself offers four sandbox profiles (`off`, `workspace`, `read-only`, `strict`), but this launcher wires through only two of them and never dispatches a worker with no OS-enforced boundary at all.
- `effort` not one of `low|medium|high|xhigh`.
- `xhigh` requested against a model id containing `4.5` — caught here, before the call, because it's a known hard error on this build.
- a malformed model id, or a resume id containing anything outside `[A-Za-z0-9-]`.
- a missing ticket file or workdir.
- **`read-only` sandbox sited under `/tmp`, `/private/tmp`, or `/var/tmp`** — verified caveat: `read-only` does not actually contain writes there (a file was created in a `/private/tmp` workdir under `--sandbox read-only` in testing, though `read-only` genuinely blocked writes elsewhere). The launcher refuses this combination outright rather than let a reviewer believe it's isolated when it isn't.
- an artifact path that doesn't end in `.json`, is a symlink, aliases the ticket file, or otherwise isn't a plain regular file.

What the launcher pins into the actual `grok` invocation once validation passes:

- `--disallowed-tools "Agent"` and `--deny "MCPTool"` — **this machine-enforces "workers never spawn workers" at the tool layer, inside the dispatched Grok process itself.** This is strictly stronger than the Codex path: Codex's launcher has no equivalent tool-denial flag, so "workers never spawn workers" there is contractual only (codex-workers.md). For Grok, even a badly-prompted worker cannot invoke a subagent-spawning tool or reach an MCP server — the CLI itself refuses.
- `--deny "Write($VAULT_GLOB)"` and `--deny "Edit($VAULT_GLOB)"` (glob overridable via `FOREMAN_VAULT_GLOB`), plus a `--rules` string forbidding session logs, vault writes, and archiving/topic-linking, and confining edits to the ticket's working directory. This exists because Grok auto-discovers and loads the user's whole Claude Code world — `~/.claude/CLAUDE.md`, `~/.claude/skills/` (204 skills loaded in testing), `.claude/agents/`, installed plugins, and MCP server config from `~/.claude.json`/`.mcp.json` — and an unconstrained dispatch was **observed** obeying the user's global Obsidian auto-archive rule and writing session logs into the vault, with vault hooks firing. `--rules` was verified to suppress it.
- `--permission-mode bypassPermissions --output-format json --sandbox "$SANDBOX" -m "$MODEL" --reasoning-effort "$EFFORT" --cwd "$WORKDIR"`, plus `--resume "$RESUME"` when a resume id was given.
- For `read-only` dispatches specifically, an additional inner allowlist — `--tools read_file,grep,list_dir` — so an advisory reviewer gets no shell and no edit tools at all: the sandbox is the outer boundary, this is the inner one.
- The child's PID is written to `<artifact>.json.pid` **before** the launcher waits on it — the "prove it stopped" handle for the LOST protocol (delegation.md). If the PID file can't be written, the launcher kills the just-spawned child and refuses rather than let paid work run untracked. An INT/TERM to the launcher forwards to the child and reaps it — no orphaned Grok process left editing after the wrapper dies.

**The wrapper contract** (put it in the wrapper's prompt verbatim — it also lives in `agents/foreman-grok-wrapper.md`):

1. Run `scripts/grok-dispatch.sh` exactly once, with exactly the arguments your ticket gives you, and the shell timeout your ticket names. Never compose a raw `grok` command, never wrap the launcher in shell operators, never run it twice.
2. Report in exactly this shape: Line 1 `DONE` if the launcher exited zero, else `BLOCKED` followed by the tail of `<artifact>.json.stderr`. Then the launcher's stdout (the transport envelope) verbatim. Then Grok's final message, extracted read-only from the JSON artifact, complete and verbatim — no summarizing, no interpretation.
3. Spawn nothing; write nothing except what the launcher itself writes.

**Vocabulary discipline:** identical to Codex's rule — the envelope is transport metadata, not a report vocabulary. The worker status or reviewer finding is read from the first line of the *relayed* Grok message, exactly as if Grok had reported directly.

**Failure mapping (deterministic — no judgment calls at the transport layer):**

| Observation | Treatment |
|---|---|
| Launcher exit nonzero (any pre-flight `BLOCKED:` refusal above, or the child itself exiting nonzero) | Worker `BLOCKED`; envelope + `<artifact>.json.stderr` are the evidence |
| Exit 0, artifact JSON top-level `{"type":"error", ...}` (e.g. an unknown model id Grok itself refused) | `BLOCKED`; the envelope prints `GROK ERROR: <message>` verbatim — a genuine provider-side refusal, not a transport glitch |
| Exit 0, no parseable status line in the relayed final message | `BLOCKED` (malformed report); artifact path in ledger |
| Exit 0, empty final message or unparsable JSON artifact | `BLOCKED`; artifact retained for diagnosis |
| Wrapper itself silent past its deadline | Wrapper task is `LOST` — apply the LOST protocol to the *wrapper* (delegation.md); check `<artifact>.json.pid`, kill the child if still live, and only then reconcile the workspace |
| Envelope reports `seat: billed-tier evidence …` | Normal and expected — record it; it is **not** `seat: verified` (see Reading back) |
| Envelope reports `CONTEXT ALERT: input exceeded 200000` | Grok is ineligible for equal-or-larger tickets for the rest of this run (model-matrix.md Table 3) — re-route and journal it |

**Enforcement scope, stated honestly:** the launcher makes compliance auditable — the transcript shows either one launcher call or a contract breach — and pins the argv so a wrapper has no legitimate reason to touch `grok` directly. It does **not** machine-prevent the wrapper's own general shell from calling `grok` raw; that remains a harness-layer concern (tool-policy hooks), exactly as with Codex. Where Grok genuinely goes further than Codex is *inside* the dispatched process: `--disallowed-tools Agent` / `--deny MCPTool` stop the worker itself from spawning subagents or reaching MCP, machine-enforced rather than merely written into its rules.

## Invocation pattern

Non-interactive, one ticket per invocation, via the wrapper (above) or directly:

```bash
# Advisory / review work — read-only sandbox, sited outside /tmp:
skills/fable-foreman/scripts/grok-dispatch.sh \
  .foreman/scratch/ticket-N.md grok-4.6 medium read-only \
  .foreman/scratch/artifact-N.json <repo-path>

# Implementation work — writable workspace:
skills/fable-foreman/scripts/grok-dispatch.sh \
  .foreman/scratch/ticket-N.md grok-4.6 high workspace \
  .foreman/scratch/artifact-N.json <repo-path>

# Continuing a prior dispatch's session (verified: the worker recalled code
# from the earlier turn without it being re-sent):
skills/fable-foreman/scripts/grok-dispatch.sh \
  .foreman/scratch/ticket-N-followup.md grok-4.6 high workspace \
  .foreman/scratch/artifact-N2.json <repo-path> <sessionId-from-artifact-N>
```

- The ticket goes in via `--prompt-file` (a real file path, baked in by the launcher) — unlike Codex's stdin pipe (`- <`), don't try to pipe a ticket to Grok directly.
- Effort defaults: `medium` for review/analysis, `high` for implementation (model-matrix.md Table 4) — escalate to `xhigh` only for the hardest verification/design work on `grok-4.6` (never on `grok-4.5`).
- Sandbox follows the *task*, exactly as for Codex: `read-only` for advisory, `workspace` for anything that edits files — and never a read-only reviewer sited under `/tmp` (the launcher refuses it anyway).
- `--json-schema` yields a validated `structuredOutput` object in place of parsed prose — verified working. **Pass it through the launcher's 8th slot (`schema-file`), never by hand-composing a `grok` command**: the launcher reads the schema from a file, validates it is real JSON, and keeps the dispatch inside the pinned argv with its `Agent`/`MCPTool` denials intact. A schema-locked verdict is the recommended shape for review tickets, so it must not cost you the machine-enforced rails.

## Reading back

**Seat provenance first — this is the one nuance that must never get flattened.** The JSON envelope's `modelUsage` key (e.g. `grok-4.6-build`) names what was *billed* for the turn, and it tracks the actual request rather than echoing a constant — verified by requesting each model in turn and observing the key change. That is real evidence, stronger than a self-report. But it comes from the usage/billing layer, not from post-resolution model-identity metadata the way verification.md's Layer 0 defines `SERVED` evidence. **Log it exactly as the launcher itself does:** `seat: billed-tier evidence — modelUsage <key> (NOT served-tier; not 'verified')`. Never write `seat: verified` for a Grok dispatch on this evidence, and never let a Grok report stand in as the accepting verifier verdict on a change (model-matrix.md Table 5; verification.md) — a Grok worker is an advisory reviewer / second opinion, full stop. Rank it closer to verification.md's `REQUESTED` tier than to `SERVED`, even though it is materially better than a bare `-m` flag with no accounting behind it.

Otherwise, Grok workers follow the same contract as Claude and Codex workers: status as the first line of the final message (`DONE` / `DONE_WITH_CONCERNS` / `NEEDS_CONTEXT` / `BLOCKED` — put this in every execution ticket's OUTPUT FORMAT), evidence not narrative, artifacts to `.foreman/scratch/` with paths. A Grok read-only reviewer never leads with a verifier verdict (`PASS`/`FAIL`/`PASS_WITH_NOTES`) the way a Codex read-only reviewer may under verification.md's stated exception — that vocabulary stays reserved for the Claude verifier and a Codex reviewer; Grok's advisory findings feed the Claude verifier as a second opinion, never substitute for it.

Multi-turn continuation is real: `--resume <sessionId>` continues a prior session across a **separate process invocation**, verified — a worker recalled code it had written in an earlier dispatch without being re-sent it. Useful for iterative fix tickets against the same Grok session; each invocation is still one ticket under delegation.md's ticket contract.

**Work-quality spot-check (one data point, not a pattern):** on this account, a Grok worker's self-reported test-pass claim (4/4, then 5/5 after a follow-up ticket) was independently re-run by the foreman and genuinely matched, across two dispatches. Treat this the same as any worker self-report per verification.md — re-run it yourself; one clean spot-check is not a standing exemption.

## Quota notes

- Grok draws on its own account pool (the grok.com subscription), independent of both the Claude pool the foreman itself runs on and Codex's ChatGPT pool (model-matrix.md Table 6) — a genuine endurance asymmetry worth using for bulk work when the Claude pool is under pressure.
- The concrete, verified boundary to route around is the **200K-token repricing cliff**: above 200K input, the *entire* request reprices at 2x, so route away from the surcharge. Which seat is then cheapest is not established — Table 3's cross-provider comparison is list-price math and this account's measured Grok billing ran well under list. Grok's 500K ceiling, by contrast, is a hard limit. The launcher measures this reactively — printing `CONTEXT WARN` above 150K and `CONTEXT ALERT` above 200K input from the envelope's own usage figures — because a foreman cannot reliably estimate request size ahead of a dispatch (Grok silently prepends the discovered Claude Code config to every call). Once any call in a run crosses 200K, treat Grok as ineligible for equal-or-larger tickets for the rest of that run.
- No verified data exists on this account for rate-limit windows or message-allowance mechanics beyond the cost-per-dispatch figures above (Billing) — don't promise numbers that weren't measured. Rate limits are per-account, same as Codex: more parallel Grok workers does not buy more throughput. A rate-limit error mid-run is a real failure toward the precedence table (delegation.md) — don't burn retries in place; fall back to the Claude seat of the same class for the remainder and journal it.
