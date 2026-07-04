# Skill: compress-logs

Orchestrator skill — run by the main session as the final step at sprint close.

## Trigger

Sprint close. Invoked by `.ai/workflows/retrospective.md` as the final step, after the retro report is written and committed. Do not run this skill mid-sprint or per issue — it is batch-oriented.

## Specialist

Orchestrator (main session). No subagent needed — this is a session routine you perform directly.

## Input

All `.ai/logs/<issue-nr>.md` from the sprint. Identify which issues were part of the sprint via the tracking issue or the sprint-planning document.

## Output

Three types depending on classification:

1. **`docs/solutions/<category>-<slug>.md`** — for issues with non-trivial technical lessons that future agents can reuse.
2. **Extended `## Gotchas` section in `docs/retros/sprint-retro-<date>.md`** — for issues where an assumption turned out wrong or a detour was taken but resolved.
3. **`.ai/logs/archive/<sprint>/<nr>.md`** — all raw logs, regardless of classification, are moved here. The archive folder is gitignored and can be cleaned manually.

## Rubric — what goes where

Classify each log file into exactly one of three levels:

| Level | Criteria | Output |
|-------|----------|--------|
| **Trivial** | 1 iteration, no review blockers, no failed attempts | Archive only — nothing written to `docs/` |
| **Gotcha** | A reviewer found an assumption that turned out wrong, or a specialist took a detour but still resolved it | 3–5 line note in `## Gotchas` in the retro file |
| **Solution** | Non-trivial technical challenge solved with a lesson that can be reused in future issues | New file in `docs/solutions/` per the compound-learning format |

When in doubt: pick the lower level. A false gotcha is harmless; an over-dimensioned solution dilutes `docs/solutions/`.

## Steps

1. **Identify log files.** List all `.ai/logs/<issue-nr>.md` belonging to the sprint. Skip files that aren't issue logs (e.g. `planned-files.txt`, `current-issue.json`).

2. **Read each log file.** For each file: note the number of iterations, presence of review blockers, failed attempts, and any technical insights.

3. **Classify per the rubric.** Assign each log one of: `trivial`, `gotcha`, `solution`. Keep your rationale in mind — you need it in the next step.

4. **Write output per classification.**

   - **Trivial:** Do nothing more — go straight to the archive step.

   - **Gotcha:** Add a bullet under `## Gotchas` in `docs/retros/sprint-retro-<date>.md`. Format:
     ```
     - **#<nr> <title>:** <1–2 sentences on what the assumption was and what actually held.>
     ```

   - **Solution:** Create `docs/solutions/<category>-<slug>.md` per the compound-learning format (see `.ai/skills/compound-learning.md`). Use one of the categories: `bug-pattern`, `architecture`, `workflow`, `domain`, `testing`.

5. **Move raw logs to the archive.** Determine the sprint name (e.g. `sprint-5` or the date `2026-04-15`). Create `.ai/logs/archive/<sprint>/` if it doesn't exist. Move each log file there:
   ```bash
   mkdir -p .ai/logs/archive/<sprint>
   mv .ai/logs/<nr>.md .ai/logs/archive/<sprint>/<nr>.md
   ```
   Move *all* logs — trivial ones too. The archive is gitignored, so no commits are needed for the archive folder.

6. **Update `docs/solutions/README.md`** (or your solutions index) if you created one or more solution files. Add one line per new file to the index.

## Common mistakes

- **Deleting raw logs without writing anything to `docs/`** — the lesson is permanently lost. Always move, never delete directly.
- **Writing trivial logs as gotchas** — creates noise in the retro report. Keep `## Gotchas` to actual surprises.
- **Writing gotchas as solutions** — dilutes `docs/solutions/` with over-granular information. A solution must be reusable in another issue, not just a note.
- **Skipping the archive step** — logs left in the `.ai/logs/` root confuse the next sprint.
- **Forgetting to update the solutions index** — new solutions become unfindable without it.

## Example

**Hypothetical scenario — Sprint 5, three issues:**

| Issue | Log summary | Classification | Output |
|-------|-------------|----------------|--------|
| #148 — Update test configuration | 1 iteration, no blockers | Trivial | Archive only |
| #150 — Add index on `transactions` | 2 iterations. Backend Specialist created a non-concurrent index that locked the table. Reviewer blocked. Fix: `CREATE INDEX CONCURRENTLY`. | Gotcha | Line in `## Gotchas`: "**#150 transactions index:** Assumed `CREATE INDEX` is non-blocking — it isn't without `CONCURRENTLY`." |
| #155 — JWT verification in serverless functions | 3 iterations. An access policy was missing for the service role, and the JWT library required a specific key format. Lesson codifiable. | Solution | `docs/solutions/bug-pattern-service-role-jwt-verification.md` |

After classification:
```bash
mkdir -p .ai/logs/archive/sprint-5
mv .ai/logs/148.md .ai/logs/150.md .ai/logs/155.md .ai/logs/archive/sprint-5/
```

## When the skill is done

Commit the new solution files and the retro update:

```bash
git add docs/solutions/<new>.md docs/retros/sprint-retro-<date>.md
git commit -m "docs: compound learning from sprint <N>"
```

The archive folder `.ai/logs/archive/` is gitignored — you don't need to commit it.
