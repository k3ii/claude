#!/usr/bin/env bash
set -e

REPO_NAME="k3ii/claude"
SPARSE_PATHS=".claude/agents .claude/skills"

# Use SSH by default; fall back to HTTPS if --https flag is passed
REPO_URL="git@github.com:${REPO_NAME}.git"
if [ "${1:-}" = "--https" ]; then
  REPO_URL="https://github.com/${REPO_NAME}.git"
fi

# --- helpers ---
cleanup() {
  if [ -n "$TMPDIR_PATH" ] && [ -d "$TMPDIR_PATH" ]; then
    rm -rf "$TMPDIR_PATH"
  fi
}
trap cleanup EXIT

info()  { printf "\033[1;34m==>\033[0m %s\n" "$1"; }
ok()    { printf "\033[1;32m  ✓\033[0m %s\n" "$1"; }
warn()  { printf "\033[1;33m  !\033[0m %s\n" "$1"; }
error() { printf "\033[1;31m  ✗\033[0m %s\n" "$1"; exit 1; }

# --- prerequisites ---
command -v git >/dev/null 2>&1 || error "git is required but not installed."

# --- sparse checkout from source repo ---
info "Fetching QRSPI framework from ${REPO_NAME}..."

TMPDIR_PATH=$(mktemp -d)
cd "$TMPDIR_PATH"

git init -q
git remote add origin "$REPO_URL"
git config core.sparseCheckout true

for path in $SPARSE_PATHS; do
  echo "$path" >> .git/info/sparse-checkout
done

git pull --depth 1 -q origin main
cd - >/dev/null

# --- back up existing files ---
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

for dir in .claude/agents .claude/skills; do
  if [ -d "$dir" ]; then
    BACKUP="${dir}.backup.${TIMESTAMP}"
    warn "Existing ${dir}/ found — backing up to ${BACKUP}/"
    mv "$dir" "$BACKUP"
  fi
done

# --- install agents ---
info "Installing agents..."
mkdir -p .claude/agents
for f in "$TMPDIR_PATH"/.claude/agents/*.md; do
  [ -f "$f" ] || continue
  cp "$f" .claude/agents/
  ok "$(basename "$f")"
done

# --- install skills ---
info "Installing skills..."
mkdir -p .claude/skills
for skill_dir in "$TMPDIR_PATH"/.claude/skills/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name=$(basename "$skill_dir")
  mkdir -p ".claude/skills/${skill_name}"
  cp "${skill_dir}"SKILL.md ".claude/skills/${skill_name}/SKILL.md"
  ok "/$(echo "$skill_name" | tr '_' ' ')"
done

# --- create thoughts directory structure ---
info "Creating thoughts/ workspace..."
for dir in thoughts/shared/plans thoughts/shared/tasks; do
  mkdir -p "$dir"
  if [ ! -f "${dir}/.gitkeep" ]; then
    touch "${dir}/.gitkeep"
  fi
  ok "$dir/"
done

# --- write quickstart guide ---
info "Writing quickstart guide..."
cat > .claude/QRSPI_QUICKSTART.md << 'QUICKSTART'
# QRSPI Quick Start

## The 7 Steps

| Step | Command                | What it does                                      |
|------|------------------------|---------------------------------------------------|
| 1    | `/questions`           | Surface clarifying questions before any research   |
| 2    | `/research_codebase`   | Objective, opinion-free codebase research          |
| 3    | `/create_design`       | Collaborative design doc — where are we going?     |
| 4    | `/create_outline`      | Structural skeleton — how do we get there?         |
| 5    | `/create_plan`         | Detailed tactical implementation plan              |
| 6    | `/create_worktree`     | Set up an isolated git worktree                    |
| 7    | `/implement_plan`      | Execute the plan phase by phase                    |

Bonus: `/commit` — create git commits with user approval.

## Example Session

```
/questions Add OAuth2 support to the login endpoint
# Answer the clarifying questions, then:
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
    questions.md      # Step 1
    research.md       # Step 2
    design.md         # Step 3
    outline.md        # Step 4
  plans/
    YYYY-MM-DD-<task-slug>.md  # Step 5
```

## Sub-Agents

These are called automatically by the slash commands — you don't invoke them directly:

- `@query-planner` — decomposes research into unbiased sub-questions
- `@codebase-locator` — finds files and directory structures
- `@codebase-analyzer` — traces system and data flows
- `@codebase-pattern-finder` — finds similar patterns and conventions
- `@thoughts-locator` — finds prior research and decisions
- `@thoughts-analyzer` — extracts insights from prior documents
- `@design-critic` — stress-tests design proposals
- `@outline-reviewer` — reviews outline sequencing and completeness
- `@web-search-researcher` — searches the web for external context
QUICKSTART
ok ".claude/QRSPI_QUICKSTART.md"

# --- summary ---
echo ""
info "QRSPI framework installed successfully!"
echo ""
echo "  Agents:  $(ls .claude/agents/*.md 2>/dev/null | wc -l | tr -d ' ') installed"
echo "  Skills:  $(ls -d .claude/skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ') installed"
echo ""
echo "  Open this repo in Claude Code and run:  /questions <your task>"
echo ""
