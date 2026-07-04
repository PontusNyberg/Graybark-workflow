# Graybark Workflow

> A structured multi-agent development workflow for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).
> Named after a capybara who watches from the sidelines.

## The problem

You tell Claude Code to "implement issue #42" and it writes code. Sometimes great code. Sometimes it misses edge cases, skips tests, introduces scope creep, or produces something that doesn't match the acceptance criteria. You catch it in review — after it already committed.

**Graybark Workflow** adds structure to the chaos. Instead of one AI session doing everything, it orchestrates a team of specialist agents with built-in quality gates that catch problems *before* they reach your PR.

## How it works

```
 Issue
   │
   ▼
 ┌─────────────────────────┐
 │     ORCHESTRATOR         │  ← Main Claude Code session
 │  (reads, plans, routes)  │
 └──────┬──────────┬────────┘
        │          │
   ┌────▼───┐ ┌───▼────┐
   │Backend │ │Frontend│      ← Specialist agents in isolated worktrees
   │ agent  │ │ agent  │         (code + tests, run in parallel)
   └────┬───┘ └───┬────┘
        │         │
        ▼         ▼
 ┌─────────────────────────┐
 │      MERGE + VERIFY     │  ← verify.sh: lint, types, tests, secrets, scope
 └──────────┬──────────────┘
            │
   ┌────────┼────────┐
   ▼        ▼        ▼
 ┌────┐  ┌────┐  ┌──────┐
 │Corr│  │Sec │  │ Conv │    ← Review agents (parallel, JSON verdicts)
 └──┬─┘  └──┬─┘  └──┬───┘
    │       │       │
    ▼       ▼       ▼
 ┌─────────────────────────┐
 │   EVALUATE & COMMIT     │  ← Auto-parse reviews, commit if clean
 └─────────────────────────┘
            │
            ▼
    Compound Learning         ← Document what was learned
```

If verify or review fails → the orchestrator sends feedback to the specialist and retries. Max 4 iterations, then it escalates to you.

## What's in the box

| Layer | What | Purpose |
|-------|------|---------|
| **Workflows** | `implement-issue.md`, `sprint-planning.md`, `retrospective.md`, `skill-lifecycle.md` | Issue→PR pipeline, sprint planning, retros, skill governance |
| **Specialists** | frontend, backend, architect agents | Code + test in worktree isolation |
| **Advisors** | UX designer, scope guardian | Advise without coding |
| **Reviewers** | correctness, security, conventions, lifecycle | Parallel diff review with JSON verdicts |
| **Quality gate** | `verify.sh` | Blocks on lint, type, test, secret, scope failures |
| **Safety hook** | `.claude/hooks/safety-check.sh` | PreToolUse hook blocking dangerous commands (DROP TABLE, force push, rm -rf, secret staging) — with its own test suite |
| **Commands** | `/ship-and-watch` | Self-driving push→PR→Copilot-review loop until the external reviewer is silent |
| **Skills** | compound-learning, parallel-dispatch, ideate, backlog-reconcile, incident-fix-scoping, compress-logs, workflow-sync | Reusable agent routines |
| **Rules** | always, on-frontend, on-backend, on-migration, on-testing | Injected into agent prompts based on affected files |
| **Sync** | `core-manifest.yml` + `VERSION` + workflow-sync skill | Keep downstream projects and this template in sync |

## Quick start

### 1. Copy into your project

```bash
# Option A: Clone and copy
git clone git@github.com:PontusNyberg/Graybark-workflow.git
cp -r Graybark-workflow/.ai your-project/.ai
cp -r Graybark-workflow/.claude your-project/.claude
cp Graybark-workflow/CLAUDE.md your-project/CLAUDE.md

# Option B: Use as GitHub template
# Click "Use this template" on GitHub
```

### 2. Fill in the TODOs

Every project-specific part is marked with `TODO:`. Find them all:

```bash
grep -r "TODO:" .ai/ .claude/ CLAUDE.md
```

