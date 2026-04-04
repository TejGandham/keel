# [Feature Name]

<!-- This is a handoff file template. Copy it for each feature:
     docs/exec-plans/active/handoffs/F{id}-{feature-name}.md

     RULES:
     - Append-only. Never rewrite previous sections.
     - Each agent reads all upstream sections, then appends its own.
     - Decision-heavy agents (pre-check, designers, oracle) populate
       ### Decisions and ### Constraints for downstream.
     - Implementer populates ### Decisions only (no constraints — its
       downstream agents are its reviewers).
     - Test-writer and researcher populate ### Decisions optionally.
     - Downstream agents READ upstream Decisions and Constraints FIRST.
     - Move to docs/exec-plans/completed/handoffs/ when feature lands. -->

status: IN-PROGRESS
pipeline: <!-- bootstrap | backend | frontend | cross-cutting -->
spec_ref: <!-- e.g., mvp-spec:4.2 -->

## pre-check
<!-- Execution brief appended here by pre-check agent -->

### Constraints for downstream
<!-- MUST/MUST NOT directives for downstream agents. Max 5 bullets. -->

## researcher
<!-- Research brief appended here (if applicable) -->

### Decisions (optional)
<!-- Key choices made and why. Max 5 bullets. -->

## oracle-consultation
<!-- Architecture guidance appended here by Oracle at Step 1.7 (if applicable) -->

### Constraints for downstream
<!-- Oracle's MUST/MUST NOT directives for designers/implementers. -->

## backend-designer / frontend-designer
<!-- Design brief appended here (if applicable) -->

### Decisions
<!-- Key choices made and why. Max 5 bullets. -->
### Constraints for downstream
<!-- MUST/MUST NOT directives for downstream agents. Max 5 bullets. -->

## test-writer
<!-- Test report appended here -->

### Decisions (optional)
<!-- Key choices made and why. Max 5 bullets. -->

## implementer
<!-- Implementation report appended here -->

### Decisions
<!-- Key choices made and why. Max 5 bullets. -->
<!-- NOTE: Implementer does NOT get "Constraints for downstream" —
     its downstream agents (spec-reviewer, safety-auditor) are its
     REVIEWERS. Constraining reviewers undermines gate integrity. -->

## spec-reviewer
<!-- Conformance report appended here -->
spec-review-attempt: <!-- 1 or 2, set by pipeline orchestrator -->

## safety-auditor
<!-- Audit report appended here (if applicable) -->

## oracle-verification
<!-- Independent structural review appended here by Oracle at Step 7.5 (if applicable) -->

## plan-lander
<!-- Landing report appended here -->
