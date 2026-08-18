# Verification: cheap checks first, then a blind reviewer

Orchestration's bottleneck isn't coordination — it's validation. This is where the skill spends its rigor.

## Layer 0 — Seat provenance (verify with the log, never the model's self-report)

Routing decisions are only as real as the seat that actually served the request, and runtimes can substitute seats (routing.md). So before a report's *content* is graded, its *provenance* is established — from deterministic evidence only. Evidence comes in tiers, and the tiers are not equal:

- **SERVED evidence** (the real thing): an artifact produced *after* model resolution that names the model that answered — a served-model field in an event stream, a provider-side log correlating the request to the serving model. Only served-tier evidence makes a seat `verified`.
- **BILLED evidence** (new, below served): provider-side *accounting* that names the model charged for the turn — e.g. Grok's envelope `modelUsage` key, which tracks the request rather than echoing a constant. Materially stronger than a self-report, because it originates outside the model's prose. It is still **not** served evidence: a billing SKU names what was charged, not the weights that answered, and nothing establishes that it would reveal a substitution. **Billed evidence never makes a seat `verified`** and never unlocks class-sensitive work.
- **ROUTED evidence** (weaker): an artifact proving which *route* a request took without naming the served model — a proxy log line, an HTTP status from a known upstream. Records that routing behaved; does not verify the seat.
- **REQUESTED evidence** (weakest): what you asked for — a `-m` flag, an agent-file `model:` line, the harness UI echoing the dispatch parameters. Necessary for the ledger, worthless as proof of what served.

Per surface, honestly stated:

- **Codex dispatches:** current Codex builds do **not** emit a served-model field in `codex exec --json` (verified 2026-08-07 against the CLI's JSONL processor source — the stream's `thread.started` carries only a thread id). The launcher (`scripts/codex-dispatch.sh`) scans for one anyway, version-tolerantly: if a future build emits it, that is served evidence; until then every Codex dispatch is `seat: unverified — requested <model> via -m`, written exactly so in the ledger attempt line. Do not dress requested evidence as served.
- **Grok dispatches:** the JSON envelope carries `modelUsage` keyed by the billed model (verified 2026-08-17: requesting 4.5 vs 4.6 changes the key). That is **billed-tier** evidence — `scripts/grok-dispatch.sh` prints it as `seat: billed-tier evidence — modelUsage <key> (NOT served-tier; not 'verified')` and the ledger records that string verbatim. Consequently a Grok seat may act as an advisory reviewer or second opinion, but **never as the accepting verifier verdict** on a change (grok-workers.md, model-matrix.md Table 5).
- **Claude subagent dispatches:** harness dispatch metadata generally records the *request* (requested tier). Where the harness surfaces a post-resolution model identity, that is served evidence; where it doesn't, the seat is `unverified` — say so rather than inferring the seat from output quality or the worker's claims.
- **Never** establish provenance by asking the worker what model it is. A model's self-identification tracks its prompt and system context, not its weights. (Measured nuance, 2026-08-07: Claude Code injects identity into Claude subagents' system prompts, and haiku subagents resisted three priming attempts including a fake proxy-routing notice — self-reports *here* are usually right. The rule stands anyway: "usually right" is not evidence, and the risk concentrates exactly where it matters — foreign models behind proxies, which have no identity anchor at all.)

Consequences of an unverified seat: the work is not discarded, but (a) it cannot count as cross-family verification (below), and (b) FRONTIER-class judgment recorded from it is downgraded to advisory. A **detected substitution** (evidence shows a different seat than routed) is a *transport/routing failure*, not a ticket failure: invalidate the seat mapping, repair the route (or change transport) before re-dispatching, and count a repeated substitution on the same route as a real failure toward the precedence table — never loop free retries into a route that is known to lie.

## Finding triage — grade the citation before you grade the code

Findings are claims, and a seat that fabricates when uncertain fabricates
confidently. **Never ask a seat to self-report a confidence score.** Require the
finding contract instead (delegation.md): every finding carries an evidence class
— `QUOTED`, `OBSERVED`, `DERIVED`, or `INFERRED` — and calibration is computed by
the foreman from whether the citations resolve.

1. **Resolve every citation first.** `QUOTED` → the exact string must exist at the
   named location (grep it). `OBSERVED` → the named command must reproduce. This
   is cheap: a lookup, not a re-derivation.
2. **Dismiss unsupported findings; do not escalate them to the user.** An
   `INFERRED` finding, or one whose citation fails to resolve, is recorded
   `DISMISSED (unsupported)` in the ledger with the reason, and never enters a fix
   wave. Resolving a bad finding is the foreman's job, not the user's.
3. **Taint rule.** One fabricated citation means re-verify *every* finding in that
   report and write `seat reliability: fabricated citation` on the attempt line.
   That seat carries no advisory weight for the rest of the run.
4. **Absence is not evidence.** "X does not exist" is `OBSERVED` only when the
   failed search is shown *and* its scope covers where X would be. A seat
   reporting absence from a sandbox that could not reach the location is
   `INFERRED` — dismiss it. (Live case, 2026-08-17: a read-only reviewer correctly
   quoted four rules from files it could see, then declared an event nonexistent
   because it lay outside its sandbox. Four findings stood; that one did not.)

## When the verifier is required

