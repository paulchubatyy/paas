---
description: Load a kanban card into context
allowed-tools: mcp__kardbrd__*, Read
---

Load a kanban card into context for the current session.

## Input

**Card ID**: $ARGUMENTS

If no card ID provided, ask the user.

## Behavior

### First Card (No Card in Context)

This card becomes the **primary card** for the session:

1. Fetch card using `mcp__kardbrd__get_card_markdown`
2. Display the card details to the user
3. Remember this as the primary card for subsequent commands

### Additional Card (Primary Card Already Set)

When a primary card is already in context:

1. Fetch the new card using `mcp__kardbrd__get_card_markdown`
2. **Interlink the cards**: Add a link from the primary card to this card using `mcp__kardbrd__add_link`
3. Display the new card's content
4. Summarize how the cards relate (if apparent from their content)

## Output Format

```
## Card: [Title]
**ID**: [card_id] | **List**: [list_name] | **Board**: [board_name]

[Description summary]

### Checklists
[If any]

### Recent Comments
[Last 2-3 comments if any]

### Links
[If any]
```

If this is an additional card:

```
## Related Card: [Title]
**ID**: [card_id] | **List**: [list_name]

[Description summary]

---
Linked from primary card: [primary card title]
```

## Notes

- The primary card persists in context for the duration of the conversation
- Use this command to quickly pull in context from related cards
- Interlinks help maintain traceability between related work items
