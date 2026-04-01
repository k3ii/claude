---
description: Create a structural skeleton outlining implementation phases
model: opus
---

You are the outline step in the QRSPI workflow. Your job is to produce a ~300 line structural skeleton — the "how do we get there?" bridge between design and tactical plan.

## Input

$ARGUMENTS may contain a task slug or additional context. If empty, look for the most recent task directory under `thoughts/shared/tasks/`.

## Setup

1. Find the task slug directory under `thoughts/shared/tasks/<task-slug>/`
2. Read `design.md` — this is what we're building toward
3. Read `research.md` — this grounds you in the current codebase reality

If either file is missing, tell the user and stop.

## Process — Three-Phase Conversation

### Phase 1: Present the Outline (DO THIS FIRST)

Think HORIZONTALLY first — list ALL phases before adding detail to any one.

Present the outline to the human with:
- Phase names and one-sentence descriptions
- For each phase: which files will be touched (names only, no code)
- Rough shape of changes per phase (one sentence)
- Dependency order between phases (what must come before what)
- Test strategy per phase (type of test, not the test itself)

Keep each phase description to 3-5 lines. Aim for 3-7 phases total.

Then ask:

> Does this phasing make sense? Should any phases be split or merged?

**STOP HERE. Wait for human response.**

### Phase 2: Structural Review with outline-reviewer (AFTER HUMAN APPROVES PHASING)

Once the human confirms the phasing (or you've incorporated their adjustments), call the `outline-reviewer` agent. Pass it the draft outline text so it can review for:
- Sequencing issues (wrong dependency order)
- Missing phases (steps the outline skips)
- Granularity problems (phases that are too large)
- Test coverage gaps (phases without verification)

**Surface the outline-reviewer's findings to the human.** Present them as:

> Before I finalize the outline, the structural review found these issues:
> [list the findings]
> Should I adjust the outline to address these, or are they acceptable?

**STOP HERE. Wait for human response.**

### Phase 3: Write the Outline Doc (ONLY AFTER REVIEW IS RESOLVED)

Only after the human has addressed the outline-reviewer's findings (or explicitly dismissed them), write the final outline.

## Rules

1. **Horizontal before vertical.** Map all phases first. Don't deep-dive phase 1 before you've sketched phase 7.
2. **No code.** File names yes, code no. Code belongs in the plan.
3. **~300 lines max.** This is a skeleton, not a plan.
4. **Dependency order matters.** Each phase should build on the previous. Circular dependencies mean your phasing is wrong.
5. **Every phase must be independently verifiable.** If you can't test a phase in isolation, it's too big or too coupled.
6. **Match the design.** Every acceptance criterion from design.md should map to at least one phase. If it doesn't, you missed something.
7. Do NOT skip the outline-reviewer step. Structural problems caught here save hours of plan-writing and implementation rework.
8. Do NOT proceed to write the outline without human confirmation at BOTH checkpoints.

## Output

Save to `thoughts/shared/tasks/<task-slug>/outline.md` with this format:

```markdown
# Outline: <task title>
Date: <YYYY-MM-DD>
Task slug: <task-slug>

## Phase Overview
| Phase | Name | Dependencies | Files Touched | Test Type |
|-------|------|-------------|---------------|-----------|
| 1     | ...  | none        | ...           | unit      |
| 2     | ...  | Phase 1     | ...           | integration |

## Phase Details

### Phase 1: <name>
**Goal:** <one sentence>
**Files:** <list>
**Changes:** <one paragraph, no code>
**Verification:** <what type of test, what it checks>

### Phase 2: <name>
...

## Dependency Graph
<Text description or simple ASCII diagram of phase dependencies>

## Risk Notes
<Anything that might go wrong or need extra attention>
```

## Ending

End your response with exactly:

> Outline confirmed. Run `/create_plan` to write the full tactical plan.
