# Skills

Skills are reusable agent routines that codify recurring patterns. They are injected into specialist prompts when a trigger matches.

## How skills work

1. In Step 4b of `implement-issue.md`, the orchestrator checks `triggers.yml`
2. If the issue's planned files AND keywords match a skill → the skill is injected into the specialist prompt
3. The specialist uses the skill as guidance (not a rigid script)

## Creating a new skill

1. Identify a recurring pattern (same type of work done 3+ times)
2. Write the skill in `.ai/skills/<name>.md`
3. Add trigger entry in `triggers.yml`
4. Submit via PR for review

## Skill types

- **Specialist skills** — injected into specialist prompts (frontend, backend)
- **Orchestrator skills** — run by the main session (compound-learning, ideate, parallel-dispatch)

## Active skills

| Skill | Type | Purpose |
|-------|------|---------|
| `compound-learning.md` | Orchestrator | Document learnings after implementation |
| `parallel-dispatch.md` | Orchestrator | Dependency analysis for parallel work |
| `ideate.md` | Orchestrator | Proactive improvement identification |

TODO: Add project-specific specialist skills as patterns emerge.
