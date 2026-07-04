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
- **Orchestrator skills** — run by the main session (compound-learning, ideate, parallel-dispatch, ...)

## Injection pattern

Matching skills are injected into the specialist prompt via the Agent tool, after rules but before the work package:

```
Agent(
  subagent_type: "<your specialist agent from .claude/agents/>",  # agent definition loads via subagent_type — do NOT inline the agent file
  isolation: "worktree",
  prompt: """
    <.ai/rules/always.md>
    <.ai/rules/<context>.md>
    <.ai/skills/<matching-skill>.md>   ← skill injected here if it matches

    ISSUE: <contents from .ai/logs/current-issue.json>
    WORK PACKAGE: ...
    TEST REQUIREMENTS: ...
  """
)
```

(Same pattern as `implement-issue.md` Step 5 — `subagent_type` supplies the agent's system prompt; the prompt carries rules, skills and the work package.)

## Active skills

| Skill | Type | Purpose |
|-------|------|---------|
| `compound-learning.md` | Orchestrator | Document learnings after implementation (Step 11) |
| `parallel-dispatch.md` | Orchestrator | Dependency analysis for parallel work |
| `ideate.md` | Orchestrator | Proactive improvement identification |
| `backlog-reconcile.md` | Orchestrator | Sync backlog/plans against actual code (sprint start) |
| `incident-fix-scoping.md` | Orchestrator | Split incident fixes into at most 3 focused PRs (Step 4a) |
| `compress-logs.md` | Orchestrator | Extract lessons from iteration logs at sprint close, archive raw logs |
| `workflow-sync.md` | Orchestrator | Keep the workflow core in sync with the shared template (upstream) |

TODO: Add project-specific specialist skills as patterns emerge.
