# KEEL Framework Extraction Plan

**Date:** 2026-04-04
**Status:** Draft
**Goal:** Make KEEL the primary artifact of this repo. Repo Man becomes a concrete example.
**Cross-validated by:** Claude Opus 4.6, Codex, Gemini 3.1 Pro (unanimous agreement on approach)

---

## 1. Summary

**Structural inversion:** Promote `keel-kit/` contents to repo root; relocate Repo Man (app + docs) into `examples/repo-man/` as a self-contained, runnable reference project. Dissolve `keel-kit/` entirely.

All three roundtable models independently converged on this same architecture.

---

## 2. Target Directory Tree

```
keel/                                          # KEEL — Knowledge-Encoded Engineering Lifecycle
├── README.md                                  # NEW: GitHub landing page for KEEL framework
├── CLAUDE.md                                  # NEW: Framework-level (describes KEEL itself)
├── ARCHITECTURE.md                            # FROM keel-kit/: Template for new projects
├── Dockerfile                                 # FROM keel-kit/: Template for new projects
├── docker-compose.yml                         # FROM keel-kit/: Template for new projects
├── .gitignore                                 # MERGED: both contexts
│
├── .claude/                                   # FROM keel-kit/.claude/ (promoted to root)
│   ├── settings.json
│   ├── agents/                                # 13 agent definitions
│   │   ├── backend-designer.md
│   │   ├── config-writer.md
│   │   ├── doc-gardener.md
│   │   ├── docker-builder.md
│   │   ├── frontend-designer.md
│   │   ├── implementer.md
│   │   ├── plan-lander.md
│   │   ├── pre-check.md
│   │   ├── researcher.md
│   │   ├── safety-auditor.md
│   │   ├── scaffolder.md
│   │   ├── spec-reviewer.md
│   │   └── test-writer.md
│   ├── skills/                                # 3 skills
│   │   ├── dev-up/SKILL.md
│   │   ├── keel-pipeline/SKILL.md
│   │   └── safety-check/SKILL.md
│   └── hooks/                                 # 2 hooks
│       ├── safety-gate.sh
│       └── doc-gate.sh
│
├── docs/                                      # Framework-level documentation
│   ├── north-star.md                          # FROM keel-kit/: Template
│   ├── process/                               # FROM keel-kit/docs/process/
│   │   ├── THE-KEEL-PROCESS.md
│   │   ├── QUICK-START.md
│   │   ├── GLOSSARY.md
│   │   ├── AUTONOMY-PROGRESSION.md
│   │   ├── ANTI-PATTERNS.md
│   │   └── OPENAI-FOUNDATIONS.md
│   ├── product-specs/
│   │   └── _TEMPLATE.md                       # FROM keel-kit/
│   ├── design-docs/
│   │   ├── core-beliefs.md                    # FROM keel-kit/: Template
│   │   ├── ui-design.md                       # FROM keel-kit/: Template
│   │   └── index.md
│   ├── exec-plans/
│   │   ├── active/
│   │   │   ├── feature-backlog.md             # FROM keel-kit/: Template
│   │   │   └── handoffs/
│   │   │       └── _TEMPLATE.md
│   │   ├── completed/
│   │   │   └── handoffs/.gitkeep
│   │   └── tech-debt-tracker.md               # FROM keel-kit/: Template
│   └── references/
│       ├── README.md
│       └── harness-engineering-article/        # FROM root docs/ (KEEL's origin story)
│
├── examples/
│   ├── domain-invariants/                     # FROM keel-kit/examples/
│   │   ├── git-operations.md
│   │   ├── rest-api.md
│   │   ├── data-pipeline.md
│   │   └── financial.md
│   └── repo-man/                              # Complete working example
│       ├── README.md                          # MERGED: keel-kit case study + repo_man README
│       ├── CLAUDE.md                          # FROM root (filled template)
│       ├── ARCHITECTURE.md                    # FROM root (filled)
│       ├── Dockerfile                         # FROM root (Elixir-specific)
│       ├── docker-compose.yml                 # FROM root (paths adjusted)
│       ├── repo_man/                          # FROM root repo_man/ (entire Phoenix app)
│       │   ├── lib/...
│       │   ├── test/...
│       │   ├── config/...
│       │   ├── assets/...
│       │   ├── priv/...
│       │   ├── mix.exs
│       │   ├── mix.lock
│       │   ├── .formatter.exs
│       │   ├── .gitignore
│       │   ├── AGENTS.md
│       │   └── README.md
│       ├── scripts/
│       │   └── terminal-opener.py             # FROM root scripts/
│       └── docs/                              # FROM root docs/ (Repo Man-specific)
│           ├── north-star.md
│           ├── product-specs/
│           │   ├── index.md
│           │   └── mvp-spec.md
│           ├── design-docs/
│           │   ├── core-beliefs.md
│           │   ├── ui-design.md
│           │   ├── index.md
│           │   ├── 2026-03-16-monitoring-wall-sizing-design.md
│           │   ├── 2026-03-31-dashboard-extraction-design.md
│           │   └── 2026-03-31-refresh-control-design.md
│           ├── exec-plans/
│           │   ├── active/
│           │   │   ├── feature-backlog.md
│           │   │   └── moes-implementation-queue.md
│           │   ├── completed/
│           │   │   ├── handoffs/F01..F31.md
│           │   │   ├── handoffs/dashboard-extraction.md
│           │   │   ├── 2026-03-16-monitoring-wall-sizing.md
│           │   │   └── 2026-03-31-refresh-control.md
│           │   └── tech-debt-tracker.md
│           ├── references/
│           │   └── brainstorm/*.html
│           └── repo-context-report.md
│
├── template/                                  # Starter files for new projects
│   ├── CLAUDE.md                              # FROM keel-kit/ (with placeholders)
│   ├── ARCHITECTURE.md                        # FROM keel-kit/ (with placeholders)
│   ├── Dockerfile                             # FROM keel-kit/ (with placeholders)
│   ├── docker-compose.yml                     # FROM keel-kit/ (with placeholders)
│   └── docs/
│       ├── north-star.md
│       ├── product-specs/_TEMPLATE.md
│       ├── design-docs/
│       │   ├── core-beliefs.md
│       │   ├── index.md
│       │   └── ui-design.md
│       ├── exec-plans/
│       │   ├── active/
│       │   │   ├── feature-backlog.md
│       │   │   └── handoffs/_TEMPLATE.md
│       │   ├── completed/handoffs/.gitkeep
│       │   └── tech-debt-tracker.md
│       └── references/README.md
│
└── scripts/
    └── bootstrap.sh                           # FROM keel-kit/ (updated paths, excludes examples/)
```

