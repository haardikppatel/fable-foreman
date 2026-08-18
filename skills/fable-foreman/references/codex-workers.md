# Codex workers: probe, invoke, read back

OpenAI's Codex CLI is an optional accelerator — never a requirement. When present, it adds a second family of worker seats.

## The probe (once per session, cache the result)

```bash
command -v codex                                   # 1. installed?
codex login status                                 # 2. authenticated? which billing mode?
test -s "${CODEX_HOME:-$HOME/.codex}/auth.json"    # 2b. fallback if the subcommand errors
```

- Step 2 is the documented status command; its output also tells you **how the account is billed** (ChatGPT subscription vs API key). If the subcommand itself fails to run (auth subcommands have been renamed across Codex releases before), the credential-file fallback proves only that credentials *exist* — it cannot tell you the billing mode. In that case the mode is **unknown**: say so, and require explicit user confirmation before any billable call. (Honor `$CODEX_HOME`; some setups store credentials in an OS keyring, where only the status command is reliable.)
- **Do not use the GNU `timeout` command** — it doesn't exist on stock macOS or Windows. Use your shell tool's own timeout parameter, set generously (60s+): a slow response is latency, not absence.

## Billing (standing pre-approval — no per-dispatch ask)

The probe above is metadata-only and free. An actual Codex invocation **spends the user's OpenAI account** — subscription quota, or real metered dollars on an API key — and the user has given standing pre-approval for that spend, including frontier-tier calls. Do not ask before dispatching. Before the first dispatch of a session:

1. Note which billing mode `login status` reported.
2. Record it in the ledger.
3. Dispatch — no confirmation step.

Run the functional check up front — one tiny call, cheapest tier you can name confidently or the account default: `codex exec "Reply with exactly: ok"`. If it fails while credentials exist, they're likely expired: tell the user to run `codex login`; never initiate an interactive auth flow yourself.

The user will tell you directly if a given run needs a Codex budget cap. Absent that, default to using Codex often and ambitiously — reach for its frontier tier whenever it's the right seat, rather than economizing.

## Discovering the account's tiers

Documentation is not entitlement, and **model IDs differ by auth mode** — this repo's own first review dispatch bounced because an API-doc model ID (`gpt-5.6`) wasn't valid for a ChatGPT-account login (which wanted `gpt-5.6-sol`). Procedure:

1. Read `${CODEX_HOME:-$HOME/.codex}/config.toml` — the user's configured `model` and `model_reasoning_effort` are their expressed preference; identify what that model *is* before classifying it.
2. Ask the user, or check `codex` interactive `/model` output, for the tiers their account actually offers.
3. Before relying on any tier in a long run, verify it with one tiny echo call. A tier that fails entitlement goes in the ledger as unavailable.

Map verified tiers to FRONTIER / WORKHORSE / FAST by the provider's published positioning for them (routing.md), and record the mapping in the ledger so it's auditable.

## Transport (v0.3): visible subagents first, direct exec as fallback

Before v0.3 the skill shelled out to `codex exec` directly from the foreman's own Bash. That works, but the Codex worker is invisible to the user (no presence in the harness UI), the foreman must hand-roll background polling and LOST detection, and long builds tie ledger hygiene to manual job bookkeeping. v0.3 changes the default:

**When the Agent tool is available, dispatch Codex through a transport wrapper subagent** — a FAST-seat Claude subagent whose entire job is to run the fixed-argv launcher once and relay the result. Use the bundled `foreman-codex-wrapper` agent where the harness registers plugin agents (its tool list machine-excludes edit tools and agent spawning); otherwise a generic FAST subagent carrying the contract below. What this buys, stated honestly:

- **User visibility:** the *wrapper* appears in the harness UI as a live subagent — the user sees a named crew member carrying the Codex job instead of an invisible shell-out. The Codex process itself sits behind it; the wrapper's report must therefore expose the handles (artifact paths, exit code) that make the inner process inspectable after the fact.
- **Notifications over polling:** the harness notifies the foreman on wrapper completion; no polling loops, no foreground blocking, and LOST detection rides the harness's own task tracking.
- **Foreman stays free:** long Codex builds no longer occupy the foreman's attention between dispatch and collection.

Cost: one FAST wrapper's tokens per dispatch (small; the wrapper does no thinking). Direct launcher invocation from the foreman's own Bash remains correct in Codex-only mode (no Agent tool) and for sub-minute advisory calls where wrapper overhead exceeds the benefit.

