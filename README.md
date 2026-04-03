# Graybark Workflow

A structured AI development workflow for Claude Code. Orchestrate specialist agents that code, test, and review — with built-in quality gates, iteration limits, and compound learning.

Named after a capybara.

## What is this?

A template for setting up a multi-agent development workflow with Claude Code. Instead of one AI doing everything, this system:

1. **Orchestrator** (main Claude Code session) reads issues, plans work, and coordinates
2. **Specialist agents** (frontend, backend, architect) code and test in isolated git worktrees
3. **Review agents** (correctness, security, conventions) review the diff in parallel
4. **Quality gates** (verify.sh) block bad code mechanically

## Quick start

1. Copy this repo's contents into your project (or use as a template)
2. Search for `TODO:` across all files and fill in your project specifics
3. Customize `verify.sh` with your linter, type checker, and test runner
4. Update agent definitions in `.claude/agents/` with your tech stack
5. Update rules in `.ai/rules/` with your coding conventions
6. Start using: tell Claude Code "implement #42" and it follows the workflow

## Structure

```
.ai/
├── CLAUDE.md                    # System overview
├── workflows/
│   └── implement-issue.md       # Main implementation workflow (11 steps)
├── rules/
│   ├── always.md                # Universal coding rules
│   ├── on-frontend.md           # Frontend-specific rules
│   ├── on-backend.md            # Backend-specific rules
│   ├── on-migration.md          # Database migration rules
│   └── on-testing.md            # Testing rules
├── agents/
│   ├── reviewer-correctness.md  # Correctness review agent
│   ├── reviewer-security.md     # Security review agent
│   └── reviewer-conventions.md  # Conventions review agent
├── scripts/
│   ├── verify.sh                # Mechanical quality gate
│   └── evaluate-reviews.sh      # Review result evaluator
├── skills/
│   ├── compound-learning.md     # Document learnings
│   ├── parallel-dispatch.md     # Multi-agent dispatch
│   ├── ideate.md                # Improvement identification
│   ├── triggers.yml             # Skill trigger definitions
│   └── README.md                # Skills documentation
└── logs/                        # Session-local logs (gitignored)

.claude/
├── agents/
│   ├── frontend-developer.md    # Frontend specialist
│   ├── backend-developer.md     # Backend specialist
│   ├── tech-lead.md             # Architect specialist
│   ├── product-designer.md      # UX advisor (doesn't code)
│   ├── product-skeptic.md       # Scope guardian (doesn't code)
│   └── TEAM.md                  # Team overview
└── settings.json

CLAUDE.md                        # Project-level instructions (entry point)

docs/
├── solutions/                   # Compound learning artifacts
├── brainstorms/                 # Ideation output
├── plans/                       # Technical plans
└── retros/                      # Sprint retrospectives
```

## The workflow

```
Issue → Validate → Plan → Dispatch specialists → Merge → Verify → Review → Commit
                                   ↑                                  |
                                   └──── fix & retry (max 4x) ───────┘
```

1. **Prepare** — Read issue, determine rules and specialists
2. **Validate** — Check acceptance criteria are clear
3. **Consult** — Ask UX/scope advisors if relevant
4. **Plan** — Break into work packages, analyze dependencies
5. **Dispatch** — Spawn specialists in worktrees (parallel if independent)
6. **Merge** — Merge worktree branches to feature branch
7. **Verify** — Run verify.sh (lint, types, tests, secrets, scope)
8. **Review** — Parallel review (correctness, security, conventions, cross-review)
9. **Evaluate** — Auto-parse review results, check for blockers
10. **Commit** — Stage, commit, push, create PR
11. **Learn** — Document insights in docs/solutions/

## Key concepts

### Worktree isolation
Each specialist gets an isolated git worktree. No conflicts between parallel agents. Changes are merged back to the feature branch.

### Quality gates
`verify.sh` blocks if:
- Type check fails
- Lint errors exist
- Tests are missing for new code
- Tests fail
- Secrets are detected
- Files outside scope were changed

### Iteration limit
Max 4 attempts (verify fail or review blocker = +1). After 4 → `needs-human` escalation.

### Compound learning
After implementation, learnings are documented in `docs/solutions/` and fed back into rules, skills, or verify.sh checks.

## Customization checklist

- [ ] `CLAUDE.md` — Project description, tech stack, paths, hard requirements
- [ ] `.claude/agents/*.md` — Specialist expertise, framework knowledge, context
- [ ] `.ai/rules/always.md` — Remove/adjust monorepo rules if not applicable
- [ ] `.ai/rules/on-frontend.md` — Your component structure, styling, testing
- [ ] `.ai/rules/on-backend.md` — Your API framework, database, auth
- [ ] `.ai/rules/on-migration.md` — Your migration tool and conventions
- [ ] `.ai/rules/on-testing.md` — Your test runner and file placement
- [ ] `.ai/scripts/verify.sh` — Your linter, type checker, test runner commands
- [ ] `.ai/skills/triggers.yml` — Your recurring patterns
- [ ] `.gitignore` — Your build output, dependencies, etc.

## License

MIT
