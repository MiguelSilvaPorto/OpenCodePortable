---
name: compose:merge
description: "Use when implementation is complete, all tests pass, and you need to decide how to integrate the work. Guides completion with structured options."
hidden: true
---

# compose:merge

**IRON LAW:** NO MERGE WITHOUT TESTS PASSING. Every feature must be verified before integration.

## When to Use

- Implementation is complete
- All tests pass
- Code has been reviewed
- Need to decide: merge, PR, or discard

## Core Flow

1. **Verify tests pass**: Run the full test suite. If fail, STOP. Fix tests first.
2. **Detect environment**:
   - Normal repo (on a named branch)
   - Detached HEAD
   - Worktree
3. **Present options to user**:
   - **Merge locally**: Integrate into the main branch
   - **Create PR**: Push and create a pull request (if `gh` is available)
   - **Keep as-is**: Leave branch for later
   - **Discard**: Remove the changes (requires typed confirmation)
4. **Execute choice**:
   - Merge: `git checkout main && git merge feature`
   - PR: `gh pr create`
   - Discard: `git checkout . && git clean -fd`
5. **Cleanup**: Remove worktrees, temp files, restore state

## Constraints

- Always verify tests before merge — never assume
- Discard requires the user to type "yes, discard" explicitly — no single-key confirmation
- After merge, call `brain_add` to record what was completed
- After merge, call `brain_sync` to sync memory to markdown
