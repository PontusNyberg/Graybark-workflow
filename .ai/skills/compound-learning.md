# Skill: Compound Learning

Orchestrator skill — used by the main session after an issue is completed.

## Purpose

Systematically document solutions so future agents automatically avoid known problems. Every fixed bug, pattern or insight becomes an investment — not a one-time cost.

## Trigger

Run after **every non-trivial issue** (Step 10 in implement-issue.md). Skip for plain text changes and config tweaks.

Signals that compound is needed:
- Did it take >1 iteration? → Document what went wrong
- Did reviewers find blockers? → Document the pattern
- Was it a new pattern we haven't seen before? → Codify it
- Did the specialist take a workaround? → Document the right path

## When to skip

- Trivial change (<20 lines)
- 1 iteration, no problems
- Plain text/config change

## Steps

### 1. Analyze the iteration log

Read `.ai/logs/<issue-nr>.md` and identify:
- **Problems that arose** (verify-fail, review-blockers, merge conflicts)
- **Solutions that worked** (what fixed the problem?)
- **Patterns** (have we seen similar problems before?)
- **Surprises** (did something take longer or was harder than expected?)

### 2. Categorize the insight

| Category | Description | Example |
|----------|-------------|---------|
| `bug-pattern` | Recurring bug with a known fix | Auth policy missed for UPDATE |
| `architecture` | Structural decision worth remembering | API endpoints always return JSON envelope |
| `workflow` | Process improvement | Parallel dispatch requires file-list analysis |
| `domain` | Domain-specific insight | Amounts always stored in cents, not dollars |
| `testing` | Test pattern or pitfall | Mocking the API client requires auth context |

### 3. Write the solution file

Create `docs/solutions/<category>-<short-description>.md`:

```markdown
# <Title — short and searchable>

**Category:** bug-pattern | architecture | workflow | domain | testing
**Discovered:** Issue #<NR>, <date>
**Specialist:** <who hit it>

## Problem

<What went wrong? 2-4 sentences.>

## Root cause

<Why did it go wrong? Not symptoms but underlying cause.>

## Solution

<What fixed the problem? Include code example if relevant.>

## Prevention

<How do we avoid this in the future?>
- [ ] Rule added in `.ai/rules/` (if applicable)
- [ ] Check added in `verify.sh` (if mechanical)
- [ ] Skill updated (if pattern in skill)
- [ ] No action — documentation is enough
```

### 4. Connect back to the system

Based on the insight, do **one** of these (or none if documentation is enough):

| Insight | Action |
|---------|--------|
| Mechanically checkable error | Add check to `verify.sh` |
| Pattern in specialist work | Update relevant skill or create new |
| Missing rule | Update relevant rule in `.ai/rules/` |
| Domain knowledge | Just the solution file is enough |

### 5. Update the solution index

If `docs/solutions/README.md` exists, add a row to the index. If not, create it with a table.

### 6. Commit

```bash
git add docs/solutions/<file>.md
git commit -m "docs: compound learning from issue #<NR>"
```

## Output

A committed file in `docs/solutions/` + optional action in rules/skills/verify.sh.

## Common mistakes

- **Too generic** — "Be careful with auth" helps no one. Describe exactly which pattern failed and what the solution was.
- **Duplication** — Check if a similar solution already exists before creating a new one. Update existing if possible.
- **Skipping prevention** — A solution without prevention is just a diary. The point is to prevent the problem from recurring.
- **Over-acting** — Not everything needs a new rule or verify check. Sometimes documentation is enough.
