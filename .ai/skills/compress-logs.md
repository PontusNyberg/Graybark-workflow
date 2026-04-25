# Skill: compress-logs

Orchestrator skill — run by the main session as the final step at sprint close.

## Trigger

Sprint close. Invoked by `.ai/workflows/retrospective.md` as the final step, after the retro report is written and committed. Do not run this skill mid-sprint or per issue — it is batch-oriented.

## Specialist

Orchestrator (main session). No subagent needed — this is a session routine you perform directly.

## Input

All `.ai/logs/<issue-nr>.md` from the sprint. Identify which issues were part of the sprint via the tracking issue or sprint planning document.

## Output

Three types depending on classification:

1. **`docs/solutions/<category>-<slug>.md`** — for issues with non-trivial technical lessons that can be reused by future agents.
2. **Extended `## Gotchas` section in `docs/retros/sprint-retro-<date>.md`** — for issues where an assumption proved wrong or a workaround was taken but resolved.
3. **`.ai/logs/archive/<sprint>/<nr>.md`** — all raw logs, regardless of classification, are moved here. The archive folder is gitignored and can be cleaned manually.

## Rubric — what goes where

Classify each log file in exactly one of three tiers:

| Tier | Criteria | Output |
|------|----------|--------|
| **Trivial** | 1 iteration, no review blockers, no failed attempts | Archive only — nothing written to `docs/` |
| **Gotcha** | Reviewer found an assumption that proved wrong, or specialist took a workaround but solved it anyway | 3–5 line note in `## Gotchas` in the retro file |
| **Solution** | Non-trivial technical challenge solved with a lesson reusable in future issues | New file in `docs/solutions/` per the compound-learning format |

Borderline classification: pick the lower tier. A false gotcha is harmless; an oversized solution dilutes `docs/solutions/`.

## Steps

1. **Identify log files.** List all `.ai/logs/<issue-nr>.md` belonging to the sprint. Skip files that aren't issue logs (e.g. `planned-files.txt`, `current-issue.json`).

2. **Read each log file.** For each: note iteration count, occurrence of review blockers, failed attempts, and any technical insights.

3. **Classify per the rubric.** Assign each log one of: `trivial`, `gotcha`, `solution`. Document your reasoning in memory — you need it in the next step.

4. **Write output per classification.**

   - **Trivial:** Do nothing more — go straight to the archive step.

   - **Gotcha:** Add a bullet under `## Gotchas` in `docs/retros/sprint-retro-<date>.md`. Format:
     ```
     - **#<nr> <title>:** <1–2 sentences about what the assumption was and what was actually true.>
     ```

   - **Solution:** Create `docs/solutions/<category>-<slug>.md` per the compound-learning format (see `.ai/skills/compound-learning.md` → Step 3). Use one of these categories: `bug-pattern`, `architecture`, `workflow`, `domain`, `testing`.

5. **Move raw logs to archive.** Determine the sprint name (e.g. `sprint-5` or the date `2026-04-15`). Create `.ai/logs/archive/<sprint>/` if it doesn't exist. Move each log file there:
   ```bash
   mkdir -p .ai/logs/archive/<sprint>
   mv .ai/logs/<nr>.md .ai/logs/archive/<sprint>/<nr>.md
   ```
   Move *all* logs — even trivial ones. The archive is gitignored, so no commits are needed for the archive folder.

6. **Update `docs/solutions/README.md`** if you created one or more solution files. Add a row per new file in the index.

## Common mistakes

- **Deleting raw logs without writing anything to `docs/`** — the lesson is lost permanently. Always move, never delete directly.
- **Writing trivial logs as gotchas** — creates noise in the retro report. Keep `## Gotchas` to actual surprises.
- **Writing gotchas as solutions** — dilutes `docs/solutions/` with too granular information. A solution should be reusable in another issue, not just a note.
- **Skipping the archive step** — logs left in the `.ai/logs/` root confuse the next sprint.
- **Forgetting to update `docs/solutions/README.md`** — new solutions become unsearchable without the index.

## Example

**Hypothetical scenario — Sprint 5, three issues:**

| Issue | Log summary | Classification | Output |
|-------|-------------|----------------|--------|
| #148 — Update test config | 1 iteration, no blockers | Trivial | Archive only |
| #150 — Add index on `transactions` | 2 iterations. Backend created a non-concurrent index that locked the table. Reviewer blocked. Fix: `CREATE INDEX CONCURRENTLY`. | Gotcha | Row in `## Gotchas`: "**#150 transactions index:** Assumed `CREATE INDEX` is non-blocking — it isn't without `CONCURRENTLY`." |
| #155 — JWT verification in API | 3 iterations. Auth policy missing for service-role, plus the JWT library required a specific key format. Lesson is codifiable. | Solution | `docs/solutions/bug-pattern-service-role-jwt.md` |

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

The archive folder `.ai/logs/archive/` is gitignored — no need to commit it.
