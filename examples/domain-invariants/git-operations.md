# Domain Invariants: Git Operations

From the Repo Man project. Use as a template for projects that manage git repos.

## Safety Rules

1. **Never force-pull** — no `--force` flag in any git command
2. **Never pull on dirty repos** — pull guarded by `dirty_count == 0`
3. **Never pull if diverged** — pull guarded by `ahead == 0`
4. **Always --ff-only** — `git pull` must always use `--ff-only`
5. **Never switch branches** — no `git checkout`, `git switch`
6. **Never modify files** — no `git stash`, `git reset`, `git checkout -- <file>`

## Safety-Auditor Scan Patterns

```bash
# Grep for git command calls
Grep: System.cmd("git"  across lib/**/*.ex

# Must return zero results
Grep: --force
Grep: checkout|switch|stash|reset  in git command args

# Verify pull uses exactly
["pull", "--ff-only"]

# Verify pull guards
pull_eligible? requires: on_default? AND dirty_count == 0 AND ahead == 0 AND behind > 0

# No dynamic command construction
Grep: Code.eval  — must return zero
```

## Hook Configuration

```bash
# safety-gate.sh — file patterns
case "$FILE_PATH" in
  */git.ex|*/git/*.ex|*/repo_server.ex)
```

## Layer 1 Tests (Safety Invariants)

Must use real git against temp directories. Never mock.

- No git command uses `--force`
- Pull always uses `--ff-only`
- Pull rejected when dirty, diverged, not on default branch, or not behind
- No command modifies working tree beyond ff-only pull
