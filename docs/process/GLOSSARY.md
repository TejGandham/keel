# KEEL Glossary

**KEEL** — Knowledge-Encoded Engineering Lifecycle. A structured process for Claude-driven software development where humans steer and agents execute through specialized pipelines. Adapted from OpenAI's harness engineering.

**Knowledge-Encoded** — The "K" in KEEL. The principle that everything agents need must be committed as versioned artifacts in the repository. If it's not in the repo, it doesn't exist.

**Knowledge Boundary** — The limit of what an agent can see. Anything outside the repo (Slack, Google Docs, verbal decisions, tacit expertise) is invisible. The only way to make it visible: encode as markdown in the repo.

**Agent Legibility** — Optimizing documentation and code for agent comprehension rather than human aesthetics. Specs must be unambiguous enough for agents to execute without clarification.

**Progressive Disclosure** — Information architecture where agents start with a small, stable entry point (CLAUDE.md ~80 lines) and are taught where to look next, rather than being overwhelmed with everything up front.

**North Star** — The vision document (`docs/north-star.md`) that defines where the project is heading, what principles govern decisions, and how the process evolves through growth stages. Where taste is encoded before it becomes linters.

**Handoff** — An append-only markdown file (`docs/exec-plans/active/handoffs/F{id}-{feature-name}.md`) that persists context between pipeline agents. Each agent reads upstream context and appends its output. Never rewritten — only appended to.

**Pipeline Variant** — One of four execution paths a feature takes through the agent roster:
- **Bootstrap:** Three separate features, each dispatching one agent then landing-verifier:
  - F01: docker-builder → landing-verifier
  - F02: scaffolder → landing-verifier
  - F03: config-writer → landing-verifier
- **Backend:** pre-check → researcher? → arch-advisor? → backend-designer? → test-writer → implementer → spec-reviewer → safety-auditor? → arch-advisor-verify? → landing-verifier
- **Frontend:** pre-check → researcher? → arch-advisor? → frontend-designer → test-writer → implementer → spec-reviewer → arch-advisor-verify? → landing-verifier
- **Cross-cutting:** pre-check → test-writer → implementer → landing-verifier

**Execution Brief** — The structured output of the pre-check agent. Contains: intent classification, complexity tier, spec reference, dependencies, what to build, new/modified files, acceptance tests, edge cases, risks, constraints for downstream (MUST/MUST NOT), and routing decisions (designer needed? researcher needed? arch-advisor needed?).

**Orchestrator** — The human who steers the KEEL process: kicks off features, reviews agent output, commits landed code, updates the backlog, and archives handoffs. The orchestrator does not write code.

**Invariant** — A non-negotiable rule specific to the project's domain, enforced mechanically. Examples: "never force-pull" (git), "validate all input at boundaries" (API), "all transforms must be idempotent" (data pipeline).

**Golden Principle** — An opinionated, mechanical rule that keeps the codebase legible and consistent for future agent runs. Encoded in the repo and enforced continuously. From OpenAI: "Human taste is captured once, then enforced continuously on every line."

**Garbage Collection** — Periodic sweeps to detect and fix documentation drift. The doc-gardener agent scans for stale content; the orchestrator applies fixes. "Docs that lie are worse than no docs."

**Ralph Wiggum Loop** — Agent-to-agent review pattern where an agent reviews its own changes, requests additional agent reviews, and iterates until all reviewers are satisfied. Named by OpenAI. Enables increasing autonomy without human bottleneck.

**RED → GREEN Flow** — The handoff between test-writer and implementer. Test-writer produces failing tests (RED state). Implementer writes code to pass them (GREEN state). Neither crosses the boundary: test-writer never writes implementation, implementer never modifies tests.

**Lifecycle** — The "L" in KEEL. The full arc: north star → spec → backlog → pipeline → landed feature → garbage collection. Every feature goes through this complete cycle.

**Arch-advisor** — Read-only architecture consultant agent with two invocation modes: CONSULT (Step 1.7, before design) provides architecture guidance for complex features; VERIFY (Step 7.5, before landing) performs independent structural review. Gated by pre-check's complexity classification — only runs for architecture-tier features.

**Intent Classification** — Pre-check's mandatory first step. Categorizes work as refactoring, build, mid-sized, architecture, or research. Determines pipeline routing: which optional agents run, complexity tier, and whether Arch-advisor is needed.

**Complexity Tier** — Pre-check's assessment of feature scope: trivial (skip designer), standard (normal pipeline), complex (all gates), architecture-tier (Arch-advisor consultation + verification). Drives pipeline routing decisions.

**Wisdom Accumulation** — Pattern where agents propagate context downstream through structured Decisions (choices made and why) and Constraints (MUST/MUST NOT for downstream agents) in the handoff file. Prevents agents from repeating upstream mistakes or violating upstream decisions.

**Structured Rejection** — Pattern where gate agents (spec-reviewer, safety-auditor) output a machine-readable `**Verdict:**` field as their first line. The pipeline branches on this verdict. Max 2 spec-review loops, max 3 safety-auditor loops before escalating to human.

**Pragmatic Minimalism** — Arch-advisor's core decision framework: bias toward simplicity, leverage what exists, prioritize developer experience, one clear path, match depth to complexity. Ported from OMA (Oh My OpenAgent).
