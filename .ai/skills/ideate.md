# Skill: Ideate

Orchestrator skill — proactive improvement identification. Finds what *should* be done, not just what's been reported.

## Purpose

Systematically discover improvement opportunities through divergent thinking → critical filtering. Output: concrete, prioritized suggestions that can become GitHub issues.

## Trigger

Run manually when:
- The sprint is over and the next is being planned
- The team wants new ideas beyond the backlog
- The user says "ideate", "what should we improve?", "find improvements"

## Steps

### Phase 1: Divergent — collect signals (broad scanning)

Collect improvement signals from **all** of these sources:

#### 1a. Codebase analysis
```bash
# Tech-debt indicators
grep -rE "TODO|FIXME|HACK|WORKAROUND" src/ -l
```
- Large files (>300 lines) that may need to be broken up
- Duplicated logic across modules
- Outdated dependencies
- Missing tests for critical paths

#### 1b. Solution history
Read `docs/solutions/` — are there recurring patterns? Problems that were fixed but not prevented?

#### 1c. Iteration logs
Read `.ai/logs/` — which issues took >2 iterations? Why? Are there systemic causes?

#### 1d. Git history
```bash
# Files that change often (hotspots)
git log --since="2 months ago" --name-only --pretty=format: | sort | uniq -c | sort -rn | head -20
# Recent bug fixes
git log --since="1 month ago" --oneline --grep="fix"
```

#### 1e. UX and product gaps
- Missing loading/error/empty states
- Inconsistent UI across surfaces
- Features available on one platform but not another

### Phase 2: Convergent — filter and prioritize

Filter every suggestion through the **scope-skeptic lens**:

| Question | Eliminates |
|----------|-----------|
| Does this solve a real problem (data/feedback)? | Solutions looking for problems |
| What happens if we DON'T do it? | Nice-to-haves without consequence |
| Can we solve it without code? | Over-engineered solutions |
| How many users are affected? | Niche improvements |
| Is it measurable? | Vague "improvements" |

### Phase 3: Structure output

Rank remaining suggestions on an **effort/impact matrix**:

```
         High impact
              │
    Quick     │    Strategic
    Wins      │    Investments
              │
  ────────────┼──────────────
              │
    Fill if   │    Probably
    Bored     │    Don't
              │
         Low impact
   Low effort          High effort
```

## Output format

Write to `docs/brainstorms/ideation-<date>.md`:

```markdown
## Ideation: <date>

### Quick Wins (high impact, low effort)
1. **<title>** — <1 sentence why>
   - Impact: <who/what is affected>
   - Effort: ~<estimate>
   - Signal: <where this was discovered>

### Strategic (high impact, high effort)
1. ...

### Considerations (low impact, low effort)
1. ...

### Rejected
- <suggestion> — Rejected: <reason>
```

## What happens with the output?

1. **Quick wins** → Create GitHub issues directly (if the user approves)
2. **Strategic** → Discuss with the user, possibly break down into smaller issues
3. **Considerations** → Save in `docs/brainstorms/ideation-<date>.md` for future reference
4. **Rejected** → Document why (so we don't re-evaluate the same idea)

The brainstorm file is always saved in `docs/brainstorms/` regardless of whether issues are created.

```bash
gh issue create --title "<finding>" --body "<description + suggested action>"
```

## Common mistakes

- **Tech debt only** — Ideate should find *all* types of improvements: UX, performance, DX, business value — not just code cleanup.
- **No concrete proposals** — "Improve error handling" is not a proposal. "Add retry logic with exponential backoff to API calls" is.
- **Skipping the filter** — A list of 30 ideas without prioritization is useless. Phase 2 is as important as Phase 1.
- **Ignoring solutions/** — If the same kind of bug has appeared 3 times, it's a systemic problem, not three separate bugs.
