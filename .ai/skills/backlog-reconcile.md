# Skill: backlog-reconcile

Orchestrator routine that syncs the backlog/plans against what ACTUALLY exists in the code.
Inspired by shadcn/improve `reconcile`. Run by the main session — codes nothing itself.

## Trigger

- At the start of sprint planning (before new issues are prioritized) — see `.ai/workflows/sprint-planning.md`
- Manually when you suspect the backlog/plans have drifted from reality
- After a longer period where several PRs merged in parallel (plans may be stale)

## Specialist

None — orchestrator skill. Dispatch read-only `Explore` agents for verification if needed,
but make the decisions in the main session.

## Steps

1. **Fetch truth.** `git fetch origin master` (or `main`) and work from the latest default
   branch — parallel merges make the local picture stale.

2. **List open threads.** Collect open issues, plans in `docs/plans/`, and any `needs-human-*` issues.

3. **Verify against the code — per thread, classify:**
   - **Landed** — the functionality already exists on the default branch. Verify with actual code/grep, not memory.
     → Close the issue with a comment + commit reference. Mark the plan as done.
   - **Drifted** — the plan/issue describes a current state that no longer holds (files moved,
     API changed). → Update the plan against current code, or mark it for rewriting.
   - **Blocked** — waiting on a dependency. → Note what blocks it; unblock if the dependency has landed.
   - **Still valid** — untouched, correct. → Leave it.
   - **Obsolete** — no longer relevant (tech change, scope change). → Close/archive with rationale.

4. **Truth-check "done" with evidence.** Never claim a thread has landed without fresh verification
   (see `always.md` → Verification). Run grep/tests, show output.

5. **Report.** Short summary to the user: what was closed, what was updated, what is blocking.
   Wait for confirmation before closing issues on GitHub if you are unsure.

## What this is NOT

- Not a new audit (that's `ideate`/`/code-review`) — reconcile only verifies that the existing
  backlog mirrors reality.
- Not implementation — no code changes, only backlog/plan hygiene.

## Common mistakes

- Closing an issue based on memory instead of verifying in the code (off-by-one against reality).
- Forgetting `git fetch origin master` first → judging against a stale local picture.
- Closing GitHub issues without the user's confirmation when unsure.
