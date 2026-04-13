# KEEL — repo-level guide for agents

This repo **is** the KEEL framework. It is *not* a project that uses KEEL.
If you are editing files here, you are editing the framework that gets
installed into other people's repos. Act accordingly.

## Orientation

|Path|What it is|
|-|-|
|`.claude/agents/`|The 15 agent definitions shipped by KEEL|
|`.claude/skills/`|Skills. `keel-pipeline`, `keel-adopt`, `keel-setup`, `safety-check` ship to users via `install.py`. `dev-up` is KEEL-internal — lives in this repo only, not copied to installs.|
|`.claude/hooks/`|`safety-gate.py`, `doc-gate.py` — shipped with KEEL|
|`template/`|**Install target.** Files here are copied into user projects by `scripts/install.py`. Edits ship to every new install.|
|`scripts/`|`install.py`, `uninstall.py`, `validate-handoff.py` — stdlib-only Python 3.10+, cross-platform|
|`docs/process/`|Reference material also copied into user installs (`THE-KEEL-PROCESS.md`, `QUICK-START.md`, `BROWNFIELD.md`, `GLOSSARY.md`, `ANTI-PATTERNS.md`, `FAILURE-PLAYBOOK.md`)|
|`docs/HOW-IT-WORKS.md`, `docs/INSTALL.md`, `docs/UNINSTALL.md`|Framework docs — **not** copied into installs|
|`NORTH-STAR.md`|Where KEEL is heading. Read before structural changes.|
|`examples/domain-invariants/`|Reference invariants users crib from when filling `safety-auditor.md`|

## Hard rules

1. **Never edit `template/CLAUDE.md` or `template/ARCHITECTURE.md` to
   describe this repo.** They are templates that ship to users with
   `<!-- CUSTOMIZE -->` markers. The installer strips `DELETE AFTER
   FILLING` comments on copy.
2. **Scripts stay stdlib-only.** `install.py`, `uninstall.py`,
   `validate-handoff.py` must not import anything
   outside the Python 3.10+ stdlib. They run on fresh machines before
   any deps are installed.
3. **Scripts stay cross-platform.** No POSIX-only path assumptions, no
   shell-outs where a stdlib call will do. `scripts/` was refactored
   from shell to Python in `42ee6a7` specifically to support Windows.
4. **The repo is the product.** KEEL has no runtime, no binary, no
   server. The markdown and agent definitions ARE the framework — edits
   to prompts ship on next install.
5. **Docs drive code, for KEEL itself too.** Process docs in
   `docs/process/` must be updated in the same commit as the agents or
   pipeline changes they describe. See `NORTH-STAR.md` §"Principles for
   Framework Development".

## Testing changes to install/uninstall

```bash
# Install into a throwaway dir using the local source
cd /tmp && rm -rf keel-smoke && mkdir keel-smoke && cd keel-smoke
python3 /mnt/agent-storage/vader/src/keel/scripts/install.py
# Verify .claude/agents/ has 15 files, docs/ is populated, CLAUDE.md has
# placeholders replaced.

# Then uninstall
python3 .claude/keel-uninstall.py
```

`install.py` detects the local source when run from a clone; it only
re-clones from GitHub when run via `curl | python3`.

## Validating handoff files

```bash
python3 scripts/validate-handoff.py docs/exec-plans/completed/handoffs/
python3 scripts/validate-handoff.py path/to/F13.md
```

Checks YAML frontmatter, pipeline-aware sections, gate verdicts, routing
fields, status consistency.

## Agent inventory (15 agents)

Reasoning tier is set in each agent's YAML frontmatter. `docs/INSTALL.md`
has the canonical table; keep them in sync. Drift in agent counts or
pipeline diagrams has been a recurring source of bugs (see `c817bfd`,
`dc85716`).

## Pipeline variants

Documented in `template/CLAUDE.md`, `docs/HOW-IT-WORKS.md`, and every
agent's handoff-reading section. If you change a pipeline variant, grep
for the ASCII diagram and update every copy — they drift.

## Where to start for common tasks

|Task|Start here|
|-|-|
|Edit an agent prompt|`.claude/agents/<name>.md`, then check `docs/INSTALL.md` tier table|
|Change pipeline shape|`docs/HOW-IT-WORKS.md`, then every agent handoff section, then `template/CLAUDE.md`|
|Change install behavior|`scripts/install.py`, then `docs/INSTALL.md`|
|Add a skill|`.claude/skills/<name>/SKILL.md`, then `scripts/install.py` skill list (~line 159), then `docs/INSTALL.md`|
|Teach KEEL a new domain|`examples/domain-invariants/`, not `safety-auditor.md` directly|

## Convention for this repo's own work

- Commits follow `type(scope): subject` — see `git log`. Recent examples:
  `fix:`, `feat(code-reviewer):`, `docs:`, `refactor:`.
- This repo does not run a KEEL pipeline on itself (no orchestration
  skill for framework edits). Edits here are direct.
- The `.claude/settings.json` hooks (`safety-gate.py`, `doc-gate.py`)
  DO fire on edits in this repo — KEEL dogfoods on its own source.
