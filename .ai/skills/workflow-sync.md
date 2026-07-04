# Skill: Workflow Sync

Orchestrator skill — keeps this project's workflow core in sync with the shared
Graybark template (upstream) without manual side-by-side comparison.

## Trigger

- At sprint start (together with `backlog-reconcile`)
- Manually: "sync the workflow" / "kör workflow-sync"
- After compound-learning or a retrospective changed a file listed as `core` in the
  manifest (event-driven backport — see step 6)

## Inputs

- **Upstream:** the Graybark repo — location in `.ai/graybark.yml` (`repo` / `local_path`)
- **Upstream truth:** Graybark's `core-manifest.yml` (which files are core/adapted/local)
  and `VERSION`
- **Project state:** `.ai/graybark.yml` (`synced_version`, `local_overrides`)

## Steps

1. **Fetch upstream.** Use the local clone if `local_path` exists (run `git -C <path> pull`),
   otherwise clone the repo shallowly to `.context/graybark/`. Read `VERSION` and
   `core-manifest.yml`.

2. **Quick gate.** If upstream `VERSION` == project `synced_version` AND `git log` shows no
   commits touching manifest-listed core files in the project since `last_sync` — report
   "in sync" and stop.

3. **Compare per file** — for every `core` file in the manifest, minus the project's
   `local_overrides`:
   - Read BOTH versions. Compare **semantically**: mechanics, steps, gates, thresholds,
     formats. Translation (e.g. Swedish project file vs English core) and project-name
     substitutions are NOT drift.
   - For `adapted` files: compare section/category structure only — a missing check
     category is drift; different commands/identifiers are not.
   - Classify: `in-sync` / `downstream` (upstream has improvements the project lacks) /
     `upstream` (project has improvements upstream lacks) / `conflict` (both changed the
     same mechanic differently).

4. **Apply downstream.** Update the project files (translate to the project's file language
   if the file is non-English). Goes into a normal project PR.

5. **Backport upstream.** For `upstream` deltas: write the generic English version into the
   Graybark clone (strip project specifics — names, paths, prod identifiers become TODO or
   generic placeholders; keep empirical attributions like "Verified on <project> PR #X").
   Bump `VERSION` (minor for additions, patch for fixes), add a `CHANGELOG.md` entry,
   commit on a branch and open a PR in the Graybark repo.

6. **Conflicts** — propose a merged version (union of both improvements) and apply it BOTH
   ways in the same PRs. If the two sides genuinely contradict (same mechanic, opposite
   decisions), stop and ask the user which wins — never silently pick.

7. **Update state.** Set `synced_version` + `last_sync` in `.ai/graybark.yml` (in the
   project PR).

8. **Report.** Table: file → classification → action taken, plus both PR URLs.

## Event-driven backport (the important half)

Periodic sync is the safety net, not the mechanism. The moment compound-learning, a
retrospective, or an incident-fix improves a file that the manifest lists as `core`:

1. Note **"Backport to Graybark"** in the project PR body.
2. Run steps 5 + 7 of this skill immediately (or open a Graybark issue if time is short).

This keeps upstream fresh so the sprint-start sync usually finds nothing.

## Rules

- **Graybark is a PUBLIC repo — everything pushed there is world-readable.** This applies
  to file contents, commit messages, PR titles/bodies and review-thread replies alike.
  Never include upstream: project/product names, private repo names or links, internal
  paths, IPs, domains, customer/incident details, or anything from gitignored files.
  Attribution is always anonymous: *"a sister project"*, *"a production project"*.
  Before every upstream push: grep the outgoing content for project identifiers.
- **Never lower quality on either side** — sync direction is "union of best", not "latest wins".
- **Never push project secrets/identifiers upstream** — prod names, IPs, API hosts, bot
  workarounds tied to a private repo tier stay generic in Graybark.
- **The manifest is upstream-owned** — to add/remove core files, change Graybark's
  `core-manifest.yml` (via backport PR), not the project copy of this skill.
- Human review gates both PRs — this skill proposes, the user merges.

## Common mistakes

- Treating translation or renamed specialists as drift (it isn't — compare mechanics).
- Backporting project-specific checks verbatim instead of genericizing them.
- Updating the project but forgetting `synced_version` — next sync re-reports everything.
- Skipping the event-driven backport because "the periodic sync will catch it" — that's
  how the projects diverged for 3 months in the first place.
