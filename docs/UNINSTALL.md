# Uninstalling KEEL

Remove all KEEL artifacts from your project. This only deletes files that
KEEL installed — your application code, git history, and any files you
created yourself are untouched.

## Quick Uninstall

```bash
cd your-project
# Review what will be deleted first
cat /path/to/keel/docs/UNINSTALL.md  # this file

# Then run:
/path/to/keel/scripts/uninstall.sh
# OR manually follow the steps below
```

## What Gets Removed

### KEEL agents (safe to delete — these are KEEL framework files)

```bash
rm -f .claude/agents/pre-check.md
rm -f .claude/agents/oracle.md
rm -f .claude/agents/researcher.md
rm -f .claude/agents/backend-designer.md
rm -f .claude/agents/frontend-designer.md
rm -f .claude/agents/test-writer.md
rm -f .claude/agents/implementer.md
rm -f .claude/agents/spec-reviewer.md
rm -f .claude/agents/safety-auditor.md
rm -f .claude/agents/plan-lander.md
rm -f .claude/agents/doc-gardener.md
rm -f .claude/agents/docker-builder.md
rm -f .claude/agents/scaffolder.md
rm -f .claude/agents/config-writer.md
```

If `.claude/agents/` is now empty, remove it:
```bash
rmdir .claude/agents 2>/dev/null
```

### KEEL skills (safe to delete)

```bash
rm -rf .claude/skills/keel-pipeline
rm -rf .claude/skills/keel-adopt
rm -rf .claude/skills/safety-check
```

If `.claude/skills/` is now empty, remove it:
```bash
rmdir .claude/skills 2>/dev/null
```

### KEEL hooks (safe to delete)

```bash
rm -f .claude/hooks/safety-gate.sh
rm -f .claude/hooks/doc-gate.sh
```

If `.claude/hooks/` is now empty, remove it:
```bash
rmdir .claude/hooks 2>/dev/null
```

If `.claude/` is now empty, remove it:
```bash
rmdir .claude 2>/dev/null
```

### KEEL process docs (safe to delete — reference material, not project-specific)

```bash
rm -f docs/process/THE-KEEL-PROCESS.md
rm -f docs/process/QUICK-START.md
rm -f docs/process/BROWNFIELD.md
rm -f docs/process/GLOSSARY.md
rm -f docs/process/ANTI-PATTERNS.md
rm -f docs/process/FAILURE-PLAYBOOK.md
rmdir docs/process 2>/dev/null
```

### KEEL templates (safe to delete IF you haven't customized them)

These are starter templates. If you filled them in with your project's
content, they are now YOUR files — keep them.

Check before deleting:
```bash
# If these still have [PROJECT_NAME] or <!-- CUSTOMIZE --> placeholders,
# they were never filled in and can be deleted safely.
grep -l 'PROJECT_NAME\|<!-- CUSTOMIZE' \
  docs/north-star.md \
  docs/design-docs/core-beliefs.md \
  docs/design-docs/ui-design.md \
  docs/design-docs/index.md \
  docs/product-specs/_TEMPLATE.md \
  docs/exec-plans/active/feature-backlog.md \
  docs/exec-plans/active/handoffs/_TEMPLATE.md \
  docs/exec-plans/tech-debt-tracker.md \
  docs/references/README.md \
  2>/dev/null
```

Files that still have placeholders were never used — safe to delete.
Files without placeholders contain your project's content — keep them.

## What is NOT Removed

The uninstall does NOT touch:

- **Your application code** — anything outside `.claude/` and `docs/`
- **Your git history** — commits, branches, tags
- **CLAUDE.md** — if you filled this in, it's your project doc now
- **ARCHITECTURE.md** — if you filled this in, it's your architecture doc
- **Dockerfile / docker-compose.yml** — if you customized these, they're yours
- **docs/product-specs/** (your specs, not KEEL's)
- **docs/exec-plans/active/handoffs/F*.md** (your feature handoffs)
- **docs/exec-plans/completed/** (your completed handoffs)
- **Any file you created yourself**

## Partial Uninstall

If you want to keep some KEEL components:

**Keep agents, remove process:**
```bash
rm -rf .claude/skills/keel-pipeline .claude/skills/keel-adopt
rm -rf docs/process
```

**Keep pipeline, remove safety:**
```bash
rm -f .claude/agents/safety-auditor.md
rm -rf .claude/skills/safety-check
rm -f .claude/hooks/safety-gate.sh
```

**Keep docs, remove agents:**
```bash
rm -rf .claude/agents .claude/skills .claude/hooks
```