---

## 3. Execution Phases

### Phase 1: Encapsulate Repo Man (git mv operations)

**Dependency:** None
**Risk:** Low — all git mv, no content changes
**Milestone:** `examples/repo-man/` contains a fully isolated Repo Man

**Steps:**

1.1. Create target directories:
```bash
mkdir -p examples/repo-man/scripts
mkdir -p examples/repo-man/docs
```

1.2. Move Repo Man application source:
```bash
git mv repo_man examples/repo-man/repo_man
```

1.3. Move Repo Man infrastructure files:
```bash
git mv CLAUDE.md examples/repo-man/CLAUDE.md
git mv ARCHITECTURE.md examples/repo-man/ARCHITECTURE.md
git mv Dockerfile examples/repo-man/Dockerfile
git mv docker-compose.yml examples/repo-man/docker-compose.yml
```

1.4. Move Repo Man scripts:
```bash
git mv scripts/terminal-opener.py examples/repo-man/scripts/terminal-opener.py
```

1.5. Move Repo Man docs (entire tree except harness-engineering-article):
```bash
git mv docs/north-star.md examples/repo-man/docs/north-star.md
git mv docs/product-specs examples/repo-man/docs/product-specs
git mv docs/design-docs examples/repo-man/docs/design-docs
git mv docs/exec-plans examples/repo-man/docs/exec-plans
git mv docs/references/brainstorm examples/repo-man/docs/references/brainstorm
git mv docs/repo-context-report.md examples/repo-man/docs/repo-context-report.md
```

1.6. Move harness-engineering-article to framework references:
```bash
mkdir -p docs/references
git mv docs/harness-engineering-article docs/references/harness-engineering-article
```

1.7. Clean up empty directories left behind.

---

### Phase 2: Promote KEEL Framework to Root

**Dependency:** Phase 1 complete
**Risk:** Low — all git mv from keel-kit/ to root
**Milestone:** Root presents as KEEL framework

**Steps:**

2.1. Promote .claude/ directory (agents, skills, hooks):
```bash
git mv keel-kit/.claude .claude
```

2.2. Promote framework process docs:
```bash
git mv keel-kit/docs/process docs/process
```

2.3. Promote framework template docs:
```bash
git mv keel-kit/docs/north-star.md docs/north-star.md
git mv keel-kit/docs/product-specs docs/product-specs
git mv keel-kit/docs/design-docs docs/design-docs
git mv keel-kit/docs/exec-plans docs/exec-plans
git mv keel-kit/docs/references/README.md docs/references/README.md
```

2.4. Promote framework root files:
```bash
git mv keel-kit/ARCHITECTURE.md ARCHITECTURE.md
git mv keel-kit/Dockerfile Dockerfile
git mv keel-kit/docker-compose.yml docker-compose.yml
```

