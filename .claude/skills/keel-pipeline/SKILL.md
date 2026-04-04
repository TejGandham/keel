---
name: keel-pipeline
description: "Orchestrate the KEEL pipeline for a feature. Dispatches agents in sequence: pre-check → test-writer → implementer → spec-reviewer → safety-auditor? → landing-verifier."
---

# KEEL Pipeline

KEEL — Knowledge-Encoded Engineering Lifecycle.

Orchestrate the full agent pipeline for a feature. You are the **orchestrator** — you dispatch agents, thread handoff files, and enforce the pipeline order from CLAUDE.md.

## Arguments

The user provides a feature name and spec path:
```
/keel-pipeline my-feature docs/product-specs/my-spec.md
```

If no spec path given, ask for one. If no spec exists yet, tell the user to write the spec first — docs drive code.

## Before Starting

1. Read `CLAUDE.md` to determine the correct pipeline variant
2. Read the feature spec
3. Create the handoff file at `docs/exec-plans/active/handoffs/F{id}-{feature-name}.md`

## Pipeline Variants

Determine the variant based on what the feature touches:

**Bootstrap** — Docker, scaffolding, config (typically F01-F03):
```
docker-builder → landing-verifier          (F01: container)
scaffolder → landing-verifier              (F02: app skeleton)
config-writer → landing-verifier           (F03: test infra)
```
Bootstrap features are orchestrator-direct: dispatch the specific bootstrap agent, then landing-verifier. No pre-check, no test-writer, no implementer. The bootstrap agent's report serves as the handoff context.

**Backend** — changes to core business logic, services, data layer:
```
pre-check → researcher? → backend-designer? → test-writer → implementer → spec-reviewer → safety-auditor? → landing-verifier
```

**Frontend** — changes to UI components, templates, styles, client-side logic:
```
pre-check → researcher? → frontend-designer → test-writer → implementer → spec-reviewer → landing-verifier
```

**Cross-cutting** — test infrastructure, config, Docker, docs:
```
pre-check → test-writer → implementer → landing-verifier
```

**Full-stack** — touches both backend and frontend: run backend pipeline, then frontend pipeline, sharing the same handoff file.

## Execution Steps

### Step 0: Bootstrap (F01-F03 only)
If the feature is a bootstrap feature, dispatch the specific bootstrap agent (docker-builder, scaffolder, or config-writer). It produces its report in the handoff file. Skip directly to Step 8 (landing-verifier). Bootstrap features do not use pre-check, designers, test-writer, or implementer.

### Step 1: Pre-check (standard pipeline only)
Dispatch the `pre-check` agent with the feature spec path. It produces an
execution brief in the handoff file. After pre-check completes, update the
handoff YAML frontmatter with routing fields from the brief:
- `intent`, `complexity` — determines which optional agents run
- `designer_needed` — YES/NO (trivial complexity → always NO)
- `researcher_needed` — YES/NO (research intent → always YES)
- `safety_auditor_needed` — YES/NO
- `arch_advisor_needed` — YES if complexity is architecture-tier

Read routing decisions from the YAML frontmatter for all subsequent steps.

### Step 1.5: Researcher (if needed)
If pre-check set `Research needed: YES`, dispatch `researcher` with the specific questions from the execution brief. Append research brief to handoff file.

### Step 1.7: Arch-advisor consultation (if architecture-tier)
If pre-check set `Arch-advisor needed: YES` or `Complexity: architecture-tier`,
dispatch `arch-advisor` agent in CONSULT mode with the execution brief, spec,
and any research brief. Arch-advisor provides architecture-level guidance
before design/implementation.
Append output to `## arch-advisor-consultation` in the handoff file.

### Step 2: Designer (if needed)
Dispatch `backend-designer` or `frontend-designer` based on pipeline variant. Append output to handoff file.

### Step 3: Test-writer
Dispatch `test-writer` with the handoff file. It writes tests, never implementation. Append output to handoff file.

### Step 4: Implementer (if needed)
If pre-check set `Implementer needed: NO`, skip to Step 6 (spec-reviewer) or Step 8 (landing-verifier).
Otherwise, dispatch `implementer` with the handoff file. It writes code to pass the tests. Never modifies tests. Append output to handoff file.

### Step 5: Code review
Dispatch `code-reviewer` with the handoff file. It reviews code quality —
DRY, patterns, edge cases, architecture fit. Its output starts with
`**Verdict:** APPROVED` or `**Verdict:** CHANGES NEEDED`.

