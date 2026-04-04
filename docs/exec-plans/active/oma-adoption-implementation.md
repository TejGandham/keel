# OMA Pattern Adoption — Implementation Plan

**Date:** 2026-04-04
**Source:** OMA (Oh My OpenAgent) agents: Metis, Arch-advisor, Momus
**Validated by:** 3-model roundtable (Claude, Codex, Gemini)
**Reviewed by:** 3-model roundtable (Claude, Codex, Gemini) — 11 findings incorporated
**Strategy:** Port battle-tested OMA prompts with minimal modification

---

## Phase 1: Pipeline Infrastructure

### 1A. Structured Rejection in keel-pipeline SKILL.md

**File:** `.claude/skills/keel-pipeline/SKILL.md`

**Change Step 6 (Spec-reviewer)** from:
```
### Step 6: Spec-reviewer
Dispatch `spec-reviewer` with the handoff file. It verifies code conforms
to specs. If it finds deviations, go back to Step 4.
```

To:
```
### Step 6: Spec-reviewer (max 2 loops)
Dispatch `spec-reviewer` with the handoff file. It verifies code conforms
to specs. Its output starts with `**Verdict:** CONFORMANT` or
`**Verdict:** DEVIATION`.

If DEVIATION:
- **Attempt 1:** Send specific deviation findings back to implementer.
  Implementer fixes. Re-run spec-reviewer.
- **Attempt 2:** If still DEVIATION, STOP. Do not loop again.
  Escalate to human: either decompose the feature or fix the spec.
  See docs/process/FAILURE-PLAYBOOK.md.

The **pipeline orchestrator** (not spec-reviewer) tracks attempts.
Before each spec-reviewer dispatch, the orchestrator sets in the handoff:
`spec-review-attempt: 1` / `spec-review-attempt: 2`
Spec-reviewer reads this value and echoes it in its output.
```

**Change Step 7 (Safety-auditor)** from:
```
### Step 7: Safety-auditor (if feature touches domain-critical modules)
Dispatch `safety-auditor` with the handoff file. If violations found,
go back to Step 4.
```

To:
```
### Step 7: Safety-auditor (if feature touches domain-critical modules)
Dispatch `safety-auditor` with the handoff file. Its output starts with
`**Verdict:** PASS` or `**Verdict:** VIOLATION`.

If VIOLATION: send findings to implementer. Fix. Re-run safety-auditor.
Safety violations are never negotiable — loop until PASS.
**Escalation ceiling:** If safety-auditor loops 3+ times, STOP.
Escalate to human — the invariant rule itself may need review, or the
spec and invariant are genuinely incompatible. This is a core-beliefs
discussion, not a pipeline problem.
```

**Add to Rules section:**
```
- **Structured verdicts.** Spec-reviewer and safety-auditor output
  `**Verdict:** CONFORMANT|DEVIATION` or `**Verdict:** PASS|VIOLATION`
  as their first line. The pipeline branches on this.
- **Max 2 spec-review loops.** After 2 DEVIATION verdicts, escalate.
  Don't try harder — decompose or fix upstream.
```

### 1B. Structured Verdict in spec-reviewer.md

**File:** `.claude/agents/spec-reviewer.md`

**Replace `**Status:**`** with `**Verdict:**` (remove the old field entirely):
```
## Spec Conformance: [Feature Name]

**Verdict:** CONFORMANT | DEVIATION

**Spec:** [file:section]
...rest unchanged...
```

Severity rules for verdict:
- **CRITICAL or MAJOR findings → `DEVIATION`** (burns a loop attempt)
- **MINOR-only findings → `CONFORMANT`** with a `**Notes:**` section listing minor items. Minor nits should not consume loop attempts or escalate to human.

**Add to Output Format** — after "Next hop":
```
**Attempt:** [1|2 — which spec-review pass this is]
```

### 1B′. Structured Verdict in safety-auditor.md

**File:** `.claude/agents/safety-auditor.md`

**Replace `**Status:** PASS | VIOLATIONS FOUND`** with:
```
## Safety Audit: [Feature Name]

**Verdict:** PASS | VIOLATION

**Files scanned:** [list]
...rest unchanged...
```

This aligns safety-auditor output with the pipeline's verdict-branching logic.