2.5. Promote examples:
```bash
git mv keel-kit/examples/domain-invariants examples/domain-invariants
```

2.6. Move keel-kit/examples/repo-man/README.md (merge with existing):
```bash
# This file becomes part of examples/repo-man/README.md (content merge in Phase 4)
git mv keel-kit/examples/repo-man/README.md examples/repo-man/CASE-STUDY.md
```

2.7. Promote bootstrap script:
```bash
git mv keel-kit/scripts/bootstrap.sh scripts/bootstrap.sh
```

2.8. Create template/ directory from remaining keel-kit files:
```bash
mkdir -p template/docs
git mv keel-kit/CLAUDE.md template/CLAUDE.md
# Note: keel-kit/ARCHITECTURE.md, Dockerfile, docker-compose.yml already moved to root
# Copy the root versions to template/ (they ARE the templates)
cp ARCHITECTURE.md template/ARCHITECTURE.md
cp Dockerfile template/Dockerfile
cp docker-compose.yml template/docker-compose.yml
cp -r docs/north-star.md template/docs/north-star.md
cp -r docs/product-specs template/docs/product-specs
cp -r docs/design-docs template/docs/design-docs
cp -r docs/exec-plans template/docs/exec-plans
cp -r docs/references/README.md template/docs/references/README.md
```

2.9. Remove empty keel-kit/:
```bash
rm -rf keel-kit/
```

---

### Phase 3: Write New Framework-Level Files

**Dependency:** Phase 2 complete
**Risk:** Medium — content creation, requires review
**Milestone:** Root CLAUDE.md and README.md describe KEEL as a framework

**Steps:**

3.1. **Write root README.md** — GitHub landing page for KEEL:
- What KEEL is (1 paragraph)
- Origin (OpenAI harness engineering adaptation)
- Quick start (clone → bootstrap.sh → fill docs → build features)
- Key concepts (knowledge boundary, progressive disclosure, spec-driven testing, domain invariants)
- Framework components table (agents, skills, hooks, process docs, templates)
- Repo Man case study link
- Link to docs/process/THE-KEEL-PROCESS.md for full guide

3.2. **Write root CLAUDE.md** — Framework-level instructions:
- What this repo is (KEEL framework)
- How to use it (bootstrap.sh for new projects, examples/ for reference)
- Key principles (docs drive code, repo is truth, coding comes last)
- Directory map (docs/, .claude/, examples/, template/, scripts/)
- Links to process docs, quick-start, glossary
- Development section (how to modify the framework itself)

3.3. **Write root ARCHITECTURE.md** — Already exists from keel-kit (template). Consider adding a "Framework Architecture" preface section explaining the relationship between root (framework), template/ (starter files), and examples/ (reference implementations).

---

### Phase 4: Adjust Paths and Fix References

**Dependency:** Phase 3 complete
**Risk:** Medium — must verify all links work
**Milestone:** No broken cross-references, docker compose works

**Steps:**

4.1. **Fix examples/repo-man/docker-compose.yml paths:**
- Volume mount `./repo_man:/app` stays as-is (relative to docker-compose location)
- Verify `REPOMAN_REPOS_PATH` and other env vars still work
- Build context may need adjustment if Dockerfile is in same dir

4.2. **Fix examples/repo-man/CLAUDE.md internal references:**
- Update relative paths: `docs/north-star.md` → still valid (within example)
- Update `ARCHITECTURE.md` reference → still valid
- Remove references to `keel-kit/` if any exist
- Update `docs/exec-plans/` paths

4.3. **Merge README files for examples/repo-man/:**
- Combine keel-kit case study (CASE-STUDY.md) with repo_man/README.md
- Add "Running the Example" section: `cd examples/repo-man && docker compose up`

4.4. **Update bootstrap.sh:**
- Update paths from `keel-kit/` references to root/template/ references
- Add `-not -path './examples/*'` to find commands to protect example files
- Update sed targets for new directory structure
- Test: `./scripts/bootstrap.sh` should not modify anything under examples/

