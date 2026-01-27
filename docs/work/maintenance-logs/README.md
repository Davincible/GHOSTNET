# Maintenance Logs

This folder contains chronological logs of maintenance work, bug fixes, small improvements, and session handoffs.

## Purpose

Maintenance logs capture work that doesn't warrant a full story:

- Bug fixes (simple)
- Small improvements
- Configuration changes
- Dependency updates
- Session handoffs (context for next agent/developer)

## Structure

Logs are organized by month:

```
maintenance-logs/
├── README.md           # This file
├── 2026-01-maintenance.md
├── 2026-02-maintenance.md
└── ...
```

## When to Use

| Work Type | Use Story | Use Maintenance Log |
|-----------|-----------|---------------------|
| New feature | Yes | No |
| Large refactor | Yes | No |
| Bug fix (complex) | Yes | No |
| Bug fix (simple) | No | Yes |
| Small improvement | No | Yes |
| Config change | No | Yes |
| Dependency update | No | Yes |
| Session handoff | No | Yes |

## Entry Format

### Simple Fix

```markdown
### Fixed [issue description]

**Type:** Bug fix | Improvement | Config | Dependency
**Commit:** abc1234
**Time:** ~30 min

[Description of what was done and why]
```

### Session Handoff

```markdown
## Session Handoff — YYYY-MM-DD HH:MM

### What Was Done
- [Completed item 1]
- [Completed item 2]

### Current State
- [Story X] at Y% complete
- [Branch status]

### What's Next
1. [Next step 1]
2. [Next step 2]

### Watch Out For
- [Gotcha 1]
- [Gotcha 2]
```

## Related

- [[../status]] - Current project status
- [[../../workflow/agile/maintenance]] - Maintenance workflow guide
- [[../../workflow/templates/maintenance-log-template]] - Entry template
