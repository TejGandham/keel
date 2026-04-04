#!/bin/bash
# KEEL Installer — Add KEEL to any project directory.
#
# Usage (from your project root):
#   curl -fsSL https://raw.githubusercontent.com/<owner>/keel/main/scripts/install.sh | bash
#   OR
#   /path/to/keel/scripts/install.sh
#
# What it does:
#   1. Copies .claude/agents/, .claude/skills/, .claude/hooks/ into your project
#   2. Creates docs/ structure from template
#   3. Creates CLAUDE.md and ARCHITECTURE.md from template
#   4. Creates Dockerfile and docker-compose.yml from template
#   5. Replaces [PROJECT_NAME], [STACK], [DESCRIPTION] placeholders
#   6. Does NOT touch existing files — skips if already present
#
# Your code stays yours. KEEL just adds the scaffolding.

set -e

# --- Resolve KEEL source ---
# If run from a cloned KEEL repo, use that. Otherwise, download.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KEEL_ROOT="$(dirname "$SCRIPT_DIR")"

if [ -f "$KEEL_ROOT/CLAUDE.md" ] && [ -d "$KEEL_ROOT/.claude/agents" ] && [ -d "$KEEL_ROOT/template" ]; then
  KEEL_SRC="$KEEL_ROOT"
  echo "Using local KEEL source: $KEEL_SRC"
else
  # Download to temp dir
  KEEL_SRC=$(mktemp -d)
  trap "rm -rf $KEEL_SRC" EXIT
  echo "Downloading KEEL..."
  git clone --depth 1 --quiet https://github.com/<owner>/keel.git "$KEEL_SRC"
  echo "Downloaded."
fi

PROJECT_DIR="$(pwd)"
echo ""
echo "================================================"
echo "  KEEL — Knowledge-Encoded Engineering Lifecycle"
echo "  Installing into: $PROJECT_DIR"
echo "================================================"
echo ""

# --- Gather project details ---
read -p "Project name (e.g., my-awesome-app): " PROJECT_NAME
if [ -z "$PROJECT_NAME" ]; then
  echo "Error: Project name is required."
  exit 1
fi

read -p "Tech stack (e.g., Elixir/Phoenix, Node/Next.js, Python/Django): " STACK
if [ -z "$STACK" ]; then
  echo "Error: Stack is required."
  exit 1
fi

read -p "One-line description: " DESCRIPTION
if [ -z "$DESCRIPTION" ]; then
  DESCRIPTION="A $STACK project built with the KEEL process."
fi

echo ""
echo "Project: $PROJECT_NAME"
echo "Stack:   $STACK"
echo "Desc:    $DESCRIPTION"
echo "Target:  $PROJECT_DIR"
echo ""
read -p "Proceed? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
  echo "Aborted."
  exit 0
fi

# --- Cross-platform sed ---
sedi() {
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}
escape_sed() { printf '%s\n' "$1" | sed 's/[&/\]/\\&/g'; }
SAFE_NAME=$(escape_sed "$PROJECT_NAME")
SAFE_STACK=$(escape_sed "$STACK")
SAFE_DESC=$(escape_sed "$DESCRIPTION")

# --- Copy agents, skills, hooks ---
echo ""
echo "Installing KEEL agents and skills..."

mkdir -p "$PROJECT_DIR/.claude"

if [ -d "$PROJECT_DIR/.claude/agents" ]; then
  echo "  .claude/agents/ already exists — skipping (won't overwrite your customizations)"
else
  cp -r "$KEEL_SRC/.claude/agents" "$PROJECT_DIR/.claude/agents"
  echo "  .claude/agents/ — 14 agent definitions installed"
fi

if [ -d "$PROJECT_DIR/.claude/skills" ]; then
  echo "  .claude/skills/ already exists — skipping"
else
  # Copy only KEEL skills, not third-party ones
  mkdir -p "$PROJECT_DIR/.claude/skills"
  for skill in keel-pipeline keel-adopt safety-check; do
    if [ -d "$KEEL_SRC/.claude/skills/$skill" ]; then
      cp -r "$KEEL_SRC/.claude/skills/$skill" "$PROJECT_DIR/.claude/skills/$skill"
    fi
  done
  echo "  .claude/skills/ — pipeline, adopt, safety-check installed"
fi