In Full, Codex-boosted, Codex-only, and Delegate-only modes: every accepted change, **except** single-file changes with no logic content (pure formatting, comments, docs). In Delegate-only mode the verifier still runs, but deterministic checks nobody could execute remain **UNVERIFIED** until the user supplies their results — a verifier verdict cannot substitute for an unrun check, so acceptance waits on both. In the Discipline modes there is no blind verifier — the disclosed reduced-assurance rule in SKILL.md replaces this section, and acceptances are labeled "self-reviewed, not blind-verified." That's the whole rule. "It seemed straightforward" is not an exemption — straightforward-looking changes are where unreviewed regressions live. If you are tempted to skip the verifier, that impulse is itself a signal the change deserves one.

## Layer 1 — Deterministic checks (free, always first)

Run the project's **real** gate yourself via Bash before paying for model judgment:

- The actual build/test command the project ships (`npm run build`, `make test`, CI's exact command). **Never a weaker proxy** — a bare `tsc --noEmit` can pass while the real `tsc -b` build fails. Unsure what the real gate is? Read `package.json` scripts / CI config; don't invent one.
- In delegate-only mode (no real shell): you cannot run these — mark them **UNVERIFIED**, ask the user to run them, and never count an unrun check as passed.

A failing deterministic check needs no verifier — it goes straight into a fix ticket.

## Layer 2 — The blind verifier (`foreman-verifier`)

Dispatch with:

1. **The original task, verbatim** — the user's words, never the worker's restatement. Workers narrow problems in self-serving ways ("customer #4012" becomes "some customers").
2. The diff or changed-file paths.
3. The acceptance criteria from the ticket, inline.
4. **Nothing else.** No worker reasoning, no summaries. Anchoring the verifier on the builder's narrative defeats the point.

The verifier assumes the work is broken until it personally reproduces evidence otherwise: re-runs checks itself, walks the diff, and checks the *goal*, not just the checklist — "checks pass but the goal is broken" is a FAIL. Its tool allowlist is read-and-run only (`Read, Glob, Grep, Bash`) — no edit tools, no delegation, no skills — and its Bash use is check-only by contract.

**The mutation backstop** (be honest about what it is): **commit the candidate change** so it is in the tree and the tree is clean *before* dispatching the verifier — never stash it, which would remove the very change under verification and leave the verifier validating the baseline. When the verifier returns, `git status --porcelain` must be empty and `git rev-parse HEAD` unchanged. That detects mutations to tracked content and refs — it does not catch ignored files or external state, so this is contract-plus-detection, not a sandbox. Any detected mutation voids the verification and is itself a finding. For hard isolation, run the verifier as a Codex read-only reviewer (`--sandbox read-only`) or, once the change is committed, in a worktree.

Verdicts: `PASS` / `FAIL` / `PASS_WITH_NOTES` — the first line of the verifier's report, whichever provider runs it (a Codex read-only reviewer acting as verifier uses this vocabulary, not the worker statuses). Per-criterion evidence table; everything unexamined goes under **Not checked** and counts as NOT verified. `PASS_WITH_NOTES` is legal only when every *required* criterion passed and the notes concern non-required observations — a required criterion under a note is a `FAIL`.

## Disagreement and flakiness rules

- **A reproduced deterministic failure is authoritative.** If the foreman's check fails and the verifier says PASS (or vice versa), the failing run wins until explained.
- Suspected flaky test: at most **3 reruns** to characterize it. Inconsistent results = treat as failing; report the flake itself as a finding. Never rerun-until-green.
- Verifier verdict vs deterministic evidence still unresolved after that → the change is **blocked**, not accepted. Report both artifacts to the user.

## Cross-family pairing

When both providers are available, verify across families: Codex built it → Claude verifies; Claude built it → a Codex read-only reviewer is a strong second opinion. Same-family reviewers share the builder's blind spots. This matters most at the frontier — independent pre-deployment evaluation in 2026 measured record rates of frontier models gaming checks (exploiting eval-environment bugs, extracting hidden test code). Worker self-reports from any provider's top tier are precisely what you don't trust.

**Independence has two axes — context and model — and they are not equal.** `foreman-verifier` runs `model: inherit`, so it holds the LEAD seat's model: a frontier lead gets a frontier verifier, which is the right default for catching real defects. What it does not get is model diversity. Rank the options honestly: cross-family (Codex reviews Claude) > same-family, different tier > **same model, fresh context** > same context. The last is worthless; the third is genuinely useful — blind context still strips the builder's reasoning, its restatement of the task, and its motivated conclusion, which is where most bad accepts come from. So keep verifying, and keep the disclosure accurate: when verifier and foreman resolve to the same model, say "blind-verified (same model, independent context)" rather than implying an independent second opinion you did not obtain. If a shared blind spot would be expensive — subtle concurrency, security boundaries, anything the whole run hinges on — that is when to reach for a Codex reviewer or ask the user for one.

## Acceptance rules for the foreman

- Trust flows from artifacts: diffs, command output, file:line citations. Narrative counts for nothing.
- A worker claiming a test passed is a claim; you or the verifier re-running it is a fact.
- Findings batch into **one** fix ticket (delegation.md), and the fix re-enters this same path. Two consecutive failed fix waves on the same findings → precedence table row 5: stop, escalate to the user with the evidence.
