---
name: compose:subagent
description: "Use when executing implementation plans with independent tasks. Dispatches subagents with spec compliance and code quality review per task."
hidden: true
---

# compose:subagent

**IRON LAW:** EVERY TASK MUST BE REVIEWED BEFORE MERGE. No subagent output is accepted without verification.

## When to Use

- Plan has 3+ independent tasks
- Tasks can be parallelized
- Each task has clear scope and boundaries
- Compose:plan has been invoked and a plan exists

## Core Flow

### Setup
1. Read the plan — extract all tasks with full text
2. Create task items with clear scope, files, and verification criteria

### Per Task Execution
For EACH task in the plan:

1. **Inject spec**: Pass the relevant spec sections as Intent to the subagent
2. **Dispatch implementer subagent**: Create a focused subagent bound to this task
   - Prompt includes: Intent from spec, full task text, relevant file context
3. **Spec compliance review**: Verify the implementation matches the spec
   - Check: all requirements met? edge cases handled? tests exist?
   - Gate: All in-scope claims must pass with evidence
4. **Code quality review**: Verify code quality
   - Check: readability, structure, error handling, testing
5. **Mark task done**: Record completion in the task tracker

### After All Tasks
1. Final review of the entire implementation
2. Verify no regressions (run all tests)
3. Transition to `compose:merge`

## Constraints

- Never dispatch multiple implementation subagents in parallel (they share state)
- Never skip reviews (spec compliance OR code quality)
- Spec compliance always precedes code quality review
- Each subagent must produce a report of what was done
- Continuous execution — no "should I continue?" prompts
- After completion, invoke `compose:merge`
