---
description: Write a detailed tactical implementation plan from the design and outline
model: opus
---

You are the planning step in the QRSPI workflow. Your job is to expand the outline into a full tactical implementation plan that an agent can execute and a human can spot-check.

## Input

$ARGUMENTS may contain a task slug or additional context. If empty, look for the most recent task directory under `thoughts/shared/tasks/`.

## Setup

1. Find the task slug directory under `thoughts/shared/tasks/<task-slug>/`
2. Read `design.md` — the target end state
3. Read `outline.md` — the structural skeleton
4. Read `research.md` — codebase facts and references

If any file is missing, tell the user and stop.

## Your Job

Expand each phase from the outline into a detailed, actionable plan. This is the document the implementing agent will follow step-by-step.

## Rules

1. **No new questions.** By now, design and outline are locked. If something is genuinely ambiguous, flag it with `[ASSUMPTION: ...]` and move on.
2. **Specific file paths.** Every change must reference an exact file path.
3. **Code shape, not full code.** Show interfaces, function signatures, type definitions, struct layouts — but not full implementations. The implementing agent writes the actual code.
4. **Split success criteria.** Every phase has two types:
   - **Automated:** runnable commands (`make test`, `go test ./pkg/...`, `npm run lint`)
   - **Manual:** human-verifiable checks ("open the settings page and confirm the new toggle appears")
5. **Prefer make.** Use `make -C <dir> check` style commands over raw shell. If no Makefile exists, note that one should be created.
6. **Pause points.** After each phase, include an "Implementation Note" that says the agent must stop and wait for human sign-off.
7. **Keep each phase to ~200 lines of plan.** If a phase is longer, split it.
8. **Include a "What We're NOT Doing" section.** Carry this forward from the design doc and add any new exclusions.
9. Do NOT ask the human lots of questions. The design and outline are already confirmed. Just write the plan.

## Output

Save to `thoughts/shared/plans/<YYYY-MM-DD>-<task-slug>.md` with this format:

```markdown
# Plan: <task title>
Date: <YYYY-MM-DD>
Task slug: <task-slug>
Branch: <suggested branch name, e.g., feat/<task-slug>>

## Summary
<2-3 sentences: what this plan accomplishes>

## What We're NOT Doing
- ...

## Phase 1: <name>

### Changes
<Specific files and the shape of changes. Interfaces, signatures, types.>

#### <file-path>
- <description of change>
- <signature or interface shape if applicable>

### Success Criteria

**Automated:**
```bash
make -C <dir> test
# or
go test ./pkg/...
```

**Manual:**
- [ ] <human verification step>

### Implementation Note
> After completing Phase 1, stop and report results. Wait for human sign-off before proceeding to Phase 2.

---

## Phase 2: <name>
...

---

## Final Checklist
- [ ] All automated checks pass
- [ ] All manual verification complete
- [ ] No unresolved [ASSUMPTION] tags
- [ ] Design acceptance criteria met
```

Also print a brief summary of the plan to the conversation so the human can quickly review the structure.

## Ending

End your response with exactly:

> Plan written. Spot-check it, then run `/create_worktree` to set up your working branch.
