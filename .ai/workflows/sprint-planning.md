# Workflow: Sprint Planning

Structured pass over all open issues to plan the next sprint.

## When does this run?

- Before every new sprint
- Manually: say "plan the sprint"

The workflow is self-contained — all data gathering uses inline `gh` commands.
Projects MAY wrap the data-gathering steps in a script (e.g. `.ai/scripts/sprint-planning.sh`),
but the script is a convenience, not a requirement.

## Input

- All open GitHub issues (fetched via `gh`)
- The latest sprint tracker (issue with label `sprint`)
- Iteration logs from the previous sprint (`.ai/logs/`)
- Velocity data: issues per sprint historically

## Step by step

### Step 0: Sync and clean up

Before planning begins:
- Run `.ai/skills/workflow-sync.md` — keep the workflow core in sync with the shared template
- Run `.ai/skills/backlog-reconcile.md` — make backlog/plans mirror the actual code

### Step 1: Gather data

Fetch via `gh` CLI (or GitHub MCP):

```bash
# 1. Open issues
gh issue list --state open --json number,title,labels,createdAt --limit 100

# 2. Latest sprint issue (tracker)
gh issue list --label sprint --state all --json number,title,state --limit 5

# 3. Closed issues in the last 2 weeks (velocity data)
gh issue list --state closed --json number,title,closedAt --limit 50 \
  --search "closed:>=$(date -d '14 days ago' +%Y-%m-%d 2>/dev/null || date -v-14d +%Y-%m-%d)"
```

4. **Ready list (dependency scan).** Identify which open issues have no open dependencies
   (can start now) vs which are blocked. Dependencies typically appear in issue bodies as
   task-lists (`- [ ] #123`) or "Depends on" / "Blocked by" sections:

```bash
# For each open issue, inspect its body for references to other open issues
gh issue view <NR> --json body -q .body | grep -oE '#[0-9]+'
```

Group results as READY (can start now) and BLOCKED (waits on other open issues).
Use the READY list as the starting point for Tier 1 candidates. Projects MAY wrap
this scan in a script (e.g. `.ai/scripts/ready.sh`).

### Step 2: Categorize issues

Group every open issue in a table:

| Issue | Title | Type | Complexity | Specialist | Dependencies |
|-------|-------|------|------------|------------|--------------|

**Type:** `bug`, `enhancement`, `feature`, `chore`, `UX`

**Complexity (t-shirt):**
- **S** — <20 lines, 1 file, no new logic (text change, config)
- **M** — 20–100 lines, 1–3 files, known pattern (skill exists)
- **L** — 100–300 lines, 3–8 files, new component/endpoint
- **XL** — >300 lines, >8 files, new feature end-to-end, should be broken down

**Specialist assignment** (per the routing table in CLAUDE.md):
- Frontend → Frontend Specialist
- Backend → Backend Specialist
- Both → Frontend + Backend Specialist
- Architecture → Architect

(Substitute your project's agent names from `.claude/agents/`.)

### Step 3: Consult the scope advisor (BEFORE prioritization)

Spawn the scope advisor **before** prioritizing — their objections should shape the plan, not tear it apart afterwards.

The advisor reviews the issue list and gives input on:
- **Scope risks** — XL issues that should be broken down
- **Challenges** — "Do we really need this now?"
- **Dependencies** — hidden couplings between issues
- **Priority suggestions** — what delivers the most value fastest

```
Agent(
  description: "Scope advisor: pre-sprint scope check",
  model: "haiku",
  prompt: """
    <contents from .claude/agents/product-skeptic.md>

    We are planning the next sprint. Here are all open issues with categorization.
    Give your honest assessment:

    1. Which issues should we NOT take on right now, and why?
    2. Which XL issues should be broken down before implementation?
    3. Are there hidden dependencies or risks?
    4. What delivers the most user value per unit of effort?
    5. Is any issue unclear and in need of clarification first?

    Be concrete and direct — better too skeptical than too optimistic.

    OPEN ISSUES:
    <the categorization table from step 2>
  """
)
```

**Handle the advisor's feedback:**
- Issues flagged as "not now" → candidates for backlog/excluded
- Issues to break down → create sub-issues before including them
- Unclear issues → `needs-clarification`, do not include in the sprint
- Present the advisor's objections to the user in the summary

### Step 4: Prioritize with MoSCoW

Assign each issue a priority based on the advisor's input + these principles:

1. **Bugs before features** — bugs affecting users = Tier 1
2. **Security before UX** — security holes = Tier 1
3. **Velocity** — mix S/M with L for an even sprint
4. **Dependencies** — if A depends on B, include B in the same sprint
5. **Advisor flags** — issues the advisor challenged need extra justification if included

**Priority matrix:**

| | High business value | Low business value |
|---|---|---|
| **Low effort** | Tier 1 — Must have | Tier 2 — Quick win |
| **High effort** | Tier 2 — Plan carefully | Tier 3 — Backlog |

### Step 5: Velocity check

Count total complexity against historical velocity:

- **Historical velocity:** issues per sprint (look at the last 2-3 sprints)
- **Sprint capacity:** aim for ~80% of max velocity (slack for the unforeseen)
- **Mix:** max 1 XL or 2 L per sprint

If the sprint looks too big → move Tier 3 to the backlog.

### Step 6: Create the sprint issue

Create a new GitHub issue with the label `sprint` in this format:

```markdown
## Sprint N — Planning

**Goal:** <1 sentence summarizing the sprint's focus>
**Velocity:** X issues (S: X, M: X, L: X)

### Tier 1 — Must have
- [ ] #XX — <title> → **Specialist**

### Tier 2 — Should have
- [ ] #XX — <title> → **Specialist**

### Tier 3 — If time permits
- [ ] #XX — <title> → **Specialist**

### Excluded (backlog)
- #XX — <title> — Reason: <why not now>
```

### Step 7: Summarize

Present to the user:
- Sprint goal (1 sentence)
- The scope advisor's objections and how they affected the plan
- Tier 1/2/3 with specialist assignment
- What was deliberately excluded and why
- Risks (XL issues, dependencies, unknowns)

## Output format

```markdown
# Sprint planning [date]

## Velocity
- Last sprint: X issues (S: X, M: X, L: X)
- This sprint: X issues (S: X, M: X, L: X)

## Scope advisor's assessment
- <summary of scope objections>
- <flagged issues and action taken>

## Open issues — overview

| # | Title | Type | Complexity | Specialist | Sprint prio |
|---|-------|------|------------|------------|-------------|
| XX | ... | bug | S | Frontend Specialist | Tier 1 |

## Sprint plan

### Goal
<focus>

### Tier 1 — Must have
- [ ] #XX — <title> → **Specialist** (complexity)

### Tier 2 — Should have
- [ ] #XX — <title> → **Specialist** (complexity)

### Tier 3 — If time permits
- [ ] #XX — <title> → **Specialist** (complexity)

### Excluded
- #XX — <reason>

## Risks
- <risks>
```

## Rules

1. **Present — don't decide** — the user makes the final priority call, we propose
2. **Motivate** — every prioritization needs a short justification
3. **Break down XL** — always propose decomposition for XL issues
4. **Bug-first** — bugs affecting users should always be proposed as Tier 1
5. **Don't skip issues** — every open issue must be visible, even if it lands in the backlog
