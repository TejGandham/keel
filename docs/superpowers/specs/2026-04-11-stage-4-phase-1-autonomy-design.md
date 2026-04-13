# Stage 4 Phase 1 — Autonomy Design

> **Partially superseded** by [landing-strategy-roundtable-design](2026-04-13-landing-strategy-roundtable-design.md)
> (Stage 4 Phase 2). The PR-only landing flow described here is now configurable.
> This document remains valid as historical context for Phase 1 decisions.

**Date:** 2026-04-11
**Status:** Revised after roundtable review — ready for implementation plan
**Scope:** KEEL framework repo (`/mnt/agent-storage/vader/src/keel`)
**Related:** `NORTH-STAR.md` §Growth Stages (row 4)

## Revision history

- **v1 (2026-04-11):** Initial spec after brainstorming + 3-agent stress test.
- **v2 (2026-04-11):** Revised after roundtable review (Claude APPROVE-WITH-FIXES, Codex REJECT, Gemini REJECT). Three must-fixes applied: (1) branch safety + clean-tree check moved to "Before Starting", not Step 9 — fixes the data-loss foot-gun where halt paths would dirty `main` with intermediate pipeline writes. (2) Staging simplified to `git add -A`, valid because Step 0 now guarantees a clean starting tree — aligns with the existing `keel-pipeline/SKILL.md:182` rule "Branch on frontmatter, not on parsing agent prose." (3) Post-LANDED procedure merged into a single Step 9 with deterministic ordering: `doc-gardener → archive → tech-debt → commit → push → PR`. No amend, no post-push mutation, one stable PR diff. Also: commit subject reads from spec H1 instead of regex-dehyphenating the slug; manual tests trimmed from 7 to 3; meaningless "escalation regression test" deleted.

## Context

Per `NORTH-STAR.md`, Stage 4 is *"Full autonomy: Feature → PR without human at each step, automatic GC."* Stages 1–3 are Done. Today the `keel-pipeline` skill runs end-to-end but pauses for human approval at Step 9 (commit) and has no push or PR automation. The user's stated primary pain is the commit approval gate.

An earlier, more ambitious proposal (Approach 2 in the brainstorming session) added git worktree isolation per feature, a `.keel/` state-file layer, three PreToolUse enforcement hooks (`halt-guard`, `worktree-scope-guard`, `auto-push-guard`), and a local HALT marker file for escalation visibility. That proposal was stress-tested with three parallel reviewer agents and failed:

- **`cd`-mid-session is architecturally impossible.** `$CLAUDE_PROJECT_DIR` is pinned at session launch, and each Bash tool call is an independent subprocess, so a single Claude session cannot shift its working directory into the worktree and still have hooks fire from the worktree. The proposed enforcement would have been dead code.
- **Hook-based enforcement is self-defeating when the bypass flag lives in the same filesystem the enforced agent controls.** ATELIER's `touch .claude/skip-<name>` pattern works because the *human* owns the bypass; in an autonomous KEEL run, the orchestrator owns it. Hooks would become speed bumps teaching the orchestrator to reach for skip flags.
- **ATELIER's enforcement philosophy targets a different context.** ATELIER is built for unattended overnight batch runs; KEEL is an interactive skill inside a single Claude session with the human present. Porting the enforcement aesthetic imports friction without importing the problem it solves.

The reviewers' consensus recommendation was: simplify. Ship the minimum that removes the stated pain, defer worktree + hook work until real evidence of orchestrator drift or concurrency collisions appears.

## Decision

Ship Stage 4 as a two-phase split:

- **Phase 1 (this spec):** Remove the commit approval gate. Enforce clean starting tree. Auto-branch from main/master. Run doc-gardener + archive handoff + commit + push + `gh pr create` as a single deterministic procedure after LANDED. ~133 lines changed across 6 files (5 prompt/doc files + a single-line edit to `doc-gardener.md`). No new files, no new scripts, no new hooks, no install/uninstall changes.
- **Phase 2 (deferred, unscheduled):** Worktree isolation, enforcement hooks, `.keel/` state layer, HALT markers, scope-guard. Revisit only if Phase 1 reveals concrete problems that Phase 2 would solve. The Phase 2 design is documented in the Deferred section below so the institutional memory is preserved.