### 1C. Wisdom Accumulation in Handoff Template

**File:** `docs/exec-plans/active/handoffs/_TEMPLATE.md`

**Add to each agent section** a structured sub-section:
```
## pre-check
<!-- Execution brief appended here by pre-check agent -->

### Constraints for downstream
<!-- MUST/MUST NOT directives for downstream agents. Max 5 bullets. -->

## researcher
...

## test-writer
<!-- Test report appended here -->

### Decisions (optional)
<!-- Key choices made and why. Max 5 bullets. Test decisions are
     largely self-evident from the test code itself. -->

## implementer
<!-- Implementation report appended here -->

### Decisions
<!-- Key choices made and why. Max 5 bullets. -->
<!-- NOTE: Implementer does NOT get "Constraints for downstream" —
     its downstream agents (spec-reviewer, safety-auditor) are its
     REVIEWERS. Allowing the implementee to constrain its reviewers
     undermines gate integrity. -->

## spec-reviewer
...
```

**Add rule to template header:**
```
     - Each agent populates ### Decisions (what was chosen and why) and
       ### Constraints for downstream (MUST/MUST NOT for next agent).
     - Downstream agents READ upstream Decisions and Constraints FIRST.
```

Also add **arch-advisor sections** to the template (for Phase 3):
```
## arch-advisor-consultation
<!-- Architecture guidance appended here by Arch-advisor at Step 1.7 (if applicable) -->

## arch-advisor-verification
<!-- Independent structural review appended here by Arch-advisor at Step 7.5 (if applicable) -->
```

### 1D. Update Agent Prompts for Wisdom

**Files:** All agent .md files that produce output

Add to each agent's "Output Format" or "Handoff Protocol" section:
```
### Decisions
- [Key choice and why — max 5 bullets]

### Constraints for downstream
- MUST: [what downstream agents must do based on your output]
- MUST NOT: [what downstream agents must avoid]
```

Agents with **Decisions + Constraints for downstream** (required):
`pre-check.md`, `backend-designer.md`, `frontend-designer.md`

Agents with **Decisions only** (required, no constraints):
`implementer.md` — its downstream agents are its reviewers; constraining
them undermines gate integrity.

Agents with **Decisions** (optional):
`test-writer.md`, `researcher.md` — their decisions are largely self-evident
from their output artifacts.

Terminal agents (no Decisions/Constraints needed):
`spec-reviewer.md`, `safety-auditor.md`, `landing-verifier.md`

---

## Phase 2: Pre-check Upgrade with Metis Patterns

### 2A. Intent Classification

**File:** `.claude/agents/pre-check.md`

**Add new section after "Your Role"**, ported from OMA `metis.ts` lines 33-44:
```
## Intent Classification (MANDATORY FIRST STEP)

Before analysis, classify the work intent. This determines your strategy.

| Intent | Signal Words | Strategy |
|-|-|-|
| Refactoring | "refactor", "restructure", "clean up" | Safety: behavior preservation, test coverage |
| Build from Scratch | New feature, greenfield, "create new" | Discovery: explore patterns first |
| Mid-sized Task | Scoped feature, specific deliverable | Guardrails: exact deliverables, exclusions |
| Architecture | System design, "how should we structure" | Strategic: long-term impact, Arch-advisor consultation |
| Research | Investigation needed, path unclear | Investigation: exit criteria, parallel probes |

Classify complexity:
- **Trivial** — single file, <10 lines, clear scope → skip designer
- **Standard** — 1-3 files, bounded scope → normal pipeline
- **Complex** — 3+ files, cross-module → full pipeline with all gates
- **Architecture-tier** — structural change, new patterns → Arch-advisor consultation
```

**Add to Output Format**, after "Spec consistency":
```
**Intent:** refactoring | build | mid-sized | architecture | research
**Complexity:** trivial | standard | complex | architecture-tier
```

**Add to Output Format**, after "Safety auditor needed":
```
**Arch-advisor needed:** YES (architecture-tier complexity) | NO
```

### 2B. MUST/MUST NOT Directives

**Add to pre-check Output Format**, new section replacing current flat format:
```
**Constraints for downstream:**
- MUST: [follow existing pattern in file:function]
- MUST: [use specific API/approach]
- MUST NOT: [add features not in spec]
- MUST NOT: [modify files outside scope]
- MUST NOT: [introduce new dependencies without justification]
```

