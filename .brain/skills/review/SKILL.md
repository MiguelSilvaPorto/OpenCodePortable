---
name: compose:review
description: "Use when completing tasks, implementing major features, or before merging. Structured code review with compliance and quality checks."
hidden: true
---

# compose:review

**IRON LAW:** NO CODE MERGED WITHOUT REVIEW. Every change must be reviewed for spec compliance and code quality.

## When to Use

- After task implementation is complete
- Before merging code
- When receiving code from subagents
- Before creating a PR

## Core Flow

1. **Get the diff**: `git diff base..head` or review files changed
2. **Check spec compliance**:
   - Does the code implement the spec?
   - Are all requirements covered?
   - Are there edge cases not handled?
3. **Check code quality**:
   - Readability: Is the code clear and self-documenting?
   - Structure: Is it properly organized?
   - Duplication: Is there repeated code that should be extracted?
   - Error handling: Are errors handled properly?
   - Testing: Are there tests for the change?
4. **Check architecture**:
   - Does it follow the project's patterns?
   - Does it introduce unnecessary dependencies?
   - Does it violate separation of concerns?

## Review Report Format

```markdown
## Review: [Feature/Fix]

### Spec Compliance
- ✅ Requirement 1: [evidence]
- ✅ Requirement 2: [evidence]
- ❌ Missing: [gap]

### Code Quality
- ✅ Strengths: [what's good]
- ⚠️ Issues:
  - Critical: [must fix before merge]
  - Important: [should fix]
  - Minor: [nice to have]

### Architecture
- [consistent with design / deviation]

### Decision
- [approve / changes requested / reject]
```

## Constraints

- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues but don't block on them
- Be constructive — point to solutions, not just problems
- After review, invoke `compose:merge` if approved, or `compose:feedback` if changes needed
