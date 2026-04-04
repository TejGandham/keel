---
name: keel-pipeline
description: "Orchestrate the KEEL pipeline for a feature. Dispatches agents in sequence: pre-check → test-writer → implementer → spec-reviewer → safety-auditor? → plan-lander."
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
docker-builder → plan-lander          (F01: container)
scaffolder → plan-lander              (F02: app skeleton)
config-writer → plan-lander           (F03: test infra)
```
Bootstrap features are orchestrator-direct: dispatch the specific bootstrap agent, then plan-lander. No pre-check, no test-writer, no implementer. The bootstrap agent's report serves as the handoff context.

**Backend** — changes to core business logic, services, data layer:
```
pre-check → researcher? → backend-designer? → test-writer → implementer → spec-reviewer → safety-auditor? → plan-lander
```

**Frontend** — changes to UI components, templates, styles, client-side logic:
```
pre-check → researcher? → frontend-designer → test-writer → implementer → spec-reviewer → plan-lander
```

**Cross-cutting** — test infrastructure, config, Docker, docs:
```
pre-check → test-writer → implementer → plan-lander
```

**Full-stack** — touches both backend and frontend: run backend pipeline, then frontend pipeline, sharing the same handoff file.

## Execution Steps

### Step 0: Bootstrap (F01-F03 only)
If the feature is a bootstrap feature, dispatch the specific bootstrap agent (docker-builder, scaffolder, or config-writer). It produces its report in the handoff file. Skip directly to Step 8 (plan-lander). Bootstrap features do not use pre-check, designers, test-writer, or implementer.

### Step 1: Pre-check (standard pipeline only)
Dispatch the `pre-check` agent with the feature spec path. It produces an execution brief in the handoff file. It tells you:
- Whether designer is needed
- Whether researcher is needed
- Whether safety-auditor is needed (YES if feature touches domain-critical modules)

### Step 1.5: Researcher (if needed)
If pre-check set `Research needed: YES`, dispatch `researcher` with the specific questions from the execution brief. Append research brief to handoff file. Then continue to Step 2.

### Step 2: Designer (if needed)
Dispatch `backend-designer` or `frontend-designer` based on pipeline variant. Append output to handoff file.

### Step 3: Test-writer
Dispatch `test-writer` with the handoff file. It writes tests, never implementation. Append output to handoff file.

### Step 4: Implementer (if needed)
If pre-check set `Implementer needed: NO`, skip to Step 6 (spec-reviewer) or Step 8 (plan-lander).
Otherwise, dispatch `implementer` with the handoff file. It writes code to pass the tests. Never modifies tests. Append output to handoff file.

### Step 5: Code review
Before dispatching spec-reviewer, do a code quality review:
1. Get the git range: `BASE_SHA` (commit before test-writer started) and `HEAD_SHA` (current HEAD)
2. Run `git diff --stat $BASE_SHA..$HEAD_SHA` to see what changed
3. Run `git diff $BASE_SHA..$HEAD_SHA` to read the actual diff
4. Review against these criteria:
   - **Requirements:** Does implementation match the spec? Anything missing or extra?
   - **Code quality:** Clean separation of concerns? DRY? Edge cases?
   - **Testing:** Tests verify behavior (not just mocks)? Edge cases covered?
   - **Architecture:** Sound design? Follows existing patterns?
5. Categorize findings: **Critical** (must fix), **Important** (should fix), **Minor** (nice to have)
6. If Critical or Important issues found, fix them before proceeding.

### Step 6: Spec-reviewer
Dispatch `spec-reviewer` with the handoff file. It verifies code conforms to specs. If it finds deviations, go back to Step 4.

### Step 7: Safety-auditor (if feature touches domain-critical modules)
Dispatch `safety-auditor` with the handoff file. If violations found, go back to Step 4.

### Step 8: Plan-lander
Dispatch `plan-lander` with the handoff file. It runs tests and verifies everything landed. If BLOCKED, fix blockers and re-run.

### Step 9: Commit (on behalf of the human orchestrator)
Only after plan-lander reports LANDED. Present the commit plan to the human for approval:
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
