---
name: compose:debug
description: "Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes. Four-phase systematic debugging."
hidden: true
---

# compose:debug

**IRON LAW:** NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.

## When to Use

- Any bug or unexpected behavior
- Test failures
- Error messages
- Regression in functionality

## Core Flow

### Phase 1: Root Cause Investigation
1. Read errors carefully — every word matters
2. Reproduce the issue consistently
3. Check recent changes (git log, diffs)
4. Gather evidence at component boundaries
5. Trace data flow from input to failure point
6. DO NOT propose fixes yet

### Phase 2: Pattern Analysis
1. Find working examples in the same codebase
2. Compare against references (similar implementations)
3. Identify what's different between working and failing
4. Understand dependency chain

### Phase 3: Hypothesis and Testing
1. Form a single hypothesis: "X causes Y because Z"
2. Test minimally — one variable at a time
3. Verify before continuing
4. If disproven, form new hypothesis

### Phase 4: Implementation
1. Create failing test (via `compose:tdd`) that reproduces the bug
2. Implement the minimal fix
3. Verify fix with the test
4. Run ALL tests to confirm no regression

## If 3+ Fixes Fail

STOP and question the architecture — not just symptoms.

This is a WRONG ARCHITECTURE, not a failed hypothesis.
- Re-read the component design
- Question assumptions
- Consider redesigning the affected area

## Constraints

- DO NOT propose fixes before root cause is identified
- DO NOT fix symptoms — fix the root cause
- Tests must reproduce the bug before AND after fix
- Document the root cause and fix in `brain_add` after resolution
