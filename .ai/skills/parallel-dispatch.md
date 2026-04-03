# Skill: Parallel Dispatch

## Trigger
2 or more independent work packages identified in Step 4.

## Dependency analysis (MANDATORY before dispatch)

Before dispatching specialists in parallel, verify independence:

1. **Extract file lists** from each work package
2. **Check overlap** — if ANY file appears in multiple packages → sequential
3. **Check data dependency** — if package B needs output from package A → sequential
4. **If no overlap and no data dependency** → parallel

### Examples

**Parallel OK:**
- Package 1: `api/routes/users.ts`, `api/models/user.ts`
- Package 2: `src/pages/Dashboard.tsx`, `src/components/Chart.tsx`
- → No overlap → dispatch simultaneously

**Must be sequential:**
- Package 1: `api/routes/budget.ts` (creates new API)
- Package 2: `src/pages/BudgetPage.tsx` (calls that API)
- → Data dependency → backend first, then frontend

**Must be sequential (file overlap):**
- Package 1: `src/lib/api.ts`, `src/pages/Home.tsx`
- Package 2: `src/lib/api.ts`, `src/pages/Settings.tsx`
- → Shared file `api.ts` → sequential

## Dispatch pattern

### Parallel (same message)
```
Agent(
  description: "Backend: issue #<NR>",
  isolation: "worktree",
  prompt: "..."
)

Agent(
  description: "Frontend: issue #<NR>",
  isolation: "worktree",
  prompt: "..."
)
```

Both run simultaneously. Merge branches after both complete.

### Sequential
```
# First
result1 = Agent(isolation: "worktree", prompt: "Backend: ...")
# Merge result1 branch

# Then
result2 = Agent(isolation: "worktree", prompt: "Frontend: ...")
# Merge result2 branch
```

## Merge process

1. Merge backend branch first (if it exists)
2. Merge frontend branch second
3. If conflicts → resolve manually or re-dispatch
4. Run verify.sh on merged result
