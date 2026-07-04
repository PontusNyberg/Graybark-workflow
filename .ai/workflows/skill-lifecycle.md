# Workflow: Skill Lifecycle

How skills are proposed, reviewed, activated, and improved.

## Overview

```
Pattern discovered (retrospective or during implementation)
  → Agent creates a skill proposal as a .md file
    → PR is created with the skill + rationale
      → Human reviews
        → Merge → Skill active
        → Rejection → Observation logged
```

## Phase 1: Discovery

Skills are proposed from two sources:

### A. Retrospective (most common)

During retrospective analysis (`.ai/workflows/retrospective.md`), patterns are identified:
- The same type of implementation took >2 iterations in 3+ issues
- The same verify error keeps recurring
- The same reviewer blocker appears repeatedly

### B. During implementation

If the main session during Step 4 (planning) sees that an issue matches a known pattern that does not yet have a skill, this is logged:

```markdown
## Skill observation
- Issue: #<NR>
- Pattern: <description>
- Potential skill: <name>
- Iterations that would have been saved: ~X
```

Logged in `.ai/logs/<issue-nr>.md`. No skill is created directly — it is collected in the retrospective.

## Phase 2: Proposal

### Gate before creating a new skill — prefer extending an existing one

Every new skill is cognitive load for the orchestrator at Step 4b matching. Before creating a new skill, ask yourself:

1. **Could this be a new section in an existing skill?** If a skill already covers an adjacent pattern (e.g. a "new database table" skill), extend it rather than creating a near-duplicate.
2. **Could this be a conditional instruction in an existing workflow?** If the pattern only applies to a few steps in a workflow, put it there instead.
3. **Could verify.sh catch this instead?** If the pattern is mechanically checkable, a check is better than a skill (cannot be forgotten).
4. **Are there only 2 concrete issues, or is that enough for a new abstraction?** Three similar lines are better than a premature abstraction.

If the answer is "yes" to any of 1–3 — do that instead. Create a new skill only when none of those paths works.

The agent creates a `.md` file per the format in `.ai/skills/README.md`:

```markdown
# Skill: <name>

## Trigger
## Specialist
## Steps
## Test requirements
## Common mistakes
```

**Requirements for skill proposals:**
1. Based on **at least 2 concrete issues** where the pattern occurred
2. Steps must be specific, not general ("validate input" ≠ specific)
3. Test requirements must be concrete, not "write tests"
4. "Common mistakes" must come from actual errors in logs

## Phase 2.5: Security gate for EXTERNAL skills (mandatory)

The phases above assume **self-written** skills. If you bring in a skill, a plugin, or an
MCP server from an **external source** (e.g. `npx skills add <repo>`, a GitHub repo, a zip),
an extra gate applies BEFORE it may be loaded into an agent prompt or installed.

External skills execute with implicit trust. Research (NVIDIA SkillSpector) shows that a
significant share of public skills contain vulnerabilities or malicious patterns (prompt
injection, data exfiltration, supply chain, excessive agency). Never trust an external
skill unseen.

**Requirements:**

1. **Scan with SkillSpector** before installation — point at the repo/zip/directory/file:
   ```bash
   # Docker (no local Python required). The image is NOT on a registry —
   # build it locally from the SkillSpector repo first (one-time):
   git clone https://github.com/NVIDIA/skillspector && cd skillspector
   docker build -t skillspector .   # see the repo README/Makefile for the current build entrypoint
   # Then scan:
   docker run --rm -v "$PWD:/scan" skillspector scan <repo-url|path>
   ```
   For CI: run against `.ai/skills/` + `.claude/` and consume the SARIF output.

2. **Read the report.** Risk score 0–100. Treat anything with medium+ severity as blocking
   until it is manually understood and dismissed.

3. **Review the source manually** even on a green result — read what the skill actually
   instructs the agent to do. A clean static scan does not prove good intent.

4. **Adapt rather than install raw.** What we usually want from an external repo is the *idea*
   (a format, a checklist, a routine) — lift it into our own `.ai/` file under our own review
   instead of importing executable third-party code. Then Phases 2–4 apply as usual.

**Hard rule:** No external skill/plugin/MCP server is installed or injected into a prompt
without a passing SkillSpector scan + manual source review, documented in the PR.

## Phase 3: Review (human gate)

The skill is reviewed as a normal PR. Reviewer checklist:

- [ ] Does the skill solve the root cause, or does it embed a workaround?
- [ ] Does the skill skip quality steps that should exist?
- [ ] Are the steps specific enough to be useful?
- [ ] Do the test requirements match the project's quality bar?
- [ ] Is the trigger sufficiently bounded (not too broad)?

**On rejection:** Log why. The pattern may still be worth solving, but differently (better rule, new verify check, etc.).

## Phase 4: Activation

After merge:
1. The skill lives in `.ai/skills/<name>.md`
2. README.md is updated with the skill in the table
3. The main session matches automatically on the next issue (via the trigger section)

## Phase 5: Improvement

Skills are living documents. They improve via:

### Retrospective updates

If the retrospective shows a skill isn't working optimally:
- The skill still took >2 iterations → steps missing or unclear
- New mistakes discovered → add to "common mistakes"
- Test requirements insufficient → extend

Updates require the same PR review as new skills.

### Deprecation

If a skill is no longer relevant (e.g. tech change):
1. Mark as deprecated in README.md
2. Keep the file for 1 sprint (reference)
3. Delete after 1 sprint

## Anti-patterns

1. **Skill that skips steps** — if verify.sh or a reviewer found the problem, the skill's steps should prevent it, not hide it
2. **Too broad a trigger** — "all API endpoints" is too broad, "API endpoint with CRUD against one table" is right
3. **Workaround skill** — if the pattern is caused by a bug, fix the bug instead
4. **Ungrounded skill** — skills without data (concrete issues) from reality risk solving the wrong problem
