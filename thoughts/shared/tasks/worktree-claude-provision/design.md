# Design: Auto-provision `.claude` directory in worktrees
Date: 2026-05-07
Task slug: worktree-claude-provision

## End State

After running `/create_worktree`, the new worktree has a working `.claude/` directory with all QRSPI skills and agents available. The user can immediately open the worktree in Claude Code and run `/implement_plan` without any manual copying. Skills stay in sync with the main repo automatically — edits to skills in the main repo are reflected in all worktrees without re-provisioning.

## Key Decisions

1. **Modify `create_worktree` directly.** The provisioning step is added between the current Step 5 (create) and Step 6 (confirm). This keeps the logic in the one skill that already resolves `<main-root>` and knows the worktree path. Rejected: separate hook script or wrapper — adds indirection and a second thing to install.

2. **Directory-level symlink as default; file-level symlinks as merge fallback.** When the worktree has no `.claude/`, create a single symlink: `<worktree>/.claude -> <main-root>/.claude`. When `.claude/` already exists (shared repo with its own skills), fall back to symlinking individual skill and agent entries that are missing or outdated. Rejected: always file-level symlinks — unnecessary complexity for the common case. Rejected: full copy — creates stale copies that drift from the main repo.

3. **Use relative symlinks.** Worktrees are always at `<main-root>/../worktrees/<branch-name>`, so the relative path back to `<main-root>/.claude` is predictable (e.g., `../../<repo-name>/.claude`). Relative symlinks survive directory renames. Rejected: absolute symlinks — break if the repo moves.

4. **Provision both `skills/` and `agents/`.** The entire `.claude/` directory is symlinked (or its contents merged). Agents are required by skills — symlinking only `skills/` would leave agent definitions missing. Since `.claude/` currently contains only `skills/` and `agents/`, the directory-level symlink covers everything.

5. **"Missing or outdated" detection via file hash.** In the merge case (`.claude/` already exists), for each skill directory and agent file in the main repo's `.claude/`, check whether it exists in the worktree. If it doesn't exist, symlink it. If it exists but its content hash (md5) differs from the main repo version, skip it — the worktree's version is intentionally different. Only missing entries are added; nothing is overwritten. Rejected: overwriting differing files — violates the "shared repo" constraint where existing skills are intentional.

6. **Silent skip when main repo has no `.claude/`.** If `<main-root>/.claude` doesn't exist, the provisioning step is a no-op with a note in the confirmation output. This handles the case where someone uses `create_worktree` in a repo without QRSPI installed. Rejected: failing the entire worktree creation — `.claude/` provisioning is a convenience, not a prerequisite.

7. **Re-provision on "use existing worktree".** When the user hits a worktree path conflict and chooses "use it as-is," the provisioning step still runs. This fixes worktrees that were created before this feature existed. The step is idempotent — re-running it on an already-provisioned worktree changes nothing.

## Out of Scope

- **Tracking `.claude` in git.** User's explicit choice to keep it untracked.
- **Cleanup on worktree removal.** Symlinks are cleaned up naturally when the worktree directory is deleted. No special teardown needed.
- **Re-syncing after initial provisioning.** In the merge case (file-level symlinks), new skills added to the main repo later won't appear in existing worktrees. This is acceptable — the user can re-run `/create_worktree` or manually copy. The directory-level symlink case syncs automatically.
- **Changes to Claude Code's skill discovery mechanism.**
- **Changes to any skill other than `create_worktree`.**

## Acceptance Criteria

1. After `/create_worktree` completes on a repo where `.claude/` is untracked, running `ls <worktree>/.claude/skills/` lists all skills from the main repo, and each is a working symlink.
2. After `/create_worktree` completes on a repo where `.claude/` already exists with different skills, the existing skills are untouched and the QRSPI skills are added as symlinks alongside them.
3. A file added to `<main-root>/.claude/skills/` is visible via `ls` in a directory-symlinked worktree without any additional action.
4. If `<main-root>/.claude/` does not exist, the worktree is still created successfully and the confirmation message notes that no skills were provisioned.
5. Running `/create_worktree` against an existing worktree (conflict → "use as-is") provisions `.claude/` if it was previously missing.