## Scope — Phase 1

Four behavior changes to the existing `keel-pipeline` skill, all prose-level:

1. **Clean-tree enforcement at pipeline start.** Add items 4 and 5 to "Before Starting": check `git status --porcelain` is empty; if `HEAD` is `main`/`master`, auto-create `keel/F{id}-{slug}`. Refuse to start a pipeline on a dirty tree.
2. **Delete the human approval gate.** Post-LANDED procedure runs without asking.
3. **Deterministic post-LANDED ordering.** Single Step 9 that runs doc-gardener → archive handoff → log tech-debt → `git add -A` → commit → push → `gh pr create`. One commit, one push, one PR, stable diff.
4. **Graceful `gh` fallback.** If `gh` is missing or not authed, push still succeeds and the orchestrator prints manual-PR instructions. Pipeline does not fail.

### Non-goals

- No worktree isolation.
- No new `.claude/hooks/` scripts.
- No `.keel/` state directory.
- No HALT marker files.
- No escalation report files for gate-ceiling trips. Escalation continues to be prose-level — the orchestrator prints "STOP. Escalate to human." and the human is in-session to see it.
- Minimal change to exactly one agent prompt: `doc-gardener.md:10` currently says *"This is a BATCH operation run periodically, not per-feature. For per-feature doc checks, that's landing-verifier's job."* That line contradicts Phase 1's per-feature GC at Step 9 sub-step 1 and contradicts NORTH-STAR §Autonomy Ceiling which already lists "Garbage collect docs after landing" as autonomous. Replace that line with: *"This runs per-feature at keel-pipeline Step 9 (auto-landing) and on-demand for batch sweeps. READ-ONLY — you report findings, the orchestrator applies fixes."* All other agent prompts are unchanged.
- No changes to gate ceilings. Spec-review stays at max 2 loops, safety at max 3, arch-advisor at max 1.
- No changes to `install.py` / `uninstall.py`. Phase 1 ships zero new files to user projects.
- No new runtime dependencies beyond `gh`, which is optional (pipeline prints manual instructions if absent).

## Design

### "Before Starting" additions (`.claude/skills/keel-pipeline/SKILL.md`)

Extend the existing "Before Starting" section (which already has items 1–3: read CLAUDE.md, read spec, create handoff) with:

```
4. Clean-tree check.
   Run `git status --porcelain`. If the output is non-empty after
   excluding the handoff file just created, STOP. Print:
     "Pipeline requires a clean working tree. Commit, stash, or drop
      the following uncommitted changes before re-running:"
   followed by the porcelain output. Do not proceed.

   Rationale: the orchestrator will `git add -A` at Step 9. Unrelated
   changes in the tree at pipeline start would be silently swept into
   the feature's commit. Phase 1 refuses that ambiguity.

5. Branch safety check.
   Run `git rev-parse --abbrev-ref HEAD`. If HEAD is `main` or `master`,
   auto-create the feature branch before any agent runs:
     git checkout -b keel/F{id}-{slug}
   where `{slug}` is derived from the handoff filename
   (`docs/exec-plans/active/handoffs/F{id}-{slug}.md` → `keel/F{id}-{slug}`).
   Stage 4 never commits to main/master, and branches BEFORE writing
   code so that a mid-pipeline halt leaves the feature branch — not
   main — in the partial state.
```

### Step 9 rewrite (`.claude/skills/keel-pipeline/SKILL.md`)

Replace the current Step 9 ("Commit on behalf of the human orchestrator") AND Step 10 ("Update docs") with a single merged Step 9:

