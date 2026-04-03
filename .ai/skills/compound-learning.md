# Skill: Compound Learning

## Trigger
After Step 10 (finalize) in implement-issue workflow — document what was learned.

## When to run
- Issue required 2+ iterations
- A non-obvious bug pattern was discovered
- The approach changed during implementation
- A workaround was needed

## When to skip
- Trivial change (<20 lines)
- 1 iteration, no problems
- Plain text/config change

## Steps

### 1. Analyze iteration log
Read `.ai/logs/<issue-nr>.md` and identify:
- What went wrong?
- What took detours?
- What was the root cause?

### 2. Categorize
Pick the best category:
- `bug-pattern` — recurring bug type
- `architecture` — structural insight
- `workflow` — process improvement
- `domain` — business logic insight
- `testing` — test strategy insight

### 3. Write solution file

Create `docs/solutions/<category>-<short-description>.md`:

```markdown
# <Title>

## Problem
<What went wrong — 2-3 sentences>

## Root cause
<Why it happened — the "five whys" result>

## Solution
<What fixed it — concrete, copy-pasteable>

## Prevention
<How to prevent this in the future>

## Learned from
Issue #<NR>, <date>
```

### 4. Connect back
If the learning is mechanically checkable:
- Add a check to `verify.sh`
- Or create/update a skill in `.ai/skills/`
- Or add a rule to `.ai/rules/`

### 5. Commit
```bash
git add docs/solutions/<file>.md
git commit -m "docs: compound learning from issue #<NR>"
```
