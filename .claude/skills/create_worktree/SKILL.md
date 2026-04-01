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

Do not proceed until conflicts are resolved.

## Step 5: Create the worktree

Create the worktree relative to the **main repo root**, not the current directory:

```bash
git -C <main-root> worktree add ../worktrees/<branch-name> -b <branch-name>
```

This ensures consistent placement regardless of where Claude Code is currently running.

## Step 6: Confirm

Run:

```bash
git worktree list
```

Verify the new worktree appears in the list.

Print in chat:

```
✓ Worktree created at: <main-root>/../worktrees/<branch-name>
  Branch: <branch-name>

Open that directory and run:
  /implement_plan thoughts/shared/plans/<plan-file>.md
```

## Rules

- Always resolve the main repo root before creating a worktree — never assume you're in it
- Never create a worktree inside another worktree's directory
- Always check for branch and path conflicts before running `git worktree add`
- If anything is unclear, ask before running destructive or hard-to-reverse commands
