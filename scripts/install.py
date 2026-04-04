#!/usr/bin/env python3
"""KEEL Installer — Add KEEL to any project directory.

Usage (from your project root):
    python3 /path/to/keel/scripts/install.py
    OR
    curl -fsSL https://raw.githubusercontent.com/TejGandham/keel/main/scripts/install.py | python3

What it does:
    1. Copies .claude/agents/, .claude/skills/, .claude/hooks/ into your project
    2. Creates docs/ structure from template
    3. Creates CLAUDE.md and ARCHITECTURE.md from template
    4. Creates Dockerfile and docker-compose.yml from template
    5. Replaces [PROJECT_NAME], [STACK], [DESCRIPTION] placeholders
    6. Does NOT touch existing files — skips if already present

Your code stays yours. KEEL just adds the scaffolding.
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def resolve_keel_source() -> Path:
    """Find the KEEL repo root — either local or download."""
    script_dir = Path(__file__).resolve().parent
    keel_root = script_dir.parent

    if (keel_root / "CLAUDE.md").exists() and (keel_root / ".claude" / "agents").is_dir() and (keel_root / "template").is_dir():
        print(f"Using local KEEL source: {keel_root}")
        return keel_root

    tmp = Path(tempfile.mkdtemp())
    print("Downloading KEEL...")
    subprocess.run(
        ["git", "clone", "--depth", "1", "--quiet", "https://github.com/TejGandham/keel.git", str(tmp)],
        check=True,
    )
    print("Downloaded.")
    return tmp


def copy_if_missing(src: Path, dst: Path) -> bool:
    """Copy file if destination doesn't exist. Returns True if copied."""
    if dst.exists():
        print(f"  {dst.name} already exists — skipping")
        return False
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    print(f"  {dst.name} — created")
    return True


def replace_placeholders(project_dir: Path, name: str, stack: str, desc: str, reference_file: Path):
    """Replace [PROJECT_NAME], [STACK], [DESCRIPTION] in text files newer than reference."""
    ref_mtime = reference_file.stat().st_mtime if reference_file.exists() else 0

    skip_dirs = {".git", "node_modules", "vendor", "__pycache__"}
    skip_exts = {".webp", ".png", ".jpg", ".jpeg", ".svg", ".ico", ".gif", ".woff", ".woff2", ".ttf", ".eot"}

    for path in project_dir.rglob("*"):
        if not path.is_file():
            continue
        if any(part in skip_dirs for part in path.parts):
            continue
        if path.suffix.lower() in skip_exts:
            continue
        if path.stat().st_mtime < ref_mtime:
            continue

        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, PermissionError):
            continue

        updated = text.replace("[PROJECT_NAME]", name).replace("[STACK]", stack).replace("[DESCRIPTION]", desc)
        if updated != text:
            path.write_text(updated, encoding="utf-8")

    # Clean DELETE AFTER FILLING comments from markdown files
    for path in project_dir.rglob("*.md"):
        if any(part in skip_dirs for part in path.parts):
            continue
        if path.stat().st_mtime < ref_mtime:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, PermissionError):
            continue
        cleaned = re.sub(r"<!-- DELETE AFTER FILLING.*?-->", "", text, flags=re.DOTALL)
        if cleaned != text:
            path.write_text(cleaned, encoding="utf-8")