```
### Step 9: Post-LANDED procedure (doc GC → archive → commit → push → PR)

Only after landing-verifier reports LANDED. The following sub-steps run
in order; no human approval at any point. If any sub-step fails, STOP
and print the underlying error verbatim.

1. Doc garbage collection.
   Dispatch `doc-gardener` agent unconditionally. NORTH-STAR §Stage 4
   lists automatic GC as a core requirement. Always run; let the agent
   decide whether a sweep finds drift. `doc-gardener` is read-only —
   it returns a findings report. If the report lists STALE or MISSING
   items, the orchestrator applies the fixes to the working tree NOW
   (before commit, so they land in the same commit — no amend, no
   post-push mutation, stable PR diff from open).

2. Archive the handoff.
   Move the handoff file:
     docs/exec-plans/active/handoffs/F{id}-{slug}.md
     → docs/exec-plans/completed/handoffs/F{id}-{slug}.md
   This move happens BEFORE staging, so the commit reflects the
   archived path (not `active/` → then moved next run).

3. Tech-debt log.
   If `docs/exec-plans/tech-debt-tracker.md` exists, append any new
   shortcuts discovered during the run and check off any resolved items.

4. Stage and commit.
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

     Spec: {spec_ref}
     Pipeline: {pipeline variant: bootstrap|backend|frontend|cross-cutting}
     Verdicts:
     {verdict_lines}

     🤖 Generated with KEEL pipeline

   Where `{verdict_lines}` is built by iterating over the handoff YAML
   frontmatter and emitting one line per verdict that is set to a
   non-empty value. Skip any verdict whose field is unset (agent
   didn't run in this pipeline variant). Format per line:
     spec-review: CONFORMANT (attempt 1)
     safety:      PASS (attempt 1)
     arch-advisor: SOUND
     code-review: APPROVED (attempt 1)

   If all verdict fields are unset (bootstrap variant), emit the
   single line: "Verdicts: n/a (bootstrap variant)".

   Commit with the constructed message.

5. Push.
   `git push -u origin HEAD`. On failure, STOP and print the raw git
   error verbatim. Do not retry, do not auto-recover. Push failures
   (auth, branch protection, network) require human judgment. The
   commit is still local — the human can fix auth and push manually.

6. Open PR.
   Probe `gh`:
   - `command -v gh` to check the binary exists.
   - `gh auth status` to check it's authed.

   If both succeed: run `gh pr create --fill`. `--fill` uses the commit
   message as both the PR title (first line) and body (remaining lines).
   Create the PR as ready-for-review (not draft) — the pipeline's gates
   passed; draft would imply uncertainty the pipeline does not have.
   Print the PR URL prominently.

   If either probe fails: print a loud message:

     gh CLI not available — branch pushed as keel/F{id}-{slug}.
     Open PR manually: {push URL from git output, or plain branch name
     if the remote didn't print one}

   Do not fail the pipeline. The branch is pushed; the human opens
   the PR by hand.

### Step 10 is removed.

The pre-revision Step 10 ("Update docs: run doc-gardener, move handoff,
check tech-debt") has been merged into the sub-steps of Step 9 above.
There is no Step 10.
```

### Rules section addition (`.claude/skills/keel-pipeline/SKILL.md`)

Append to the existing Rules list:

```
- **Stage 4 auto-landing.** After LANDED, the orchestrator runs Step 9
  end-to-end without asking. The human's review surface is the PR on
  GitHub, not a per-step prompt. To run the pipeline without
  auto-landing (e.g., for debugging), interrupt before Step 9 — the
  orchestrator will stop at the landing boundary.
- **Clean tree, then branch, then build.** "Before Starting" refuses
  a dirty working tree and auto-branches from main/master BEFORE any
  agent runs. This is the only automatic branch creation the pipeline
  performs. Once inside a feature branch, intermediate pipeline writes
  cannot pollute main even on a halt.
- **gh is optional.** The pipeline prints manual PR instructions if gh
  is missing or not authed. It does not fail the run.
- **doc-gardener is unconditional.** Step 9 sub-step 1 always dispatches
  doc-gardener; no more "if the feature was substantial" judgment call.
  Drift fixes are applied to the working tree BEFORE the commit, so the
  PR diff is stable from the moment it opens.
```

