# Skill: Parallel Worktree Dispatch

Orchestrator skill — used by the main session (not by specialists).

## Purpose

Dispatch 2+ specialists in parallel in isolated git worktrees. Halves implementation time for issues with independent work packages (e.g. backend + frontend without shared code).

## Trigger

2 or more independent work packages identified in Step 4.

## When to use

Use parallel dispatch when:
- The issue has **2+ work packages** assigned to **different specialists**
- The work packages have **no shared files** (no specialist edits files another needs)
- The work packages can **build/test independently**

Do NOT use parallel dispatch when:
- Frontend depends on backend output (e.g. new API schema the frontend consumes)
- The same file is edited by multiple specialists
- There are unknowns that require sequential feedback

## Dependency analysis (MANDATORY before dispatch)

Before dispatching specialists in parallel, verify independence:

1. **Extract file lists** from each work package
2. **Check overlap** — if ANY file appears in multiple packages → sequential
3. **Check data dependency** — if package B needs output from package A → sequential
4. **If no overlap and no data dependency** → parallel

```
Package A files ∩ Package B files = ∅  →  PARALLEL OK
Package A files ∩ Package B files ≠ ∅  →  SEQUENTIAL (or split files)
```

Gray zone: If packages don't share files but share **types** (e.g. a shared types file) — run sequentially if the type change is part of the issue, in parallel if the types already exist.

### Examples

**Parallel OK:**
- Package 1: `api/routes/users.ts`, `api/models/user.ts`
- Package 2: `src/pages/Dashboard.tsx`, `src/components/Chart.tsx`
- → No overlap → dispatch simultaneously

**Must be sequential (data dependency):**
- Package 1: `api/routes/budget.ts` (creates new API)
- Package 2: `src/pages/BudgetPage.tsx` (calls that API)
- → Data dependency → backend first, then frontend

**Must be sequential (file overlap):**
- Package 1: `src/lib/api.ts`, `src/pages/Home.tsx`
- Package 2: `src/lib/api.ts`, `src/pages/Settings.tsx`
- → Shared file `api.ts` → sequential

## Dispatch patterns

### Parallel (independent packages)

Dispatch all specialists in **the same message** with `Agent(isolation: "worktree")`:

```
Agent(
  description: "Backend: issue #X",
  isolation: "worktree",
  prompt: """
    <agent definition from .claude/agents/backend-developer.md>
    <rules from .ai/rules/always.md + context rules>
    <matching skill if any>

    WORK PACKAGE:
    <description of what to do>

    TEST REQUIREMENTS (MANDATORY):
    <specific tests that must be written>

    ISSUE:
    <issue data from .ai/logs/current-issue.json>
  """
)

Agent(
  description: "Frontend: issue #X",
  isolation: "worktree",
  prompt: """
    <agent definition from .claude/agents/frontend-developer.md>
    <rules from .ai/rules/always.md + context rules>
    <matching skill if any>

    WORK PACKAGE:
    <description of what to do>

    TEST REQUIREMENTS (MANDATORY):
    <specific tests that must be written>

    ISSUE:
    <issue data from .ai/logs/current-issue.json>
  """
)
```

Both agents run **simultaneously** in separate worktrees. Claude Code handles worktree creation and cleanup automatically.

### Sequential (dependent packages)

Dispatch one package at a time. The second package gets access to the first's result:

```
# Step 1: Backend first
Agent(isolation: "worktree", prompt: "Backend: create API...")
# → merge branch to feature branch

# Step 2: Frontend with backend in place
Agent(isolation: "worktree", prompt: "Frontend: build UI against the new API...")
```

### Hybrid (partially independent)

If 3+ work packages where A and B are independent but C depends on both:

```
# Step 1: A + B in parallel
Agent(isolation: "worktree", prompt: "Backend: package A...")
Agent(isolation: "worktree", prompt: "Architect: package B...")
# → merge both

# Step 2: C sequentially
Agent(isolation: "worktree", prompt: "Frontend: package C...")
```

## Merge process

After all parallel agents have completed:

1. **Inspect results** — Each Agent call returns the worktree branch and path if changes were made
2. **Merge sequentially** — Merge each branch to the feature branch, one at a time
3. **Resolve conflicts** — If merge conflicts arise (rare with correct dependency analysis):
   - Review the conflict
   - Resolve manually or dispatch a specialist to resolve
   - Log as observation in the iteration log
4. **Run verify.sh** — Verify the merged result

```bash
# Merge worktree branch (if Agent returned a branch name)
git merge <worktree-branch-1> --no-ff -m "merge: backend for #X"
git merge <worktree-branch-2> --no-ff -m "merge: frontend for #X"

# Verify
bash .ai/scripts/verify.sh
```

## Anti-patterns

1. **Parallel dispatch with shared files** — Guaranteed merge conflict. Run sequentially.
2. **Dispatching all sprint issues in parallel** — Each issue should have its own feature branch. Parallelism applies to work packages *within* an issue.
3. **Skipping dependency analysis** — "It should work" → merge hell. Always check file lists.
4. **Dispatching advisors in worktree** — Advisors don't change files, no worktree needed.
