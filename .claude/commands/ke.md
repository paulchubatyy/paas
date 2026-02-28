---
description: Explore codebase and gather context for a kanban card
allowed-tools: Read, Glob, Grep, Task, mcp__kardbrd__*
---

You are in the **Explore (Research)** phase of the agentic workflow. Your job is to be **deeply curious** - dig into the codebase until you thoroughly understand how to approach this task. Don't settle for surface-level findings.

## Input

**Card ID**: $ARGUMENTS

If no card ID provided, ask the user.

## Mindset: Be Relentlessly Curious

- **Don't stop at file names** - read the actual code
- **Follow the threads** - when you find something interesting, dig deeper
- **Look for examples** - find similar features that work well
- **Check the tests** - they reveal expected behavior and edge cases
- **Trace the data flow** - understand how data moves through the system
- **Question assumptions** - verify what you think you know

## Process

### Step 1: Read the Card Thoroughly

Use `mcp__kardbrd__get_card_markdown` to understand:

- Requirements and acceptance criteria
- Existing context and comments
- Any attachments that might contain specs

Extract **key terms** and **concepts** that will guide your search.

### Step 1.5: Check Branch Freshness

If a card branch exists (`card/<card-id>`), check how far behind main it is:

```bash
git fetch origin main
git rev-list --count card/<card-id>..origin/main 2>/dev/null
```

If behind by >0 commits:

- Print warning: "Card branch is N commits behind main (exploration will use current codebase, not the stale branch)."
- Exploration proceeds from current working tree (main or wherever the agent is), NOT from the card's stale worktree.

If the branch doesn't exist, skip this check silently.

### Step 2: Multi-Pass Deep Exploration

Run multiple focused explorations. Use the Task tool with `subagent_type: "Explore"` and explicitly request **"very thorough"** exploration level. Do NOT combine these into one vague query - run separate targeted searches:

**Pass 1: Find Similar Features**

- Search for existing implementations of similar functionality
- How does the codebase handle comparable use cases?
- What patterns were used? What can be reused?

**Pass 2: Trace the Architecture**

- Where does this feature fit in the system?
- What's the data flow (models -> views -> templates -> frontend)?
- What API endpoints are involved?
- How do frontend components interact with backend?

**Pass 3: Examine Tests & Edge Cases**

- What tests exist for related features?
- What edge cases do they cover?
- What validation/error handling patterns are used?

**Pass 4: Dependencies & Integration Points**

- What external services/libraries are involved?
- How do other parts of the system interact with this area?
- Are there events, signals, or hooks to consider?

### Step 3: Read Key Files In Depth

Don't just list files - **actually read them** using the Read tool:

- Read at least 3-5 most relevant files completely
- Look at the imports to understand dependencies
- Study the function signatures and class structures
- Note any comments or docstrings that explain intent

### Step 4: Verify Your Understanding

Before documenting findings, verify:

- [ ] You understand the data models involved
- [ ] You know which views/API endpoints handle this
- [ ] You've seen how the frontend renders related features
- [ ] You've found relevant tests
- [ ] You can trace the complete user flow

If any are unclear, explore more.

### Step 4.5: Assign Labels to the Card

Based on your exploration findings, assign labels to help humans navigate the board at a glance.

1. **Get available labels**: Call `mcp__kardbrd__get_board_labels` with the board ID (from the card markdown header).

2. **Determine which labels apply** based on the board's label definitions and the nature of the changes discovered.

3. **Preserve existing labels**: Parse any existing labels from the `**Labels:**` line in the card markdown. Build a name->ID mapping from the board labels response.

4. **Merge and update**: Combine existing labels with newly determined ones (union), then call `mcp__kardbrd__update_card` with `card_id` and the merged `label_ids` list.

Skip this step if no labels apply.

### Step 5: Add Exploration Findings to Card

Use `mcp__kardbrd__add_comment` to document your findings:

```markdown
## Exploration Findings

### Key Files

- `path/file.py:123` - [purpose, key functions]
- `path/other.py:456` - [purpose, key functions]

### Data Flow

[How data moves: Model -> View -> Template -> JS -> API]

### Existing Patterns

[How similar things are done in the codebase - with code examples]

### Related Tests

- `path/test.py::TestClass::test_name` - [what it tests]

### Dependencies

- External: [libraries, services]
- Internal: [modules, shared utilities]

### Constraints & Gotchas

[Limitations, edge cases, tricky areas]

### Open Questions

[Anything needing clarification]
```

## Output

Tell the user:

1. What you discovered (key insights, not just file lists)
2. Existing patterns and conventions found
3. Constraints or limitations discovered
4. Open questions that need clarification

## Quality Check

Before finishing, ask yourself:

- Could another agent implement this feature using only my findings?
- Did I provide specific file:line references, not just file names?
- Did I show actual code patterns, not just describe them?
- Are there any areas I glossed over that deserve more investigation?

If the answer to any is "no", keep exploring.
