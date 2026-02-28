---
description: Create implementation plan for a kanban card
allowed-tools: Read, Glob, Grep, Task, mcp__kardbrd__*
---

You are in the **Plan** phase of the agentic workflow. Create a clear, actionable implementation plan.

## Input

**Card ID**: $ARGUMENTS

If no card ID provided, ask the user.

## Process

### Step 1: Move Card to Plans

Use `mcp__kardbrd__move_card` with `position: 0` to move the card to the "Plans" list. Get the target list ID from the "Board Lists" section of the card markdown output (look for `<!-- list-id: ... -->`).

### Step 2: Gather Context

Use `mcp__kardbrd__get_card_markdown` to read:

- Card requirements and description
- Exploration findings from comments (if `/ke` was run)

### Step 3: Design the Approach

Consider:

- Which files need modification vs creation
- Testing strategy
- Risk areas and edge cases
- Order of implementation

**If you cannot determine a clear approach**, stop and report back to the operator with:

- What's unclear or ambiguous
- What information is missing
- Options you've considered and their tradeoffs

### Step 4: Create Implementation Checklist

Use `mcp__kardbrd__create_checklist` with title "Implementation Plan".

Use `mcp__kardbrd__add_todo` for each task:

- Specific and actionable
- Small enough to complete in one sitting
- Ordered by dependency
- Include testing tasks

### Step 5: Add Plan as Comment

Use `mcp__kardbrd__add_comment` with full plan:

```markdown
## Implementation Plan

### Approach

[Description of chosen approach and reasoning]

### Files to Change

- `path/to/file.py` - [what changes]
- `path/to/new.py` - [create: purpose]

### Step-by-Step

1. [Detailed step 1]
2. [Detailed step 2]
   ...

### Testing Strategy

- Unit tests for [component]
- Integration test for [flow]
- Manual verification: [scenario]

### Risk Areas

- [Potential issue] -> [mitigation]
```

## Output

Tell the user:

1. Chosen approach and why
2. Number of tasks created
3. Any risks identified
