# KEEL Framework Review — Gaps, Boundaries, and Augmentation Path

**Date:** 2026-04-04
**Reviewers:** Claude Opus 4.6, Codex, Gemini 3.1 Pro (independent deep analysis, then synthesized)
**Consensus Level:** High — all three models converged on the same core findings

---

## 1. What KEEL Solves (Clearly)

KEEL solves the **tacit knowledge problem** in AI-agent development. When you give an agent a vague prompt, it hallucinates because unstated assumptions aren't in the repo. KEEL forces you to encode everything the agent needs — specs, invariants, architecture, testing doctrine — into the repository itself.

**The core value proposition:** KEEL creates *compounding institutional knowledge* in the repo. Ad-hoc prompting creates ephemeral results. With KEEL, feature 20 benefits from everything learned building features 1-19 because it's all encoded in docs, tests, and handoff files.

**When KEEL is right:**
- Multi-feature greenfield projects (10+ features)
- Solo developer or small team with one AI agent as primary implementer
- Projects where safety/correctness matters more than speed
- Projects with clear domain invariants (financial, git, data pipelines)

**When KEEL is overkill:**
- One-off scripts, prototypes, experiments
- Projects with < 5 features
- Teams that change tools/agents frequently
- Projects where "move fast and break things" is the right strategy

---

## 2. Where KEEL Starts and Ends

### Starts (clear)
KEEL starts **before the first line of code**, when you decide to run an agent-led, spec-first workflow. The entry point is `bootstrap.sh` or manually creating the doc structure.

### Ends (ambiguous — this is a gap)
KEEL's operational coverage **ends at `git commit`**. "Feature landed" means code is in the repo with passing tests. That's it.

KEEL does NOT cover:
- Getting code from commit to production
- Operating the software after deployment
- Responding to incidents
- Scaling the team beyond one orchestrator

---

## 3. What KEEL Does NOT Cover

### Explicitly absent (all three reviewers agree):

| Category | Gap | Impact |
|-|-|-|
| **CI/CD** | No pipeline-to-deployment bridge. Commit ritual ends at git. | HIGH |
| **Deployment** | No staging, feature flags, rollback strategies | HIGH |
| **Brownfield/Legacy** | No adoption path for existing codebases | HIGH |
| **Multi-agent platform** | Locked to Claude Code (model: opus/sonnet in frontmatter) | HIGH |
| **Team scaling** | Single orchestrator model, no merge conflict resolution for handoffs | MEDIUM |
| **Multi-repo/microservices** | Single CLAUDE.md, single ARCHITECTURE.md, single backlog | MEDIUM |
| **Monitoring/Observability** | Referenced in OpenAI article, not adapted | MEDIUM |
| **Security review** | No security-specific agent or checklist | MEDIUM |
| **Incident response** | No runbook generation, no on-call integration | LOW |
| **Performance testing** | No performance budgets, no load testing | LOW |
| **Accessibility** | Mentioned in frontend-designer output format, no systematic treatment | LOW |
| **i18n** | Not addressed | LOW |
| **Dependency management** | No update strategy, no vulnerability scanning | LOW |
| **Non-Docker environments** | Mobile, embedded, serverless excluded by core belief | LOW |

---

## 4. Process Weaknesses (Prioritized)

### 4.1 Error Recovery is Underspecified (HIGH)

**Problem:** The pipeline's recovery path is "loop back to implementer." But:
- What if the spec is wrong? There's no spec-change lane.
- What if test-writer wrote invalid tests? Implementer can't modify tests.
- What's the maximum number of loops before escalation?
- What if the problem is upstream (design, not implementation)?

**Fix:** Add a **Pipeline Failure Playbook** — a decision tree:
```
Spec wrong         → Update spec, restart from pre-check
Tests wrong        → Send back to test-writer with findings
Implementation     → Loop to implementer (max 2 attempts)
Can't satisfy      → Escalate to human orchestrator
Safety violation   → Fix, re-audit, no shortcuts
```

### 4.2 Orchestrator Role Contradiction (HIGH)

**Problem:** The keel-pipeline skill says "You don't write code" but also instructs the orchestrator to perform code review and commit files. The orchestrator is simultaneously "hands-off conductor" and "active reviewer" — a role not in the 13-agent roster.

**Fix:** Either add a `code-reviewer` agent to the roster, or explicitly acknowledge that the orchestrator reviews at gate points. Remove the contradiction.

### 4.3 Pre-Check Makes Hard-to-Reverse Routing Decisions (MEDIUM)

**Problem:** Pre-check decides: designer needed? researcher needed? safety-auditor needed? If pre-check gets this wrong (says "no designer" when complex UI design is needed), the error isn't detected until spec-reviewer or landing-verifier — late in the pipeline. Cost: full pipeline re-run.

**Fix:** Add a "circuit breaker" — if spec-reviewer finds MAJOR deviations that trace back to a missing design phase, the pipeline can route back to the designer, not just the implementer.

### 4.4 Test-Writer/Implementer Deadlock (MEDIUM)

**Problem:** Test-writer writes tests. Implementer makes them pass. But if test-writer writes an invalid test (wrong mock setup, incorrect assertion, impossible contract), the implementer is forbidden from fixing tests. The pipeline stalls.

**Fix:** Allow the implementer to flag test issues with a `BLOCKED: test-issue` status in the handoff. The pipeline routes back to test-writer with the implementer's findings.

### 4.5 Handoff Files Scale Poorly (MEDIUM)

**Problem:** Append-only markdown is great for auditability but poor for searchability, automation, and concurrency. For complex features, downstream agents parse walls of upstream noise. At scale, KEEL needs structured metadata.

