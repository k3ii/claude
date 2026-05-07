---
description: Set up a git worktree for the implementation, resolving the correct root path even if already running inside a worktree.
model: sonnet
tools: Bash, Read
---

You are setting up an isolated git worktree for a new implementation branch.

## Step 1: Read the plan

Read the plan file passed as an argument to extract:

- The task slug (e.g. `add-user-auth-endpoint`)
- The suggested branch name (e.g. `feat/add-user-auth-endpoint`)

If no plan file was passed, ask the user: "Which plan file should I use? (e.g. `thoughts/shared/plans/2025-01-08-my-feature.md`)"

## Step 2: Detect if already inside a worktree

Run:

```bash
git rev-parse --git-dir
```

If the output is something like `/path/to/repo/.git/worktrees/<name>`, you are inside a worktree.
If the output is `.git` or an absolute path ending in `.git`, you are in the main repo.

## Step 3: Find the main repo root

Run:

```bash
git worktree list --porcelain
```

The first entry is always the main worktree. Extract its path — this is `<main-root>`.

## Step 4: Check for conflicts

Before creating anything, check:

1. **Branch already exists:**

```bash
git branch --list <branch-name>
```

If it exists, ask the user: "Branch `<branch-name>` already exists. Use it as-is, or choose a new name?"

2. **Worktree path already exists:**

```bash
ls <main-root>/../worktrees/<branch-name>
```

If it exists, ask the user: "A worktree at that path already exists. Remove it, use it as-is, or choose a different path?"

If the user chooses **"use it as-is"**: set `<worktree-path>` to the existing worktree path, skip Step 5, and go directly to Step 6 (Provision `.claude`). Then continue to Step 7.

Do not proceed until conflicts are resolved.

## Step 5: Create the worktree

Create the worktree relative to the **main repo root**, not the current directory:

```bash
git -C <main-root> worktree add ../worktrees/<branch-name> -b <branch-name>
```

This ensures consistent placement regardless of where Claude Code is currently running.

## Step 6: Provision `.claude`

The worktree path is `<main-root>/../worktrees/<branch-name>`. Store this as `<worktree-path>`.

1. **Check if the main repo has `.claude/`:**

```bash
test -d <main-root>/.claude && echo "exists" || echo "missing"
```

If missing, set provisioning status to `"skipped (no .claude in main repo)"` and proceed to Step 7.

2. **Check the worktree's `.claude/` state:**

```bash
test -L <worktree-path>/.claude && echo "symlink" || (test -d <worktree-path>/.claude && echo "directory" || echo "absent")
```

- `"symlink"` → Already provisioned. Set status to `"skipped (already symlinked)"`. Proceed to Step 7.
- `"directory"` → Real directory exists (shared repo). Run the **merge logic** described below.
- `"absent"` → Proceed with directory-level symlink (next sub-step).

3. **Compute the relative symlink path** (for the `"absent"` case):

```bash
python3 -c "import os; print(os.path.relpath('<main-root>/.claude', '<worktree-path>'))"
```

Store the output as `<relative-claude-path>`.

4. **Create the symlink:**

```bash
ln -s <relative-claude-path> <worktree-path>/.claude
```

5. **Verify the symlink resolves:**

```bash
ls <worktree-path>/.claude/skills/
```

If this fails, the relative path is wrong. Print an error and ask the user for help. Do not silently continue.

Set provisioning status to `"symlinked .claude → <relative-claude-path>"`.

### Merge logic (for the `"directory"` case)

When `<worktree-path>/.claude` exists as a real directory, add missing skills and agents individually:

1. Ensure subdirectories exist:

```bash
mkdir -p <worktree-path>/.claude/skills
mkdir -p <worktree-path>/.claude/agents
```

2. For each subdirectory in `<main-root>/.claude/skills/`:

   - If it does **not** exist in `<worktree-path>/.claude/skills/`:
     ```bash
     relative=$(python3 -c "import os; print(os.path.relpath('<main-root>/.claude/skills/<skill-name>', '<worktree-path>/.claude/skills'))")
     ln -s "$relative" <worktree-path>/.claude/skills/<skill-name>
     ```
   - If it **exists**, compare hashes:
     ```bash
     md5 -q <main-root>/.claude/skills/<skill-name>/SKILL.md
     md5 -q <worktree-path>/.claude/skills/<skill-name>/SKILL.md
     ```
     If hashes match → skip (in sync). If hashes differ → skip (intentionally different, do not overwrite).

3. For each file in `<main-root>/.claude/agents/`:

   - If it does **not** exist in `<worktree-path>/.claude/agents/`:
     ```bash
     relative=$(python3 -c "import os; print(os.path.relpath('<main-root>/.claude/agents/<agent-file>', '<worktree-path>/.claude/agents'))")
     ln -s "$relative" <worktree-path>/.claude/agents/<agent-file>
     ```
   - If it **exists**, compare hashes:
     ```bash
     md5 -q <main-root>/.claude/agents/<agent-file>
     md5 -q <worktree-path>/.claude/agents/<agent-file>
     ```
     Same logic: match → skip, differ → skip.

4. Report counts: how many added, how many already present, how many differ (kept existing).

Set provisioning status to `"merged: <N> added, <M> already present, <K> differ (kept existing)"`.

## Step 7: Confirm

Run:

```bash
git worktree list
```

Verify the new worktree appears in the list.

Print in chat:

```
✓ Worktree created at: <worktree-path>
  Branch: <branch-name>
  Skills: <provisioning-status>

Open that directory and run:
  /implement_plan thoughts/shared/plans/<plan-file>.md
```

## Rules

- Always resolve the main repo root before creating a worktree — never assume you're in it
- Never create a worktree inside another worktree's directory
- Always check for branch and path conflicts before running `git worktree add`
- If anything is unclear, ask before running destructive or hard-to-reverse commands
