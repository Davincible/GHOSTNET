# Hotfixes

This folder contains documentation for urgent production fixes that bypass normal workflow.

## Purpose

Hotfixes are for production emergencies that can't wait for normal workflow:

- Production down
- Security vulnerability discovered
- Critical data corruption
- User-blocking bugs

## When to Use Hotfix Process

| Situation | Process |
|-----------|---------|
| Minor production bug | Normal bug fix workflow |
| Degraded service, workaround exists | Normal workflow, expedited |
| Production down, users blocked | **Hotfix workflow** |
| Security vulnerability | **Hotfix workflow** |

## Hotfix Workflow

### During Hotfix

1. **Identify and confirm** the issue
2. **Communicate status** (if team involved)
3. **Implement fix** on hotfix branch
4. **Test critical path** (minimal, focused)
5. **Deploy** immediately
6. **Verify resolution**

### After Hotfix

1. **Document** in this folder or maintenance log
2. **Add to gotchas** if applicable
3. **Create follow-up items** in backlog
4. **Post-mortem** if significant

## File Structure

For significant hotfixes, create a dedicated file:

```
hotfixes/
├── README.md                           # This file
├── HOTFIX-2026-01-22-api-500-errors.md  # Example
└── ...
```

## Hotfix Document Template

```markdown
---
type: hotfix
date: YYYY-MM-DD
severity: critical | high
status: resolved | monitoring
duration: X minutes
commits:
  - abc123
tags:
  - type/hotfix
  - hotfix/resolved
---

# HOTFIX-YYYY-MM-DD: [Brief Title]

## Incident

[What happened, when, impact]

## Cause

[Root cause analysis]

## Fix

[What was done]

## Impact

- **Duration:** X minutes
- **Affected:** [users, transactions, etc.]
- **Data loss:** [None | Description]

## Follow-up

- [ ] [Follow-up item 1]
- [ ] [Follow-up item 2]
```

## Git Workflow

```bash
# Create hotfix from latest release
git checkout v1.2.0
git checkout -b hotfix/v1.2.1

# Make fix, commit
git commit -m "fix: critical [description]"

# Tag and release
git tag -a v1.2.1 -m "Hotfix: [description]"
git push origin v1.2.1 hotfix/v1.2.1

# Merge back to main
git checkout main
git merge hotfix/v1.2.1
```

## Lightweight Alternative

For smaller projects or minor hotfixes, a maintenance log entry is sufficient:

```markdown
### HOTFIX: YYYY-MM-DD HH:MM — [Brief Title]

**Issue:** [What went wrong]
**Cause:** [Root cause]
**Fix:** [What was done] (commit `abc123`)
**Duration:** [Time to resolve]
**Follow-up:** [Any needed follow-up]
```

---

## Current Status

*No hotfixes recorded yet — project is pre-production.*

## Related

- [[../maintenance-logs/]] - Maintenance logs (for minor fixes)
- [[../status]] - Current project status
- [[../../workflow/agile/maintenance#hotfix-workflow]] - Full hotfix process
