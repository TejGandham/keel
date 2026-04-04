#!/usr/bin/env python3
"""KEEL Bootstrap — Interactive setup for a new KEEL project.

Legacy script for in-place placeholder replacement. Replaces
[PROJECT_NAME], [STACK], [DESCRIPTION] in all text files and
removes DELETE AFTER FILLING comments.

For new projects, prefer scripts/install.py instead.

Usage:
    python3 scripts/bootstrap.py
"""

import re
import subprocess
import sys
from pathlib import Path


def replace_placeholders(project_dir: Path, name: str, stack: str, desc: str):
    """Replace placeholders in all text files."""
    skip_dirs = {".git", "examples", "node_modules", "vendor", "__pycache__"}
    skip_exts = {".webp", ".png", ".jpg", ".jpeg", ".svg", ".ico", ".gif"}
    skip_files = {"bootstrap.py", "bootstrap.sh"}

    for path in sorted(project_dir.rglob("*")):
        if not path.is_file():
            continue
        if any(part in skip_dirs for part in path.parts):
            continue
        if path.suffix.lower() in skip_exts:
            continue
        if path.name in skip_files:
            continue

        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, PermissionError):
            continue

        updated = text.replace("[PROJECT_NAME]", name).replace("[STACK]", stack).replace("[DESCRIPTION]", desc)
        if updated != text:
            path.write_text(updated, encoding="utf-8")

    # Clean DELETE AFTER FILLING comments
    for path in sorted(project_dir.rglob("*.md")):
        if any(part in skip_dirs for part in path.parts):
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, PermissionError):
            continue
        cleaned = re.sub(r"<!-- DELETE AFTER FILLING.*?-->", "", text, flags=re.DOTALL)
        if cleaned != text:
            path.write_text(cleaned, encoding="utf-8")


def main():
    print("=" * 48)
    print("  KEEL — Knowledge-Encoded Engineering Lifecycle")
    print("  Bootstrap a new project")
    print("=" * 48)
    print()

    project_name = input("Project name (e.g., my-awesome-app): ").strip()
    if not project_name:
        print("Error: Project name is required.")
        sys.exit(1)

    stack = input("Tech stack (e.g., Elixir/Phoenix, Node/Next.js, Python/Django): ").strip()
    if not stack:
        print("Error: Stack is required.")
        sys.exit(1)

    description = input("One-line description: ").strip()
    if not description:
        description = f"A {stack} project built with the KEEL process."

    print()
    print(f"Project: {project_name}")
    print(f"Stack:   {stack}")
    print(f"Desc:    {description}")
    print()

    confirm = input("Proceed? (y/n): ").strip().lower()
    if confirm != "y":
        print("Aborted.")
        sys.exit(0)

    print()
    print("Replacing placeholders...")
    replace_placeholders(Path.cwd(), project_name, stack, description)
    print("Done.")

    print()
    print("Cleaning instruction comments...")
    # Already handled in replace_placeholders
    print("Done.")

    # Initialize git repo if not already
    if not Path(".git").exists():
        print()
        print("Initializing git repository...")
        subprocess.run(["git", "init"], check=True)
        subprocess.run(["git", "add", "-A"], check=True)
        subprocess.run(["git", "commit", "-m", f"feat(F00): bootstrap KEEL kit for {project_name}"], check=True)
        print("Initial commit created.")
    else:
        print()
        print("Git repo already exists. Skipping init.")

    print()
    print("=" * 48)
    print("  Kitchen is stocked.")
    print()
    print("  Next steps:")
    print("  1. Read docs/process/QUICK-START.md")
    print("  2. Fill in docs/north-star.md")
    print("  3. Fill in CLAUDE.md")
    print("  4. Write your product spec")
    print("  5. Start building!")
    print("=" * 48)


if __name__ == "__main__":
    main()