The main things to customize:
- **`CLAUDE.md`** — Your project name, tech stack, file paths, hard requirements
- **`.claude/agents/*.md`** — Your specialists' expertise and framework knowledge
- **`.ai/scripts/verify.sh`** — Your linter, type checker, and test commands
- **`.ai/rules/on-*.md`** — Your coding conventions per domain

### 3. Use it

```
You: implement #42
Claude: *reads issue, loads rules, plans work packages, dispatches specialists...*
```

That's it. The workflow handles the rest.

## File structure

```
.ai/
├── CLAUDE.md                    # Agent system overview
├── workflows/
│   ├── implement-issue.md       # The 11-step workflow
│   ├── sprint-planning.md       # Sprint planning with scope advisor + velocity
│   ├── retrospective.md         # Sprint retros → rule/skill improvements
│   └── skill-lifecycle.md       # How skills are proposed, reviewed, activated
├── rules/
│   ├── always.md                # Universal rules (scope, types, git, quality)
│   ├── on-frontend.md           # Frontend conventions
│   ├── on-backend.md            # Backend conventions
│   ├── on-migration.md          # Database migration rules
│   └── on-testing.md            # Test writing rules
├── agents/
│   ├── reviewer-correctness.md  # "Does it fulfill the acceptance criteria?"
│   ├── reviewer-security.md     # "Is it secure?"
│   ├── reviewer-conventions.md  # "Does it follow our patterns?"
│   └── reviewer-lifecycle.md    # "What happens across calls and module boundaries?"
├── scripts/
│   ├── verify.sh                # Quality gate (customize this!)
│   └── evaluate-reviews.sh      # Parses reviewer JSON verdicts
├── skills/
│   ├── compound-learning.md     # Post-implementation learning capture
│   ├── parallel-dispatch.md     # Dependency analysis for parallel agents
│   ├── ideate.md                # Proactive improvement identification
│   ├── backlog-reconcile.md     # Sync backlog/plans against actual code
│   ├── incident-fix-scoping.md  # Split incident fixes into ≤3 focused PRs
│   ├── compress-logs.md         # Sprint-close log compression + archiving
│   ├── workflow-sync.md         # Two-way sync with this template
│   └── triggers.yml             # When to inject which skill
└── logs/                        # Session-local (gitignored)

.claude/
├── agents/
│   ├── frontend-developer.md    # Codes UI, components, pages
│   ├── backend-developer.md     # Codes API, database, auth
│   ├── tech-lead.md             # Codes config, CI/CD, architecture
│   ├── product-designer.md      # UX advice (no code)
│   ├── product-skeptic.md       # Scope control (no code)
│   └── TEAM.md                  # Who does what
├── commands/
│   └── ship-and-watch.md        # /ship-and-watch — automated Copilot review loop
├── hooks/
│   ├── safety-check.sh          # PreToolUse hook: blocks dangerous commands
│   └── test-safety-hook.sh      # Test suite for the safety hook
└── settings.json                # Workflow gate + safety hooks wiring

CLAUDE.md                        # Entry point — Claude reads this first
core-manifest.yml                # Which files are shared workflow core
VERSION                          # Template version (for workflow-sync)
docs/
├── solutions/                   # Compound learning artifacts
├── brainstorms/                 # Ideation output
├── plans/                       # Technical plans (TEMPLATE.md included)
└── retros/                      # Sprint retrospectives
```

## Key design decisions

### Why worktrees?

Each specialist agent gets a full git worktree — an isolated copy of the repo. This means:
- **No conflicts** between agents working in parallel
- **Clean merges** back to the feature branch
- **Platform-independent** (no pipe hacks for Windows)
- Agents use standard Edit/Write tools, no file-marker parsing

### Why separate reviewers?

Four reviewers with different lenses catch more than one reviewer trying to check everything:
- **Correctness** — Does it actually fulfill the acceptance criteria?
- **Security** — SQL injection? Auth bypass? Data leak?
- **Conventions** — Does it match existing patterns?
- **Lifecycle** — What happens across multiple calls, state transitions, and module boundaries? (Added after 5 critical lifecycle bugs passed the other three reviewers in a production project.)

