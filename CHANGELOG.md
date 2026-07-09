# Changelog

All notable changes to the Graybark workflow core. Versions follow semver:
minor = new mechanics/components, patch = fixes/clarifications.
Downstream projects track their synced version in `.ai/graybark.yml`.

## 2.1.0 — 2026-07-09

### Added
- **parallel-dispatch: mandatory STEP 0 merge for dependent sequential packages.**
  Worktree agents fork from the DEFAULT branch, not from the orchestrator's
  checked-out sprint branch — a sequential package building on earlier merged
  sprint work does not see it automatically. The skill now prescribes a
  merge-first prompt step (`git merge <sprint-HEAD-sha> --no-edit` + verifiable
  postcondition; exact sha, never a branch name). Verified empirically on a
  production project, 2026-07-09: one specialist built on a false premise and a
  second was headed into avoidable merge conflicts before mid-flight correction.

## 2.0.0 — 2026-07-04

Union of three months of production evolution in the two downstream production
projects, plus the sync layer that keeps them aligned going forward.

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
- **`/fresh-review` command + `reviewer-fresh-eyes` agent:** quota-free replacement for
  the Copilot gate — an isolated adversarial reviewer (diff-only input, no session
  context) run as a synchronous subagent in a fix-loop until a clean round
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

Initial extraction from a production project: orchestrator + worktree-isolated specialists,
3 parallel reviewers, verify.sh gate, 4-iteration limit, compound learning.
