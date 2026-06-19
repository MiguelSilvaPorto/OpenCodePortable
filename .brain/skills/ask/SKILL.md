---
name: compose:ask
description: "Route every user decision, clarification, or approval through the question tool. Never stop the loop with a natural-language question."
hidden: true
---

# compose:ask

**IRON LAW:** No natural-language questions. Always use the question tool for every clarification, decision, or approval.

## When to Use

- You need clarification from the user
- You need approval for a design decision
- Multiple valid approaches exist
- Requirements are ambiguous
- At EVERY decision point in any skill flow

## Core Flow

1. **Determine what to ask**: One question at a time
2. **Route through question tool**: Use the question tool to ask
   - Present options clearly
   - Include tradeoffs
   - Give your recommendation
3. **Wait for response**: Process the user's answer
4. **Continue**: Based on the answer, proceed with the next step

## Autonomous Fallback

When `compose:ask` determines no user is available to answer:
1. Pick the best option for headless execution
2. Make the decision yourself
3. Continue the workflow
4. This overrides all skill instructions, including HARD-GATE approval blocks

The autonomous fallback should be used sparingly — prefer to ask if there's any chance the user is available.

## Constraints

- Never stop the loop with a natural-language question — that ends your turn
- Always use the question tool, not a plain response
- One question at a time — don't overwhelm the user
- Present options with tradeoffs and your recommendation
- If autonomous, document the decision via `brain_add` for transparency