### 2C. AI-Slop Guardrails

**File:** `.claude/agents/pre-check.md`

**Add new section**, adapted from OMA `metis.ts` lines 109-119:
```
## AI-Slop Prevention

Flag these anti-patterns in your execution brief. Downstream agents
(especially implementer) must avoid them:

- **Scope inflation** — building adjacent features not in the spec
- **Premature abstraction** — extracting utilities for one-time operations
- **Over-validation** — adding error handling for impossible states
- **Documentation bloat** — adding docstrings to code you didn't write
- **Gold-plating** — adding configurability, feature flags, or backwards
  compatibility shims when the spec doesn't require them

Add specific MUST NOT directives for any slop risks you identify.
```

### 2D. Self-Validation (Momus-lite)

**File:** `.claude/agents/pre-check.md`

**Add to Rules section:**
```
- Before finalizing your execution brief, self-validate:
  - [ ] All file paths in "New files" and "Modified files" — do parent dirs exist?
  - [ ] All "Existing patterns to follow" — do those files/functions actually exist?
  - [ ] All acceptance tests — are they testable (not vague)?
  - [ ] No contradictions between your brief and the spec
  - [ ] Constraints for downstream are actionable (not generic)
  If any check fails, fix it before outputting. Do not emit a brief with
  known gaps — that's what Momus catches, and you ARE the Momus gate.
```

### 2E. Update keel-pipeline for Intent Routing

**File:** `.claude/skills/keel-pipeline/SKILL.md`

**Change Step 1** to read the new fields:
```
### Step 1: Pre-check (standard pipeline only)
Dispatch the `pre-check` agent with the feature spec path. It produces an
execution brief in the handoff file. Read the brief for routing decisions:
- **Intent** and **Complexity** — determines which optional agents run
- **Designer needed** — YES/NO
- **Researcher needed** — YES/NO
- **Safety-auditor needed** — YES/NO
- **Arch-advisor needed** — YES if complexity is architecture-tier
```

**NOTE:** Arch-advisor pipeline steps (1.7 and 7.5) are added in Phase 3C,
after the Arch-advisor agent exists. Phase 2 only adds the routing fields
that will eventually gate Arch-advisor dispatch.

---

## Phase 3: Arch-advisor Agent

### 3A. Create Arch-advisor Agent Definition

**File:** `.claude/agents/arch-advisor.md` (NEW)

Port directly from OMA `arch-advisor (originally oracle.ts)` lines 44-153 (the `ARCH_ADVISOR_DEFAULT_PROMPT`),
adapted to KEEL's markdown agent format. Key sections to preserve verbatim:

- **Decision framework** — pragmatic minimalism, bias toward simplicity,
  leverage what exists, one clear path, match depth to complexity
- **Output verbosity spec** — bottom line 2-3 sentences, action plan ≤7 steps,
  why ≤4 bullets, watch out ≤3 bullets
- **Response structure** — Essential (always) / Expanded (when relevant) /
  Edge cases (only when applicable)
- **Scope discipline** — recommend ONLY what was asked, no unsolicited improvements
- **High-risk self-check** — re-scan for unstated assumptions, verify claims
  are grounded in code

Changes from OMA:
- Remove TypeScript agent config wrapper → markdown frontmatter
- Remove GPT-specific variant → single prompt (KEEL is platform-agnostic)
- Add KEEL handoff protocol (read handoff file, append output)
- Add reference to ARCHITECTURE.md and core-beliefs.md as required reading
- Tools: Read, Glob, Grep (read-only, no Write/Edit/Bash)
- Model: opus

### 3B. Update Handoff Template

Already handled in Phase 1C — `## arch-advisor-consultation` and
`## arch-advisor-verification` sections exist.

### 3C. Add Arch-advisor Pipeline Steps

**File:** `.claude/skills/keel-pipeline/SKILL.md`

Now that `arch-advisor.md` exists, add the dispatch steps:

