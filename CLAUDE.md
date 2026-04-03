# TODO: Project Name

TODO: Short project description. Tech stack, purpose, team.

## Pre-flight (BLOCKING — before ALL coding)

Before writing or changing a single line of code, these steps MUST be completed:

1. **Load** `.ai/rules/always.md`
2. **Load** `.ai/workflows/implement-issue.md` and follow steps 1–4
3. **Create** `.ai/logs/planned-files.txt` with all files to be changed
4. **Load** relevant rules from the table below based on affected files
5. **Delegate** to specialists via Agent tool with `isolation: "worktree"` — do NOT code yourself

If the user says "go ahead", "implement", or similar — start with step 1, NOT with code.
Jumping straight to coding without pre-flight is a workflow violation.

### Instruction priority

1. **User's explicit instructions** (direct requests, conversation context) — highest
2. **This CLAUDE.md + workflows/skills** — overrides default behavior
3. **System default** — lowest

If the user says "skip workflow" or "code directly" — obey the user. But "implement #42" does NOT mean "skip workflow" — it means "follow the workflow to implement #42".

**Principle:** User instructions say WHAT, not HOW. "Add X" or "Fix Y" does not mean skip pre-flight — it says what to do, the workflow determines how.

### Rationalization guard

If you think any of the following — STOP. You're rationalizing away the workflow:

| Thought | Reality |
|---------|---------|
| "This is just a simple change" | If it touches code → pre-flight applies (exception: <20 lines, see below) |
| "I need to explore the code first" | Pre-flight comes BEFORE implementation exploration |
| "I can quickly fix this without workflow" | Quick fixes without workflow have caused regressions before |
| "This doesn't need formal process" | If the workflow applies → follow it. Period. |
| "I'll just do a small thing first" | Workflow check BEFORE you do anything |
| "The user seems to want it fast" | Fast = follow the workflow efficiently, not skip it |
| "I already know what's needed" | Knowing the answer ≠ skipping the process |

## AI Agent System

For **issue implementation**: Follow `.ai/workflows/implement-issue.md` step by step.
For **sprint planning**: Follow `.ai/workflows/sprint-planning.md` (or run `bash .ai/scripts/sprint-planning.sh`).
For **retrospectives**: Run `bash .ai/scripts/retrospective.sh`.
Full system documentation: `.ai/CLAUDE.md`.

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
| `compound-learning` | After Step 10 — document solution in `docs/solutions/` |
| `ideate` | Manual — proactive improvement identification |
| `parallel-dispatch` | 2+ independent work packages |

## Specialist routing

| Domain | Specialist | Agent |
|--------|-----------|-------|
| Frontend | TODO: Name | `.claude/agents/frontend-developer.md` |
| Backend | TODO: Name | `.claude/agents/backend-developer.md` |
| Architecture, CI/CD | TODO: Name | `.claude/agents/tech-lead.md` |
| Scope, prioritization (advisor) | TODO: Name | `.claude/agents/product-skeptic.md` |
| UX (advisor) | TODO: Name | `.claude/agents/product-designer.md` |

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
3. **Max 4 iterations** — then `needs-human`
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
