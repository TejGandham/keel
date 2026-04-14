---
name: keel-pipeline
description: "Orchestrate the KEEL pipeline for a feature. Dispatches agents in sequence: pre-check → test-writer → implementer → code-reviewer → spec-reviewer → safety-auditor? → landing-verifier."
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
   by copying from `_TEMPLATE.md`. Then immediately seed the YAML frontmatter:
   - `status: IN-PROGRESS`
   - `pipeline:` — set to `bootstrap`, `backend`, `frontend`, or `cross-cutting`
   - `spec_ref:` — set to the spec file path and section (e.g., `mvp-spec:4.2`)
   
   These fields MUST be set before dispatching any agent. Downstream agents
   read them for context and routing.

4. **Clean-tree check.**
   Run `git status --porcelain`. If the output is non-empty after excluding
   the handoff file just created in step 3, STOP. Print:

     Pipeline requires a clean working tree. Commit, stash, or drop the
     following uncommitted changes before re-running:
     <paste the porcelain output>

   Do not proceed. Rationale: Step 9 uses `git add -A` to stage the feature,
   so any unrelated changes in the tree at pipeline start would be silently
   swept into the feature's commit. Phase 1 refuses that ambiguity.

5. **Branch safety check.**
   Run `git rev-parse --abbrev-ref HEAD`. If HEAD is `main` or `master`,
   auto-create the feature branch BEFORE any agent runs:

     git checkout -b keel/F{id}-{slug}

   where `{slug}` is derived from the handoff filename
   (`docs/exec-plans/active/handoffs/F{id}-{slug}.md` → `keel/F{id}-{slug}`).
   The pipeline never commits to main/master, and branches BEFORE writing
   code so that a mid-pipeline halt leaves the feature branch — not main —
   in the partial state.

6. **Remote check.**
   Run `git remote get-url origin`. If it fails or prints nothing, STOP:

     Pipeline lands features by opening a PR on your forge. No `origin`
     remote is configured. Add one (e.g., `git remote add origin <url>`)
     and re-run, or edit `.claude/skills/keel-pipeline/SKILL.md` Step 9
     locally if you want to land differently.

   This catches a missing remote early instead of at Step 9, an hour into
   the pipeline.

### Step 0.5: Roundtable availability

After the clean-tree/branch/remote checks, before any agent dispatch:

Check roundtable availability: read `Roundtable review` from CLAUDE.md.
If `true` (or absent — default is true), probe roundtable MCP server.
Store `roundtable_enabled: true|false` in handoff YAML.

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
pre-check → researcher? → backend-designer? → roundtable-review? → test-writer → implementer → code-reviewer → spec-reviewer → safety-auditor? → landing-verifier → roundtable-review? → post-landing
```

**Frontend** — changes to UI components, templates, styles, client-side logic:
```
pre-check → researcher? → frontend-designer → roundtable-review? → test-writer → implementer → code-reviewer → spec-reviewer → landing-verifier → roundtable-review? → post-landing
```

**Cross-cutting** — test infrastructure, config, Docker, docs:
```
pre-check → test-writer → implementer → code-reviewer → landing-verifier → roundtable-review? → post-landing
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

### Step 2.5: Roundtable design review (if enabled)

Runs only when `designer_needed: YES` AND `roundtable_enabled: true`.

1. Re-check roundtable MCP availability (120s timeout per tool call).
   If unavailable: set `roundtable_skipped: true` with reason in handoff YAML,
   continue to test-writer.
2. Call `mcp__roundtable__architect` with designer output from handoff.
3. Call `mcp__roundtable__challenge` with designer output from handoff.
4. Append combined output to `## roundtable-design-review` in handoff.
5. Set `roundtable_design_attempt: 1` in YAML.
6. If critical concerns raised: send findings back to designer, designer
   revises, increment `roundtable_design_attempt` to 2, re-run architect +
   challenge.
7. If still concerns after attempt 2: proceed anyway (advisory, not blocking).
   Set `roundtable_design_verdict: CONCERNS`. Log unresolved items in handoff.
8. If no concerns: set `roundtable_design_verdict: APPROVED`.

Roundtable is advisory. It never directly blocks the pipeline — its findings
feed back through the designer for revision, not through authoritative gates.

### Step 3: Test-writer
Dispatch `test-writer` with the handoff file. It writes tests, never implementation. Append output to handoff file.