if [ -d "$PROJECT_DIR/.claude/hooks" ] || [ -d "$KEEL_SRC/.claude/hooks" ]; then
  if [ -d "$KEEL_SRC/.claude/hooks" ] && [ ! -d "$PROJECT_DIR/.claude/hooks" ]; then
    cp -r "$KEEL_SRC/.claude/hooks" "$PROJECT_DIR/.claude/hooks"
    echo "  .claude/hooks/ — safety-gate, doc-gate installed"
  else
    echo "  .claude/hooks/ already exists — skipping"
  fi
fi

# --- Copy template docs ---
echo ""
echo "Installing doc structure..."

copy_if_missing() {
  local src="$1" dst="$2"
  if [ -e "$dst" ]; then
    echo "  $(basename "$dst") already exists — skipping"
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo "  $(basename "$dst") — created"
  fi
}

# Root files
copy_if_missing "$KEEL_SRC/template/CLAUDE.md" "$PROJECT_DIR/CLAUDE.md"
copy_if_missing "$KEEL_SRC/template/ARCHITECTURE.md" "$PROJECT_DIR/ARCHITECTURE.md"
copy_if_missing "$KEEL_SRC/template/Dockerfile" "$PROJECT_DIR/Dockerfile"
copy_if_missing "$KEEL_SRC/template/docker-compose.yml" "$PROJECT_DIR/docker-compose.yml"

# Docs structure
for f in $(cd "$KEEL_SRC/template" && find docs -type f 2>/dev/null); do
  copy_if_missing "$KEEL_SRC/template/$f" "$PROJECT_DIR/$f"
done

# --- Replace placeholders ---
echo ""
echo "Replacing placeholders..."

find "$PROJECT_DIR" -type f \
  -not -path '*/.git/*' \
  -not -path '*/node_modules/*' \
  -not -path '*/vendor/*' \
  -not -name '*.webp' -not -name '*.png' -not -name '*.jpg' -not -name '*.svg' \
  -newer "$PROJECT_DIR/.claude/agents/pre-check.md" \
  | while read -r file; do
    if file "$file" | grep -q text; then
      sedi "s/\[PROJECT_NAME\]/$SAFE_NAME/g" "$file" 2>/dev/null || true
      sedi "s/\[STACK\]/$SAFE_STACK/g" "$file" 2>/dev/null || true
      sedi "s/\[DESCRIPTION\]/$SAFE_DESC/g" "$file" 2>/dev/null || true
    fi
  done

# Clean instruction comments from new files
find "$PROJECT_DIR" -type f -name '*.md' \
  -not -path '*/.git/*' \
  -newer "$PROJECT_DIR/.claude/agents/pre-check.md" \
  | while read -r file; do
    sedi '/<!-- DELETE AFTER FILLING/,/-->/d' "$file" 2>/dev/null || true
  done

echo "Done."

# --- Copy process docs as reference (read-only) ---
echo ""
echo "Installing process reference docs..."
mkdir -p "$PROJECT_DIR/docs/process"
for doc in THE-KEEL-PROCESS.md QUICK-START.md BROWNFIELD.md GLOSSARY.md \
           ANTI-PATTERNS.md FAILURE-PLAYBOOK.md; do
  copy_if_missing "$KEEL_SRC/docs/process/$doc" "$PROJECT_DIR/docs/process/$doc"
done

echo ""
echo "================================================"
echo "  KEEL installed into $PROJECT_DIR"
echo ""
echo "  What was added:"
echo "    .claude/agents/    14 agent definitions"
echo "    .claude/skills/    3 skills (pipeline, adopt, safety-check)"
echo "    docs/              Spec structure, handoff templates, process guides"
echo "    CLAUDE.md          Project entry point (customize this first)"
echo "    ARCHITECTURE.md    Module map (fill in as you build)"
echo ""
echo "  Next steps:"
echo "    1. Open CLAUDE.md — fill in the <!-- CUSTOMIZE --> sections"
echo "    2. Open docs/north-star.md — define your vision"
echo "    3. Write your first product spec in docs/product-specs/"
echo "    4. Fill in domain invariants in .claude/agents/safety-auditor.md"
echo "    5. Run: /keel-pipeline my-feature docs/product-specs/my-spec.md"
echo ""
echo "  Process reference: docs/process/QUICK-START.md"
echo "================================================"
