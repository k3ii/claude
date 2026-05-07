# Questions: Auto-provision `.claude` directory in worktrees
Date: 2026-05-07

## Task
After `/create_worktree` sets up a git worktree, the `.claude` directory (containing QRSPI skills) is missing because it's untracked. Automate provisioning so `/implement_plan` works immediately.

## Answers
1. Is `.claude` gitignore'd or just not staged? → Not tracked by git (not staged/committed)
2. Should the fix live in `create_worktree` or elsewhere? → Best practice (to be determined in design)
3. Copy entire `.claude` or just `skills/`? → Best practice (to be determined in design)
4. Symlink vs one-time copy? → Unknown — to be determined in design
5. Should it skip if `.claude` already exists with the right skills? → Yes, but it should check whether the user's specific skills are present, since repos may be shared and already have a `.claude` with different content
6. Is modifying `create_worktree` acceptable? → Yes

## Key Constraints
- `.claude` is not tracked in git, so worktrees never get it automatically
- Shared repos may already have a `.claude` directory with different skills — must merge/check, not blindly overwrite
- Solution must ensure QRSPI skills are available in the worktree so `/implement_plan` works without manual copying

## Out of Scope
- Tracking `.claude` in git (user's choice to keep it untracked)
- Changing the git workflow or worktree mechanism itself
