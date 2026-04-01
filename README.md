# QRSPI — Claude Code Command Suite

A 7-step workflow for AI-assisted software development in complex codebases, built as [Claude Code](https://docs.anthropic.com/en/docs/claude-code) slash commands.

QRSPI evolves the RPI (Research / Plan / Implement) pattern by splitting a single monolithic prompt into focused, lean commands — each with a small instruction budget and a single responsibility.

## Why QRSPI?

Large monolithic prompts (85+ instructions) cause poor instruction-following. QRSPI fixes this by:

- **Small instruction budgets** — each command does ONE thing, ~30-40 instructions max
- **No outsourced thinking** — every step surfaces reasoning to the human before proceeding
- **Objective research** — the research step never sees the implementation goal, avoiding confirmation bias
- **Read the code, not the plan** — commands produce artifacts humans can spot-check quickly
- **Explicit handoffs** — each command exits cleanly and tells you what to run next

## The 7 Steps

| Step | Command | Purpose |
|------|---------|---------|
| 1 | `/questions` | Surface clarifying questions about the task before any research |
| 2 | `/research_codebase` | Objective, opinion-free research of how the codebase works |
| 3 | `/create_design` | Collaborative design doc — where are we going? |
| 4 | `/create_outline` | Structural skeleton — how do we get there? |
| 5 | `/create_plan` | Detailed tactical implementation plan |
| 6 | `/create_worktree` | Set up an isolated git worktree for implementation |
| 7 | `/implement_plan` | Execute the plan phase by phase with human checkpoints |

## Installation

Copy the `.claude/` directory into any repository:

```bash
cp -r .claude/ /path/to/your/repo/.claude/
```

The commands will be available as slash commands in Claude Code when you open that repo.

## Quick Start

1. Open your repo in Claude Code
2. Start with your task:
   ```
   /questions Add OAuth2 support to the login endpoint
   ```
3. Answer the clarifying questions, then follow the chain:
   ```
   /research_codebase How does the current authentication system work?
   /create_design
   /create_outline
   /create_plan
   /create_worktree
   /implement_plan thoughts/shared/plans/2025-01-15-add-oauth2-login.md
   ```

Each command tells you exactly what to run next. You don't need to memorize the sequence.

## Artifacts

All intermediate artifacts are saved to `thoughts/shared/`:

```
thoughts/shared/
  tasks/<task-slug>/
    questions.md      # Step 1 output
    research.md       # Step 2 output
    design.md         # Step 3 output
    outline.md        # Step 4 output
  plans/
    YYYY-MM-DD-<task-slug>.md  # Step 5 output
```

These artifacts serve as a paper trail. They're useful for:
- Reviewing the reasoning behind implementation decisions
- Onboarding teammates to a feature's context
- Resuming work after a break

## Design Principles

1. **One command, one job.** Each command has ~30-40 instructions and does exactly one thing well.
2. **Human stays in the loop.** Every command that produces a decision artifact (design, outline, plan) asks for human confirmation before writing the final version.
3. **Objective research.** The research step describes what IS, never what SHOULD change. This prevents the AI from anchoring on a solution before understanding the problem.
4. **Explicit handoffs.** No implicit control flow. Each command ends with a clear "run X next" instruction.
5. **Prefer make.** Verification steps use `make -C <dir> check` over raw shell commands.
6. **Spot-check the code, not the plan.** Plans are kept to a level of detail that's quick to scan. Deep review happens on the actual implementation.
