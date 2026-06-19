---
name: compose:brainstorm
description: "Use before any creative work - creating features, building components, adding functionality, or modifying behavior. Explores user intent, requirements and design before implementation."
hidden: true
---

# compose:brainstorm

**IRON LAW:** Do NOT invoke any implementation skill until the user has approved a design.

## When to Use

- User asks "let's build X" or "create a feature"
- Requirements are unclear or ambiguous
- Multiple architectural approaches exist
- Before any creative work

## When to Skip

Skip brainstorm scope check when ALL true:
- Task is a specific bug fix
- Requirements are fully stated (no design ambiguity)
- No architectural decisions needed

## Core Flow

1. **Explore project context**: Read relevant files, docs, recent commits
2. **Ask clarifying questions**: One at a time. What exactly? Why? How should it work?
3. **Propose 2-3 approaches**: With tradeoffs and your recommendation
4. **Present design sections**: Get approval after each section
5. **Self-review**: Placeholder scan, internal consistency, scope, ambiguity
6. **Transition**: Invoke `compose:plan` after design is approved

## Design Sections

When writing a design, cover:
- Goal and non-goals
- Architecture overview
- Component/module breakdown
- Data flow
- API surface
- Error handling
- Open questions

## Constraints

- No code written until design is approved (HARD-GATE)
- Autonomous override: When no user available, skip approval gates and decide yourself
- Terminal state is invoking `compose:plan` — never invoke any implementation skill directly
