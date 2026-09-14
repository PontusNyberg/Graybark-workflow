# TODO: Project Name

TODO: Short project description. Tech stack, purpose, team.

## Pre-flight (before code changes)

Code changes go through `.ai/workflows/implement-issue.md`: quality in this project comes from the plan → specialist → verify → review loop, and the verify.sh scope check depends on the plan existing. Before changing code:

1. Load `.ai/rules/always.md` and the rules matching the affected files (table below)
2. Follow implement-issue steps 1–4 — reading the code to plan is part of this
3. Write `.ai/logs/planned-files.txt` with all files to be changed
4. Delegate the implementation to specialists via Agent tool with `isolation: "worktree"`

"Implement #42", "go ahead", "add X" or "fix Y" says what to do; the workflow decides how. Code directly only when the user explicitly says so ("skip workflow", "code directly") or the change qualifies as a small issue (see Iteration logs below).

### Pre-commit hook (secret scan)

A defense-in-depth pre-commit hook in `.githooks/pre-commit` (if you create one) blocks commits with secret patterns (service-role keys, live API keys, JWTs, etc.). Activate the hook locally ONCE per clone:

```bash
git config core.hooksPath .githooks
```

The hook is a safety net — it does not replace discipline around never committing secrets in cleartext.

## AI Agent System

For **issue implementation**: Follow `.ai/workflows/implement-issue.md` step by step.
For **sprint planning**: Follow `.ai/workflows/sprint-planning.md`.
For **retrospectives**: Follow `.ai/workflows/retrospective.md`.
For **shipping + external AI review**: Run `/fresh-review` (`.claude/skills/fresh-review/SKILL.md`) — iterative review by the isolated fresh-eyes agent until a clean round, no external quota. `/ship-and-watch` (`.claude/skills/ship-and-watch/SKILL.md`) does the same via GitHub Copilot — optional extra pass on high-stakes PRs. Both are Claude Code skills: the user triggers them with `/<name>`, and the model can trigger them itself via the Skill tool when the workflow reaches that step.
Full system documentation: `.ai/CLAUDE.md`.

**Keeping in sync with the shared template:** `core-manifest.yml` lists which files are shared workflow core; `.ai/skills/workflow-sync.md` syncs them both ways (project ↔ template).

## Iteration logs (MANDATORY per issue)

Every issue MUST have a log file `.ai/logs/<issue-nr>.md` — even with 1 iteration.
The log is critical during long conversations that get compacted.

**Exception — small issues (direct coding allowed):**
Issues that are ONLY text changes, renames, or config adjustments (<20 lines changed, no new files)
need neither iteration log nor specialist delegation. Code directly.

**Format:** See `.ai/workflows/implement-issue.md` → Log format.

## Sprint close (MANDATORY)

When a sprint is complete (all issues implemented, pushed and PR created) you MUST:

1. **Verify iteration logs** — every issue (except small/trivial) should have `.ai/logs/<issue-nr>.md`
2. **Run retrospective** — write `docs/retros/sprint-retro-<date>.md` per `.ai/workflows/retrospective.md`
3. **Update sprint tracker** — check off all issues in the tracking issue
4. **Close already-implemented issues** — if an issue turns out to already be done, close with comment

Do NOT wait for the user to remind you — this is part of the sprint workflow.

## Rules

ALWAYS load `.ai/rules/always.md`. Load other rules based on affected files:

| Files | Rule |
|-------|------|
| `src/` or frontend paths | `.ai/rules/on-frontend.md` |
| `api/` or backend paths | `.ai/rules/on-backend.md` |
| Database migrations | `.ai/rules/on-migration.md` |
| `*_test.*`, `*.test.*` | `.ai/rules/on-testing.md` |

TODO: Adjust the table above to match your project structure.

## Skills

Reusable agent routines in `.ai/skills/`. Match issue to skill trigger in Step 4b, inject into specialist prompt.
New skills require PR review. See `.ai/workflows/skill-lifecycle.md`.

### Orchestrator skills (run by main session)

| Skill | Trigger |
|-------|---------|
| `compound-learning` | Step 11 — document solution in `docs/solutions/` |
| `ideate` | Manual — proactive improvement identification |
| `parallel-dispatch` | 2+ independent work packages |
| `backlog-reconcile` | Sprint start, or when backlog/plans have drifted from the code |
| `incident-fix-scoping` | Issue labeled `incident`/`postmortem` or branch `hotfix/*` (Step 4a) |
| `compress-logs` | Sprint close — final step of the retrospective |
| `workflow-sync` | Sprint start, or when a core-manifest file changed |

## Specialist routing

| Domain | Specialist | Agent |
|--------|-----------|-------|
| Frontend | TODO: Name | `.claude/agents/frontend-developer.md` |
| Backend | TODO: Name | `.claude/agents/backend-developer.md` |
| Architecture, CI/CD | TODO: Name | `.claude/agents/tech-lead.md` |
| Scope, prioritization (advisor) | TODO: Name | `.claude/agents/product-skeptic.md` |
| UX (advisor) | TODO: Name | `.claude/agents/product-designer.md` |

**Reviewers:** correctness, security, conventions always; lifecycle conditionally (stateful diffs — deterministic trigger in implement-issue Step 8) — `.ai/agents/reviewer-*.md`. Plus an optional specialist cross-reviewer.

## Parallel dispatch (worktrees)

Specialists are dispatched via Agent tool with `isolation: "worktree"`. Each specialist gets an isolated copy of the repo and edits files directly — no `### FILE:` markers or manual application needed.

**Parallel:** Independent work packages (no shared files) → dispatch in same message:
```
Agent(isolation: "worktree", prompt: "Backend: ...")  ─┐ simultaneously
Agent(isolation: "worktree", prompt: "Frontend: ...") ─┘
→ merge branches to feature branch
```

**Sequential:** Dependent work packages (frontend needs backend) → one at a time.

**Dependency analysis:** If work packages' file lists overlap → sequential. If they don't → parallel.

See `.ai/skills/parallel-dispatch.md` and `.ai/workflows/implement-issue.md` Step 5 for details.

## Hard requirements

1. **Feature branch + PR** — NEVER commit directly on main/master, work on branch and create PR
2. **Tests mandatory** — verify.sh blocks without tests. Adjust test placement rules per your framework.
3. **Max 4 iterations** — then graded escalation: `needs-human-p2` (quick-fix hypothesis), `needs-human-p1` (unclear how to proceed), or `needs-human-p0` (requires architecture/product decision). See the rubric in `.ai/workflows/implement-issue.md` → "Escalation states".
4. **Never commit** `.env`, credentials, `node_modules/`, `vendor/`
5. **Explicit file staging** — never `git add -A`
6. **Worktree isolation for specialists** — always dispatch coding agents with `isolation: "worktree"`
7. **Dependency analysis before parallel dispatch** — verify that work packages don't share files

## Artifact lifecycle

| Type | Location | Lifecycle | Committed? |
|------|----------|-----------|------------|
| **Ephemeral** | `.context/` | Cleaned after task completion | No (gitignored) |
| **Solutions** | `docs/solutions/` | Permanent — compound learning | Yes |
| **Brainstorms** | `docs/brainstorms/` | Permanent — ideation output | Yes |
| **Plans** | `docs/plans/` | Permanent — technical plans | Yes |
| **Iteration logs** | `.ai/logs/<nr>.md` | Session-local — cleaned manually | No (gitignored) |
| **Sprint retros** | `docs/retros/sprint-retro-*.md` | Permanent | Yes |
