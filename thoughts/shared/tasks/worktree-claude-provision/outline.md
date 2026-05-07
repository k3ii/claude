# Outline: Auto-provision `.claude` directory in worktrees
Date: 2026-05-07
Task slug: worktree-claude-provision

## Phase Overview
| Phase | Name | Dependencies | Files Touched | Test Type |
|-------|------|-------------|---------------|-----------|
| 1 | Default path: directory-level symlink | none | `create_worktree/SKILL.md` | manual |
| 2 | Merge path: file-level symlinks | Phase 1 | `create_worktree/SKILL.md` | manual |
| 3 | Edge cases & idempotency | Phase 2 | `create_worktree/SKILL.md` | manual |

## Phase Details

### Phase 1: Default path — directory-level symlink
**Goal:** After worktree creation, symlink `.claude/` from the worktree back to the main repo when no `.claude/` exists in the worktree.
**Files:** `.claude/skills/create_worktree/SKILL.md`
**Changes:**
- Add a new Step 6 "Provision `.claude`" between current Step 5 (create) and Step 6 (confirm). Renumber old Step 6 → Step 7.
- The step first checks if `<main-root>/.claude` exists. If not, skip with a note (no QRSPI installed).
- Then checks if `<worktree>/.claude` exists. If it does not, compute the relative path from the worktree back to `<main-root>/.claude` (expected form: `../../<repo-name>/.claude`) and create the symlink with `ln -s`.
- If `<worktree>/.claude` already exists as a symlink (`test -L`), skip — already provisioned. This guard prevents Phase 2's merge logic from firing on a directory-symlinked worktree.
- If `<worktree>/.claude` exists as a real directory, defer to Phase 2's merge logic.
- Update the Step 7 confirmation message to include provisioning status (symlinked / merged / skipped).
- Note: the "use existing worktree" conflict-resolution path is excluded from Phase 1 scope — Phase 3 will add provisioning there.

**Verification:**
1. Create a worktree in a repo with untracked `.claude/`. Confirm `ls -la <worktree>/.claude` shows a relative symlink (not absolute).
2. Confirm `ls <worktree>/.claude/skills/` resolves and lists all skills.
3. Confirm Claude Code discovers skills when opened in the worktree.
4. Add a new file to `<main-root>/.claude/skills/` after provisioning — confirm it appears in `<worktree>/.claude/skills/` without re-provisioning (AC3).

**Acceptance criteria covered:** AC1, AC3

### Phase 2: Merge path — file-level symlinks
**Goal:** When `.claude/` already exists as a real directory in the worktree, add missing QRSPI skills/agents as individual symlinks without touching existing content.
**Files:** `.claude/skills/create_worktree/SKILL.md`
**Changes:**
- Extend the provisioning step's "real directory" branch: iterate over each subdirectory in `<main-root>/.claude/skills/` and each file in `<main-root>/.claude/agents/`.
- For each entry: if it doesn't exist in the worktree's `.claude/`, create a relative symlink to the main repo's version.
- If it exists and the md5 hash matches, skip (already in sync).
- If it exists and the md5 hash differs, skip (worktree's version is intentionally different — do not overwrite).
- Ensure `<worktree>/.claude/skills/` and `<worktree>/.claude/agents/` directories exist before symlinking into them (mkdir -p).

**Verification:**
1. Create a worktree in a repo that has `.claude/` tracked in git with its own skills. Confirm existing skills are untouched (content unchanged).
2. Confirm QRSPI skills are added as symlinks alongside existing skills.
3. Confirm Claude Code discovers both sets of skills.
4. Test the hash-skip branch: place a skill in the worktree's `.claude/` with the same name as a QRSPI skill but different content. Confirm it is left untouched after provisioning (AC2 second half).

**Acceptance criteria covered:** AC2

### Phase 3: Edge cases & idempotency
**Goal:** Handle no-`.claude/` main repos, re-provisioning on conflict resolution, and idempotency across both paths.
**Files:** `.claude/skills/create_worktree/SKILL.md`
**Changes:**
- Ensure the provisioning step runs in the "use existing worktree" conflict-resolution path (Step 4, "use it as-is" option), not only after fresh creation.
- Verify the guard added in Phase 1 (skip when `<main-root>/.claude` doesn't exist) produces a clear note in the confirmation message.
- Verify idempotency: re-running provisioning on an already-provisioned worktree (both directory-symlink and merge cases) produces no errors, duplicate symlinks, or altered files.

**Verification:**
1. Run `/create_worktree` in a repo with no `.claude/` at all — worktree created, confirmation says no skills provisioned (AC4).
2. Hit the worktree path conflict, choose "use as-is" on a worktree missing `.claude/` — confirm `.claude/` is provisioned (AC5).
3. Re-run provisioning on a directory-symlinked worktree — no changes, no errors.
4. Re-run provisioning on a merge-path worktree with existing symlinks inside — no duplicates, no errors, existing symlinks and files unchanged.

**Acceptance criteria covered:** AC4, AC5

## Dependency Graph
```
Phase 1 (directory symlink + test -L guard)
  └→ Phase 2 (merge logic for real directories)
       └→ Phase 3 (edge cases, conflict path, idempotency)
```
Linear chain — each phase extends the provisioning step added in Phase 1.

## Risk Notes
- **Relative path computation**: The symlink path (`../../<repo-name>/.claude`) depends on the worktree always being at `<main-root>/../worktrees/<branch-name>`. If branch names contain slashes (e.g. `feat/auth`), `git worktree add` creates nested directories, changing the depth. The relative path must be computed dynamically, not hardcoded.
- **All changes are in one file**: Since `create_worktree/SKILL.md` is a natural-language instruction set (not code), the changes are prose instructions telling the agent what shell commands to run. Testing is manual — there's no unit test harness for skill files.
- **Symlink resolution on macOS vs Linux**: `ln -s` and `test -L` behave identically on both, but `md5` (macOS) vs `md5sum` (Linux) differ. The plan should use a portable hash command.
