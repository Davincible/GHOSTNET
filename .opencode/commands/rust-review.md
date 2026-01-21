---
description: Thorough rust review practices
agent: akira-reviewer
subtask: true
---

Recent git commits:
!`git log --oneline -10`

You task with reviewing the latest code based on:

---
## Gathering Context
**Diffs alone are not enough.** After getting the diff, read the entire file(s) being modified to understand the full context. Code that looks wrong in isolation may be correct given surrounding logic—and vice versa.
- Use the diff to identify which files changed
- Read the full file to understand existing patterns, control flow, and error handling
- Check for existing style guide or conventions files (CONVENTIONS.md, AGENTS.md, .editorconfig, etc.)
---
## What to Look For
**Bugs** - Your primary focus.
- Logic errors, off-by-one mistakes, incorrect conditionals
- If-else guards: missing guards, incorrect branching, unreachable code paths
- Edge cases: null/empty/undefined inputs, error conditions, race conditions
- Security issues: injection, auth bypass, data exposure
- Broken error handling that swallows failures, throws unexpectedly or returns error types that are not caught.
**Structure** - Does the code fit the codebase?
- Does it follow existing patterns and conventions?
- Are there established abstractions it should use but doesn't?
- Excessive nesting that could be flattened with early returns or extraction
**Performance** - Only flag if obviously problematic.
- O(n²) on unbounded data, N+1 queries, blocking I/O on hot paths

**In General**
- Production readiness
- Best practices
- Any major security vulnerabilities
- Any major performance bottlenecks
- Does this code contain any potential surface areas for performance issues or security issues that we have not thought about yet?
- Are the test functionally correct, and testing business logic?
---
## Before You Flag Something
**Be certain.** If you're going to call something a bug, you need to be confident it actually is one.
- Only review the changes - do not review pre-existing code that wasn't modified
- Don't flag something as a bug if you're unsure - investigate first
- Don't invent hypothetical problems - if an edge case matters, explain the realistic scenario where it breaks
- If you need more context to be sure, use the tools below to get it
**Don't be a zealot about style.** When checking code against conventions:
- Verify the code is *actually* in violation. Don't complain about else statements if early returns are already being used correctly.
- Some "violations" are acceptable when they're the simplest option. A `let` statement is fine if the alternative is convoluted.
- Excessive nesting is a legitimate concern regardless of other style choices.
- Don't flag style preferences as issues unless they clearly violate established project conventions.
---

Please critically review the lastest relevant Rust git commit. Provide thourogh feedback, but don't invent things

IMPORTANT: Please use your rust skills, call the skill mcp to load all relevant skills, and to thoroughly perform the review

$1
