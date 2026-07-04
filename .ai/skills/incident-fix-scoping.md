# Skill: Incident-Fix PR Scoping

## Trigger

Inject when the issue:
- has label `incident` or `postmortem`, OR
- references an active production incident in title/body, OR
- the orchestrator is creating a branch matching `fix/<incident-name>` or `hotfix/*`

Detect manually during Step 4 (plan work packages) of `implement-issue.md`.

## Why this skill exists

In a sister project, a single incident-fix PR swallowed:
- the core fix (circuit breaker + mutex + error classifier + retry-state lifecycle)
- monitoring (alerts + runbook)
- adjacent outage detection
- the postmortem
- 9 rounds of AI review-fixes
- 6 reviewer-prompt updates
- 5 follow-up issue references

Result: a sprawling PR that took 3 days to converge through 9 review batches. The same work split across focused PRs would have given each part its own focused review.

## The rule

For any incident-fix work, split into **at most three PRs**:

### PR 1 — Stop the bleeding (urgent)

Scope:
- The minimal code change that stops the production damage
- A regression test that pins the fixed behavior
- Nothing else

Goal: merge within hours, deploy immediately.

In the sister-project incident, this would have been the safeguard fix only (circuit breaker + mutex + classifier + retry-state lifecycle), with ONE test driving a full open→cooldown→reopen cycle.

### PR 2 — Visibility + adjacent hardening (within the week)

Scope:
- Monitoring / alerting for the failure mode
- Whatever scope-adjacent gap the incident exposed (e.g. single-entity outage detection)
- Postmortem doc

Goal: detect recurrence; explain what happened.

### PR 3 — Process improvements (when calm)

Scope:
- Reviewer-prompt updates that capture new lessons
- New skills / workflow rules distilled from the incident
- Tooling (drift checks, new verify.sh gates)

Goal: prevent the next instance of this class of bug.

## What stays out of every incident-fix PR

- Refactors that don't directly support the fix (file size, naming, etc.)
- Unrelated cleanups that were "noticed while in the area"
- New features
- Sweeping doc rewrites

## Steps for the orchestrator

When the trigger fires, in Step 4 (plan work packages):

1. **Identify the minimal stop-the-bleeding change.** Anything that isn't in the critical path is moved to PR 2 or PR 3.
2. **Create the iteration log with three sections** (PR 1 / PR 2 / PR 3) listing what goes where.
3. **Open PR 1 against the default branch immediately** with the minimal fix. Even before all phases are coded.
4. **Open follow-up issues** for the PR 2 and PR 3 work as soon as their scope is clear.

## Anti-pattern caught by this skill

> "Let's also fix this related thing while we're in this file" — NO. The related thing goes into PR 2 or 3, opened immediately as an issue. Discipline here is what makes review converge in 2-3 rounds instead of 9.

## Origin

Distilled from a sister-project incident PR's iteration cadence: 9 AI review batches over 3 days, 22 commits, 27 file changes — most of which weren't on the critical path to "stop the bleeding".