**The wrapper contract (put it in the wrapper's prompt verbatim):**

1. Run `scripts/codex-dispatch.sh` (in this skill's directory) exactly once, with exactly the six arguments given in your ticket — ticket file, model, effort, sandbox, artifact path, workdir. Never compose a raw `codex` command, never add shell operators around the launcher, never run it twice, never edit any file yourself. Set your shell tool's timeout to the deadline named in the ticket.
2. Relay two things, clearly separated: first the launcher's **transport envelope** (its stdout: exit code, duration, seat evidence — verbatim), then the Codex worker's final message extracted from the artifact JSONL, **verbatim** — no summarizing, no interpretation. You are transport, not a reviewer.
3. Spawn nothing; write nothing except the artifact files the launcher itself names.

**Vocabulary discipline:** the transport envelope is *transport metadata*, not a report vocabulary. The worker status (`DONE`/`BLOCKED`/…) or verifier verdict (`PASS`/`FAIL`/…) is read from the first line of the **relayed Codex message**, exactly as if Codex had reported directly; the foreman enters `REPORTED(status)` from that line alone. An envelope without a parseable status line in the relayed message maps to `BLOCKED` (see failure mapping). Three vocabularies remain three (delegation.md).

**Failure mapping (deterministic — no judgment calls at the transport layer):**

| Observation | Treatment |
|---|---|
| Launcher exit nonzero | Worker `BLOCKED`; envelope + stderr artifact are the evidence |
| Exit 0, no parseable status line in relayed message | `BLOCKED` (malformed report); artifact path in ledger |
| Exit 0, empty final message / malformed JSONL | `BLOCKED`; artifact retained for diagnosis |
| Wrapper itself silent past its deadline | Wrapper task is `LOST` — apply the LOST protocol (delegation.md) to the *wrapper*; then reconcile the workspace before any retry, because the inner Codex process may have kept editing after the wrapper died |
| Envelope reports `seat: unverified` | Normal under current Codex builds — record it; Layer 0 consequences apply (verification.md) |

The wrapper is transport, not delegation — this is the sanctioned carve-out to "workers never spawn workers" (SKILL.md hard rail 1), and it is tight *because the launcher pins the argv*: the wrapper has no legitimate reason to touch `codex` directly, and a wrapper that does has broken contract.

**Enforcement scope, stated honestly:** the launcher makes compliance *deterministically auditable* (the transcript shows either one launcher call or a contract breach — there is no ambiguous middle), and the launcher itself validates everything it is given. What it does not do is machine-prevent a wrapper from invoking `codex` raw — the wrapper holds a general shell, and prompt text cannot revoke it. Machine enforcement belongs to the harness layer (tool-policy hooks or permission rules restricting `codex` outside the launcher path) and is a recommended hardening for standing setups, not something this skill can impose from inside a prompt. Treat a transcript showing a raw `codex` call from a wrapper exactly like a worker editing outside its WRITE SET: a contract breach that voids the dispatch.

**Orphan control:** the launcher records the Codex child PID to `<artifact>.pid` before waiting, and forwards INT/TERM to the child. On a wrapper-LOST event, that PID file is the "prove it stopped" handle (delegation.md): check it, kill if live, and only then reconcile the workspace.

**Native-transport option (documented, not default):** a claudemix-style loopback splitter can make GPT models *literally* native subagents (model pinned in agent frontmatter, no CLI at all). That requires third-party infrastructure (CLIProxyAPI), an interactive OAuth install, and a terms-of-service judgment that belongs to the user. Procedure and caveats: [setup-runbook.md](setup-runbook.md), Part B. Never install it unprompted.

## Invocation pattern

Non-interactive, one task per invocation, seat and effort pinned per the routing decision:

```bash
# Advisory / review work — read-only sandbox:
codex exec -m <verified-model> -c model_reasoning_effort=<level> \
  --sandbox read-only -C <repo-path> - < .foreman/scratch/ticket-N.md

# Implementation work — writable workspace:
codex exec -m <verified-model> -c model_reasoning_effort=<level> \
  --sandbox workspace-write -C <repo-path> - < .foreman/scratch/ticket-N.md
```

- Write the ticket to a file and pipe via stdin (`- <`) — avoids shell-quoting bugs.
- Sandbox follows the *task* (advisory vs implementation), not the seat.
- `--json` emits a JSONL event stream if you need structured events; otherwise the final message arrives on stdout.
- Long tasks: under the default wrapper transport, the wrapper subagent carries the job and the harness handles completion notification — record the wrapper's task identity in the ledger instead of a raw job ID. Under direct exec (fallback), the baseline rule stands: **record the job ID and output file path in the ledger at dispatch time**, capture the exit code on collection, and apply the LOST-worker protocol (delegation.md) if it goes silent. Never foreground-block the session on a long build.

## Reading back

Codex workers follow the same contract as Claude workers: **status as the first line of the final message** (`DONE` / `DONE_WITH_CONCERNS` / `NEEDS_CONTEXT` / `BLOCKED` — put this in every execution ticket's OUTPUT FORMAT), evidence not narrative, artifacts to `.foreman/scratch/` with paths. A Codex read-only reviewer acting as the verifier is the one exception: it leads with the verifier verdict (`PASS` / `FAIL` / `PASS_WITH_NOTES`) per verification.md. Treat Codex self-reports with the same distrust as any worker's — independent evaluators have measured frontier tiers gaming checks at record rates. Cross-family verification (Claude verifies Codex work) is the default.

## Quota notes

- Codex plans meter usage in rolling windows, with cheaper tiers typically draining the shared pool more slowly and often enjoying higher message allowances — but verify against the user's plan rather than promising numbers.
- Rate limits are per-account: more parallel workers ≠ more throughput. Sequential-by-default applies here too.
- Rate-limit errors mid-run: don't burn retries — fall back to the Claude seat of the same class for the remainder and note it in the ledger.
