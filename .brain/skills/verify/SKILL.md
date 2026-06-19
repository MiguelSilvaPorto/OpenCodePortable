---
name: compose:verify
description: "Use when about to claim work is complete, fixed, or passing, before committing or creating PRs. Evidence-before-claims verification gate."
hidden: true
---

# compose:verify

**IRON LAW:** NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.

## When to Use

- Before saying "it's done"
- Before committing code
- Before submitting a PR
- After applying a fix
- When asked "does it work?"

## Core Flow

1. **IDENTIFY**: What command proves this claim?
   - Tests? Build? Lint? Typecheck? Manual reproduction?
   - Be specific: `python test.py`, `npm run build`, etc.

2. **RUN**: Execute the FULL command
   - Fresh execution — not from memory
   - Complete output — not truncated
   - No assumptions about results

3. **READ**: Examine the output
   - Check exit code (0 = success, non-zero = failure)
   - Count failures (0 failing tests, 0 lint errors, etc.)
   - Verify the output matches the claim

4. **VERIFY**: Does the output confirm the claim?
   - "Tests pass" → all tests pass, not just the one you care about
   - "Build succeeds" → build completes without errors
   - "Fix works" → the specific scenario now works

5. **ONLY THEN**: Make the claim
   - "Done" = verified. Not "I think it's done".

## Rationalization Prevention

| Thought | Reality |
|---------|---------|
| "I'm confident it works" | Confidence ≠ evidence. Run it. |
| "It should be fine" | "Should" = lying, not verifying |
| "It compiled before" | Fresh context, fresh run |
| "The fix seems obvious" | Obvious fixes still break things |

## Constraints

- "Should", "probably", "seems to" = lying, not verifying
- Confidence != evidence. No exceptions without user permission
- If verification fails, transition to `compose:debug`
- After verification passes, transition to `compose:review` (if code) or `compose:report` (if research)
