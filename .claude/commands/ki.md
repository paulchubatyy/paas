---
description: Implement a kanban card following the plan
allowed-tools: Read, Edit, Write, Glob, Grep, Bash, Task, mcp__kardbrd__*
---

You are in the **Implement (Execute)** phase of the agentic workflow. Execute the plan and build the solution.

## Input

**Card ID**: $ARGUMENTS

If no card ID provided, ask the user.

## Process

### Step 1: Read Card and Plan

Use `mcp__kardbrd__get_card_markdown` to read:

- Requirements
- Implementation plan (from comments)
- Checklist of tasks

### Step 2: Move Card to In Progress

Use `mcp__kardbrd__move_card` with `position: 0` to move the card to the "In Progress" list. Get the target list ID from the "Board Lists" section of the card markdown output (look for `<!-- list-id: ... -->`).

### Step 2.5: Branch Freshness Check (NO REBASE)

Check if the branch is behind main:

```bash
git fetch origin main
BEHIND=$(git rev-list --count HEAD..origin/main)
```

If BEHIND > 0, print a warning but do **NOT** rebase:

```
Branch is $BEHIND commits behind main. The plan was written for this code snapshot — proceeding WITHOUT rebase. Rebase will happen at PR time.
```

Do NOT offer to rebase. Do NOT rebase. The plan's file paths, line numbers, and context depend on this snapshot.

### Step 3: Execute the Plan

Work through the checklist systematically:

1. **Implement**: Write the code following the plan
2. **After each task**: Use `mcp__kardbrd__complete_todo` to check it off

Follow project conventions from CLAUDE.md:

- Follow existing patterns in the codebase
- Don't over-engineer

### Step 4: Track Blockers Only

Only add comments if you encounter a **blocker** that prevents progress:

```markdown
## Blocker

**Issue:** [What's blocking progress]
**Need:** [What's required to unblock]
```

Do NOT add progress comments for normal work - the todo checkoffs provide sufficient tracking.

### Step 5: Final Implementation Comment

When implementation is complete, add summary comment:

```markdown
## Implementation Complete

### Files Changed

- `path/to/file.py` - [what changed]
- `path/to/new.py` - [created: purpose]

### Key Decisions

- [Any deviations from plan and why]

### Testing Done

- [Tests written/run]

### Next Steps

Create a pull request for review.
```

### Step 6: Commit Changes

**This step is REQUIRED before reporting completion.**

Stage all changes and commit with a conventional commit message:

```bash
# Check what needs to be staged
git status

# Stage changed files (review the list, don't blindly add everything)
git add <files>

# Commit with card ID reference
git commit -m "$(cat <<'EOF'
<type>(<scope>): <description>

<Card ID>: <Card Title>
Card: https://app.kardbrd.com/c/<card-id>

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

Where `<type>` is one of: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, etc.

### Step 7: Verify Clean Working Tree

**Confirm there are no uncommitted changes:**

```bash
git status
```

Expected output should show a clean working tree.

**If there are still uncommitted changes, go back to Step 6 and commit them.**

Do NOT report the task as complete if there are uncommitted changes.

## Output

Tell the user:

1. What was implemented
2. Any deviations from the plan
3. Commit hash
