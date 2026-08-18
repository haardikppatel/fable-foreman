# The model matrix — who gets the work, at what effort, at what cost

Companion to [routing.md](routing.md). routing.md is the *procedure* for resolving
classes to seats; this file is the *evidence table* that procedure consults.

**Read this first — what the dollars mean.** On a subscription-authenticated
account (ChatGPT login for Codex, grok.com login for Grok, a Claude plan for the
LEAD seat) these prices are **not** card charges. They are the best available
**proxy for how fast a dispatch depletes that provider's allowance**. They become
literal only on API-key auth. Never quote them to the user as money spent without
first establishing the auth mode (codex-workers.md, grok-workers.md).

**List prices are an UPPER BOUND, not the bill.** Measured on this account
2026-08-17: a real 6-turn Grok 4.6 review moving 370K input tokens and 18K output
reported **$0.0714** in its own envelope — roughly **3.5x below** what the list
prices in Table 1 predict. Session/subscription rates evidently sit well under
public API list. Where an envelope reports actual usage and cost, **that number
wins over this table**; the tables are for choosing between seats, not for
telling the user what they spent.

**Currency rule applies to this whole file.** Every number below is dated. Model
lineups move faster than skill files. If anything here disagrees with the live
provider docs or the account itself, the live source wins and this table is
stale — re-derive it, don't route off it.

## Table 1 — Seats, price, capability (verified 2026-08-17)

Capability = Artificial Analysis Intelligence Index v4.1.1, one consistent source
so the column is comparable. It is a **composite**, not a coding benchmark — see
the health warning under Table 4 before treating small gaps as real.

| Seat | In $/M | Out $/M | Cache read | Context | Index | Notes |
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

## Table 2 — What one real dispatch costs

A 4-turn agentic dispatch: ~100K working context sent fresh once, ~300K re-sent
from cache across later turns, 12K output. This shape matters more than list
price, because caching dominates multi-turn work.

| Seat | Cost | Index | Capability per dollar |
|---|---|---|---|
| gpt-5.6-luna | **$0.040** | 52 | **1287** |
| Claude Haiku 4.5 | $0.190 | 30 | 158 |
| Grok 4.5 | $0.362 | 56 | 155 |
| Claude Sonnet 5 | $0.380 | 55 | 145 |
| gpt-5.6-terra | $0.404 | 57 | 141 |
| **Grok 4.6** | **$0.422** | **61** | 145 |
| Claude Opus 5 | $0.950 | 63 | 66 |
| gpt-5.6-sol | $1.010 | 61 | 60 |
| Claude Fable 5 | $1.900 | 62 | 33 |

Three conclusions that should drive routing:

1. **Grok 4.6 is the near-frontier value seat.** It sits in the same index band as
   Opus 5 and sol (61 vs 63 vs 61) at roughly **44% of Opus 5's depletion** and
   **42% of sol's**. State it as a band, not a ratio: per the health warning
   below, a 2-point composite gap is inside the noise, so "61 vs 63" licenses
   "same tier, far cheaper" and nothing more precise. That, not "Grok is cheap",
   is the reason to field it.
2. **gpt-5.6-luna dominates Haiku 4.5 outright** — cheaper *and* far more capable
   (52 vs 30), and Haiku's 4096-token cache floor means short agent turns often
   get no caching discount at all. Where Codex is available, luna is the FAST
   seat; Haiku is the fallback when it isn't.
3. **Sol and Fable are priced above their measured capability.** Sol costs 2.4x
   Grok 4.6 for the same index; Fable costs 2x Opus 5 while scoring at or below
   it. Field them for reasons other than capability-per-dollar — a specific
   strength, cross-family independence, or an unloaded pool — never by default.

## Table 3 — The Grok cliff is a routing boundary, not a price bump

Grok reprices the **entire request** at 2x once it crosses 200K, so cost jumps
discontinuously. Same job, 17% more input:

| Job | Grok 4.6 | Sonnet 5 | Verdict |
|---|---|---|---|
| 180K in / 15K out | **$0.450** | $0.510 | Grok wins |
| 210K in / 15K out | $1.020 | **$0.570** | Sonnet 79% cheaper |
| 250K in / 15K out | $1.180 | **$0.650** | Sonnet 82% cheaper |
| 400K in / 20K out | $1.840 | **$1.000** | Sonnet 84% cheaper |

