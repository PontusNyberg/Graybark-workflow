# Workflow: Implement Issue

Main loop for implementing a GitHub issue. Claude Code (main session) coordinates everything — specialist agents code and test, reviewer agents review.

> Specialist names are generic here ("Backend Specialist", "Frontend Specialist").
> Each project names its own agents in `.claude/agents/` — substitute your project's
> agent names when dispatching.

## Prerequisites

- Issue with clear acceptance criteria
- Clean git branch created from `main`/`master`

## Git branch (MANDATORY)

**NEVER commit directly on main/master.** Every sprint/issue should work on a feature branch with PR.

```bash
# Sprint branch (for sprint implementation)
git checkout master && git pull
git checkout -b sprint-<N>

# Issue branch (for individual issue)
git checkout master && git pull
git checkout -b fix/<issue-nr>-<short-description>
```

When implementation is complete → push branch + create PR against main/master via `gh pr create`.

## Step by step

### Step 1: Prepare context

```bash
mkdir -p .ai/logs
gh issue view <ISSUE_NR> --json title,body > .ai/logs/current-issue.json
```

Determine which rules apply based on affected files (see rule matrix in `.ai/CLAUDE.md`).

### Step 2: Validate issue

Check:
- **Clear acceptance criteria** — what "done" means
- **Bounded scope** — what is NOT included

If unclear → `needs-clarification`, **STOP**.

### Step 3: Consult advisors (if relevant)

Spawn UX or scope advisors via Agent tool if the issue touches their domain:

```
Agent(
  description: "UX advisor: advice for issue #<NR>",
  prompt: """
    <contents from .claude/agents/product-designer.md>

    I'm implementing the following issue. Give UX advice, short and concrete.

    ISSUE:
    <contents from .ai/logs/current-issue.json>
  """
)
```

Advisors do **not** need worktrees — they don't change files.

**Skip if:** Bug fix or clearly technically bounded.

### Step 4: Plan work packages

Break down the issue and assign specialist(s).

**Step 4a (conditional): Incident-fix scoping.** If the issue is tagged
`incident`/`postmortem`, references a production outage, or the branch
name matches `fix/<incident-name>` / `hotfix/*`, load
`.ai/skills/incident-fix-scoping.md` BEFORE further planning. The rule
forces you to split incident work into:
1. PR 1 — stop the bleeding (minimal, urgent)
2. PR 2 — visibility / adjacent hardening / postmortem
3. PR 3 — process improvements (reviewer prompts, skills, tooling)

In a sister project, one incident PR swallowed all three phases and took
9 AI-review rounds over 3 days to converge. Don't repeat that.

**Save planned files** for scope validation in verify.sh:

```bash
# Save planned files (one per line) — verify.sh uses this for scope check
cat > .ai/logs/planned-files.txt <<'EOF'
path/to/file1.ts
path/to/file2.ts
path/to/file3.ts
EOF
```

Plan format:

```markdown
## Plan: Issue #<NR>

### Work package 1: Backend
- Specialist: Backend Specialist
- Files: TODO: your backend paths (e.g. api/src/...)
- AC: AC-1, AC-3
- Rules: always.md + on-backend.md
- Tests: API test, integration test

### Work package 2: Frontend
- Specialist: Frontend Specialist
- Files: TODO: your frontend paths (e.g. src/...)
- AC: AC-2, AC-4
- Rules: always.md + on-frontend.md
- Tests: Component test, loading/error state test
- Depends on: Work package 1
```

### Step 4b: Match skills

Use `.ai/skills/triggers.yml` for deterministic matching:

1. **Files-match:** Check if planned files (from Step 4) match a `files` pattern in triggers.yml
2. **Keyword-match:** Check if issue text (title+body) contains at least one `keywords` word
3. **Match = files AND at least one keyword** → inject the skill's `.md` file into specialist prompt (Step 5)

If match: include the skill in the specialist prompt. Skills are aids — the specialist may deviate if the issue requires it.

If nothing matches but the pattern feels familiar: log a skill observation in `.ai/logs/<issue-nr>.md` for future retrospective.

### Step 5: Dispatch specialists (worktree isolation)

Specialists are dispatched via **Agent tool with `isolation: "worktree"`**. Each specialist gets an isolated repo copy and edits files directly with Edit/Write tools.

**Dependency analysis:** Check file lists from Step 4. If work packages don't share files → parallel dispatch. If they share files → sequential. See `.ai/skills/parallel-dispatch.md` for detailed guidance.

#### Parallel dispatch (independent work packages)

Dispatch all specialists in **the same message** — Claude Code runs them simultaneously:

**Prompt ordering (important for token efficiency):**

1. Agent definition (background/role)
2. Rules (constraints)
3. Skills (if match)
4. Issue context (background)
5. Work package (what to do)
6. Test requirements (last — the most important thing to remember)

