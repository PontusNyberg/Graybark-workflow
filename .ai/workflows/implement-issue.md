# Workflow: Implement Issue

Main loop for implementing a GitHub issue. Claude Code (main session) coordinates everything — specialist agents code and test, reviewer agents review.

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

Check whether any open PR already addresses this issue:

```bash
# Check if issue-nr is mentioned in an open PR's title, body, or branch
# If a hit → stop and report to the user before continuing
```

If you find an open PR covering the same scope: **stop**. Ask the user whether to build on the PR, take it over, or wait. Restarting work that is already in flight in an unreviewed PR is duplicate work and discards the contributor's (human or other session) effort.

Determine which rules apply based on affected files (see rule matrix in `.ai/CLAUDE.md`).

### Step 2: Validate issue

Check:
- **Clear acceptance criteria** — what "done" means
- **Bounded scope** — what is NOT included

If unclear → `needs-clarification`, **STOP**.

### Step 3: Consult advisors (if relevant)

Spawn UX or business advisors via Agent tool if the issue touches their domain.
Advisors run on **Haiku** (short, structured output — Opus is overkill).

```
Agent(
  description: "UX advisor: advice for issue #<NR>",
  model: "haiku",
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
- Specialist: Backend (.claude/agents/backend-developer.md)
- Files: api/...
- AC: AC-1, AC-3
- Rules: always.md + on-backend.md
- Tests: API test, integration test

### Work package 2: Frontend
- Specialist: Frontend (.claude/agents/frontend-developer.md)
- Files: src/pages/...
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

Information in the middle of long prompts risks being "lost" (lost-in-middle). Structure prompts so the most important — the task and test requirements — comes **last** (recency bias):

1. Agent definition (background/role)
2. Rules (constraints)
3. Skills (if match)
4. Issue context (background)
5. Work package (what to do)
6. Test requirements (last — the most important thing to remember)

**Prompt budget:** Keep specialist prompts under ~4000 tokens. If agent definition + rules + skill exceeds this — trim the agent definition to the essentials and reference files the agent can read on demand.

```
Agent(
  description: "Backend: issue #<NR>",
  model: "opus",
  isolation: "worktree",
  prompt: """
    <contents from .claude/agents/backend-developer.md>

    <contents from .ai/rules/always.md>
    <contents from relevant domain rule>
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
  model: "sonnet",
  isolation: "worktree",
  prompt: """
    <contents from .claude/agents/frontend-developer.md>

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
Agent(isolation: "worktree", prompt: "Backend: create API...")
# → merge worktree branch to feature branch

# Step 2: Frontend with backend in place
Agent(isolation: "worktree", prompt: "Frontend: build UI against API...")
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

verify.sh checks:
- Linting / type checking
- Test requirements — blocks if tests are missing for new code
- Test execution — runs all tests
- Secrets, scope, code quality checks

**If verify fails:**
- Send error messages back to the right specialist
- Run specialist again with error messages as context
- Run verify again
- Increment iteration counter

### Step 8: Parallel review

Spawn reviewers in parallel via Agent tool. Always 3 generic + optional specialist reviewer.

Reviewers do **not** need worktrees — they don't change files, only analyze diff.

**Model tier per reviewer:**
- Rev-Correctness + Rev-Security → **Opus** (subtle semantic analysis, security-critical)
- Rev-Conventions → **Sonnet** (pattern matching against an explicit checklist)

```
# Prepare diff (run in Bash)
git diff main...HEAD > /tmp/diff-full.txt
DIFF_LINES=$(wc -l < /tmp/diff-full.txt)

# Dispatch all reviewers in parallel in the same message:

Agent(
  description: "Review: correctness",
  model: "opus",
  prompt: """
    <contents from .ai/agents/reviewer-correctness.md>
    ISSUE: <contents from .ai/logs/current-issue.json>
    DIFF: <contents from /tmp/diff-full.txt>
  """
)

Agent(
  description: "Review: security",
  model: "opus",
  prompt: """
    <contents from .ai/agents/reviewer-security.md>
    ISSUE: <contents from .ai/logs/current-issue.json>
    DIFF: <contents from /tmp/diff-full.txt>
  """
)

Agent(
  description: "Review: conventions",
  model: "sonnet",
  prompt: """
    <contents from .ai/agents/reviewer-conventions.md>
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

#### Landing Protocol (mandatory postcondition)

The issue is not done until every step below is completed. You are personally responsible for each step.

1. Commit locally (format below)
2. Push the branch to origin
3. Create the PR via `gh pr create` (or `mcp__github__create_pull_request` if the user requested it)
4. Verify that `git status` shows "up to date with origin/<branch>"
5. Report the PR URL to the user

**The plane has not landed until `git push` is complete.** Never say "ready to push when you want" — you push it yourself. Leaving work unpushed strands it locally and blocks the next session.

```bash
# Stage ONLY files changed by specialists — NEVER git add -A
git add <specific changed files>
git commit -m "feat: <short description>

Resolves #<ISSUE_NR>

Changes:
- <one line per logical change>

Implemented by: <specialist(s)>
Reviewed by: correctness, security, conventions, <specialist>"

# Push branch and create PR
git push -u origin HEAD
gh pr create --title "<short description>" --body "$(cat <<'PRBODY'
## Summary
- <summary of changes>

## Test plan
- [ ] Unit tests pass
- [ ] TypeScript typecheck passes

Generated with [Claude Code](https://claude.com/claude-code)
PRBODY
)"
```

### Step 10.5: Handoff prompt (if the session ends before the issue is done)

If you must end the session mid-work (compaction, tokens exhausted, user disconnects), write a **handoff prompt** the user can paste directly into the next session. This saves tokens massively — the next LLM doesn't need to read the entire prior conversation.

Format:

```
## Continue work on #<NR>: <title>

**Status:** <short — iteration X/4, package A done, package B in progress, etc.>
**Branch:** <branch name>
**Latest commit:** <sha> — <message>
**Next step:** <what to do next, concretely>
**Blockers:** <if any, with link to relevant log or file>
**Files touched:** <list>
**Context:** <2-3 sentences about why-decisions not visible from the diff>
```

Write the prompt to the user directly at the end of the session. Don't repeat the entire plan — point to `.ai/logs/<nr>.md` for details.

This applies to both main session and subagent sessions handing off to an orchestrator.

### Step 11: Compound Learning

**Skip if:** Trivial change (<20 lines), 1 iteration without problems, plain text change.

Follow `.ai/skills/compound-learning.md`:

1. **Analyze** the iteration log — what went wrong, what took detours?
2. **Categorize** the insight (bug-pattern, architecture, workflow, domain, testing)
3. **Write solution file** in `docs/solutions/<category>-<short-description>.md`
4. **Connect back** — if mechanically checkable → verify.sh, if pattern → skill, if rule → rules/
5. **Commit** the solution file (it's durable, not ephemeral)

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

## Escalation states

| State | Meaning |
|-------|---------|
| `needs-human-p2` | Max iterations reached. You have a concrete hypothesis about what's needed. Likely a quick fix. |
| `needs-human-p1` | Max iterations reached. You don't know how to proceed. 3+ fix attempts have failed for different reasons. |
| `needs-human-p0` | Issue requires an architecture or product decision. Implementation is not meaningful until the decision is made. |
| `needs-clarification` | Issue unclear — acceptance criteria are vague or contradictory. |

### Choosing a level — rubric

**Pick P2 if:**
- Iteration 3 or 4 failed for the same concrete reason (e.g. "test X fails with Y")
- You have a concrete hypothesis about why
- The fix is mechanical (swap a library, change an assertion, adjust an env var)

**Pick P1 if:**
- 3+ different fix attempts failed for different reasons
- You understand what should happen but not why it isn't happening
- The test suite or verify.sh behaves inconsistently
- Reviewers give contradictory signals

**Pick P0 if:**
- Issue requires an architecture decision (data model, pattern choice, paywall placement)
- Acceptance criteria are vague or contradictory
- Implementation impacts other open issues that must sync
- Security or product decision that must be approved

**You MUST pick a level** when escalating. The default "needs-human" without a grade is not allowed. If you can't choose between P1 and P2 — pick P1 (the more cautious one).

### On escalation — format

```markdown
## Needs Human Review (P<level>)

Issue: #<NR>
Iterations: 4/4
Severity: P<0|1|2> — <short justification per rubric>

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

Label the GitHub issue with the corresponding label: `needs-human-p0`, `needs-human-p1`, or `needs-human-p2`. Labels need to be created manually in the repo the first time (suggested colors: red for P0, orange for P1, yellow for P2). Document this as a TODO if labels are missing.

## Log format

In `.ai/logs/<issue-nr>.md`:

```markdown
# Issue #<NR>: <title>

Started: <timestamp>
Rules: always, on-frontend
Specialists: Frontend, Backend

### Iteration 1
- Specialist(s): Frontend, Backend
- Changed files: [list]
- Verify: PASS/FAIL
- Tests: X passed, Y failed
- Review: [correctness: pass, security: fail, conventions: pass, specialist: pass]
- Blockers: [list]
- Action: [fix, new iteration]

## Final result
- Status: completed / needs-human / needs-clarification
- Iterations: X/4
- Commit: <hash>
```

Log files are NOT committed — they live in `.gitignore`.
