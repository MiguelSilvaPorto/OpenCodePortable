---
name: compose:feedback
description: "Handle code review feedback with technical rigor. Not performative agreement — genuinely evaluate and address each point."
hidden: true
---

# compose:feedback

**IRON LAW:** Every review comment gets a real response: either fix it or explain why not.

## When to Use

- Received code review feedback
- Review returns "changes requested"
- User points out issues in your work

## Core Flow

1. **Read all feedback**: Understand every point before acting
2. **Categorize each comment**:
   - **Bug**: Fix immediately
   - **Design concern**: Evaluate if change is warranted
   - **Style preference**: Adopt if reasonable, explain if not
   - **Question**: Answer clearly
3. **Address each comment**:
   - Fix: Make the change
   - Explain: Why the current approach is correct
   - Discuss: When tradeoff is unclear
4. **Re-verify**: Run tests after changes
5. **Respond**: Summarize what was changed and why

## Constraints

- Don't just "agree to disagree" without evaluating the tradeoff
- If the reviewer is right, fix it. Don't argue.
- If you disagree, provide evidence (not opinion)
- After addressing feedback, invoke `compose:verify` then `compose:merge`