They run in parallel (fast) and output structured JSON (parseable).

### Why an iteration limit?

Without a limit, the agent will retry forever on a fundamentally broken approach. Max 4 iterations forces escalation to a human when the problem is deeper than a quick fix.

### Why compound learning?

Every multi-iteration issue teaches something. The `compound-learning` skill captures *why* things went wrong and feeds it back into rules, skills, or verify.sh checks — so the same mistake doesn't happen twice.

## The workflow in detail

| Step | What happens | Who |
|------|-------------|-----|
| 1. Prepare | Read issue, load rules | Orchestrator |
| 2. Validate | Check acceptance criteria are clear | Orchestrator |
| 3. Consult | Ask UX/scope advisors (optional) | Advisors |
| 4. Plan | Break into work packages, dependency analysis | Orchestrator |
| 4b. Match skills | Check triggers.yml for matching skills | Orchestrator |
| 5. Dispatch | Spawn specialists in worktrees | Specialists |
| 5b. Merge | Merge worktree branches to feature branch | Orchestrator |
| 6. Verify completeness | All ACs covered? All planned files changed? | Orchestrator |
| 7. Verify quality | Run verify.sh (lint, types, tests, secrets) | verify.sh |
| 8. Review | Parallel review (3 generic + conditional lifecycle + cross-review) | Reviewers |
| 9. Evaluate | Parse JSON verdicts, check for blockers | evaluate-reviews.sh |
| 10. Commit | Stage, commit, push, create PR | Orchestrator |
| 11. Learn | Document insights in docs/solutions/ | Orchestrator |

If step 7 or 9 fails → back to step 5 with error context. Max 4 loops.

## Customization checklist

After copying into your project:

- [ ] `CLAUDE.md` — Project name, tech stack, file paths, hard requirements
- [ ] `.claude/agents/frontend-developer.md` — Your frontend framework and patterns
- [ ] `.claude/agents/backend-developer.md` — Your backend framework and patterns
- [ ] `.claude/agents/tech-lead.md` — Your architecture and CI/CD
- [ ] `.ai/rules/always.md` — Adjust or remove monorepo-specific rules
- [ ] `.ai/rules/on-frontend.md` — Component structure, styling, testing approach
- [ ] `.ai/rules/on-backend.md` — API framework, database, auth patterns
- [ ] `.ai/rules/on-migration.md` — Your migration tool and naming conventions
- [ ] `.ai/rules/on-testing.md` — Test runner, file placement, mocking strategy
- [ ] `.ai/scripts/verify.sh` — **Critical:** add your linter, type checker, and test commands
- [ ] `.ai/skills/triggers.yml` — Add skills for your recurring patterns
- [ ] `.gitignore` — Your build output, dependencies, etc.

## Keeping projects in sync

Projects that adopt this template drift from it over time — and improve on it. Two files make the sync bidirectional:

- **`core-manifest.yml`** — declares which files are shared workflow core (synced semantically, both ways), which are adapted (structure core, content project-specific), and which are purely local.
- **`.ai/skills/workflow-sync.md`** — the orchestrator skill a downstream project runs at sprint start (or event-driven after improving a core file). It compares core files semantically, applies template improvements downstream, and backports project improvements upstream as a PR against this repo with a `VERSION` bump.

Translation and renamed specialists are not drift — mechanics, gates, thresholds, and formats are.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (CLI, desktop app, or IDE extension)
- Git
- GitHub CLI (`gh`) for issue reading and PR creation
- `jq` for review evaluation (optional but recommended)

## Origin

This workflow was extracted from a production project ([PennyKoll](https://github.com/PontusNyberg)) where it orchestrated 17+ sprints of development. The project-specific parts were replaced with `TODO:` markers, but the orchestration patterns, quality gates, and agent definitions are battle-tested.

## License

MIT