### Step 4: Implementer (if needed)
If pre-check set `Implementer needed: NO`, skip to Step 6 (spec-reviewer) or Step 8 (landing-verifier).
Otherwise, dispatch `implementer` with the handoff file. It writes code to pass the tests. Never modifies tests. Append output to handoff file.

### Step 5: Code review
Dispatch `code-reviewer` with the handoff file. It reviews code quality —
DRY, patterns, edge cases, architecture fit. Its output includes
`**Verdict:** APPROVED` or `**Verdict:** CHANGES NEEDED`.

After code-reviewer completes, increment `code_review_attempt` and copy
the verdict to `code_review_verdict` in the YAML frontmatter.

If CHANGES NEEDED with CRITICAL or MAJOR findings: send findings
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
Dispatch `landing-verifier` with the handoff file. It runs tests and verifies everything is complete. Its output is `VERIFIED` (all gates passed, tests pass) or `BLOCKED`. If BLOCKED, fix blockers and re-run.

### Step 8.5: Roundtable landing review (if enabled)

Runs for ALL pipeline variants when `roundtable_enabled: true`.

1. Re-check roundtable MCP availability (120s timeout per tool call).
   If unavailable: set `roundtable_skipped: true` with reason, proceed to Step 9.
2. Call `mcp__roundtable__xray` with implementation summary from handoff.
3. Call `mcp__roundtable__challenge` with implementation summary from handoff.
4. Append combined output to `## roundtable-landing-review` in handoff.
5. Set `roundtable_landing_attempt: 1` in YAML.
6. If critical concerns raised: send findings back to implementer, implementer
   fixes, then re-run the full gate chain with separate counters:
   `code-reviewer` (roundtable_retry_code_review_attempt) →
   `spec-reviewer` (roundtable_retry_spec_review_attempt) →
   `safety-auditor?` (roundtable_retry_safety_attempt) →
   `arch-advisor?` → `landing-verifier`.
   Each roundtable-triggered gate re-run gets max 1 attempt. If a re-run gate
   itself fails, escalate to human — do not loop further.
7. After gate chain passes, re-run roundtable landing review (attempt 2).
8. If still concerns after attempt 2: proceed anyway (advisory, not blocking).
   Set `roundtable_landing_verdict: CONCERNS`. Log unresolved concerns.
9. If no concerns: set `roundtable_landing_verdict: APPROVED`.
10. Set handoff status to `READY-TO-LAND`.

When roundtable is disabled (roundtable_enabled: false), skip this step
entirely. The `VERIFIED` status from Step 8 triggers Step 9 directly.

Roundtable is advisory, not authoritative. Its findings feed back through
the existing authoritative gates on re-run. Roundtable never directly
blocks landing; it triggers re-evaluation by the authoritative gates.

### Step 9: Post-landing procedure (doc GC → archive → commit → land)

Triggers on `READY-TO-LAND` (after roundtable review) or `VERIFIED` (when
roundtable is disabled). The following sub-steps run in order; no human
approval at any point. If any sub-step fails, STOP and print the underlying
error verbatim.

1. **Doc garbage collection.**
   Dispatch `doc-gardener` agent unconditionally. NORTH-STAR §Stage 4
   lists automatic GC as a core requirement. Always run; let the agent
   decide whether a sweep finds drift. `doc-gardener` is read-only — it
   returns a findings report. If the report lists STALE or MISSING
   items, the orchestrator applies the fixes to the working tree NOW
   (before commit, so they land in the same commit — no amend, no
   post-push mutation, stable PR diff from open).

2. **Archive the handoff.**
   Move the handoff file:
     `docs/exec-plans/active/handoffs/F{id}-{slug}.md`
     → `docs/exec-plans/completed/handoffs/F{id}-{slug}.md`
   This move happens BEFORE staging, so the commit reflects the archived
   path (not active → then moved next run).

3. **Tech-debt log.**
   If `docs/exec-plans/tech-debt-tracker.md` exists, append any new
   shortcuts discovered during the run and check off any resolved items.