```
Agent(
  description: "Backend: issue #<NR>",
  subagent_type: "<your backend agent from .claude/agents/>",
  isolation: "worktree",
  prompt: """
    <contents from .ai/rules/always.md>
    <contents from .ai/rules/on-backend.md>
    <contents from matching skill, if any>

    ISSUE:
    <contents from .ai/logs/current-issue.json>

    WORK PACKAGE:
    Create API endpoint for ...

    TEST REQUIREMENTS (MANDATORY):
    You MUST write tests that prove the code fulfills acceptance criteria:
    1. ...
    2. ...
    Without tests, verify.sh will block.
  """
)

Agent(
  description: "Frontend: issue #<NR>",
  subagent_type: "<your frontend agent from .claude/agents/>",
  isolation: "worktree",
  prompt: """
    <contents from .ai/rules/always.md>
    <contents from .ai/rules/on-frontend.md>
    <contents from matching skill, if any>

    ISSUE:
    <contents from .ai/logs/current-issue.json>

    WORK PACKAGE:
    <description of frontend work package>

    TEST REQUIREMENTS (MANDATORY):
    <specific test requirements>
    Without tests, verify.sh will block.
  """
)
```

Both agents run **simultaneously** in separate worktrees.

#### Sequential dispatch (dependent work packages)

If frontend depends on backend (e.g., new API schema):

```
# Step 1: Backend first
Agent(subagent_type: "<backend agent>", isolation: "worktree", prompt: "Backend: create API...")
# → merge worktree branch to feature branch

# Step 2: Frontend with backend in place
Agent(subagent_type: "<frontend agent>", isolation: "worktree", prompt: "Frontend: build UI against API...")
```

### Step 5b: Merge worktree branches

Agents edit files directly in their worktrees. Claude Code returns the worktree branch and path if changes were made.

1. **Inspect results** — Verify each agent produced changes
2. **Merge sequentially** — Merge each worktree branch to the feature branch
3. **Resolve conflicts** — If merge conflicts (rare with correct dependency analysis):
   - Review and resolve manually
   - Or dispatch specialist to resolve
   - Log as observation in iteration log
4. **Check scope** — Verify changed files match planned-files.txt

```bash
# Merge worktree branches (branch names returned by Agent call)
git merge <worktree-branch-backend> --no-ff -m "merge: backend for #<NR>"
git merge <worktree-branch-frontend> --no-ff -m "merge: frontend for #<NR>"
```

### Step 6: Verify completeness

1. Check that all acceptance criteria have been covered
2. Check that all planned files (Step 4) have been changed
3. Quick-review the diff for obvious problems

### Step 7: Verify (mechanical checks + tests)

```bash
git add <changed files>
bash .ai/scripts/verify.sh
```

verify.sh checks (customize for your stack):
- Type checking
- Linting
- Test execution
- Secrets detection
- Scope check against planned-files.txt
- Test requirements gate

**If verify fails:**
- Send error messages back to the right specialist
- Run specialist again with error messages as context
- Run verify again
- Increment iteration counter

### Step 8: Parallel review

Spawn reviewers in parallel via Agent tool. Always **4 generic** (correctness,
security, conventions, lifecycle) + optional specialist reviewer.

Reviewers do **not** need worktrees — they don't change files, only analyze diff.

