---
name: compose:plan
description: "Use when you have a spec or requirements for a multi-step task, before touching code. Creates detailed implementation plans with bite-sized TDD steps."
hidden: true
---

# compose:plan

**IRON LAW:** NO IMPLEMENTATION WITHOUT A PLAN. Every multi-step task must have a written plan before execution.

## When to Use

- After brainstorming/design phase
- Requirements are clear and well-defined
- Task involves 2+ steps or multiple files

## Core Flow

1. **Scope check**: Break multi-subsystem specs into separate plans
2. **Map file structure**: Which files created/modified, responsibilities
3. **Write bite-sized tasks**: 2-5 min each, TDD cycles, frequent commits
4. **Plan header**: Goal, architecture, tech stack
5. **Task structure**: Each task must have:
   - Exact file paths
   - Complete code (NO placeholders)
   - Exact commands
6. **Self-review**: Spec coverage, placeholder scan, type consistency
7. **Execution handoff**: Decide subagent vs inline execution

## Plan Format

```markdown
# Plan: [Feature Name]
_Goal: [brief description]_
_Architecture: [key decisions]_
_Tech stack: [languages, frameworks]_

## Tasks

### T1: [Task name]
- Files: [paths]
- What: [description]
- Covers: [spec sections]
- Commands: [test/verify commands]

### T2: [Task name]
...
```

## Constraints

- No placeholders — every step must contain actual content
- Plans saved to `.brain/skills/plan/plans/YYYY-MM-DD-feature-name.md`
- Each task should be independently verifiable (testable)
- After plan is written, invoke `compose:subagent` or `compose:task` for execution
