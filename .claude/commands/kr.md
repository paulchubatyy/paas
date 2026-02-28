---
description: Full review of kanban card (runs all review types)
allowed-tools: Task, mcp__kardbrd__*
---

You are performing a **Full Review** of a kanban card implementation. This orchestrates specialized review sub-agents and consolidates their findings.

## Input

**Card ID**: $ARGUMENTS

If no card ID provided, ask the user.

## Review Areas

| Area      | Focus                                     |
| --------- | ----------------------------------------- |
| Security  | Vulnerabilities, auth, data protection    |
| Code      | Quality, patterns, tests, performance     |
| Docs      | Code docs, API docs, guides               |
| UX        | User flow, accessibility, feedback states |
| Mobile UX | Phone-specific, touch, responsiveness     |

## Process

### Step 1: Move Card to Review

Use `mcp__kardbrd__move_card` with `position: 0` to move the card to the "Review" list. Get the target list ID from the "Board Lists" section of the card markdown output (look for `<!-- list-id: ... -->`).

### Step 2: Gather Context

Use `mcp__kardbrd__get_card_markdown` to understand:

- What was implemented
- Which files changed
- What type of changes (backend, frontend, both)

### Step 3: Determine Applicable Reviews

Based on the changes:

- **Backend changes** (Python, API): Security, Code, Docs
- **Frontend changes** (templates, JS, CSS): Code, UX, Mobile UX, Docs
- **Full-stack changes**: All reviews

### Step 4: Execute Reviews in Sub-Agents

For each applicable review area, use the **Task tool** with `subagent_type: "general-purpose"`. Each sub-agent should:

1. Read the card context
2. Find and read the changed files (from implementation comments)
3. Review for its specific area
4. Return findings

Run independent reviews in parallel. Each sub-agent returns its findings to you.

**Security Review** should check:

- Input validation and sanitization
- Authentication and authorization
- Data exposure risks
- SQL injection, XSS, CSRF protections

**Code Review** should check:

- Code quality and readability
- Adherence to project patterns
- Test coverage
- Performance considerations

**Documentation Review** should check:

- Code comments and docstrings
- API documentation
- User-facing documentation updates

**UX Review** should check:

- User flow completeness
- Error states and feedback
- Accessibility (WCAG)
- Loading and empty states

**Mobile UX Review** should check:

- Touch targets (min 44px)
- Responsive layout
- Mobile-specific interactions

### Step 5: Consolidate and Update Card

Collect all sub-agent outputs and use `mcp__kardbrd__add_comment` to add **one** consolidated review:

```markdown
## Review Complete

### Overall Status: [Approved | Changes Requested]

### Security Review

[Findings or "Not applicable"]

### Code Review

[Findings]

### Documentation Review

[Findings]

### UX Review

[Findings or "Not applicable"]

### Mobile UX Review

[Findings or "Not applicable"]

### Critical Issues

- [List any critical issues across all reviews]
```

## Output

Tell the user:

1. Overall status
2. Summary from each review type
3. Total critical/important issues
