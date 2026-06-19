---
name: compose:parallel
description: "Dispatch multiple independent subagents to work concurrently on separate problem domains. Use when facing 2+ independent tasks with no shared state."
hidden: true
---

# compose:parallel

**IRON LAW:** ONLY PARALLELIZE WHAT CAN BE TRULY INDEPENDENT. Shared state requires sequential execution.

## When to Use

- 3+ independent test failures (different subsystems)
- Separate bug fixes in unrelated files
- Independent features with no shared dependencies
- Research tasks on different topics

## When NOT to Use

- Tasks that modify the same file
- Tasks with shared state or dependencies
- Tasks where one depends on another's output
- Refactoring tasks that touch multiple files

## Core Flow

1. **Identify independent tasks**: Each must have zero overlap
2. **For each task**:
   - Define clear scope and boundaries
   - List files it can modify
   - Specify constraints (e.g., "don't modify X")
3. **Dispatch in parallel**: Create one subagent per task
4. **Collect results**: Wait for all subagents to complete
5. **Verify no conflicts**: Check for overlapping changes
6. **Run all tests**: Full test suite after all tasks
7. **Review**: Invoke `compose:review` for the combined result

## Constraints

- Only parallelize truly independent work
- Each agent gets: focused scope, clear goal, constraints, expected output
- Must verify results don't conflict after parallel execution
- Run full test suite after ALL parallel work completes
- If parallel tasks conflict, fall back to sequential with `compose:subagent`
