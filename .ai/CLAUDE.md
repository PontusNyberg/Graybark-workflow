# AI Agent System

## Purpose

Structured workflow system where Claude Code (main session) coordinates specialist agents that code, test, and review. No middlemen — the main session spawns specialists directly.

## Architecture

```
Claude Code (main session / orchestrator)
  │
  ├── 1. Read issue, determine specialist(s)
  ├── 2. Consult advisors (scope-check, UX, business)
  ├── 3. Plan work packages + dependency analysis
  ├── 4. Dispatch specialists in worktrees
  │     ├── [worktree A] Backend specialist    ─┐
  │     ├── [worktree B] Frontend specialist   ─┤ parallel if independent
  │     └── [worktree C] Architect             ─┘
  ├── 5. Merge worktree branches → feature branch
  ├── 6. Run verify.sh on merged result
  └── 7. Dispatch reviewer agents in parallel
        ├── Correctness reviewer
        ├── Security reviewer
        ├── Conventions reviewer
        └── Specialist reviewer (cross-review)
```

**Dispatch method:** Agent tool with `isolation: "worktree"` — each specialist gets an isolated repo copy and edits files directly.

**Important:** Subagents CANNOT spawn new agents. All orchestration happens in the main session.

## Worktree-based parallelism

### Why worktrees?

- Platform-independent (no pipe issues on Windows)
- Agents edit files directly with Edit/Write tools (no FILE-marker parsing)
- Full git worktree isolation — no conflicts between parallel agents
- Agent tool handles parallelism natively

### Dispatch patterns

**Parallel** — Independent work packages (no shared files):
```
Agent(isolation: "worktree", prompt: "Backend: ...")  ─┐ simultaneously
Agent(isolation: "worktree", prompt: "Frontend: ...") ─┘
→ merge both branches to feature branch
```

**Sequential** — Dependent work packages (frontend needs backend API):
```
Agent(isolation: "worktree", prompt: "Backend: create API...")
→ merge branch
Agent(isolation: "worktree", prompt: "Frontend: build UI against API...")
→ merge branch
```

**Hybrid** — Mix of independent and dependent:
```
Agent(isolation: "worktree", prompt: "Backend: API...")     ─┐ simultaneously
Agent(isolation: "worktree", prompt: "Architect: config...") ─┘
→ merge both
Agent(isolation: "worktree", prompt: "Frontend: UI...")
→ merge
```

### What does NOT need worktrees?

- **Advisors** (scope-check, UX, business) — don't change files
- **Reviewers** (correctness, security, conventions) — analyze diff, change nothing
- **Small issues** (<20 lines) — orchestrator codes directly

## Agent overview

### Specialist agents (code + test)

Defined in `.claude/agents/`. Dispatched by main session via Agent tool with `isolation: "worktree"`.

| Agent | File | Codes | Tests |
|-------|------|-------|-------|
| **Frontend** | `.claude/agents/frontend-developer.md` | UI, components, pages | Unit, component, E2E |
| **Backend** | `.claude/agents/backend-developer.md` | API, database, auth | API tests, integration |
| **Architect** | `.claude/agents/tech-lead.md` | Config, CI/CD, shared code | Integration, config validation |

### Advisors (do NOT code)

| Agent | File | Consulted for |
|-------|------|---------------|
| **UX advisor** | `.claude/agents/product-designer.md` | UX decisions, user flows, new features |
| **Scope guardian** | `.claude/agents/product-skeptic.md` | Scope control, prioritization |

### Review agents

| Role | File | Focus |
|------|------|-------|
| **Correctness** | `.ai/agents/reviewer-correctness.md` | Acceptance criteria, logic, edge cases |
| **Security** | `.ai/agents/reviewer-security.md` | Auth, injections, data leaks |
| **Conventions** | `.ai/agents/reviewer-conventions.md` | Code style, patterns |

## Specialist routing — who codes what?

TODO: Adjust to your project structure.

| Changed files | Specialist |
|---------------|-----------|
| Frontend paths | **Frontend specialist** |
| Backend/API paths | **Backend specialist** |
| Database migrations | **Backend specialist** |
| Architecture, CI/CD | **Architect** |
| Scope check | **Scope guardian** (advisor) |

## Rule matrix — when are which rules injected?

Rules in `rules/always.md` apply **always**. Others are injected based on which files change:

| Trigger | Rule file | Condition |
|---------|-----------|-----------|
| Always | `rules/always.md` | Every implementation |
| Frontend | `rules/on-frontend.md` | Frontend file changes |
| Backend | `rules/on-backend.md` | Backend file changes |
| Migration | `rules/on-migration.md` | Database migration files |
| Testing | `rules/on-testing.md` | Test files |

Do NOT load all rules — only those that match. Include relevant rules in the specialist prompt.

## Test requirements (hard gate)

**Every specialist MUST write tests.** verify.sh blocks if tests are missing.

TODO: Adjust file types and test patterns to match your project.

| File type | Test requirement |
|-----------|-----------------|
| Source files | Matching test file |
| Modified source | Warning if test missing |
| Config, docs | No test required |

## Parallel review

After verify.sh, dispatch reviewers in parallel via Agent tool (without worktrees — they don't change files):

```
# Prepare diff
git diff main...HEAD > /tmp/diff-full.txt

# Dispatch all reviewers in the same message:
Agent(description: "Review: correctness", prompt: "<reviewer-def + issue + diff>")
Agent(description: "Review: security", prompt: "<reviewer-def + issue + diff>")
Agent(description: "Review: conventions", prompt: "<reviewer-def + issue + diff>")
Agent(description: "Review: specialist cross-review", prompt: "<cross-reviewer-def + issue + diff>")

# Evaluate results
bash .ai/scripts/evaluate-reviews.sh
```

## Iteration limit

- **Max 4 iterations** (implementation + verify + review = 1 iteration)
- If iteration 4 fails → `needs-human`
- Every iteration is logged in `.ai/logs/<issue-nr>.md`

## Prompt construction (token efficiency)

### Prompt ordering

Information in the middle of long prompts risks being "lost" (lost-in-middle). Structure specialist prompts:

1. Agent definition (background/role) — first
2. Rules + skills (constraints) — middle
3. Issue context (background) — later
4. **Work package + test requirements — LAST** (recency bias, most important)

### Prompt budget

Keep specialist prompts under **~4000 tokens**. If it exceeds — trim the agent definition and reference files the agent can read.

### Anti-pattern: template patterns in prompts

Do NOT use patterns like:
```
Thought: <what you think>
Action: <what you do>
Observation: <what you see>
```

The model interprets these as **output templates to imitate**, not instructions. Write imperative instructions instead: "Analyze X", "Implement Y", "Verify Z".

## Anti-patterns

1. **Specialist codes without tests** — verify.sh blocks
2. **Main session codes everything itself** — delegate to specialist
3. **Subagent tries to spawn subagent** — doesn't work, all orchestration in main session
4. **Scope creep** — only what the issue requires
5. **Infinite loop** — max 4 iterations
6. **Lowered standards** — retrospectives must never lower quality
7. **Over-consultation** — max 2 advisors per issue
8. **Parallel dispatch with shared files** — guaranteed merge conflict, run sequentially
9. **Worktree for advisors/reviewers** — unnecessary overhead, they don't change files
10. **Skip dependency analysis** — always check file lists before parallel dispatch