If CHANGES NEEDED with CRITICAL or IMPORTANT findings: send findings
back to `implementer`. Implementer fixes. Re-run code-reviewer.
Max 1 code review loop — if still CHANGES NEEDED, proceed to
spec-reviewer anyway (spec conformance is the harder gate).

### Step 6: Spec-reviewer (max 2 loops)
Dispatch `spec-reviewer` with the handoff file. It verifies code conforms
to specs. Its output includes `**Verdict:** CONFORMANT` or
`**Verdict:** DEVIATION`.

Before dispatching, increment `spec_review_attempt` in the YAML frontmatter
(starting at 1). After spec-reviewer completes, copy the verdict to
`spec_review_verdict` in the YAML frontmatter.

If DEVIATION:
- **Attempt 1:** Send specific deviation findings back to implementer.
  Implementer fixes. Re-run spec-reviewer (set attempt to 2).
- **Attempt 2:** If still DEVIATION, STOP. Do not loop again.
  Escalate to human: either decompose the feature or fix the spec.
  See docs/process/FAILURE-PLAYBOOK.md.

### Step 7: Safety-auditor (if feature touches domain-critical modules)
Dispatch `safety-auditor` with the handoff file. Its output includes
`**Verdict:** PASS` or `**Verdict:** VIOLATION`.

After safety-auditor completes, increment `safety_attempt` and copy the
verdict to `safety_verdict` in the YAML frontmatter.

If VIOLATION: send findings to implementer. Fix. Re-run safety-auditor.
Safety violations are never negotiable — max 3 attempts.
If still VIOLATION after 3 attempts, STOP. Escalate to human — the
invariant rule itself may need review, or the spec and invariant are
genuinely incompatible.

### Step 7.5: Arch-advisor verification (if pre-check classified architecture-tier)
If pre-check set `Arch-advisor needed: YES`, dispatch `arch-advisor` in VERIFY mode
for independent structural review before landing-verifier. Arch-advisor evaluates
whether the implementation is architecturally sound — not just spec-conformant.

If Arch-advisor's verdict is UNSOUND:
- Send findings to implementer with specific architecture issues
- Implementer fixes. Then re-run the full gate sequence:
  spec-reviewer → safety-auditor (if required) → Arch-advisor verification
- Arch-advisor-triggered gate passes use a SEPARATE counter from the
  initial spec-review attempts (those counters do not interact)
- Max 1 Arch-advisor verification retry. If still UNSOUND, escalate to human.

Append output to `## arch-advisor-verification` in the handoff file.

### Step 8: Landing-verifier
Dispatch `landing-verifier` with the handoff file. It runs tests and verifies everything landed. If BLOCKED, fix blockers and re-run.

### Step 9: Commit (on behalf of the human orchestrator)
Only after landing-verifier reports LANDED. Present the commit plan to the human for approval:
1. Run `git status`, `git diff HEAD`, `git log --oneline -10` to understand what's being committed
2. Stage only the test + implementation files (not unrelated changes)
3. Write a commit message that summarizes the **why**, not the what. Follow the repo's convention: `feat(F{id}): {feature name}`
4. Commit. Do not push unless explicitly asked.

### Step 10: Update docs
1. Move handoff: `docs/exec-plans/active/handoffs/` → `docs/exec-plans/completed/handoffs/`
2. Re-read `CLAUDE.md` — does it still reflect reality after this feature? If behavior changed, update it.
3. Re-read `ARCHITECTURE.md` — does the module map, data flow, or diagram need updating?
4. Check `docs/exec-plans/tech-debt-tracker.md` — any new shortcuts to log? Any resolved items to check off?
5. Run `doc-gardener` agent for a full sweep if the feature was substantial.

## Rules

- **Never skip steps.** Every agent in the pipeline runs.
- **Handoff file is the thread.** Each agent reads and appends to it.
- **Pre-check decides optionals.** Only skip designer/researcher/safety-auditor if pre-check says so.
- **Spec-reviewer and safety-auditor are gates.** If they find issues, loop back to implementer.
- **You don't write code.** Agents write code. You orchestrate.
- **Docs drive code.** If there's no spec, there's no pipeline. Write the spec first.
- **Structured verdicts.** Gate agents output `**Verdict:**` in their
  sections. The orchestrator copies verdicts and attempt counts to the
  YAML frontmatter. Branch on frontmatter, not on parsing agent prose.
- **Max 2 spec-review loops.** After 2 DEVIATION verdicts, escalate.
  Don't try harder — decompose or fix upstream.
- **Downstream reads upstream.** Each agent reads upstream Decisions and
  Constraints FIRST before starting its own work.
