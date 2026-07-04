# Plan: <short title>

> Self-contained implementation plan. A plan must be executable by a specialist
> (or a cheaper model) WITHOUT access to the conversation it was written in.
> Assume no session context — everything needed is stated here or pointed out with file:line.
>
> Inspired by the shadcn/improve plan format. Copy this file to
> `docs/plans/<NN>-<slug>.md`, fill it in, remove the instruction blocks.

| Field | Value |
|-------|-------|
| Issue | #<NR> |
| Specialist | <Backend Specialist / Frontend Specialist / Architect> |
| Estimated effort | S / M / L |
| Dependencies | <other plans/issues that must be done first, or "none"> |

## Why this matters

<1–3 sentences: what concrete problem/bug/risk does the plan solve? What happens if we DON'T do it?>

## Current state

<Describe what the code looks like today. Paste relevant excerpts with file:line so the executor
doesn't have to search. Point out exactly where the change goes.>

```ts
// path/to/file.ts:42 — current code
```

## Scope boundaries (hard limits)

**In scope (files that MAY be changed):**
- `path/to/file-1`
- `path/to/file-2`

**Out of scope (do NOT touch):**
- <files/areas that are nearby but must not be touched — prevents scope creep>

## Steps

> Explicit, ordered steps. Each step must be concrete enough that it requires no guessing.

1. <Step with exact file and what changes>
2. <Step ...>
3. <Step ...>

## Test plan

> Match existing test patterns in the module. No new test infrastructure without justification.

- <Test file + what it verifies>
- Negative cases / edge cases: <...>

## Verification (machine-checkable)

> Commands the executor runs + EXPECTED result. Not prose — runnable gates.

```bash
bash .ai/scripts/verify.sh        # expected: exit 0, no blockers
# TODO: your typecheck/test commands, e.g.:
# npx tsc --noEmit                # expected: 0 errors
```

## Done criteria (Definition of Done)

> Checkable, objective. "It works" is not enough — state how to prove it.

- [ ] <Observable behavior X verified — how?>
- [ ] verify.sh exit 0 (output shown)
- [ ] Tests green (output shown)
- [ ] No changes outside the scope list above

## Maintenance notes / escape hatches

<Known pitfalls, what happens if an assumption doesn't hold, where the executor should
stop and escalate instead of guessing.>