## Files touched

| File | Change | Lines |
|-|-|-|
| `.claude/skills/keel-pipeline/SKILL.md` | Extend "Before Starting" with items 4 & 5 (~20 lines). Rewrite Step 9 as merged post-LANDED procedure (~75 lines). Delete Step 10 (~6 lines removed). Append 4 Rules bullets (~10 lines). | ~100 |
| `.claude/agents/doc-gardener.md` | Single-line edit at line 10: remove the "BATCH operation, not per-feature" restriction. Replace with text aligning doc-gardener with its per-feature role in Step 9. `install.py` copies agents from `.claude/agents/` directly, not from `template/`, so no template sync is needed. | ~2 |
| `NORTH-STAR.md` | Update Growth Stages row 4 status: "Next" → "Phase 1 done (auto-land + PR). Phase 2 deferred pending real-world evidence of need." | ~3 |
| `docs/HOW-IT-WORKS.md` | Mermaid pipeline diagram currently jumps from `GC` (doc-gardener) → `PR` (human reviews). Replace the GC node with a "Post-LANDED: GC → archive → commit → push → gh pr create" node (or a short sub-subgraph). Ensure the terminal "YOU REVIEW THE RESULT" is still the human-review landing point. | ~8 |
| `docs/process/THE-KEEL-PROCESS.md` | Update the human-in-loop doctrine statement at lines 115–116 ("execute repo mutations... only after presenting the action and receiving human approval") to add a Stage 4 carve-out: after LANDED, commit/push/PR is autonomous; human review moves from per-step to PR-level. | ~10 |
| `template/CLAUDE.md` | Rewrite the "After landing-verifier reports LANDED" workflow block at lines 74–77. Current text is human-centric; new text reflects the deterministic Step 9 procedure (GC, archive, commit, push `keel/F{id}-{slug}`, `gh pr create`). | ~10 |

**Total:** ~133 lines changed across 6 files. Zero new files. Zero script changes. Zero hook changes. One single-line agent prompt change (`doc-gardener.md`). Zero install/uninstall changes. Budget grew from the v1 estimate of ~85 lines because Step 9 absorbed Step 10 and the "Before Starting" additions are new territory.

## Decisions resolved

| # | Question | Decision | Rationale |
|-|-|-|-|
| 1 | Where does branch safety run? | **"Before Starting" items 4 and 5**, before any agent runs | Branching at Step 9 leaves main dirty on halt paths (pipeline writes files to working tree as it runs; if it halts at Step 6/7 before reaching Step 9, main is polluted). Branching before any agent runs guarantees isolation for the full pipeline, not just the landing phase. Also: clean-tree enforcement makes `git add -A` safe at Step 9, removing the whole class of staging-rule ambiguity the roundtable flagged. |
| 2 | On HEAD=main at pipeline start: hard-fail or auto-create? | **Auto-create** `keel/F{id}-{slug}` | More autonomous; matches Phase 1's spirit (remove gates, not add them). The human is protected from accidental commits to main while still getting full auto-landing. |
| 3 | PR body: `gh pr create --fill` or craft templated body? | **`--fill`** | The commit message already contains spec ref, pipeline variant, and verdict table. `--fill` copies it verbatim. Richer PR bodies can be a follow-up if batch-review UX needs it. |
| 4 | PR created as draft or ready-for-review? | **Ready-for-review** | The pipeline's gates passed. Draft would imply uncertainty the pipeline does not have. |
| 5 | What if `git push` fails? | **Hard stop with raw git error** | Push failures (auth, branch protection, network) need human judgment. The commit is still local; nothing is lost. |
| 6 | Commit subject source? | **Spec file H1**, fallback to slug-dehyphenation | Slug regex (v1 rule) loses acronym casing on names like `oauth-pkce-flow`. Spec H1 is already the human-readable title. |
| 7 | doc-gardener ordering? | **Before commit**, not after push | v1 ran doc-gardener AFTER the PR was open, then said "amend with a follow-up commit" — which is oxymoronic (amend = force-push = mutating PR diff under reviewer). v2 runs doc-gardener first, applies its fixes to the working tree, then stages and commits once. Stable diff from PR-open forward. |
| 8 | Staging rule? | **`git add -A`** | Roundtable flagged that v1's prose-scraping rule violated `keel-pipeline/SKILL.md:182` ("Branch on frontmatter, not on parsing agent prose") AND had undefined semantics on spec-review rework loops (multiple `## implementer` sections). v2 relies on the "Before Starting" clean-tree guarantee: every modified file at Step 9 IS the feature's work. `git add -A` is now correct and simple. |

