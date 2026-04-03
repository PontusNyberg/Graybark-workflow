# Team Overview

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