**Optional AI code review gate (e.g. GitHub Copilot) — before internal reviewers.**
If your repo has an external AI reviewer attached, push the branch, open the PR,
and let it comment first. Empirically (sister project), an external AI reviewer
caught lifecycle and cross-module bugs that all three conventional internal
reviewers missed (5 CRITICAL bugs in one PR's case). If the external reviewer has
open comments, address them BEFORE invoking internal reviewers — running internal
reviewers on a diff already flagged wastes their context and confuses the verdict.
The `/ship-and-watch` command (`.claude/commands/ship-and-watch.md`) automates
this gate as a self-driving loop.

```
# Prepare diff (run in Bash)
# Detect default branch: git metadata first (no gh/auth needed), gh as fallback
BASE=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
[ -n "$BASE" ] || BASE=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null)
[ -n "$BASE" ] || BASE=$(git branch -l main master --format='%(refname:short)' | head -1)
git diff "$BASE"...HEAD > /tmp/diff-full.txt
DIFF_LINES=$(wc -l < /tmp/diff-full.txt)

# Dispatch all reviewers in parallel in the same message:

Agent(
  description: "Review: correctness",
  prompt: """
    <contents from .ai/agents/reviewer-correctness.md>
    ISSUE: <contents from .ai/logs/current-issue.json>
    DIFF: <contents from /tmp/diff-full.txt>
  """
)

Agent(
  description: "Review: security",
  prompt: """
    <contents from .ai/agents/reviewer-security.md>
    ISSUE: <contents from .ai/logs/current-issue.json>
    DIFF: <contents from /tmp/diff-full.txt>
  """
)

Agent(
  description: "Review: conventions",
  prompt: """
    <contents from .ai/agents/reviewer-conventions.md>
    ISSUE: <contents from .ai/logs/current-issue.json>
    DIFF: <contents from /tmp/diff-full.txt>
  """
)

Agent(
  description: "Review: lifecycle",
  prompt: """
    <contents from .ai/agents/reviewer-lifecycle.md>
    ISSUE: <contents from .ai/logs/current-issue.json>
    DIFF: <contents from /tmp/diff-full.txt>
  """
)

# Specialist reviewer (cross-review: not the same specialist that coded)
Agent(
  description: "Review: specialist cross-review",
  prompt: """
    <agent definition for cross-reviewer>
    You review as specialist. Respond in JSON:
    {"reviewer": "<name>", "verdict": "pass|fail", "issues": [...]}
    ISSUE: <issue data>
    DIFF: <diff data>
  """
)
```

**Large diff (>3000 lines):** Filter diff per reviewer domain.

**Safeguard-injection:** If the diff introduces or extends a safeguard
primitive (circuit breaker, mutex, rate limiter, retry logic, classifier,
state machine), inject any safeguard-review checklist your project keeps
in `.ai/skills/` into the **correctness** and **lifecycle** reviewer prompts.

### Step 8b: Validate review output

```bash
for review in /tmp/review-*.json; do
  [ ! -f "$review" ] && continue
  if [ ! -s "$review" ]; then
    echo "ERROR: Empty review file: $review — re-run"
  elif ! jq -e '.verdict' "$review" > /dev/null 2>&1; then
    echo "ERROR: Invalid JSON: $review — re-run"
  fi
done
```

### Step 9: Evaluate reviews automatically

```bash
bash .ai/scripts/evaluate-reviews.sh
```

The script:
1. Parses all `/tmp/review-*.json`
2. Extracts blockers, warnings, nits
3. Exit code 1 if blockers exist
4. Writes summary to stdout

**If blockers:** → Back to Step 5 with feedback, increment iteration.
**If no blockers:** → Step 10.

Warnings requiring scope change → log as "known warning, out of scope".

### Step 10: Finalize

```bash
# Stage ONLY files changed by specialists — NEVER git add -A
git add <specific changed files>
git commit -m "feat: <short description>

Resolves #<ISSUE_NR>

Changes:
- <one line per logical change>

Implemented by: <specialist(s)>
Reviewed by: correctness, security, conventions, lifecycle, <specialist>"

# Push branch and create PR
git push -u origin HEAD
gh pr create --title "<short description>" --body "$(cat <<'PRBODY'
## Summary
- <summary of changes>

## Test plan
- [ ] Unit tests pass
- [ ] Type check passes
- [ ] Lint passes

Generated with [Claude Code](https://claude.com/claude-code)
PRBODY
)"
```

### Step 10.5: Handoff prompt (if the session ends before the issue is done)

If you must end the session mid-work (compaction, tokens, user leaving), write a
**handoff prompt** the user can paste directly into the next session. This saves tokens
massively — the next session doesn't need to re-read the whole conversation.

Format:

```
## Continue work on #<NR>: <title>

**Status:** <short — iteration X/4, package A done, package B in progress, etc.>
**Branch:** <branch name>
**Latest commit:** <sha> — <message>
**Next step:** <what to do next, concrete>
**Blockers:** <if any, with link to relevant log or file>
**Files touched:** <list>
**Context:** <2-3 sentences about why-decisions that aren't visible in the diff>
```

Write the prompt to the user at the end of the session. Don't repeat the whole plan —
point to `.ai/logs/<nr>.md` for details. Applies to both the main session and a
subagent session handing off to an orchestrator.

### Step 11: Compound Learning (BLOCKING — the issue is not done until this is resolved)

The iteration log (`.ai/logs/<nr>.md`) is **gitignored and ephemeral** — iteration logs
may contain sensitive data (PII, decrypted values) so they can never be committed. A
lesson that stays only in the log is **lost**. Step 11 is how it survives. This is part
of "done", not optional cleanup.

**This step has a mandatory decision — you MUST do exactly one of:**

A. **Write a solution doc** (required when the issue was non-trivial — ANY of: 2+ iterations,
   a non-obvious bug, the approach changed, a workaround, a review/CI-caught defect, a
   reusable pattern). Then link it in the PR body: `Solution-doc: docs/solutions/<file>.md`.

B. **Explicitly waive it** (only for genuinely trivial issues — text/config/rename,
   <20 lines, 1 clean iteration). Record `Solution-doc: N/A — <one-line reason>` in the PR body.

Silently skipping = workflow violation. verify.sh can emit a non-blocking reminder when a
non-trivial code diff carries no `docs/solutions/` change and no `Solution-doc:` marker.
Note: such a check detects the marker in the **diff or recent commit messages only** — it
cannot read the PR body. So to silence the reminder, put `Solution-doc: …` in a commit
message (the PR-body field is the human-facing record, not what the check sees).

**To write the doc — follow `.ai/skills/compound-learning.md`:**

1. **Analyze** the iteration log — what went wrong, what took detours, root cause?
2. **Categorize** the insight (bug-pattern, architecture, workflow, domain, testing)
3. **Write solution file** in `docs/solutions/<category-or-YYYY-MM-DD>-<short-description>.md`.
   **PII-free** — distil the lesson; never paste sensitive/decrypted values or raw data rows
   from the log.
4. **Connect back** — if mechanically checkable → verify.sh, if pattern → skill, if rule → rules/
5. **Commit** the solution file on the feature branch so it ships in THIS PR (durable, not ephemeral).

```bash
git add docs/solutions/<new-file>.md
git commit -m "docs: compound learning from issue #<NR>"
```

## Iteration limit

```
iteration = 0

while iteration < 4:
    spawn_specialists()
    apply_output()

    if not verify():
        log_iteration(iteration, "verify failed", error_messages)
        iteration++
        continue

    reviews = parallel_review()

    if not valid_json(reviews):
        retry_invalid_reviewers()  # does not count as iteration
        continue

    if has_blockers(reviews):
        log_iteration(iteration, "blockers found", blockers)
        iteration++
        continue

    log_iteration(iteration, "passed", [])
    commit()
    break

if iteration >= 4:
    needs_human()
```

### What counts as an iteration?

- Verify fail → +1
- Review blocker → +1
- Invalid reviewer output → NOT +1 (re-run)
- Reviewer timeout → NOT +1 (re-run)

## Escalation states (graded)

| State | Meaning |
|-------|---------|
| `needs-human-p2` | Max iterations reached. You have a concrete hypothesis about what's needed. Likely quick-fix. |
| `needs-human-p1` | Max iterations reached. You don't know how to proceed. 3+ fix attempts failed for different reasons. |
| `needs-human-p0` | The issue requires an architecture or product decision. Implementation is pointless until it's made. |
| `needs-clarification` | Issue unclear — acceptance criteria vague or contradictory. |

### Choosing the level — rubric

**Pick P2 if:**
- Iteration 3 or 4 failed for the same concrete reason (e.g. "test X fails with Y")
- You have a concrete hypothesis why
- The fix is mechanical (swap library, change assertion, adjust env var)

**Pick P1 if:**
- 3+ different fix attempts failed for different reasons
- You understand what should happen but not why it doesn't
- The test suite or verify.sh behaves inconsistently
- Reviewers give contradictory signals

**Pick P0 if:**
- The issue requires an architecture decision (data model, pattern choice)
- Acceptance criteria are vague or contradictory
- Implementation affects other open issues that must stay in sync
- A security or product decision needs sign-off

**You MUST pick a level** when escalating. A plain ungraded "needs-human" is not allowed.
If torn between P1 and P2 — pick P1 (the more cautious one).

### Escalation format

```markdown
## Needs Human Review (P<level>)

Issue: #<NR>
Iterations: 4/4
Severity: P<0|1|2> — <one-line motivation per the rubric>

Remaining problems:
- <unresolved blockers/verify errors>

What was tried:
- Iteration 1: <specialist, result>
- Iteration 2: <change, result>
- Iteration 3: <...>
- Iteration 4: <...>

Next step (your recommendation):
- <what you think is needed>
```

Label the GitHub issue accordingly: `needs-human-p0`, `needs-human-p1` or `needs-human-p2`
(create the labels once if missing: red for P0, orange for P1, yellow for P2).

## Log format

In `.ai/logs/<issue-nr>.md`:

```markdown
# Issue #<NR>: <title>

Started: <timestamp>
Rules: always, on-frontend
Specialists: Frontend Specialist, Backend Specialist

### Iteration 1
- Specialist(s): Frontend Specialist, Backend Specialist
- Changed files: [list]
- Verify: PASS/FAIL
- Tests: X passed, Y failed
- Review: [correctness: pass, security: fail, conventions: pass, lifecycle: pass, specialist: pass]
- Blockers: [list]
- Action: [fix, new iteration]

## Final result
- Status: completed / needs-human-p0|p1|p2 / needs-clarification
- Iterations: X/4
- Commit: <hash>
```

Log files are NOT committed — they live in `.gitignore` (iteration logs may contain
sensitive data such as PII or decrypted values).
