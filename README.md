# Fable Foreman

**Your strongest model shouldn't be swinging the hammer.**

Built in public by [DontSleepOnAI](https://dontsleeponai.com) — the story behind this skill (including the five-round adversarial review where OpenAI's newest model tore apart the first draft) lives there.

Fable Foreman turns whichever frontier-class Claude model leads your session into a team lead: it plans, routes each task to the cheapest worker that clears the quality bar — Claude subagents, OpenAI Codex CLI workers, or xAI Grok CLI workers, auto-detected — and refuses to accept meaningful changes until a blind, fresh-context Claude verifier reproduces the evidence. Any subset of those providers works; absence is a routing input, never a blocker. (Environments without subagents get an honest reduced-assurance mode that says so.)

No dated model IDs in routing policy. No configuration files. One skill, five agent roles, four small deterministic scripts, and a set of rules good enough that a frontier model actually follows them.

## What's new in v0.4.0 — know what a seat costs

1. **Grok is a third worker family.** `scripts/grok-dispatch.sh` is a fixed-argv launcher and `foreman-grok-wrapper` is the visible subagent that runs it. Grok's own CLI default sandbox is `off`; the launcher refuses that outright and every dispatch passes an explicit `read-only` or `workspace` profile. It also pins `--disallowed-tools Agent`, `--no-subagents`, and `--deny MCPTool`, so "workers never spawn workers" is machine-enforced *inside* the Grok process — and it switches Claude-config discovery off at the source (`GROK_CLAUDE_*_ENABLED=false`), because an unconstrained dispatch was observed loading the user's whole Claude Code world and writing session logs into their notes vault. Cost comes from the provider's own JSON envelope, not from a table.
2. **Routing now consults a dated cost/capability matrix** — `references/model-matrix.md`, the section below. Classes still decide the tier; the matrix decides the seat *within* the tier, and it prefers off-family workers for bulk implementation because Claude workers drain the same allowance the foreman itself runs on.
3. **Findings carry citations.** Every reviewer, any provider, tags each finding `QUOTED` / `OBSERVED` / `DERIVED` / `INFERRED` and shows the citation behind it. Seats are never asked to self-rate their confidence. The foreman resolves the citations before grading code; unsupported findings are dismissed and journaled, and one fabricated citation taints its whole report.
4. **Self-correction is automatic, and bounded.** Confirmed findings go to a fix worker and then to a *fresh* verifier; the verifier itself never edits. It still stops — for an ask that was advisory in the first place (a review is not a licence to implement), for a design or user-visible-contract decision the user owns, for external blockers, destructive actions, policy refusals, or a bar no seat clears.
5. **Route to what is actually there.** Harness capabilities and the provider pool are two independent axes now, not an enumerated combination table. Claude-only, Claude+Codex, Claude+Grok, or all three — all legal. The foreman never stalls on an absent provider and never asks you to install one mid-run. In every combination the accepting verdict is the Claude verifier.
6. **A `BILLED` evidence tier, ranked below `SERVED`.** Grok's envelope names the model that was *charged* for the turn — real evidence, better than a self-report, but a billing SKU is not the weights that answered. It never makes a seat `verified`, so a Grok seat advises and never accepts.
7. **Opt-in Codex pre-approval, and a wrapper relay treated as a claim.** The published consent default is unchanged; you can now opt your own machine out of the per-session ask (see *What it needs*). And because a transport wrapper was observed relaying an invented report while the real artifact sat on disk, both wrapper contracts pin read-only extraction commands and the foreman reads the artifact file directly for anything it acts on.

**Deliberately not changed:** the First Law is untouched — an earlier draft would have made it "pool-aware" so quota pressure could move the quality bar, and that was dropped. Grok cannot hold a verifier verdict. The ledger discipline is the same.

**"Fable" is where it started, not what it needs.** The foreman seat is a capability class, so any frontier-class Claude runs the skill identically — Opus leads it exactly as Fable does, with the same routing tree, gates, and verification contract. That holds whether an Opus session invokes the skill directly or a Fable session falls back to Opus mid-run; the skill re-probes its own seat and carries on rather than routing off a stale identity.

## The model matrix — who gets the work, at what effort, at what cost

Routing used to answer "which *class* of model does this need?" and stop there. v0.4.0 adds the evidence table that answers the next question: given several seats that clear the bar, which one costs the least? It lives at [`references/model-matrix.md`](skills/fable-foreman/references/model-matrix.md), every number dated and sourced.

**Read the caveats first, because they change what these numbers mean.** On a subscription login (a Claude plan, a ChatGPT login for Codex, a grok.com login for Grok) these prices are **not** card charges — they are the best available proxy for how fast a dispatch depletes that provider's allowance. They become literal money only on API-key auth. Every figure is dated 2026-08-17/18, and the currency rule says the live provider docs win: if anything here disagrees with them, this table is stale, so re-derive it rather than route off it. The capability index is Artificial Analysis Intelligence Index v4.1.1 — one consistent source so the column is comparable, but a **composite**, not a coding benchmark. Small gaps in it are noise.

### Table 1 — seats, price, capability (verified 2026-08-17)

| Seat | In $/M | Out $/M | Cache read | Context | Index | Note |
|---|---|---|---|---|---|---|
| Claude Opus 5 | 5 | 25 | 90% off | 1M | **63** | highest measured; no surcharge at any length |
| Claude Fable 5 | 10 | 50 | 90% off | 1M | 62* | *score unstable across index revisions (64.9 → 60 → 62) |
| Grok 4.6 | 2 | 6 | 75% off | 500K | **61** | **2x on the WHOLE request above 200K** |
| gpt-5.6-sol | 5 | 30 | 90% off | 1.05M | 61 | >272K: 2x in / 1.5x out |
| gpt-5.6-terra | 2 | 12 | 90% off | 1.05M | 57 | >272K surcharge as above |
| Grok 4.5 | 2 | 6 | 85% off | 500K | 56 | no `xhigh` — sending it is a hard error |
| Claude Sonnet 5 | 2 | 10 | 90% off | 1M | 55 | no surcharge ever |
| gpt-5.6-luna | 0.20 | 1.20 | 90% off | 1.05M | **52** | best value on the board by a wide margin |
| Claude Haiku 4.5 | 1 | 5 | 90% off | **200K** | 30 | 4096-token cache floor — short turns cache poorly |

### The three conclusions that drive routing

1. **Grok 4.6 is the near-frontier value seat.** It sits in the same index band as Opus 5 and sol (61 vs 63 vs 61) at roughly **44% of Opus 5's depletion** and **42% of sol's**. State it as a band, not a ratio — a 2-point composite gap is inside the noise, so "61 vs 63" licenses "same tier, far cheaper" and nothing more precise. That, not "Grok is cheap", is the reason to field it.
2. **gpt-5.6-luna dominates Haiku 4.5 outright** — cheaper *and* far more capable (52 vs 30), and Haiku's 4096-token cache floor means short agent turns often get no caching discount at all. Where Codex is available, luna is the FAST seat; Haiku is the fallback when it isn't.
3. **Sol and Fable are priced above their measured capability.** Sol costs 2.4x Grok 4.6 for the same index; Fable costs 2x Opus 5 while scoring at or below it. Field them for a specific strength, cross-family independence, or an unloaded pool — never by default.

### Effort is a volume dial, and it pays off unevenly

Verified for all three providers: **raising reasoning effort never changes the per-token price.** It changes how many reasoning and output tokens get generated, billed at the ordinary output rate — so it multiplies the expensive half of the bill. The payoff depends on the *shape* of the task, not on difficulty alone. Analysis, knowledge work and review curves are **nearly flat** (`low` gives up only 1–3 points for 33–50% less cost; `medium` matches `high` at 70–85% of cost) → default `medium`. Long-horizon coding is **steep** (`low` gives up ~8 points) → default `high`, and do not economize there. The one published tradeoff number: Grok `xhigh` vs `high` on CursorBench buys **+0.9pp accuracy for +20% cost**, which makes `xhigh` on a review close to pure waste.

### The 200K cliff is a routing boundary, not a price bump

Grok reprices the **entire request** at 2x once it crosses 200K, so a job at 210K in / 15K out costs $1.020 against Sonnet 5's $0.570 — Sonnet 44% cheaper on list price, and the same story at 250K and 400K. The launcher measures the dispatch's average prompt size per model call from the envelope and emits `CONTEXT WARN` / `CONTEXT ALERT`, and the foreman routes away from the surcharge rather than trying to estimate request size in advance. Above 500K Grok is ineligible outright — a hard context ceiling, not a price argument.

### Task type to seat (condensed from Table 5)

The First Law is not suspended here: if no listed seat clears the bar, go up a tier or stop — never take the cheap row because it is cheap.

| Task | First choice | Never |
|---|---|---|
| Architecture, ambiguous debugging, final judgment | LEAD (whichever frontier-class model holds the session) | Grok, luna, Haiku |
| Accepting verdict on a change (blind verifier) | **Claude verifier — always the acceptor** | **Grok**, and any off-family seat *as acceptor* |
| Adversarial review / second opinion | **Grok 4.6 @ medium**, then Codex sol | — |
| Well-specified implementation, tests, refactors | **Grok 4.6 @ high** (<200K) when cost dominates, else terra | — |
| Large-context implementation (>200K) | **Sonnet 5**, then terra | **Grok (cliff)**, Haiku (200K cap) |
| Mechanical edits, extraction, scanning | **gpt-5.6-luna @ low**, then Haiku 4.5 | frontier seats |
| Repo-wide sweep (>500K) | Claude or Codex (1M context) | **Grok (500K ceiling)** |

## Why

Anthropic's own engineering shows both sides of the ledger. Their [multi-agent research system writeup](https://www.anthropic.com/engineering/multi-agent-research-system) found an orchestrator-plus-cheaper-subagents design strongly outperformed single agents — an Opus lead with Sonnet workers, exactly this skill's shape — while consuming roughly **15x** the tokens of a single chat, which is why they conclude multi-agent work only pays for high-value tasks. Anthropic's own [cost guidance](https://code.claude.com/docs/en/costs) likewise recommends cheaper-tier teammates under a stronger lead as the default for multi-agent work. And the community has receipts for what happens without discipline — runaway-subagent cost stories are a genre of their own on every AI-coding forum, which is exactly why this skill bounds crew sizes, retries, and spend announcements the way it does.

The difference between those two outcomes is not orchestration machinery — it's **routing judgment and verification discipline**. That's what this skill installs.

## What it does

1. **Probes the job site** — what model is the session running, can it spawn agents, is there a real shell, and which provider CLIs are present. Codex is checked binary-then-`codex login status` for auth *and billing mode*, with a version-tolerant credential-file fallback; Grok is checked for presence, version, auth mode and cached model ids. No billable call, not even the functional `echo ok`, until you've consented to spending that account's credits. The probe is cached, but **expires when the session model changes** — a fallback, a quota event, or a `/model` switch triggers a re-probe rather than letting the foreman route off an identity it no longer has.
2. **Routes by capability class, not model name** — FRONTIER (judgment), WORKHORSE (implementation), FAST (scanning). Classes resolve at runtime to stable aliases and to whatever Codex and Grok tiers your account actually offers today; the matrix above picks the seat within the class. New model releases require zero skill updates.
3. **Delegates with self-contained tickets** — 7 core sections plus a mandatory write-set fence on implementation work, file paths instead of pasted context, gradeable acceptance criteria.
4. **Collects four-status reports** — `DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED` — with a bounded escalation ladder: two failures at a seat, then escalate one seat or take over. Never a third identical retry.
5. **Verifies like it trusts no one** — the project's real build/test command first (free), then a blind verifier that gets the original task verbatim and none of the worker's reasoning. Required for every accepted change except single-file zero-logic edits. Off-family reviewers sharpen the read — a Codex read-only reviewer is the strongest cross-family second opinion, Grok the cheap adversarial one — but the accepting verdict is always the Claude verifier. When the verifier resolves to the same model as the lead, it says so — "blind-verified (same model, independent context)" — instead of implying independence it didn't obtain.
6. **Respects your budget both directions** — sequential dispatch by default (prompt-cache warmth), announced fan-outs, and the degradation rule: under quota pressure it steps seats down *visibly* and prefers stopping cleanly over silently shipping degraded work. **Economics never lowers the quality bar.**

## How it was built

Three adversarial reviews by Grok itself while the release was being built — the first returned `VERDICT:REVISE` with four blockers, three were conceded, and the plan was cut back. Then a blind Claude verification. Then an independent review by a Fable session running this skill on itself, which found four things all of those had missed: a personal "spend without asking" Codex policy that had been swept into the public commit, a backwards percentage in the cliff table (it stated Grok's premium where it meant Sonnet's saving), a reactive 200K rule that measured the wrong quantity, and a transport wrapper that fabricated its relay while the real artifact sat correct on disk. All four were fixed and re-verified before release.

## Install

**Claude Code — recommended.** Paste this into a Claude Code session:

```
Install this skill globally on my machine: https://github.com/olsenbrands/fable-foreman
```

Claude clones this repo and installs two things — **both are required**:

| From the repo | Goes to |
|---|---|
| `skills/fable-foreman/` (skill + `references/` + `scripts/`) | `~/.claude/skills/fable-foreman/` |
| `agents/*.md` — **all five** | `~/.claude/agents/` |

The skill dispatches `foreman-scout`, `foreman-worker`, `foreman-verifier`, `foreman-codex-wrapper`, and (v0.4) `foreman-grok-wrapper` **by name**. Install the skill without the agents and delegation and blind verification won't work — so copy both directories, not just the skill.

**Claude Code (manual):** clone this repo, then:

```bash
cp -R skills/fable-foreman ~/.claude/skills/
cp agents/*.md ~/.claude/agents/
```

<details>
<summary><b>Claude Code (plugin) — currently broken on Windows</b></summary>

```
/plugin marketplace add olsenbrands/fable-foreman
/plugin install fable-foreman@fable-foreman
```

Run them **one at a time** — the first only registers the marketplace, and the second prompts you for an install scope (choose **User**).

**On Windows this fails** with `EPERM: operation not permitted, rename` while finalizing the marketplace cache. It's a Claude Code bug ([anthropics/claude-code#52435](https://github.com/anthropics/claude-code/issues/52435)), closed as *not planned* — so there's no fix coming. Use the paste-in method above instead; it works on every platform.

</details>

**Claude Desktop / claude.ai:** package the skill folder as a ZIP and upload it under Settings → Customize → Skills (requires code execution enabled; see Anthropic's current docs for plan availability):

```bash
cd skills && zip -r fable-foreman-skill.zip fable-foreman/
```

Releases on this repo will also attach a pre-built `fable-foreman-skill.zip`. That ZIP contains the skill only, not the `agents/` — which is correct for Claude Desktop (no subagents there) but means it is **not** a complete Claude Code install; for Claude Code use the paste-in or manual method above. Without the Agent tool, the skill runs in *discipline mode* — separate plan/execute/self-review passes, ledger, and status contracts on your single conversation model. That's honest same-model self-review, weaker than full mode; the skill says so rather than pretending otherwise.

**Recommended:** add one line to your `CLAUDE.md` so the skill fires reliably (the [fables project](https://github.com/czlonkowski/fables) measured description-based triggering alone at only ~50–60% recall):

```
For any multi-file or multi-stage task, use the fable-foreman skill.
```

## What it needs

- **For full orchestration:** Claude Code, any model — the stronger your session model, the more the economics favor delegation. Any frontier-class Claude leads the same way, so it makes no difference which one your session lands on, and a mid-run switch between them doesn't disturb the run. On claude.ai/Desktop the skill still installs and runs in discipline mode.
- **Optional: OpenAI Codex CLI**, installed and logged in. If present — and only with your explicit OK, since it spends your OpenAI subscription or API credits — execution can route to Codex tiers, discovered from your account at runtime and chosen per task the same way Claude tiers are. If you'd rather not be asked every session, that consent is opt-in per machine: create `~/.foreman/codex-preapproved` or export `FOREMAN_CODEX_PREAPPROVED=1`, and the probe reports it, the ask is skipped, and budget step-down stops applying to Codex. The flag is yours to set; it never ships in this repo, and the published default is still to ask.
- **Optional: xAI Grok CLI**, installed and logged in. If present, it adds a third worker family — the value seat for adversarial review and for well-specified implementation under 200K. Grok has **no** pre-approval flag: ordinary budget discipline applies, and every dispatch runs under an explicit sandbox profile. Note the honest limit on macOS — neither Grok profile blocks child-process network and both can read the whole filesystem; only writes are confined, so Grok's `workspace` is weaker than Codex's `workspace-write`. Reserve it for repos you'd let an autonomous agent read your home directory from.
- If any of these are absent, everything falls back to what remains. Nothing breaks.

## Notes on quotas

Subscription users: subagent calls share your plan's quota — delegation buys *quality-per-token*, and cheaper tiers drain shared quota more slowly (some plans additionally meter cheaper tiers in larger buckets — check yours). It does not buy discounts. API users: the cost savings are direct. Codex and Grok draw on their own separate account pools, which is the one genuine endurance asymmetry the skill uses: prefer an off-family seat for bulk implementation so the pool the foreman itself runs on lasts longer.

## License

MIT © Jordan Olsen
