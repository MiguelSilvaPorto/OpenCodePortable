---
name: compose:tdd
description: "Use when implementing any feature or bugfix, before writing implementation code. Strict test-driven development with RED-GREEN-REFACTOR cycle."
hidden: true
---

# compose:tdd

**IRON LAW:** NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST.

## When to Use

- Implementing any feature
- Fixing any bug
- Adding any new functionality

## Core Flow

### RED Phase
1. Write ONE minimal failing test
   - One behavior, clear name, real assertions
   - Test must be minimal — only what's needed to define the behavior
2. **Verify RED**: Run test, confirm it fails correctly
   - Failure must be from the test assertion, not from errors/exceptions
   - If test passes immediately: you wrote too much code first, or test is too weak

### GREEN Phase
3. Write the SIMPLEST code to pass
   - No extra features
   - No refactoring
   - No edge case handling that isn't tested
4. **Verify GREEN**: Run test, confirm it passes
   - Run ALL tests, not just the new one
   - ALL must pass

### REFACTOR Phase
5. Remove duplication, improve names, extract helpers
   - Keep tests green throughout
   - Each refactor step: change → run tests → confirm

### Repeat
6. Go to step 1 for the next behavior

## Iron Law Enforcement

| Rationalization | Reality |
|----------------|---------|
| "I'll write the test after" | No. Code before test = delete it. Start over. |
| "This code is simple enough" | Simple = fastest to write test first |
| "The test would pass anyway" | Prove it. Write test, watch it fail. |
| "I'm just exploring" | Add a failing test for what you find |
| "I'll add tests later" | Later = never. Add tests now. |

## Constraints

- Code before test? Delete it. Start over. No exceptions.
- Don't keep as "reference", don't "adapt", don't look at it
- Tests written after code pass immediately = prove nothing
- Violating the letter of the rules = violating the spirit
- Each cycle is ONE behavior. Don't batch behaviors.