def main():
    project_dir = Path.cwd()
    keel_src = resolve_keel_source()

    print()
    print("=" * 48)
    print("  KEEL — Knowledge-Encoded Engineering Lifecycle")
    print(f"  Installing into: {project_dir}")
    print("=" * 48)
    print()

    # --- Gather project details ---
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
    print(f"Target:  {project_dir}")
    print()

    confirm = input("Proceed? (y/n): ").strip().lower()
    if confirm != "y":
        print("Aborted.")
        sys.exit(0)

    # --- Copy agents ---
    print()
    print("Installing KEEL agents and skills...")

    agents_src = keel_src / ".claude" / "agents"
    agents_dst = project_dir / ".claude" / "agents"
    agents_dst.mkdir(parents=True, exist_ok=True)

    agent_count = 0
    for agent in sorted(agents_src.glob("*.md")):
        dst = agents_dst / agent.name
        if not dst.exists():
            shutil.copy2(agent, dst)
            agent_count += 1
    print(f"  .claude/agents/ — {agent_count} new agents installed (existing kept)")

    # --- Copy skills ---
    skills_dst = project_dir / ".claude" / "skills"
    skills_dst.mkdir(parents=True, exist_ok=True)

    skill_count = 0
    for skill_name in ("keel-pipeline", "keel-adopt", "safety-check"):
        skill_src = keel_src / ".claude" / "skills" / skill_name
        skill_dst_dir = skills_dst / skill_name
        if skill_src.is_dir() and not skill_dst_dir.exists():
            shutil.copytree(skill_src, skill_dst_dir)
            skill_count += 1
    print(f"  .claude/skills/ — {skill_count} new skills installed (existing kept)")

    # --- Copy hooks ---
    hooks_src = keel_src / ".claude" / "hooks"
    if hooks_src.is_dir():
        hooks_dst = project_dir / ".claude" / "hooks"
        hooks_dst.mkdir(parents=True, exist_ok=True)
        hook_count = 0
        for hook in hooks_src.iterdir():
            dst = hooks_dst / hook.name
            if not dst.exists():
                shutil.copy2(hook, dst)
                hook_count += 1
        print(f"  .claude/hooks/ — {hook_count} new hooks installed (existing kept)")

    # --- Copy settings.json if missing ---
    settings_src = keel_src / ".claude" / "settings.json"
    settings_dst = project_dir / ".claude" / "settings.json"
    if settings_src.exists():
        copy_if_missing(settings_src, settings_dst)

    # --- Copy uninstall script ---
    print()
    print("Installing doc structure...")

    uninstall_src = keel_src / "scripts" / "uninstall.py"
    uninstall_dst = project_dir / ".claude" / "keel-uninstall.py"
    copy_if_missing(uninstall_src, uninstall_dst)

    # --- Copy root template files ---
    template_dir = keel_src / "template"
    for name in ("CLAUDE.md", "ARCHITECTURE.md", "Dockerfile", "docker-compose.yml"):
        copy_if_missing(template_dir / name, project_dir / name)

    # --- Copy docs structure ---
    for path in sorted(template_dir.rglob("*")):
        if path.is_file():
            rel = path.relative_to(template_dir)
            copy_if_missing(path, project_dir / rel)

    # --- Replace placeholders ---
    print()
    print("Replacing placeholders...")
    ref_file = project_dir / ".claude" / "agents" / "pre-check.md"
    replace_placeholders(project_dir, project_name, stack, description, ref_file)
    print("Done.")

    # --- Copy process docs ---
    print()
    print("Installing process reference docs...")
    process_dst = project_dir / "docs" / "process"
    process_dst.mkdir(parents=True, exist_ok=True)

    for doc_name in ("THE-KEEL-PROCESS.md", "QUICK-START.md", "BROWNFIELD.md",
                      "GLOSSARY.md", "ANTI-PATTERNS.md", "FAILURE-PLAYBOOK.md"):
        src = keel_src / "docs" / "process" / doc_name
        if src.exists():
            copy_if_missing(src, process_dst / doc_name)

    print()
    print("=" * 48)
    print(f"  KEEL installed into {project_dir}")
    print()
    print("  What was added:")
    print("    .claude/agents/    14 agent definitions")
    print("    .claude/skills/    3 skills (pipeline, adopt, safety-check)")
    print("    docs/              Spec structure, handoff templates, process guides")
    print("    CLAUDE.md          Project entry point (customize this first)")
    print("    ARCHITECTURE.md    Module map (fill in as you build)")
    print()
    print("  Next steps:")
    print("    1. Open CLAUDE.md — fill in the <!-- CUSTOMIZE --> sections")
    print("    2. Open docs/north-star.md — define your vision")
    print("    3. Write your first product spec in docs/product-specs/")
    print("    4. Fill in domain invariants in .claude/agents/safety-auditor.md")
    print("    5. Run: /keel-pipeline my-feature docs/product-specs/my-spec.md")
    print()
    print("  Process reference: docs/process/QUICK-START.md")
    print("=" * 48)


if __name__ == "__main__":
    main()