4. **Stage and commit.**
   Because "Before Starting" enforced a clean tree, every modified or
   new file in the working tree now is this feature's work. Stage
   everything:

     git add -A

   Compose the commit subject from the spec file:
   - The orchestrator was invoked with a full spec path (e.g.,
     `docs/product-specs/mvp-spec.md`) — that's in conversation context
     from Step 1. Read that file directly. Do NOT attempt to reconstruct
     the path from the handoff's `spec_ref` YAML field (which is in
     `filename:section` shorthand like `mvp-spec:4.2` and does not
     include the full path).
   - Extract the first `# ` H1 line from the spec file. Use it as the
     feature title.
   - If the spec file is missing or has no H1, fall back to the handoff
     slug with hyphens replaced by spaces (e.g., `F42-oauth-pkce-flow`
     → `oauth pkce flow`). The fallback is lossy but deterministic.

   Message format (HEREDOC):

     feat(F{id}): {feature title from spec H1}

     Spec: {spec_ref from handoff YAML frontmatter}
     Pipeline: {pipeline variant: bootstrap|backend|frontend|cross-cutting}
     Verdicts:
     {verdict_lines}

     🤖 Generated with KEEL pipeline

   Where `{verdict_lines}` is built by iterating over the handoff YAML
   frontmatter and emitting one line per verdict field that is set to a
   non-empty value. Skip any verdict whose field is unset (agent did not
   run in this pipeline variant). Format per line:

     spec-review: CONFORMANT (attempt 1)
     safety:      PASS (attempt 1)
     arch-advisor: SOUND
     code-review: APPROVED (attempt 1)
     roundtable-design: APPROVED (attempt 1)
     roundtable-landing: APPROVED (attempt 1)

   If all verdict fields are unset (bootstrap variant), emit the single
   line: `Verdicts: n/a (bootstrap variant)`.

   Commit with the constructed message.

5. **Push the branch.**
   `git push -u origin HEAD`. On failure, STOP and print the raw git
   error verbatim. The commit is still local — the human pushes manually
   once they've resolved the error.

6. **Open a PR.**
   Probe `gh`: `command -v gh` and `gh auth status`.
   - If both succeed: `gh pr create --fill` (ready-for-review). Record the
     returned PR URL in the handoff YAML as `pr_url`.
   - If `gh` is unavailable or not authenticated: print manual instructions:

         Forge CLI not available — branch pushed as keel/F{id}-{slug}.
         Open a PR on your forge manually.

     Do not fail the pipeline. The branch is pushed; the human opens the
     PR by hand. Leave `pr_url` unset.

   KEEL only ships a PR-based landing flow. If a project needs direct
   merge-to-base or a different forge integration, edit this skill file
   in the installed `.claude/skills/keel-pipeline/SKILL.md` — the skill
   is installed into each project and is a first-class customization
   point.

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
- **Stage 4 auto-landing.** After VERIFIED/READY-TO-LAND, the orchestrator runs Step 9
  end-to-end without asking. The human's review surface is the PR on
  GitHub, not a per-step prompt. To run the pipeline without auto-landing
  (e.g., for debugging), interrupt before Step 9 — the orchestrator will
  stop at the landing boundary.
- **Clean tree, then branch, then build.** "Before Starting" refuses a
  dirty working tree and auto-branches from main/master BEFORE any agent
  runs. This is the only automatic branch creation the pipeline performs.
  Once inside a feature branch, intermediate pipeline writes cannot
  pollute main even on a halt.
- **gh is optional.** The pipeline prints manual PR instructions if gh
  is missing or not authed. It does not fail the run.
- **doc-gardener is unconditional.** Step 9 sub-step 1 always dispatches
  doc-gardener; no more "if the feature was substantial" judgment call.
  Drift fixes are applied to the working tree BEFORE the commit, so the
  PR diff is stable from the moment it opens.
- **Roundtable is advisory.** It never directly blocks landing. Findings
  feed back through authoritative gates (spec-reviewer, safety-auditor) on
  re-run. If roundtable has concerns after max attempts, proceed anyway.
- **Re-check MCP before each call.** Don't rely on the roundtable_enabled
  flag from Step 0.5. Probe availability immediately before each roundtable
  tool call. Timeout: 120s. On failure: skip, log reason, continue.
- **PR-only landing.** Every feature lands by pushing the feature branch
  and opening a PR. No merge-to-base, no strategy selection. To change the
  landing flow, edit Step 9 in the installed skill file.
- **VERIFIED → READY-TO-LAND → LANDED.** Landing-verifier emits VERIFIED.
  Roundtable review (if enabled) transitions to READY-TO-LAND. Step 9
  transitions to LANDED after commit+push+PR. When roundtable is disabled,
  VERIFIED triggers Step 9 directly (skip READY-TO-LAND).
