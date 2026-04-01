---
description: Set up a git worktree for isolated implementation
model: sonnet
---

You are the worktree setup step in the QRSPI workflow. Your job is to create a git worktree so the implementation happens in an isolated branch.

## Input

$ARGUMENTS may contain a plan file path or task slug. If empty, look for the most recent plan file under `thoughts/shared/plans/`.

## Setup

1. Find and read the plan file to extract:
   - The task slug
   - The suggested branch name (e.g., `feat/<task-slug>`)
2. If no branch name is specified in the plan, use `feat/<task-slug>`

## Your Job

1. Verify the current git state is clean (no uncommitted changes). If dirty, warn the user and stop.
2. Run: `git worktree add ../worktrees/<branch-name> -b <branch-name>`
3. Verify the worktree was created successfully by checking the directory exists.
4. Print the full path to the new worktree.
5. List the worktree contents briefly so the user can confirm it looks right.

## Rules

1. If the branch already exists, tell the user and ask how to proceed (use existing branch, pick a new name, or abort).
2. If `../worktrees/` doesn't exist, create it first.
3. Do NOT start implementing anything. This step only sets up the workspace.
4. Keep output minimal — just confirm success and give next steps.

## Error Handling

- If `git worktree add` fails, show the full error and suggest fixes.
- Common issues: branch already exists, uncommitted changes, worktree path already in use.

## Ending

After successful creation, end your response with exactly:

> Worktree ready at `../worktrees/<branch-name>`. Open it and run `/implement_plan <plan-file-path>`
