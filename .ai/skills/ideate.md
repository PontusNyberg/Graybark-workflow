# Skill: Ideate

## Trigger
Manual — run when you want to proactively identify improvements.

## Purpose
Systematically identify actionable improvements in the codebase, workflow, or architecture.

## Steps

### 1. Scan for signals
Look at:
- Recent iteration logs (what caused multiple iterations?)
- `docs/solutions/` (what patterns keep recurring?)
- `verify.sh` warnings (what keeps getting flagged?)
- Open issues (what's been deferred?)

### 2. Categorize findings
For each finding:
- **Impact:** High / Medium / Low
- **Effort:** Small / Medium / Large
- **Category:** Performance, DX, Security, UX, Architecture, Testing

### 3. Prioritize
Use impact/effort matrix:
- High impact + Small effort → Do first
- High impact + Large effort → Plan carefully
- Low impact + Small effort → Quick wins for morale
- Low impact + Large effort → Defer or skip

### 4. Output

Write to `docs/brainstorms/<date>-<topic>.md`:

```markdown
# Ideation: <Topic>

Date: <date>

## Findings

### 1. <Finding title>
- **Impact:** High/Medium/Low
- **Effort:** Small/Medium/Large
- **Category:** ...
- **Description:** ...
- **Suggested action:** ...

## Priority order
1. <highest priority finding>
2. ...
```

### 5. Create issues
For high-impact findings, create GitHub issues:
```bash
gh issue create --title "<finding>" --body "<description + suggested action>"
```
