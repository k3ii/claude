# Plan: Auto-provision `.claude` directory in worktrees
Date: 2026-05-07
Task slug: worktree-claude-provision
Branch: feat/worktree-claude-provision

## Summary

Modify the `create_worktree` skill to automatically provision the `.claude/` directory in new worktrees via symlinks. The default path creates a single directory-level symlink; when the worktree already has a `.claude/` directory (shared repo), it falls back to symlinking individual missing skills and agents. This eliminates the manual copy step that currently blocks `/implement_plan` in worktrees.

## What We're NOT Doing

- Tracking `.claude` in git
- Cleanup on worktree removal (symlinks die with the worktree directory)
- Re-syncing file-level symlinks after initial provisioning (directory-level symlinks sync automatically)
- Changes to Claude Code's skill discovery mechanism
- Changes to any skill other than `create_worktree`
- Portable hash commands for Linux — using `md5` (macOS) for now [ASSUMPTION: user is on macOS; if cross-platform support is needed later, switch to `shasum -a 256`]

---

## Phase 1: Default path — directory-level symlink

### Changes

#### `.claude/skills/create_worktree/SKILL.md`

**Insert new Step 6 "Provision `.claude`" between current Step 5 (line 61-69) and Step 6 (line 71-89). Renumber old Step 6 → Step 7.**

The new Step 6 should contain these instructions:

1. **Define the worktree path variable.** The worktree was just created at `<main-root>/../worktrees/<branch-name>`. Store this as `<worktree-path>`.

2. **Check if the main repo has `.claude/`:**

   ```bash
   test -d <main-root>/.claude && echo "exists" || echo "missing"
   ```

   If missing, set provisioning status to `"skipped (no .claude in main repo)"` and proceed to Step 7. Do not treat this as an error.

3. **Check the worktree's `.claude/` state:**

   ```bash
   test -L <worktree-path>/.claude && echo "symlink" || (test -d <worktree-path>/.claude && echo "directory" || echo "absent")
   ```

   Three possible outcomes:
   - `"symlink"` → Already provisioned. Set status to `"skipped (already symlinked)"`. Proceed to Step 7.
   - `"directory"` → Real directory exists (shared repo case). Defer to merge logic (Phase 2 will add this).
   - `"absent"` → Proceed with directory-level symlink (next sub-step).

4. **Compute the relative symlink path.** Use `realpath --relative-to` to compute the path dynamically (handles branch names with slashes):

   ```bash
   realpath --relative-to=<worktree-path> <main-root>/.claude
   ```

   This outputs something like `../../my-repo/.claude`. Store this as `<relative-claude-path>`.

   [ASSUMPTION: `realpath` is available on the system. On macOS, this requires `coreutils` (`brew install coreutils`) or use Python as fallback: `python3 -c "import os; print(os.path.relpath('<main-root>/.claude', '<worktree-path>'))"`]

5. **Create the symlink:**

   ```bash
   ln -s <relative-claude-path> <worktree-path>/.claude
   ```

6. **Verify the symlink resolves:**

   ```bash
   ls <worktree-path>/.claude/skills/
   ```

   If this fails, the relative path is wrong. Print an error and ask the user for help. Do not silently continue.

   Set provisioning status to `"symlinked .claude → <relative-claude-path>"`.

**Update the Step 7 (formerly Step 6) confirmation message** to include provisioning status:

```
✓ Worktree created at: <worktree-path>
  Branch: <branch-name>
  Skills: <provisioning-status>

Open that directory and run:
  /implement_plan thoughts/shared/plans/<plan-file>.md
```

**Note:** The "use existing worktree" conflict-resolution path in Step 4 is NOT modified in this phase. Phase 3 will add provisioning there.

### Success Criteria

**Automated:**
```bash
# After running /create_worktree on a test repo with untracked .claude/:
ls -la <worktree-path>/.claude  # Should show symlink, not directory
ls <worktree-path>/.claude/skills/  # Should list all skills
readlink <worktree-path>/.claude  # Should show relative path, not absolute
```

**Manual:**
- [ ] Create a worktree in a repo with untracked `.claude/`. The symlink target is a relative path.
- [ ] `ls <worktree-path>/.claude/skills/` lists all 8 skill directories.
- [ ] Open the worktree directory in Claude Code — `/implement_plan` and other skills appear as slash commands.
- [ ] Add a dummy file to `<main-root>/.claude/skills/test_dummy/SKILL.md`. Confirm `ls <worktree-path>/.claude/skills/test_dummy/` shows it without re-provisioning. Remove the dummy after.

### Implementation Note
> After completing Phase 1, stop and report results. Wait for human sign-off before proceeding to Phase 2.

---

## Phase 2: Merge path — file-level symlinks

### Changes

#### `.claude/skills/create_worktree/SKILL.md`

**Extend Step 6's `"directory"` branch** (the case where `<worktree-path>/.claude` exists as a real directory).

Add these instructions for the merge path:

1. **Ensure subdirectories exist:**

   ```bash
   mkdir -p <worktree-path>/.claude/skills
   mkdir -p <worktree-path>/.claude/agents
   ```

2. **Iterate over skill directories in the main repo.** For each subdirectory in `<main-root>/.claude/skills/`:

   ```bash
   ls -d <main-root>/.claude/skills/*/
   ```

   For each skill directory (e.g., `create_worktree`):

   a. Check if it exists in the worktree:
   ```bash
   test -e <worktree-path>/.claude/skills/<skill-name> && echo "exists" || echo "missing"
   ```

   b. If **missing**: compute relative path and symlink it:
   ```bash
   relative=$(realpath --relative-to=<worktree-path>/.claude/skills <main-root>/.claude/skills/<skill-name>)
   ln -s "$relative" <worktree-path>/.claude/skills/<skill-name>
   ```

   c. If **exists**: compare content hashes. For skill directories, hash the SKILL.md file inside:
   ```bash
   md5 -q <main-root>/.claude/skills/<skill-name>/SKILL.md
   md5 -q <worktree-path>/.claude/skills/<skill-name>/SKILL.md
   ```
   If hashes match → skip (already in sync). If hashes differ → skip (intentionally different, do not overwrite).

