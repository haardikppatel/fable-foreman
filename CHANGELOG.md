# Changelog

## 0.3.0 — 2026-08-07

The "trust the log, see the crew" release. Derived from a comparative study of
[claudemix](https://github.com/hughminhphan/claudemix), hardened through three
rounds of adversarial review by OpenAI's frontier Codex model (16 findings →
fixed or explicitly disclosed), and live-tested head-to-head against v0.2.0.

### Added
- **Layer 0 seat provenance** (`references/verification.md`): which model
  actually served a dispatch is graded by deterministic evidence in three
  tiers — SERVED > ROUTED > REQUESTED — never by a worker's self-report.
  Dispatches without real evidence are honestly ledgered `seat: unverified`.
- **Visible-subagent Codex transport** (`references/codex-workers.md`): Codex
  jobs run inside harness-visible wrapper subagents by default — live presence
  in the UI, completion notifications instead of polling, foreman stays free
  during long builds. Direct exec remains the documented fallback for
  sub-minute calls and Codex-only mode.
- **`scripts/codex-dispatch.sh`** — fixed-argv Codex launcher: validates every
  argument, constrains artifact paths (no symlinks, no ticket aliasing),
  records the child PID for orphan control, forwards termination signals, and
  reports seat evidence honestly (current Codex CLI emits no served-model
  field; the launcher says so instead of inventing one).
- **`scripts/probe.sh`** — deterministic Step 0 probe (Codex presence/auth/
  billing mode, native-transport facts, git baseline) with secrets redacted
  from output.
- **`scripts/init-ledger.sh`** — atomic, injection-hardened ledger bootstrap
  that refuses to clobber an existing ledger.
- **`agents/foreman-codex-wrapper.md`** — bundled transport-wrapper role with
  a machine-narrowed tool list (no edit tools, no agent spawning).
- **`references/setup-runbook.md`** — agent-executable, evidence-verified
  environment setup; optional consent-gated native-GPT-subagent transport
  (claudemix-style splitter) with supply-chain pinning rules and honest
  security/ToS statements.
- **Silent-fallback hazard** documentation (`references/routing.md`) with
  current-build empirical results: what silently substitutes, what fails
  loudly, and the countermeasures.

### Changed
- Hard rails: added rail 5 (seat provenance) and a tightly-scoped transport
  carve-out to rail 1 (the wrapper may invoke the launcher exactly once).
- Behavioral anomaly is now a *trigger* for a provenance check, never itself
  evidence of which model served.
- Detected seat substitution is classified as a transport/routing failure with
  its own escalation path (never free same-seat retries).

### Known limitations (disclosed, not hidden)
- Current Codex CLI provides no served-model metadata, so Codex seats remain
  `unverified` at the SERVED tier until the CLI emits it — the launcher already
  scans version-tolerantly for the day it does.
- The wrapper-must-use-the-launcher rule is contractual and transcript-
  auditable; machine prevention requires harness-level tool policy.

## 0.2.0 — 2026-07-19

- Frontier-class LEAD seat parity: any frontier Claude (Fable, Opus) runs the
  foreman identically; Step 0 probe cache expires on mid-run model change.

## 0.1.0 — 2026-07-14

- Initial release: capability-class routing (FRONTIER/WORKHORSE/FAST),
  ticket/status delegation contract, blind fresh-context verification,
  append-only ledger, Codex CLI worker integration.
