# Team Overview

Agent team for the project. Each agent has a specific role and expertise.

## Team members

TODO: Replace TODO names with the names you want to call your agents (or
remove the Name column entirely if you prefer role-based addressing).

| Agent | File | Role | Model | Focus area |
|-------|------|------|-------|------------|
| TODO Tech-lead | `tech-lead.md` | Tech Lead / Architect | Sonnet | System design, infra, technical decisions |
| TODO UX-advisor | `product-designer.md` | Product designer / UX | Haiku | User experience, features, onboarding |
| TODO Scope-skeptic | `product-skeptic.md` | Scope guardian | Haiku | Challenges scope, demands evidence, zero-alternative |
| TODO Frontend-name | `frontend-developer.md` | Frontend specialist | Sonnet | UI, components, pages |
| TODO Backend-name | `backend-developer.md` | Backend specialist | Opus | API, database, auth, security |

## Model tier (token optimization)

Model choice per agent based on task complexity and cost of failure:

- **Opus** — Security-critical code and review (Backend, Rev-Correctness, Rev-Security)
- **Sonnet** — Coders with strong mechanical guardrails and pattern-matching reviewers (Frontend, Architect, Rev-Conventions)
- **Haiku** — Advisors with short, structured output (Scope guardian, UX advisor)

Pass the `model` parameter in Agent() calls: `Agent(model: "sonnet", ...)`

## Specialists (code + test)

| Agent | File | Domain |
|-------|------|--------|
| Frontend | `frontend-developer.md` | UI, components, pages, frontend tests |
| Backend | `backend-developer.md` | API, database, auth, backend tests |
| Architect | `tech-lead.md` | Config, CI/CD, shared code, architecture |

## Advisors (do NOT code)

| Agent | File | Domain |
|-------|------|--------|
| UX Advisor | `product-designer.md` | UX, design, accessibility |
| Scope Guardian | `product-skeptic.md` | Scope, prioritization, simplification |

## Routing

| Changed files | Specialist |
|---------------|-----------|
| Frontend source | Frontend |
| Backend/API source | Backend |
| Database migrations | Backend |
| Config, CI/CD | Architect |

## Dispatch rules

- Specialists: always `isolation: "worktree"`
- Advisors: no worktree needed (they don't change files)
- Reviewers: no worktree needed (they analyze diff)
- Independent work → parallel dispatch
- Dependent work → sequential dispatch

## How the team is used

Start a discussion by giving each agent a question related to their expertise. Cross-reference answers — for example:
- UX advisor proposes a feature → Scope guardian questions whether it's needed → Architect estimates technical complexity → Specialists implement.