3. **Iterate over agent files in the main repo.** For each file in `<main-root>/.claude/agents/`:

   ```bash
   ls <main-root>/.claude/agents/*.md
   ```

   For each agent file (e.g., `codebase-analyzer.md`):

   a. Check if it exists in the worktree:
   ```bash
   test -e <worktree-path>/.claude/agents/<agent-file> && echo "exists" || echo "missing"
   ```

   b. If **missing**: compute relative path and symlink:
   ```bash
   relative=$(realpath --relative-to=<worktree-path>/.claude/agents <main-root>/.claude/agents/<agent-file>)
   ln -s "$relative" <worktree-path>/.claude/agents/<agent-file>
   ```

   c. If **exists**: compare hashes:
   ```bash
   md5 -q <main-root>/.claude/agents/<agent-file>
   md5 -q <worktree-path>/.claude/agents/<agent-file>
   ```
   Same logic: match → skip, differ → skip.

4. **Report what was done.** Count and report:
   - How many skills/agents were symlinked (added)
   - How many were skipped (already present, same hash)
   - How many were skipped (already present, different hash)

   Set provisioning status to `"merged: <N> added, <M> already present, <K> differ (kept existing)"`.

### Success Criteria

**Automated:**
```bash
# After running /create_worktree on a repo with existing .claude/:
ls -la <worktree-path>/.claude/skills/  # Mix of regular dirs and symlinks
ls -la <worktree-path>/.claude/agents/  # Mix of regular files and symlinks
# Symlinked entries should point to relative paths
```

**Manual:**
- [ ] Create a worktree in a repo that has `.claude/` with 2 existing skills. After provisioning, those 2 skills are unchanged (diff the content). QRSPI skills appear as symlinks alongside them.
- [ ] Place a skill with the same name as a QRSPI skill (e.g., `commit`) but different content in the worktree's `.claude/`. After provisioning, the worktree's version is untouched.
- [ ] Open the worktree in Claude Code — both the repo's original skills and the QRSPI skills appear as slash commands.

### Implementation Note
> After completing Phase 2, stop and report results. Wait for human sign-off before proceeding to Phase 3.

---

## Phase 3: Edge cases & idempotency

### Changes

#### `.claude/skills/create_worktree/SKILL.md`

**1. Add provisioning to the "use existing worktree" conflict path.**

In Step 4, the second conflict check ("Worktree path already exists") offers three options: remove, use as-is, or choose different path. For the **"use it as-is"** option:

Add an instruction after the user chooses "use as-is": run the same provisioning logic from Step 6, using the existing worktree path. This means:
- Set `<worktree-path>` to the existing worktree's path
- Execute Step 6 (provision `.claude`) exactly as written
- Then proceed to Step 7 (confirm)

The provisioning step is already idempotent by design:
- If `.claude` is already a symlink → `test -L` catches it, skips
- If `.claude` is a real directory with symlinks inside → merge logic skips entries that exist
- If `.claude` doesn't exist → creates the directory-level symlink

**2. Verify the no-`.claude/` guard message.**

The guard from Phase 1 (Step 6, sub-step 2) already handles this. Ensure the confirmation message in Step 7 includes the status `"skipped (no .claude in main repo)"` so the user sees it clearly.

**No new code shapes** — this phase wires existing logic into an additional code path and verifies edge cases.

### Success Criteria

**Automated:**
```bash
# No-claude case: after running /create_worktree in a repo with no .claude/:
test -e <worktree-path>/.claude && echo "FAIL: .claude should not exist" || echo "PASS"

# Idempotency - directory symlink case:
readlink <worktree-path>/.claude  # Run before
# Re-run provisioning
readlink <worktree-path>/.claude  # Should be identical

# Idempotency - merge case:
ls -la <worktree-path>/.claude/skills/  # Run before
# Re-run provisioning
ls -la <worktree-path>/.claude/skills/  # Should be identical
```

**Manual:**
- [ ] Run `/create_worktree` in a repo with no `.claude/` at all. Worktree is created. Confirmation message says skills were not provisioned.
- [ ] Create a worktree, then re-run `/create_worktree` with the same branch. Choose "use as-is" when prompted about the existing path. Confirm `.claude/` is provisioned (if it wasn't already) or unchanged (if it was).
- [ ] Run provisioning twice on a directory-symlinked worktree — no errors, symlink unchanged.
- [ ] Run provisioning twice on a merge-path worktree — no duplicate symlinks, no errors, existing files unchanged.

### Implementation Note
> After completing Phase 3, stop and report results. Wait for human sign-off before marking the task complete.

---

## Final Checklist

- [ ] All automated checks pass for all three phases
- [ ] All manual verification complete for all three phases
- [ ] AC1: Worktree `.claude/skills/` lists all skills via symlink
- [ ] AC2: Existing `.claude/` skills untouched, QRSPI skills added alongside
- [ ] AC3: New file in main repo `.claude/skills/` visible in directory-symlinked worktree
- [ ] AC4: No `.claude/` in main repo → worktree created, message notes no skills
- [ ] AC5: "Use existing" conflict path → `.claude/` provisioned if missing
- [ ] No unresolved [ASSUMPTION] tags (or assumptions confirmed acceptable)