4.5. **Update .claude/settings.json hook paths:**
- Verify hook script paths (.claude/hooks/*.sh) resolve correctly from root

4.6. **Fix .gitignore:**
- Merge root .gitignore with repo_man/.gitignore concerns
- Ensure examples/repo-man/_build, deps, etc. are covered

4.7. **Audit all markdown cross-references:**
- Run: `grep -r '\.\./\|keel-kit/' docs/ examples/ .claude/ --include='*.md'`
- Fix any broken relative links
- Verify spec_ref paths in handoff files still resolve

---

### Phase 5: Validation

**Dependency:** Phase 4 complete
**Risk:** Low — read-only verification
**Milestone:** Everything works

**Steps:**

5.1. **Verify Repo Man still runs:**
```bash
cd examples/repo-man
docker compose build
docker compose run --rm app mix test
docker compose run --rm app mix test --include integration
docker compose up  # verify localhost:4000 works
```

5.2. **Verify bootstrap.sh works:**
```bash
# In a temp directory, test the bootstrap flow
mkdir /tmp/test-keel-project
cp -r scripts/bootstrap.sh /tmp/test-keel-project/
cp -r template/ /tmp/test-keel-project/
# Run bootstrap, verify placeholder replacement
```

5.3. **Verify no broken links:**
```bash
grep -rn 'keel-kit/' . --include='*.md' | grep -v '.git/'
grep -rn '\.\./keel-kit' . --include='*.md'
# Both should return empty
```

5.4. **Verify .claude/ agents load:**
- Start Claude Code in repo root
- Confirm agents, skills, and hooks are discovered

5.5. **Run doc-gardener equivalent check:**
- CLAUDE.md references valid paths
- ARCHITECTURE.md references valid paths
- Process docs have no dead links

---

### Phase 6: Commit and Document

**Dependency:** Phase 5 all green
**Risk:** None
**Milestone:** Clean commit with clear message

**Steps:**

6.1. Stage all changes:
```bash
git add -A
```

6.2. Commit:
```
restructure: promote KEEL framework to repo root, move Repo Man to examples/

KEEL (Knowledge-Encoded Engineering Lifecycle) is now the primary artifact
of this repository. Repo Man, the Phoenix LiveView git dashboard, is
preserved as a complete working example under examples/repo-man/.

Changes:
- Promoted keel-kit/.claude/ (13 agents, 3 skills, 2 hooks) to root
- Promoted keel-kit/docs/process/ (6 process guides) to root
- Moved repo_man/, its docs, and infra to examples/repo-man/
- Created template/ for new project bootstrapping
- New root README.md and CLAUDE.md describing KEEL framework
- Updated bootstrap.sh to exclude examples/ from placeholder replacement
- All 250+ Repo Man tests still pass
```

---

## 4. Key Decisions

| Decision | Rationale |
|-|-|
| Dissolve keel-kit/ entirely | Having both keel-kit/ and root creates identity confusion. Root IS the framework. |
| Keep template/ separate from root docs/ | Root docs/ serves as framework reference. template/ is what bootstrap.sh copies for new projects. They start identical but may diverge. |
| Move harness-engineering-article to framework level | It's KEEL's intellectual origin, not Repo Man-specific. |
| Keep repo_man/ subfolder inside examples/repo-man/ | Preserves Phoenix project structure. Avoids `examples/repo-man/lib/` which loses the "this is a Phoenix app" signal. |
| No package registry or git submodules | Clone → bootstrap.sh is the distribution model. Simple, predictable, no dependency management. |

---

## 5. Risks and Mitigations

| Risk | Impact | Mitigation |
|-|-|-|
| bootstrap.sh corrupts example files | High | Add `-not -path './examples/*'` exclusion |
| Broken relative links in moved docs | Medium | Phase 4 link audit + grep verification |
| Docker compose path breakage | Medium | Phase 5 build/test verification |
| Git history fragmentation | Low | git mv preserves blame; `--follow` for log |
| Root/example CLAUDE.md confusion | Low | Root describes KEEL; example describes Repo Man |
| .claude/ settings not discovered | Medium | Phase 5 verification of agent/skill/hook loading |

---

## 6. File Count Summary

| Source | Files Moving | Destination |
|-|-|-|
| Root → examples/repo-man/ | ~200 | Repo Man app, docs, scripts, infra |
| keel-kit/ → root | ~50 | .claude/, docs/process/, scripts/, root files |
| keel-kit/ → template/ | ~20 | Placeholder docs and config templates |
| keel-kit/ → examples/ | ~5 | Domain invariant examples |
| NEW files | ~3 | README.md, CLAUDE.md, possibly ARCHITECTURE.md preface |
| DELETED | ~0 | keel-kit/ directory itself (after extraction) |

---

## 7. Estimated Effort

| Phase | Effort | Notes |
|-|-|-|
| Phase 1: Encapsulate Repo Man | ~30 git mv commands | Mechanical, low risk |
| Phase 2: Promote KEEL | ~20 git mv + cp commands | Mechanical, low risk |
| Phase 3: Write new files | ~2 files (README, CLAUDE.md) | Content creation, needs review |
| Phase 4: Fix references | ~15 file edits | Grep-driven, systematic |
| Phase 5: Validation | ~10 commands | Build, test, link audit |
| Phase 6: Commit | 1 commit | Clean single commit |

Total: ~275 file operations across 6 phases. Executable in a single session.