**Rule: above ~200K, Grok loses its own cost advantage — change seats.** What is
certain is the *within-Grok* jump: xAI's published policy reprices the whole
request 2x, so the same job costs twice what it would have. What is **not**
established is the cross-provider winner: the table above is list-price math, and
this account's measured Grok billing ran ~3.5x below list (see the upper-bound
note) with no matching subscription measurement for Claude. So treat "Sonnet is
cheaper above the cliff" as a **list-price-relative** claim to confirm against
measured envelope costs, and treat "don't pay Grok's surcharge" as the rule.
Above 500K Grok is ineligible outright — that is a hard context ceiling, not a
price argument.

**How to apply this without counting tokens.** A foreman cannot reliably estimate
request size ahead of a dispatch, and Grok silently prepends discovered config to
every call, so an *ex-ante* estimate is unfalsifiable. Measure instead:
`grok-dispatch.sh` prints `usage: input=… total=…` from the envelope on every
call, and emits `CONTEXT WARN` above 150K and `CONTEXT ALERT` above 200K. Ledger
that number. **Reactive rule:** once any call in a run crosses 200K, Grok is
ineligible for equal-or-larger tickets for the rest of that run.

## Table 4 — Effort: a volume dial, and it pays off unevenly

Verified for all three providers: **raising reasoning effort never changes the
per-token price.** It changes how many reasoning/output tokens get generated,
billed at the ordinary output rate. Effort therefore multiplies the *output* half
of the bill — the expensive half on every seat in Table 1.

**The finding that should drive effort choice — the payoff depends on task shape,
not on difficulty alone.** Anthropic publishes the only quantified curve (PRIMARY,
2026-08-17), and the two shapes diverge sharply:

| Task shape | Accuracy-vs-effort curve | What to do |
|---|---|---|
| Analysis / knowledge work / review (WideSearch, GDPval, BrowseComp) | **nearly flat** — `low` gives up only 1-3 points for 33-50% less cost; `medium` matches `high` at 70-85% of cost | **default `medium`**; top effort is usually wasted money |
| Long-horizon coding (SWE-bench Pro) | **steep** — `low` gives up ~8 points | **default `high`**; do not economize here |

Anthropic's own framing: "Long-horizon coding is the other shape." Treat this as
measured on Anthropic models; the shape is a strong prior for other families, not
a proven transfer.

xAI's own published level guidance (PRIMARY, docs.x.ai) points the same way —
note that `medium`, not `high`, is the level it names for analysis:

| Grok level | xAI says it is for |
|---|---|
| `low` | latency-sensitive work, simple tool calls |
| `medium` | **complex data analysis and long-context reasoning** |
| `high` (default) | hard math, multi-step logic |
| `xhigh` | the hardest problems only |

OpenAI grades `none`→`max` by latency tolerance and difficulty, not by task
category. No vendor draws an explicit review-vs-build line.

| Surface | Levels | Default to | Escalate when |
|---|---|---|---|
| Grok 4.6 | low, medium, high, xhigh | **medium** for review/analysis, **high** for implementation | `xhigh` only for the hardest verification/design |
| Grok 4.5 | low, medium, high (**no xhigh**) | same, capped at high | — sending `xhigh` exits 1 |
| Codex | per codex-workers.md | provider default | hard debugging, final review |
| Claude subagents | scout low / worker high / verifier high | role default | per delegation.md |

The one hard tradeoff number anyone publishes: Grok `xhigh` vs `high` on
CursorBench buys **+0.9pp accuracy for +20% cost** (69.9% → 70.8%; SECONDARY,
cross-corroborated, absent from primary xAI pages). Combined with the flat
analysis curve above, `xhigh` on a review is close to pure waste.

Per routing.md: **raising effort on a cheap seat is often better economics than
raising the tier** — a tier step costs 2-5x (Table 2), an effort step ~20%. That
holds best on coding-shaped work, where the effort curve is steep.

## Table 4b — Grok as reviewer: supported, with a hard operating rule

Review work is reasoning-heavy and output-light. Measured on this account: an
adversarial plan review by Grok 4.6 billed **18,044 output tokens of which 14,579
(81%) were reasoning**. So the seat choice for deep review is dominated by output
price — which is where Grok is cheapest relative to capability: the same review
priced **2.4x on Opus 5, 2.7x on sol, 4.7x on Fable 5**, at index 61 vs 63/61/62.

Benchmark support is real but indirect (SECONDARY): Grok 4.6 **wins** knowledge-
work evaluations (GDPVal-AA, Harvey legal) and **loses** software-engineering
execution ones (DeepSWE -7.1pts, Terminal-Bench -8.6pts vs sol). That is
consistent with "relatively stronger at analysis than at execution" — it is not
proof, no code-review benchmark exists for any model, and some practitioner
reports argue the opposite. Do not overstate it.

