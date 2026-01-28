---
name: feature-dev
description: Trigger when starting implementation of a new feature. Creates worklog, identifies invariants, runs persona reviews.
---

# Feature Development Workflow

## Before Writing Code

1. **Read the spec** — Check `SPEC.md` for feature requirements
2. **Check existing skills** — Load relevant patterns from `.claude/skills/`
3. **Create worklog** — `WORKLOG.md` with milestones and invariants

## Worklog Template

```markdown
# Feature: [Feature Name]

## Milestones
- [ ] M1: [First atomic change]
- [ ] M2: [Second atomic change]
- [ ] M3: [Third atomic change]

## Invariants
- **INV-1:** [Verifiable condition that must always hold]
- **INV-2:** [Another invariant]

## Skills Loaded
- `/adb-logcat` — for log parsing patterns
- `/swift-macos` — for SwiftUI patterns

## Session Log
### Session 1 (YYYY-MM-DD)
- Started feature development
- **Next:** Complete M1
```

## Invariant Guidelines

✅ **Good (verifiable):**
- "INV-1: No log entry is lost during pause/resume"
- "INV-2: ADB disconnect is detected within 500ms"

❌ **Bad (vague requirements):**
- "Must handle ADB disconnect properly"
- "Should be performant"

## Persona Review Checkpoints

After M1 and M2:
```
@Security-Agent, review the implementation
@UX-Agent, review the UX
@Mobile-Agent, verify Android compatibility
```

## Commit Guidelines

- Atomic commits: one logical change per commit
- 3-5 commits per feature
- Include invariant IDs in commit messages when relevant

## The Worklog Smell Test

Before starting, check:
- Worklog > 100 lines for a < 2 hour task? Cut it.
- More than 5 commits? Merge related changes.
- Invariants for UI-only changes? Skip them.
