# Fable Foreman

**Your strongest model shouldn't be swinging the hammer.**

Built in public by [DontSleepOnAI](https://dontsleeponai.com) — the story behind this skill (including the five-round adversarial review where OpenAI's newest model tore apart the first draft) lives there.

Fable Foreman turns whichever frontier-class Claude model leads your session into a team lead: it plans, routes each task to the cheapest worker that clears the quality bar — Claude subagents or OpenAI Codex CLI workers, auto-detected — and, in full orchestration mode, refuses to accept meaningful changes until a blind, fresh-context verifier reproduces the evidence. (Environments without subagents get an honest reduced-assurance mode that says so.)

No dated model IDs in routing policy. No configuration files. No enforcement scripts. One skill, three agent roles, and a set of rules good enough that a frontier model actually follows them.

**"Fable" is where it started, not what it needs.** The foreman seat is a capability class, so any frontier-class Claude runs the skill identically — Opus leads it exactly as Fable does, with the same routing tree, gates, and verification contract. That holds whether an Opus session invokes the skill directly or a Fable session falls back to Opus mid-run; the skill re-probes its own seat and carries on rather than routing off a stale identity.

## Why

Anthropic's own engineering shows both sides of the ledger. Their [multi-agent research system writeup](https://www.anthropic.com/engineering/multi-agent-research-system) found an orchestrator-plus-cheaper-subagents design strongly outperformed single agents — an Opus lead with Sonnet workers, exactly this skill's shape — while consuming roughly **15x** the tokens of a single chat, which is why they conclude multi-agent work only pays for high-value tasks. Anthropic's own [cost guidance](https://code.claude.com/docs/en/costs) likewise recommends cheaper-tier teammates under a stronger lead as the default for multi-agent work. And the community has receipts for what happens without discipline — runaway-subagent cost stories are a genre of their own on every AI-coding forum, which is exactly why this skill bounds crew sizes, retries, and spend announcements the way it does.

The difference between those two outcomes is not orchestration machinery — it's **routing judgment and verification discipline**. That's what this skill installs.

## What it does

1. **Probes the job site** — what model is the session running, can it spawn agents, is a working Codex CLI present: binary on PATH, then `codex login status` for auth *and billing mode*, with a version-tolerant credential-file fallback if that subcommand ever changes — and no billable call, not even the functional `echo ok`, until you've consented to spending your OpenAI credits. The probe is cached, but **expires when the session model changes** — a fallback, a quota event, or a `/model` switch triggers a re-probe rather than letting the foreman route off an identity it no longer has.
2. **Routes by capability class, not model name** — FRONTIER (judgment), WORKHORSE (implementation), FAST (scanning). Classes resolve at runtime to stable aliases and to whatever Codex tiers your account offers today. Frontier is a *class*, so any top-tier Claude leads identically, and frontier-class workers are dispatchable when parallel judgment work genuinely needs them. New model releases require zero skill updates.
3. **Delegates with self-contained tickets** — 7 core sections plus a mandatory write-set fence on implementation work, file paths instead of pasted context, gradeable acceptance criteria.
4. **Collects four-status reports** — `DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED` — with a bounded escalation ladder: two failures at a seat, then escalate one seat or take over. Never a third identical retry.
5. **Verifies like it trusts no one** — the project's real build/test command first (free), then a blind verifier that gets the original task verbatim and none of the worker's reasoning. Required for every accepted change except single-file zero-logic edits. Cross-family when possible: Claude verifies Codex work and vice versa. When the verifier resolves to the same model as the lead, it says so — "blind-verified (same model, independent context)" — instead of implying independence it didn't obtain.
6. **Respects your budget both directions** — sequential dispatch by default (prompt-cache warmth), announced fan-outs, and the degradation rule: under quota pressure it steps seats down *visibly* and prefers stopping cleanly over silently shipping degraded work. **Economics never lowers the quality bar.**

## Install

**Claude Code — recommended.** Paste this into a Claude Code session:

```
Install this skill globally on my machine: https://github.com/olsenbrands/fable-foreman
```

Claude clones this repo and installs two things — **both are required**:

| From the repo | Goes to |
|---|---|
| `skills/fable-foreman/` (skill + `references/`) | `~/.claude/skills/fable-foreman/` |
| `agents/*.md` — **all three** | `~/.claude/agents/` |

The skill dispatches `foreman-scout`, `foreman-worker`, and `foreman-verifier` **by name**. Install the skill without the agents and delegation and blind verification won't work — so copy both directories, not just the skill.

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
- **Optional:** OpenAI Codex CLI, installed and logged in. If present — and only with your explicit OK, since it spends your OpenAI subscription or API credits — execution can route to Codex tiers, discovered from your account at runtime and chosen per task the same way Claude tiers are. If absent, everything falls back to Claude workers. Nothing breaks.

## Notes on quotas

Subscription users: subagent calls share your plan's quota — delegation buys *quality-per-token*, and cheaper tiers drain shared quota more slowly (some plans additionally meter cheaper tiers in larger buckets — check yours). It does not buy discounts. API users: the cost savings are direct.

## License

MIT © Jordan Olsen
