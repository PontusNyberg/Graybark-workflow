# Workflow: Retrospective

Sprint retrospective that analyzes failures and proposes rule improvements.

## When does this run?

- After every sprint (or after ~5-10 implemented issues)
- Manually when needed

The workflow is self-contained — data gathering uses the inline commands below.
Projects MAY wrap them in a script (e.g. `.ai/scripts/retrospective.sh`), but the
script is a convenience, not a requirement.

## Output

The retrospective report is saved in `docs/retros/sprint-retro-<date>.md` (durable, committed).

## Input

- **Iteration logs:** `.ai/logs/<issue-nr>.md` — structured logs per issue
- **Solutions:** `docs/solutions/` — do we have solutions that repeat? Patterns to codify?
- **Git history:** commits during the period
- **GitHub issues:** issues marked `needs-human-*` or `needs-clarification`

## Analysis steps

### 1. Gather data

```bash
# Iteration logs (primary data source)
ls .ai/logs/*.md 2>/dev/null

# Commits during the period (adjust --since as needed, e.g. "1 month ago")
git log --oneline --since="2 weeks ago"

# Issues that took >2 iterations
grep -l "Iteration 3\|Iteration 4\|needs-human" .ai/logs/*.md 2>/dev/null

# Issues that needed clarification
grep -l "needs-clarification" .ai/logs/*.md 2>/dev/null

# Escalated issues on GitHub
gh issue list --label needs-human-p0 --label needs-human-p1 --label needs-human-p2 --state all --limit 20
```

### 2. Identify patterns

Answer:
- Which types of blockers appeared most often?
- Which verify checks failed the most?
- Which reviewer found the most blockers?
- Were there issues stuck in a loop?
- Which rules were broken most often?

### 3. Categorize improvement proposals

Rank by effectiveness:

#### Prio 1: New mechanical checks (best — cannot be forgotten)
Things that can be caught automatically in `verify.sh`:
- New lint rules
- New type checks
- Grep-based pattern checks
- Test minimum requirements

#### Prio 2: Rewritten/new rules
Clarify rules that were misunderstood or add rules that were missing:
- Update `rules/*.md`
- Break down rule files that got too large (>2000 tokens)

#### Prio 2b: New or updated skills
Recurring patterns codified into executable routines:
- New skill: based on at least 2 issues with the same pattern
- Updated skill: an existing skill that didn't save enough iterations
- See `.ai/workflows/skill-lifecycle.md` for format and requirements

#### Prio 3: Updated reviewer prompts
If a reviewer consistently misses things:
- Add specific things to look for
- Clarify the severity guide

### 4. Write proposals

## Output format

```markdown
# Retrospective [date]

## Statistics
- Issues implemented: X
- Average iterations: X.X
- Issues that reached needs-human: X
- Most common blocker type: [type]

## Patterns
- [Pattern 1: description + frequency]
- [Pattern 2: description + frequency]

## Proposed changes

### Mechanical checks (verify.sh)
- [ ] [New check: description + why]

### Rules
- [ ] [Rule to change/add: description + why]

### Skills (require PR review)
- [ ] [New/updated skill: name + trigger + which issues it is based on]

### Skill observations (log for the future)
- [ ] [Pattern that doesn't yet qualify as a skill: description + frequency]

### Reviewer prompts
- [ ] [Prompt to update: description + why]

### Solutions to extract
- [ ] [Problem from this sprint that should become a solution file in docs/solutions/]

## Discussion
[Open questions requiring a human decision]
```

## Rules for the retrospective

1. **NEVER lower quality requirements to increase throughput** — if issues take many iterations, the solution is better rules, not lower standards
2. **NEVER propose removing a reviewer** — improve it instead
3. **All proposed rule changes require human review** — never commit rule changes automatically
4. **Prioritize mechanical checks** — they are the most reliable
5. **Be specific** — "improve security review" is not enough, give the exact prompt change

## Final step — compress iteration logs

When the retrospective report is written and committed, run `.ai/skills/compress-logs.md` to extract lessons from the sprint's iteration logs and archive the raw logs.

This is not a separate person — it is a skill invocation you perform yourself as part of the retrospective. The skill compresses `.ai/logs/<issue-nr>.md` files into:

- `docs/solutions/<slug>.md` — for non-trivial technical lessons
- `docs/retros/sprint-retro-<date>.md` — the Gotchas section is extended
- `.ai/logs/archive/<sprint>/<nr>.md` — raw logs are moved here

Do not skip this step — lessons not extracted before `.ai/logs/` is cleaned are lost.
