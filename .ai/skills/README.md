# Skills — Reusable agent routines

## What is a skill?

A skill is an **executable routine** a specialist agent can follow to solve a recurring problem. Unlike rules (which say "don't do X") and templates (static text), a skill is a context-aware instruction that:

1. Has a **trigger** — when to use it
2. Has **steps** — what the agent should do, in order
3. Has **test requirements** — what must be verified
4. **Adapts** to the issue — the agent reads the issue and adjusts each step

## Why skills?

Sprint 1: Specialist takes 4 iterations on a new API endpoint (auth, validation, error handling — all from scratch).
Sprint 3: Specialist has a skill that codifies the pattern → 1-2 iterations.

The win is **compounding** — each sprint becomes faster without sacrificing quality.

## How skills are used

### In implement-issue.md, Step 5 (spawn specialist)

The main session matches the issue against available skills (via `triggers.yml`) and injects them into the specialist prompt:

```
Agent(
  isolation: "worktree",
  prompt: """
    <agent definition>
    <relevant rules>
    <matching skill — injected here>

    WORK PACKAGE: ...
    ISSUE: ...
  """
)
```

### Matching logic

The main session decides if a skill matches based on:
1. The skill's **trigger section** (keywords in the issue)
2. Which **specialist** should run
3. Which **files** are affected

A skill is an **aid**, not a mandate. The specialist may deviate if the issue requires it.

## Skill format

```markdown
# Skill: <name>

## Trigger
<When this skill matches — keywords, file types, patterns>

## Specialist
<Which specialist uses this skill>

## Steps
1. <Step with context about why>
2. <Step with code example if relevant>
...

## Test requirements
- <Mandatory tests>

## Common mistakes
- <Things that have gone wrong historically>
```

## Quality assurance — 3-tier model

Skills have three paths into the system:

| Tier | What | Gate | Example |
|------|------|------|---------|
| **Auto** | New mechanical check in verify.sh | Dry-run on 3 issues first | "Block TIMESTAMP without TZ" |
| **Propose** | New skill, template, or rule | PR review by human | "API CRUD skill" |
| **Log** | Observation without action | Retrospective analysis | "Specialist took 3 iterations due to X" |

**Hard rule:** Skills (tier 2) ALWAYS require human approval via PR before activation.

## Lifecycle

See `.ai/workflows/skill-lifecycle.md` for details (if defined for your project).

```
Retrospective discovers pattern
  → Agent proposes skill as .md file
    → PR is created with the skill
      → Human reviews and merges
        → Skill active from next issue
```

## Creating a new skill

1. Identify a recurring pattern (same type of work done 3+ times)
2. Write the skill in `.ai/skills/<name>.md`
3. Add trigger entry in `triggers.yml`
4. Submit via PR for review

## Skill types

- **Specialist skills** — injected into specialist prompts (frontend, backend, etc.)
- **Orchestrator skills** — run by the main session

## Active skills

### Orchestrator skills

| Skill | Trigger |
|-------|---------|
| [compound-learning](compound-learning.md) | After non-trivial issue (Step 11) |
| [parallel-dispatch](parallel-dispatch.md) | 2+ independent work packages |
| [ideate](ideate.md) | Sprint planning or manual |
| [compress-logs](compress-logs.md) | Sprint close — final step of retro |

### Specialist skills

TODO: Add project-specific specialist skills as patterns emerge.