> **Hard operating rule — verify a Grok reviewer's citations before acting.**
> Grok 4.6's measured non-hallucination rate is **65.7%** (SECONDARY): when
> uncertain it invents an answer roughly one time in three. That is a genuine
> hazard in a critic. Live evidence from this account cuts both ways — in a real
> plan review its quotations of this skill's own rules checked out verbatim
> against the files, and it caught a true self-contradiction; it also asserted an
> event "does not exist" when the event was simply outside its sandbox. So:
> **treat Grok findings as leads with citations attached, and confirm each
> against the named file or line before you act on it.** This is exactly why
> Grok is an advisory reviewer and never the accepting verdict (Table 5).

## Table 5 — Task type to seat

Judgment content decides the class (routing.md); this maps class to a first-choice
seat once economics is allowed to choose among seats that already clear the bar.
**The First Law is not suspended here:** if no listed seat clears the bar for a
task, go up a tier or stop — never take the cheap row because it is cheap.

| Task | Class | First choice | Then | Never |
|---|---|---|---|---|
| Architecture, ambiguous debugging, final judgment | FRONTIER | LEAD (Opus 5) | frontier subagent | Grok, luna, Haiku |
| Accepting verdict on a change (blind verifier) | FRONTIER | **Claude verifier**; a **Codex read-only reviewer** is the sanctioned cross-family verifier (verification.md) | — | **Grok** — its seat evidence is billed-tier, and a Grok reviewer never leads with a verdict (grok-workers.md) |
| Adversarial review / second opinion | FRONTIER-advisory | **Grok 4.6 @ high** | Codex sol | — |
| Well-specified implementation, tests, refactors | WORKHORSE | **Grok 4.6 @ high** (<200K) when cost dominates; **sol** when agentic-execution reliability dominates — the only measured head-to-head shows Grok trailing *sol* on DeepSWE and Terminal-Bench (Table 4b). No comparable execution measurement exists for Sonnet 5, whose only cross-model number here is the composite index (where Grok leads 61 to 55) — so do not pick Sonnet over Grok on reliability grounds this table cannot support. | Sonnet 5 / terra on pool grounds | — |
| Large-context implementation (>200K) | WORKHORSE | **Sonnet 5** | terra | **Grok (cliff)**, Haiku (200K cap) |
| Mechanical edits, extraction, scanning | FAST | **gpt-5.6-luna @ low** | Haiku 4.5 | frontier seats |
| Repo-wide sweep (>500K) | any | Claude or Codex (1M ctx) | — | **Grok (500K ceiling)** |

> **On "FRONTIER-advisory" — what that row does and does not grant.** A billed-tier
> seat never carries class-sensitive *authority* (verification.md): it cannot make
> a seat `verified`, cannot supply an accepting verdict, and cannot be the
> FRONTIER judgment a decision rests on. What it can do is *produce findings* that
> a frontier seat then adjudicates. "Advisory" names that asymmetry — the seat
> argues, the foreman decides, and nothing is accepted on the strength of the
> advisory seat alone. If you catch yourself accepting a change *because* the
> advisory reviewer approved it, that is the smuggle this note exists to stop.

## Table 6 — Which pool a seat drains

Claude workers draw on **the same allowance the foreman itself runs on**; Codex
and Grok workers do not. That is the one genuine endurance asymmetry, and it is
the only "pool" consideration this skill makes — remaining allowance is **not
observable** on any provider, so nothing here allocates quota.

| Seat | Pool | Consequence |
|---|---|---|
| Claude (LEAD + subagents) | the foreman's own | heavy Claude fan-out shortens the run itself |
| Codex | ChatGPT subscription, weekly rolling window | independent; exhaustion is abrupt and has happened |
| Grok | grok.com account | independent third pool |

**Use:** prefer an off-family seat for bulk implementation so the LEAD pool lasts.
When a pool is *known* down, re-route the remainder and journal it. This never
licenses a seat that does not clear the task's bar — a dead pool is a reason to
stop and tell the user, not to accept weaker work (delegation.md, First Law).

## Provenance of this table
- Prices, context windows, cache discounts, effort mechanics: primary vendor docs, 2026-08-17.
- Capability index: Artificial Analysis Intelligence Index v4.1.1, 2026-08-17.
- Grok CLI behaviours (cliff handling, effort validation, envelope usage fields): established by direct execution on this machine, 2026-08-17.
- Cost tables: computed from the above; recompute rather than trusting if any input changes.
