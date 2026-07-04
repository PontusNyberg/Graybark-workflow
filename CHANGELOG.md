# Changelog

All notable changes to the Graybark workflow core. Versions follow semver:
minor = new mechanics/components, patch = fixes/clarifications.
Downstream projects track their synced version in `.ai/graybark.yml`.

## 2.0.0 — 2026-07-04

Union of three months of production evolution in the two downstream projects
(PennyKoll, Verolog), plus the sync layer that keeps them aligned going forward.

### Added
- **Sync layer:** `VERSION`, `core-manifest.yml` (core/adapted/local file classification),
  `.ai/skills/workflow-sync.md` (semantic two-way sync skill with event-driven backport)
- **Fourth generic reviewer:** `.ai/agents/reviewer-lifecycle.md` — state machines,
  cross-module signal journeys, resource cleanup, second-occurrence bugs (born from a
  sister-project incident where 5 CRITICAL lifecycle bugs passed three conventional reviewers)
- **Missing workflows** (previously referenced but never extracted):
  `sprint-planning.md`, `retrospective.md`, `skill-lifecycle.md` (incl. Phase 2.5
  security gate for external skills — SkillSpector scan + manual source review)
- **Skills:** `backlog-reconcile.md`, `incident-fix-scoping.md` (max 3 PRs per incident),
  `compress-logs.md`
- **Enforcement hooks** in `.claude/settings.json`: SessionStart pre-flight gate,
  Edit/Write block until `planned-files.txt` exists, `git add -A` block, verify reminder
- **Safety hook:** `.claude/hooks/safety-check.sh` + test suite (38 tests) — blocks
  destructive commands (prod DB ops, force-push to main, rm -rf on critical dirs,
  package publishing, staging secrets); read operations always pass
- **`/ship-and-watch` command:** self-driving AI-review loop (GraphQL Copilot trigger,
  cache-aware 270s polling, two-silent-ticks exit, cutoff timestamp, hard caps)
- **`docs/` structure:** `plans/TEMPLATE.md` (self-contained plan format),
  `solutions/`, `brainstorms/`, `retros/`

### Changed
- `implement-issue.md`: Step 4a incident scoping, 4 generic reviewers in Step 8,
  optional AI code review gate, Step 10.5 handoff prompt, Step 11 compound learning
  as a mandatory A/B decision (`Solution-doc: N/A — <reason>` to waive),
  graded escalation `needs-human-p0/p1/p2` with selection rubric
- `always.md`: decision ladder before generating code; date empirical platform findings
- `verify.sh`: review gate now covers all implementation branches
  (`sprint*`/`feat/*`/`fix/*`/`hotfix/*` — previously `fix/*` silently skipped the gate)
  and includes the lifecycle review verdict

## 1.0.0 — 2026-04-03

Initial extraction from PennyKoll: orchestrator + worktree-isolated specialists,
3 parallel reviewers, verify.sh gate, 4-iteration limit, compound learning.