## Stress-test findings addressed

### From the v1 3-agent stress test (arch-advisor, code-architect, devil's advocate)

- **`gh` is a new runtime dependency:** Mitigated by making `gh` optional with a graceful fallback that prints manual PR instructions. `install.py` does not gain a dependency; the framework still ships stdlib-only.
- **doc-gardener short-circuit on halt:** Halt path unchanged (still prose-level "escalate to human"); success path now runs doc-gardener unconditionally and BEFORE commit, closing NORTH-STAR §Stage 4's GC requirement.
- **Context budget:** Phase 1 does not make this worse. The human is in-session during the run and can `/compact` as needed. Phase 2 would need to address it explicitly if unattended runs ever become a goal.
- **`git add -A` safety:** Previously flagged as a concern by the code-architect reviewer. v2 flips the answer: clean-tree enforcement at "Before Starting" makes `git add -A` provably safe because every modified file at landing time is this feature's work by construction.

All worktree-related and hook-related findings from v1's stress test remain sidestepped by the Phase 2 deferral.

### From the v2 roundtable review (claude, codex, gemini)

- **Branch creation ordering (all 3 reviewers, must-fix):** Fixed by moving branch safety to "Before Starting" items 4 and 5.
- **"Amend with follow-up commit" self-contradiction (all 3, must-fix):** Fixed by running doc-gardener BEFORE the commit. Single commit, no amend.
- **Staging rule conflicts with `Branch on frontmatter, not prose` architectural rule (Codex, must-fix):** Fixed by replacing prose-scraping with `git add -A` + clean-tree guarantee.
- **Rework-loop staging ambiguity (Claude + Gemini, must-fix):** Same fix as above — `git add -A` has no rework-loop edge cases because it stages what's in the tree, not what prose says is in the tree.
- **Commit subject from slug is lossy (Claude + Codex, should-fix):** Fixed by reading spec H1 with slug fallback.
- **Manual test count is aspirational (Claude + Codex, should-fix):** Trimmed from 7 to 3 core tests; remaining scenarios moved to documentation.
- **Escalation regression test is meaningless (Claude, should-fix):** Deleted. Step 9 never runs on halt paths by construction, so there's nothing to regress.
- **NORTH-STAR consistency (all 3, no issue):** All three reviewers confirmed that push-to-feature-branch + PR sit cleanly within the autonomy ceiling (which only forbids push-to-main and merge).

## Deferred — Phase 2 (unscheduled)

Documented here so the brainstorming work is preserved, not for immediate implementation. Revisit only if Phase 1 reveals concrete evidence of one or more of:

- **Repeated accidental commits to main.** The Phase 1 branch safety check at "Before Starting" should prevent this, but if it fires too often or a Claude session finds a way around it, Phase 2's `protect-main-writes` hook becomes justified.
- **Concurrent-run collisions.** If two features are in flight in the same working directory and collide, worktree isolation becomes justified.
- **Orchestrator drift.** If the orchestrator is observed writing files outside a feature's declared scope, scope-guard becomes justified — and needs to be redesigned so the bypass flag isn't trivially writable by the orchestrator itself (the original Approach 2 had this backwards).
- **Unattended overnight runs.** If the usage pattern shifts toward "kick off features at midnight, review PRs in the morning," the full ATELIER-style enforcement philosophy becomes a better fit and Phase 2's hooks become real.

