#!/bin/bash
# KEEL Uninstall — Remove KEEL artifacts from your project.
#
# ONLY removes files installed by KEEL. Never touches your application
# code, git history, or files you created yourself.
#
# Usage (from your project root):
#   /path/to/keel/scripts/uninstall.sh

set -e

PROJECT_DIR="$(pwd)"

echo "================================================"
echo "  KEEL — Uninstall"
echo "  Project: $PROJECT_DIR"
echo "================================================"
echo ""

# --- Define KEEL agents (exact filenames) ---
KEEL_AGENTS=(
  pre-check.md arch-advisor.md researcher.md
  backend-designer.md frontend-designer.md
  test-writer.md implementer.md
  spec-reviewer.md safety-auditor.md
  landing-verifier.md doc-gardener.md
  docker-builder.md scaffolder.md config-writer.md
)

KEEL_SKILLS=(keel-pipeline keel-adopt safety-check)
KEEL_HOOKS=(safety-gate.sh doc-gate.sh)
KEEL_PROCESS_DOCS=(
  THE-KEEL-PROCESS.md QUICK-START.md BROWNFIELD.md
  GLOSSARY.md ANTI-PATTERNS.md FAILURE-PLAYBOOK.md
)

# --- Count what will be removed ---
agent_count=0
for a in "${KEEL_AGENTS[@]}"; do
  [ -f ".claude/agents/$a" ] && agent_count=$((agent_count + 1))
done

skill_count=0
for s in "${KEEL_SKILLS[@]}"; do
  [ -d ".claude/skills/$s" ] && skill_count=$((skill_count + 1))
done

hook_count=0
for h in "${KEEL_HOOKS[@]}"; do
  [ -f ".claude/hooks/$h" ] && hook_count=$((hook_count + 1))
done

doc_count=0
for d in "${KEEL_PROCESS_DOCS[@]}"; do
  [ -f "docs/process/$d" ] && doc_count=$((doc_count + 1))
done

if [ $agent_count -eq 0 ] && [ $skill_count -eq 0 ] && [ $hook_count -eq 0 ] && [ $doc_count -eq 0 ]; then
  echo "No KEEL artifacts found in $PROJECT_DIR. Nothing to remove."
  exit 0
fi

echo "Found KEEL artifacts:"
[ $agent_count -gt 0 ] && echo "  $agent_count agents in .claude/agents/"
[ $skill_count -gt 0 ] && echo "  $skill_count skills in .claude/skills/"
[ $hook_count -gt 0 ]  && echo "  $hook_count hooks in .claude/hooks/"
[ $doc_count -gt 0 ]   && echo "  $doc_count process docs in docs/process/"
echo ""
echo "This will NOT touch:"
echo "  - Your application code"
echo "  - Your git history"
echo "  - CLAUDE.md, ARCHITECTURE.md (your project docs)"
echo "  - docs/product-specs/, docs/exec-plans/ (your content)"
echo "  - Dockerfile, docker-compose.yml (your config)"
echo ""
read -p "Remove KEEL artifacts? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
  echo "Aborted."
  exit 0
fi

# --- Remove agents ---
for a in "${KEEL_AGENTS[@]}"; do
  if [ -f ".claude/agents/$a" ]; then
    rm -f ".claude/agents/$a"
    echo "  Removed .claude/agents/$a"
  fi
done

# --- Remove skills ---
for s in "${KEEL_SKILLS[@]}"; do
  if [ -d ".claude/skills/$s" ]; then
    rm -rf ".claude/skills/$s"
    echo "  Removed .claude/skills/$s/"
  fi
done

# --- Remove hooks ---
for h in "${KEEL_HOOKS[@]}"; do
  if [ -f ".claude/hooks/$h" ]; then
    rm -f ".claude/hooks/$h"
    echo "  Removed .claude/hooks/$h"
  fi
done

# --- Remove process docs ---
for d in "${KEEL_PROCESS_DOCS[@]}"; do
  if [ -f "docs/process/$d" ]; then
    rm -f "docs/process/$d"
    echo "  Removed docs/process/$d"
  fi
done

# --- Remove bundled uninstall script ---
if [ -f ".claude/keel-uninstall.sh" ]; then
  rm -f ".claude/keel-uninstall.sh"
  echo "  Removed .claude/keel-uninstall.sh"
fi

# --- Clean up empty directories (only if empty) ---
rmdir .claude/agents 2>/dev/null && echo "  Removed empty .claude/agents/" || true
rmdir .claude/skills 2>/dev/null && echo "  Removed empty .claude/skills/" || true
rmdir .claude/hooks 2>/dev/null  && echo "  Removed empty .claude/hooks/" || true
rmdir .claude 2>/dev/null        && echo "  Removed empty .claude/" || true
rmdir docs/process 2>/dev/null   && echo "  Removed empty docs/process/" || true

echo ""
echo "================================================"
echo "  KEEL artifacts removed."
echo ""
echo "  Kept (if present):"
echo "    CLAUDE.md, ARCHITECTURE.md"
echo "    docs/product-specs/, docs/exec-plans/"
echo "    docs/design-docs/, docs/north-star.md"
echo "    Dockerfile, docker-compose.yml"
echo "    All your application code"
echo "================================================"
