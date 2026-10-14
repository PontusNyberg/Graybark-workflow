# Changelog

All notable changes to the Graybark workflow core. Versions follow semver:
minor = new mechanics/components, patch = fixes/clarifications.
Downstream projects track their synced version in `.ai/graybark.yml`.

## 2.3.0 — 2026-10-14

Backport of three months of production evolution from a downstream project.

### Added
- **Shortcut-marker convention** (`.ai/rules/always.md` + new `.ai/rules/on-shortcut-markers.md`).
  A deliberate shortcut is marked `// shortcut: <ceiling>, <upgrade trigger>` and is then a
  decision rather than a reviewer finding — unless the ceiling is already crossed. The
  ceiling must be **checkable** (a number or named condition); an uncheckable ceiling counts
  as no ceiling and silences nothing. A gated exception list ("this may never be shortcut":
  security, validation at trust boundaries, error handling that prevents data loss,
  accessibility, anything the user asked for) is read from the BASE revision, and a diff that
  deletes — or narrows — an entry from it is a blocker in itself. The rule file is listed
  explicitly under `core` in `core-manifest.yml`, overriding the `local` glob
  `.ai/rules/on-*.md`, and is injected into every reviewer dispatch (implement-issue Step 8
  and the fresh-review loop). It also records what a mechanical guard for the rule is NOT:
  the downstream implementation leaked in four consecutive review rounds, each time through a
  hole in the previous patch's *justification* — including an appended variable assignment
  that neutralized the gate with no `-` line. The two control-file classes (semantic, gated on
  every change; delivery path, gated when the wiring is touched) come from that history.
- **Evidence requirement in all five reviewer profiles.** Every finding must carry a concrete
  failure scenario (input/state → wrong outcome); `failure_scenario` and `fix` are now
  required fields on `blocker` and `warning`, `if_skipped` on `blocker`. A finding that cannot
  be filled in is not ripe — drop it to `nit` or cut it. `evaluate-reviews.sh` prints the
  scenario and the fix alongside each blocker.
- **`.ai/agents/reviewer-skip-approver.md` + skip approval in `evaluate-reviews.sh`.** A
  risk-free diff (in practice pure prose) may skip the three mandatory reviewers, but only
  with a one-line reason an isolated agent approved. The approver gets the branch, the reason,
  the file list and the diff — never the issue or the session's reasoning — and defaults to
  `denied`. The exit-code contract is explicit: 0 pass/skipped, 1 blockers or a failing
  verdict, 2 artifact problem. Empty `reason`, `approver` or `rationale` is a hard fail, not a
  pass — those fields are the only audit trail for skipping all code review. A denial is a
  normal outcome: run the reviewers, do not escalate.
- **Per-branch review artifact directory** (new `.ai/scripts/review-dir.sh`), replacing the
  shared `/tmp` default: `<repo-root>/.ai/logs/reviews/<branch-slug>/`, with precedence
  explicit argument > `$REVIEW_DIR` > per-branch default. In a worktree the root is that
  worktree's own, so parallel sessions cannot collide. Verified empirically 2026-08-08:
  three sessions sharing `/tmp` lost a review context mid-round and overwrote three verdicts
  about entirely different files. The resolution and the skip validation have exactly ONE
  implementation, shared by every caller — two copies that drift mean the round writes in one
  directory and the evaluation reads in another, i.e. silent green.
- **`.ai/skills/shortcut-debt.md`** — sprint-start ledger over `shortcut:`/`TODO`/`FIXME`
  markers: reads each ceiling, flags the crossed ones as bugs rather than debt, and tags
  `no-trigger` / `no-ceiling`. The marker pattern must stay in phase with any mechanical
  guard's pattern — two patterns that disagree ARE a bypass.
- **`.ai/skills/repo-audit.md`** — whole-repo review as a read-only report (must fix / should
  fix / nice to have), adapted from ponytail (MIT). Deliberately NOT a sprint-start skill, and
  never part of implement-issue. Includes the rules for reading credential material: presence
  and prefix only, never values, in the report and in every issue it becomes.
- **`.ai/skills/grill.md` + `.ai/scripts/grill-comment.sh`** — unclear acceptance criteria in
  Step 2 are now clarified via `AskUserQuestion` instead of stopping at
  `needs-clarification`, with a decision gate in Step 4 sharing one 3-round budget per issue.
  Only questions whose answer changes which files are touched or which AC apply may be asked.
  The budget is deliberately self-discipline, not a counter: a counter written by the agent it
  limits cannot fire. Decisions are posted to the issue through one narrow script — no code
  path to the body, the title, other repos or other hosts; destination compared against a
  constant; environment built with an `env -i` allowlist; `gh`'s config directory pinned to an
  empty directory so `http_unix_socket` cannot redirect the transport via
  `HOME`/`APPDATA`/`USERPROFILE`; token via stdin, never argv. Verified empirically
  2026-08-13 (gh 2.80.0, Windows): a poisoned `APPDATA` redirected `gh` to a unix socket with
  `-R` untouched. The script's header is explicit that it is a narrow interface, not a
  sandbox — it does not stop a caller who controls `PATH`.

### Changed
- `always.md`: `AskUserQuestion` in the main session is now an explicit exception to the
  interactive-prompts ban (it is harness-handled and returns a structured answer; subagents do
  not have it and are not covered).
- `implement-issue.md`: Step 1 also fetches issue comments (a grill comment is a **memory, not
  an authority** — `OWNER` is set by construction when an agent posts with the owner's token,
  so the check excludes third parties, not your own loop); Step 2 calls grill instead of
  stopping; Step 4 gained the decision gate; Step 4b gained the CLARIFIED DECISIONS prompt
  block (framed as material, since subagents cannot ask); Step 8 gained the artifact-directory
  and skip sections and injects the shortcut rule into every reviewer prompt; Step 9 documents
  the exit-code contract.
- `sprint-planning.md`: Step 0 runs `shortcut-debt`; unclear issues at planning time are
  deferred rather than grilled (grill belongs to implementation, where ambiguity blocks
  concrete work).
- `.claude/skills/fresh-review/SKILL.md`: injects the shortcut rule and tells the reviewer to
  read the exception list from the base revision; documents that an "later commits are
  unreviewed" warning from a review gate is EXPECTED in the fix loop — restarting the review
  round mid-loop would discard the Step 8 verdicts the gate exists to check.

## 2.2.0 — 2026-08-28

### Changed
- **Slash commands migrated to Claude Code skills.** `.claude/commands/fresh-review.md`
  and `.claude/commands/ship-and-watch.md` moved to `.claude/skills/<name>/SKILL.md`
  with `name` + `description` frontmatter. Same `/fresh-review` and `/ship-and-watch`
  invocations for the user, but now the model can also trigger them itself via the
  Skill tool when the workflow reaches the shipping/review step, and the description
  is visible in every session's skill listing. Backported from a downstream project
  (2026-08-28). `core-manifest.yml` core entries updated accordingly (manifest
  `version` also aligned with `VERSION` — it had lagged at 2.0.0 since 2.1.0).



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