If any of the above materializes, Phase 2 should be re-brainstormed from scratch — not resurrected from the original Approach 2 proposal. The original proposal had structural errors (`cd`-mid-session impossibility, self-defeating bypass flags, cross-platform symlink issues, `install.py` settings-merge gap) that need a fresh design, not a patch.

## Testing strategy

Phase 1 is entirely prompt-level changes to `keel-pipeline/SKILL.md` with supporting doc updates. There is no code to unit-test. Verification is behavioral, performed against a throwaway KEEL-installed repo. Three gating tests plus documented scenarios:

### Gating tests (must pass before merge)

1. **Clean-path smoke test.** In a scratch clone on a feature branch, with a clean tree, run a full pipeline invocation for a trivial backend feature. Verify: pipeline reaches LANDED, Step 9 runs deterministically (doc-gardener → archive → commit → push → PR), commit subject is drawn from the spec H1, verdict table in the commit body reflects the actual agent runs, `gh pr create --fill` opens a ready-for-review PR with the full commit message as body.
2. **Dirty-tree abort test.** Leave an unrelated modified file in the tree. Invoke the pipeline. Verify "Before Starting" item 4 refuses to start, prints the porcelain output, and does not dispatch any agent. Clean the file, re-run, verify it now proceeds normally.
3. **Main-branch auto-branch test.** Start on `main` with a clean tree. Invoke the pipeline. Verify "Before Starting" item 5 auto-creates `keel/F{id}-{slug}` BEFORE test-writer runs (not at Step 9), so any intermediate writes land on the feature branch. Confirm the branch name matches the slug from the handoff filename.

### Documented scenarios (not gated; exercise manually if suspect)

- **gh-missing fallback.** Temporarily shadow `gh` in PATH with a nonexistent binary. Verify Step 9 sub-step 6 prints manual-PR instructions and does not fail. Verify the branch is still pushed and the handoff is still archived.
- **gh-unauthed fallback.** `gh auth logout`, run the pipeline, verify the same fallback fires.
- **Push-failure behavior.** Set up a remote that rejects pushes (pre-receive hook). Verify Step 9 sub-step 5 stops with the raw git error and does not attempt recovery. Verify the commit is still in the local branch.
- **Spec H1 fallback.** Run with a spec file that has no H1. Verify the commit subject falls back to slug-dehyphenation.

## Acceptance criteria

Phase 1 is complete when:

- [ ] `.claude/skills/keel-pipeline/SKILL.md` "Before Starting" is extended with items 4 and 5 per the Design section.
- [ ] `.claude/skills/keel-pipeline/SKILL.md` Step 9 is rewritten as the merged post-LANDED procedure. Step 10 is removed.
- [ ] The four Rules bullets are appended to `keel-pipeline/SKILL.md`.
- [ ] `.claude/agents/doc-gardener.md:10` is updated to remove the "BATCH-only" restriction (no `template/` sync needed).
- [ ] `NORTH-STAR.md` Growth Stages row 4 reflects the Phase 1 / Phase 2 split.
- [ ] `docs/HOW-IT-WORKS.md` Mermaid diagram includes the post-LANDED procedure node.
- [ ] `docs/process/THE-KEEL-PROCESS.md` lines 115–116 carry the Stage 4 carve-out.
- [ ] `template/CLAUDE.md` "After landing-verifier reports LANDED" workflow block describes the deterministic Step 9 procedure.
- [ ] All 3 gating tests in the Testing Strategy pass on a throwaway repo.
- [ ] `git log` shows the changes in a single commit or tightly-scoped series matching this repo's conventional commit style.

## Open questions

None at spec-approval time. All eight design decisions are resolved.
