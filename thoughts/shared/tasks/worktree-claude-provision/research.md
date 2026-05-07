# Research: How does `create_worktree` set up git worktrees, and how does `.claude` get referenced by skills?
Date: 2026-05-07
Git commit: 27598cb
Branch: main
Task slug: worktree-claude-provision

## Summary

- `create_worktree` creates worktrees at `<main-root>/../worktrees/<branch-name>` but performs **zero operations** on the `.claude` directory — it is not copied, symlinked, or referenced.
- `.claude/` is **not tracked in git** (not staged, no `.gitignore` — simply untracked). Therefore it never appears in any worktree automatically.
- No skill or agent file references `.claude/` as a path. Skills invoke agents by name, not by filesystem path — but Claude Code itself needs the `.claude/` directory present in the worktree to discover and load skills.
- `implement_plan` has a fallback chain for resolving `thoughts/` paths back to the main repo root (via `git worktree list --porcelain`), but no equivalent mechanism exists for `.claude/`.
- The `.claude/` directory contains only two subdirectories: `agents/` (9 files) and `skills/` (8 subdirectories with SKILL.md each). No config files like `settings.json` or `CLAUDE.md` live inside it.

## Relevant Files

| File | Description |
|------|-------------|
| `.claude/skills/create_worktree/SKILL.md` | 6-step worktree creation procedure; no `.claude` handling |
| `.claude/skills/implement_plan/SKILL.md` | Phase-by-phase plan executor; has `thoughts/` fallback but no `.claude` fallback |
| `.claude/skills/create_plan/SKILL.md` | Writes plans; hands off to `create_worktree` as next step |
| `.claude/agents/*.md` | 9 agent definitions used by skills |
| `setup-qrspi.sh` | Installation script that copies `.claude/` into a target repo |

## Architecture

### Worktree creation flow (`create_worktree/SKILL.md`)

1. **Read plan** (line 11) — extracts task slug and branch name from the plan file argument
2. **Detect context** (line 22-27) — runs `git rev-parse --git-dir` to determine if inside a worktree or main repo
3. **Find main root** (line 33-37) — runs `git worktree list --porcelain`, first entry = main repo root
4. **Conflict checks** (line 42-59) — checks branch existence (`git branch --list`) and path existence (`ls <main-root>/../worktrees/<branch-name>`)
5. **Create** (line 65-67) — `git -C <main-root> worktree add ../worktrees/<branch-name> -b <branch-name>`
6. **Confirm** (line 73-89) — verifies via `git worktree list`, prints path and next command

The worktree lands at `<main-root>/../worktrees/<branch-name>` — a sibling directory to the main repo, not inside it.

### Plan file resolution in `implement_plan` (`implement_plan/SKILL.md:9-35`)

A 4-step fallback chain:
1. Direct `ls <plan-file-path>` (line 16)
2. Check if `thoughts/` exists in cwd (line 22-24)
3. If missing, resolve main repo root via `git worktree list --porcelain` and probe `<main-root>/thoughts/shared/plans/` (line 25-32)
4. Print available files and ask user (line 33)

This chain handles `thoughts/` being absent from the worktree. **No equivalent chain exists for `.claude/`** — if `.claude/` is absent, skills simply aren't available.

### How Claude Code discovers skills

Skills are loaded from `.claude/skills/` relative to the project root (the directory Claude Code is opened in). When Claude Code is opened in a worktree directory, it looks for `.claude/skills/` inside that worktree. If the directory doesn't exist, the skills are not available as slash commands.

## Existing Patterns

### Path resolution pattern (implement_plan)

The `implement_plan` skill already solves an analogous problem: `thoughts/` doesn't exist in worktrees. Its solution (`implement_plan/SKILL.md:21-32`):
1. Detect absence of `thoughts/` in cwd
2. Run `git worktree list --porcelain` to find main root
3. Resolve the path from main root

This pattern could be adapted for `.claude/`, but with a key difference: skills must be present at Claude Code startup (not runtime), so a resolve-on-demand approach wouldn't work. The `.claude/` directory must physically exist in the worktree before Claude Code is opened.

### Installation pattern (setup-qrspi.sh)

The setup script copies the entire `.claude/` directory into a target repo. This is a one-time copy, not a sync mechanism.

## Test Infrastructure

No test infrastructure exists in this repository. There are no test files, test scripts, or testing frameworks configured.

## Prior Research & Decisions

One document found: `thoughts/shared/tasks/worktree-claude-provision/questions.md` — captures the user's clarifying answers from the `/questions` step. Key constraint noted: shared repos may already have a `.claude` directory with different skills, so the solution must merge/check rather than blindly overwrite.

## Gaps & Unknowns

- **Claude Code skill discovery internals**: The exact mechanism Claude Code uses to discover `.claude/skills/` is not documented in this repo. It's assumed to be a directory scan at startup relative to the project root.
- **Symlink support**: Whether Claude Code follows symlinks for `.claude/` or `.claude/skills/` is unknown. If it does, symlinking back to the main repo would be the simplest solution.
- **Shared repo merging**: When a target repo already has `.claude/` with its own skills, the merge strategy (additive copy vs. full replace) needs a design decision. No prior art exists in this codebase for this.
- **Git worktree limitations**: Git worktrees share the `.git` directory but not untracked files. There is no native git mechanism to auto-provision untracked files into new worktrees.
