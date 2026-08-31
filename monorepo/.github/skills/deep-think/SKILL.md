---
name: deep-think
description: "Shared multi-lens self-interrogation checklist to surface gaps in plans, tasks, and implementations before finalizing. Iterates until no new gaps surface. Load from generate-plan, generate-task, execute-task, fix-task."
---

# deep-think

> Silent pass — do not narrate reasoning to the user. Only emit gaps folded into the artifact, `Assumptions`, or `Open Questions`.

## DEEP_THINK_PASS

**Inputs:** `ARTIFACT` (plan draft | task draft | implemented diff), `SCOPE` (`business` | `technical`) → **Outputs:** `GAPS[]`, `ASSUMPTIONS[]`, `PASS_COUNT`

1. LOOP: up to 3 passes; stop early if a pass surfaces zero new findings
2. Each pass — interrogate `ARTIFACT` against every lens below tagged with `SCOPE` (or both); for `technical` scope also sweep the Change Surface Checklist and, when implementation exists, the Adversarial Review Bank
3. Classify every finding via Ambiguity Classification → route per that table
4. STORE: `PASS_COUNT`, `GAPS[]`, `ASSUMPTIONS[]` (each tagged with a Confidence level)

### Lenses

| Lens | Ask | Scope |
|---|---|---|
| Functional completeness | Every stated behaviour covered? Implicit behaviour assumed but unwritten? | business + technical |
| Edge cases | Sweep Boundary Values below against every input/state | business + technical |
| Concurrency & idempotency | Can this run twice (retry/duplicate event/double-click)? Can two actors act on the same record at once? | technical |
| Error & failure modes | What fails, how is it surfaced, retried, rolled back? Partial failure across a DB+external-call boundary? | technical |
| Security & authz | Who can call this? Input validation? Injection (SQL/command/XSS/SSRF/path traversal)? Secrets/PII exposure in logs/errors? | business + technical |
| Data integrity | Migrations, existing-row backfill/defaults, backward compatibility, transactional boundaries? | technical |
| Non-functional | Performance/scale, timeouts, rate limits? | business + technical |
| Observability | Logs/metrics/alerts for new failure paths? Stable error codes, not just messages? | technical |
| Dependencies & integration | Upstream/downstream contracts changed? Breaking? What if the external call succeeds but the response is lost/timed out locally? | technical |
| Rollback / recovery | Safely revertible? Old + new code coexisting mid-rollout? Feature flag/toggle needed? | technical |
| UX / accessibility | Loading/error/empty/disabled states? A11y/i18n? (UI only) | business + technical |

### Ambiguity Classification

| Class | Definition | Route |
|---|---|---|
| Known fact | Directly supported by requirement, existing code, schema, tests, or docs | Fold into artifact, no flag |
| Strong inference | Not stated but strongly implied by current system behaviour | Fold into artifact, flag `(inferred)` |
| Assumption | A decision is needed to proceed but isn't confirmed | Fold into artifact + log under `Assumptions` with a Confidence level |
| Unknown | Can't be safely determined and materially affects architecture/contract/data/security/UX/compatibility | `Open Questions` — never invent the answer |

### Confidence Classification

| Level | Basis |
|---|---|
| High | Verified by code, tests, schema, docs, or an executed command |
| Medium | Strong inference from repository behaviour |
| Low | Assumption or incomplete evidence |

### Change Surface Checklist (technical scope)

UI · routing · state management · API contract · controller · service · domain logic · repository · DB schema/migration · seed/reference data · events/messages · external integrations · authentication · authorisation · validation · error handling · logging/metrics/tracing · config/secrets · infra/CI-CD · docs · tests · rollback

Not every slice touches every layer — mark `N/A`, never omit silently.

### Boundary Values (feeds the Edge Cases lens)

`0` · `1` · `max-1` · `max` · `max+1` · `null` · empty string/array · whitespace-only · duplicate · oversized/huge · malformed/unicode · concurrent/out-of-order arrival

### Adversarial Review Bank (technical scope, run once an implementation/diff exists)

- Empty / null / duplicate / oversized input?
- Retried by the client, or processed twice by a worker/consumer?
- Two requests hit the same record simultaneously?
- A dependency (DB/external API) is unavailable or times out?
- The external call succeeds but the response is lost/timed out locally?
- The caller lacks permission?
- Existing rows/old clients lack the new field/contract?
- Deployment stops halfway — old and new code coexist?
- Required config/secret is missing at runtime?
- Cache is stale or a queue is delayed?

### Stop Conditions

- Max 3 passes OR a pass yields 0 new gaps → stop
- A blocking gap (unresolvable from context, halts correctness) → surface immediately, don't wait for pass limit