**Add new Step 1.7 (Arch-advisor consultation):**
```
### Step 1.7: Arch-advisor consultation (if architecture-tier)
If pre-check set `Arch-advisor needed: YES` or `Complexity: architecture-tier`,
dispatch `arch-advisor` agent in CONSULT mode with the execution brief and spec.
Arch-advisor provides architecture-level guidance before design/implementation.
Append output to `## arch-advisor-consultation` in the handoff file.
```

**Add new Step 7.5 (Arch-advisor verification):**
```
### Step 7.5: Arch-advisor verification (if pre-check classified architecture-tier)
If pre-check set `Arch-advisor needed: YES`, dispatch `arch-advisor` in VERIFY mode
for independent structural review before landing-verifier. Arch-advisor evaluates
whether the implementation is architecturally sound — not just spec-conformant.

If Arch-advisor's verdict is UNSOUND:
- Send findings to implementer with specific architecture issues
- Implementer fixes, re-run spec-reviewer, then Arch-advisor verification again
- Max 1 Arch-advisor verification retry. If still UNSOUND, escalate to human.

Append output to `## arch-advisor-verification` in the handoff file.
```

**NOTE:** Arch-advisor invocation is gated purely by pre-check's classification.
The "3+ modules" heuristic is dropped — pre-check already evaluates
complexity and sets `Arch-advisor needed: YES/NO` based on full analysis.

---

## Files Changed Summary

| Phase | File | Change Type |
|-|-|-|
| 1A | `.claude/skills/keel-pipeline/SKILL.md` | Edit (Steps 6, 7, Rules) |
| 1B | `.claude/agents/spec-reviewer.md` | Edit (replace Status→Verdict, severity rules) |
| 1B′ | `.claude/agents/safety-auditor.md` | Edit (replace Status→Verdict) |
| 1C | `docs/exec-plans/active/handoffs/_TEMPLATE.md` | Edit (add sections) |
| 1D | `.claude/agents/pre-check.md` | Edit (add Decisions/Constraints) |
| 1D | `.claude/agents/backend-designer.md` | Edit (add Decisions/Constraints) |
| 1D | `.claude/agents/frontend-designer.md` | Edit (add Decisions/Constraints) |
| 1D | `.claude/agents/implementer.md` | Edit (add Decisions only) |
| 1D | `.claude/agents/test-writer.md` | Edit (add optional Decisions) |
| 1D | `.claude/agents/researcher.md` | Edit (add optional Decisions) |
| 2A-D | `.claude/agents/pre-check.md` | Edit (intent, complexity, slop, self-validation) |
| 2E | `.claude/skills/keel-pipeline/SKILL.md` | Edit (Step 1 routing fields) |
| 3A | `.claude/agents/arch-advisor.md` | **NEW** (ported from OMA) |
| 3C | `.claude/skills/keel-pipeline/SKILL.md` | Edit (Steps 1.7, 7.5) |

**Total: 12 file edits + 1 new file across 3 phases.**

---

## Commit Plan

Three commits, one per phase:

1. `feat(pipeline): add structured rejection, wisdom accumulation, and verdict protocol`
2. `feat(pre-check): add Metis patterns — intent classification, MUST/MUST NOT, anti-slop, self-validation`
3. `feat(agents): add Arch-advisor agent — architecture consultation and independent verification`

After all phases: update `template/` copies to match.

4. `chore(template): sync template agents and skills with OMA adoption changes`

---

## Roundtable Review Findings (incorporated above)

**Must-fix items (all 3 models agreed):**
1. safety-auditor.md was missing from edit list → added as Phase 1B′
2. Phase 2E dispatched Arch-advisor before Phase 3 created it → moved to Phase 3C
3. spec-reviewer had redundant Status/Verdict fields → explicit replacement
4. spec-review-attempt writer unspecified → pipeline orchestrator owns it
5. Safety-auditor infinite loop → capped at 3 attempts with escalation
6. Implementer constraining its reviewers → Decisions only, no Constraints

**Should-fix items incorporated:**
- MINOR-only deviations → CONFORMANT with Notes (don't burn loop attempts)
- Dropped "3+ modules" heuristic → Arch-advisor gated by pre-check classification only
- Wisdom sections optional for test-writer/researcher
- Arch-advisor failure at Step 7.5 → defined consequence (retry once, then escalate)
- Split arch-advisor handoff into consultation vs verification sections
- Template update added as Phase 4 commit