**Fix:** Not urgent for solo dev. For team scaling: consider structured YAML frontmatter in handoff sections, or a machine-readable status field per agent section.

---

## 5. Competitive Position

| Dimension | KEEL | Codex Harness | Cursor Rules | Windsurf | Devin/Factory |
|-|-|-|-|-|-|
| Spec-driven | Yes (strongest) | Yes (origin) | No | No | Varies |
| Safety invariants | Mechanical enforcement | Referenced | Not covered | Not covered | Not covered |
| Brownfield | None | Assumed | Yes (rules overlay) | Yes | Yes |
| Team scaling | Not addressed | 3-7 engineers | Implicit | Built-in | Built-in |
| Adoption cost | High (5-7 docs) | High (not public) | Low (1 file) | Low | Low-Medium |
| Platform lock | Claude Code | Codex | Cursor IDE | Windsurf | Respective |
| CI/CD integration | None | Full | PR reviews | PR reviews | Full |

**KEEL's advantage:** No public competitor matches its process rigor — structured knowledge encoding, domain invariant templates, 6-layer testing model, and the spec-first discipline.

**KEEL's disadvantage:** High adoption cost. Cursor Rules achieves ~60% of the benefit with ~5% of the effort (one `.cursorrules` file). KEEL's ROI only appears around feature 10+.

---

## 6. Augmentation Recommendations (Prioritized)

### Tier 1: Do Now (highest impact, lowest effort)

**6.1 Explicit Scope Statement**
Add one paragraph to README.md and THE-KEEL-PROCESS.md:
> "KEEL covers the build phase: from product spec to landed feature. It does not cover deployment, operations, or incident response. KEEL's boundary is the git commit. Your CI/CD pipeline takes over from there."

**6.2 Target User Statement**
> "KEEL is designed for a solo developer or small team (1-3 people) using an AI coding agent as their primary implementer, building a multi-feature greenfield application."

**6.3 Pipeline Failure Playbook**
A 1-page decision tree covering the 5 failure modes identified in section 4.1.

### Tier 2: Do Soon (high impact, moderate effort)

**6.4 "KEEL for Existing Projects" Guide**
How to retrofit KEEL onto a brownfield codebase:
1. Write ARCHITECTURE.md from what exists (agent reads code, proposes architecture)
2. Backfill core-beliefs from existing patterns
3. Create feature backlog of *improvements*, not greenfield features
4. Write invariant tests for existing safety-critical paths
5. Start pipeline from the next new feature

**6.5 Deployment Bridge**
Even minimal guidance: "After landing-verifier reports LANDED, your CI pipeline takes over. Here's how teams connect KEEL to GitHub Actions / GitLab CI." Include a sample workflow file.

**6.6 KEEL Lite (Incremental Adoption Path)**
```
Level 0: Just add CLAUDE.md                          (5 min)
Level 1: Add core-beliefs + domain invariants        (30 min)
Level 2: Add spec-driven testing doctrine            (1 hour)
Level 3: Add feature backlog + handoff files         (2 hours)
Level 4: Full pipeline with all 13 agents            (half day)
```

### Tier 3: Do Later (medium impact, high effort)

**6.7 Platform Abstraction Layer**
Separate the process (spec → test → code → verify, 13 roles, 4 pipeline variants) from the Claude Code implementation. The principles work for any agent platform. `model: opus` in agent frontmatter could become `capability: high` or similar platform-neutral markers.

**6.8 Team Scaling Guide**
- How 2-3 developers share a backlog
- Merge conflict resolution for handoff files
- Parallel pipeline execution on different features
- Code review integration (PR-based gates instead of local spec-reviewer)

**6.9 Async CI/CD Safety Gates**
Move `safety-auditor` and `spec-reviewer` to run asynchronously on GitHub PRs. This enables concurrent feature development and better team scaling. The local pipeline becomes: pre-check → test-writer → implementer → commit → PR → automated review.

**6.10 Structured Handoff Format**
Add YAML frontmatter to each agent section in the handoff file for machine readability:
```yaml
---
agent: implementer
status: GREEN
files_changed: [lib/foo.ex, lib/bar.ex]
tests_passing: 24/24
duration_seconds: 180
---
```

---

## 7. What "KEEL 2.0" Looks Like

Based on the consensus across all three reviewers:

```
KEEL Core (what exists today, refined)
├── Knowledge encoding (CLAUDE.md, ARCHITECTURE.md, specs)
├── Domain invariants + safety-auditor
├── Spec-driven testing (6 layers)
├── Feature pipeline (pre-check → ... → landing-verifier)
└── Garbage collection

KEEL Ops (new extension)
├── CI/CD bridge (GitHub Actions / GitLab CI templates)
├── Deployment verification
├── Monitoring/alerting integration
└── Incident response runbooks

KEEL Scale (new extension)
├── Team workflow (parallel pipelines, PR-based gates)
├── Multi-repo coordination
├── Backlog sync (Jira/GitHub Issues)
└── Structured handoff format

KEEL Adapt (new extension)
├── Brownfield adoption guide
├── Legacy backfill playbook
├── Platform adapters (Codex, Cursor, Windsurf, Gemini)
└── Non-Docker environments
```

---

## 8. Summary

**KEEL is strong where it focuses:** spec-driven development, safety invariants, pipeline discipline, and institutional knowledge encoding. No public competitor matches this rigor.

**KEEL is weak where it overreaches:** claiming "lifecycle" coverage when it stops at git commit, assuming greenfield-only, and being locked to Claude Code + Docker.

**The path forward:** Narrow the positioning now ("agent implementation framework" not "engineering lifecycle"), then modularize into Core + Ops + Scale + Adapt extensions. The strongest immediate improvements are: explicit scope boundaries, brownfield guide, deployment bridge, and incremental adoption path.
