---
name: compose:report
description: "Write final-state reports consolidating what was done, spec iterations, and decisions. Ensures knowledge persists across sessions."
hidden: true
---

# compose:report

**IRON LAW:** NO FEATURE IS COMPLETE UNTIL IT'S DOCUMENTED. Knowledge that isn't written down doesn't exist for future sessions.

## When to Use

- After implementation is verified
- When wrapping up a session
- When completing a research task
- Before `compose:merge`

## Core Flow

1. **Gather context**: What was done? What decisions were made?
2. **Write final state report**:
   - Feature implemented
   - Files changed/created
   - Architecture decisions
   - Known limitations
   - Future work
3. **Save to memory**: Use `brain_add` to store report
4. **Save checkpoint**: Use `brain_checkpoint` to save session state

## Report Format

```markdown
## Report: [Feature/Fix]

### Summary
[Brief description of what was done]

### Changes
- `path/to/file.py` — [description of change]
- `path/to/new.py` — [description of new file]

### Decisions
- [Decision 1]: [Rationale]
- [Decision 2]: [Rationale]

### Test Results
```
[verification output]
```

### Known Limitations
- [Issue 1]
- [Issue 2]

### Future Work
- [Enhancement 1]
- [Enhancement 2]
```

## Constraints

- Store report via `brain_add` for cross-session persistence
- Be specific — include file paths, function names, decisions
- Don't document obvious things — focus on what's unique
- After report, invoke `compose:merge` to complete the cycle
