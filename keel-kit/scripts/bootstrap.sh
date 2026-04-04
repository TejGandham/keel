#!/bin/bash
# KEEL Bootstrap — Interactive setup for a new KEEL project.
# Replaces placeholders and prepares the repo for first use.

set -e

echo "================================================"
echo "  KEEL — Knowledge-Encoded Engineering Lifecycle"
echo "  Bootstrap a new project"
echo "================================================"
echo ""

# Gather project details
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
echo ""
read -p "Proceed? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
  echo "Aborted."
  exit 0
fi

# Cross-platform sed -i (BSD vs GNU)
sedi() {
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

# Escape user input for sed safety (handles /, &, \ in input)
escape_sed() { printf '%s\n' "$1" | sed 's/[&/\]/\\&/g'; }
SAFE_NAME=$(escape_sed "$PROJECT_NAME")
SAFE_STACK=$(escape_sed "$STACK")
SAFE_DESC=$(escape_sed "$DESCRIPTION")

# Replace placeholders in all files
echo ""
echo "Replacing placeholders..."

# Find all text files and replace placeholders
# Excludes .git, binary files, and this script itself
find . -type f \
  -not -path './.git/*' \
  -not -path './scripts/bootstrap.sh' \
  -not -name '*.webp' \
  -not -name '*.png' \
  -not -name '*.jpg' \
  -not -name '*.svg' \
  | while read -r file; do
    if file "$file" | grep -q text; then
      sedi "s/\[PROJECT_NAME\]/$SAFE_NAME/g" "$file" 2>/dev/null || true
      sedi "s/\[STACK\]/$SAFE_STACK/g" "$file" 2>/dev/null || true
      sedi "s/\[DESCRIPTION\]/$SAFE_DESC/g" "$file" 2>/dev/null || true
    fi
  done

echo "Done."

# Remove DELETE AFTER FILLING comments
echo "Cleaning instruction comments..."
find . -type f -name '*.md' \
  -not -path './.git/*' \
  | while read -r file; do
    sedi '/<!-- DELETE AFTER FILLING/,/-->/d' "$file" 2>/dev/null || true
  done

echo "Done."

# Initialize git repo if not already
if [ ! -d .git ]; then
  echo ""
  echo "Initializing git repository..."
  git init
  git add -A
  git commit -m "feat(F00): bootstrap KEEL kit for $PROJECT_NAME"
  echo "Initial commit created."
else
  echo ""
  echo "Git repo already exists. Skipping init."
fi

echo ""
echo "================================================"
echo "  Kitchen is stocked."
echo ""
echo "  Next steps:"
echo "  1. Read docs/process/QUICK-START.md"
echo "  2. Fill in docs/north-star.md"
echo "  3. Fill in CLAUDE.md"
echo "  4. Write your product spec"
echo "  5. Start building!"
echo "================================================"
