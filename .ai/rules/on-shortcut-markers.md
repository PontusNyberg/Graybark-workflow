# Rules: Shortcut markers at review time

Injected into EVERY reviewer dispatch (the four internal reviewers and the
fresh-eyes reviewer). It lives in its own file because it previously existed as
five byte-identical copies inside `.ai/agents/reviewer-*.md` — and in the PR that
introduced it the copies had already drifted into three versions, so two of five
protected categories had no reviewer watching them.

The convention this enforces lives in `.ai/rules/always.md` → "Deliberate
shortcuts are marked".

## The base rule

A shortcut carrying a `shortcut: <ceiling>, <upgrade trigger>` comment is a
deliberate decision, not a finding — as long as the ceiling has not already been
crossed by today's reality. If the ceiling is crossed it is a bug, not a deferral.

## The exception list — read it from the base revision

The list of things that may never be shortcut lives in `.ai/rules/always.md`, in
the section `### Deliberate shortcuts are marked`, as the bullet list under the
bold sentence "This may never be shortcut" (it is a sentence, not a heading —
search for the string). A marker on anything in that list is always a `blocker`.
The list is deliberately NOT repeated here: a copy drifts from the original and
then protects none of what it claims to protect.

Read it from the **base revision**, never from the working tree:

```bash
MSYS_NO_PATHCONV=1 git show origin/master:.ai/rules/always.md
```

`MSYS_NO_PATHCONV=1` is required in Git Bash on Windows — without it MSYS
rewrites the argument into a path and the command aborts with `fatal: ambiguous
argument`, rc 128 (silent if only stdout is captured; verified empirically
2026-10-11). The prefix is harmless on other platforms. Substitute your default
branch if it is not `master`.

The reason is that otherwise the list sits inside the very diff it is supposed to
gate — the same commit that adds a marker can delete an entry from the list.

## The rules that follow from it

1. **A marker in code plus a changed control file in the same diff = `blocker`**,
   whatever the justification. Control files come in two classes, and the
   difference is deliberate:

   **Semantic** — gated on EVERY change, because they define what may be
   silenced:
   - `.ai/rules/always.md`
   - `.ai/rules/on-shortcut-markers.md` (this file)
   - `.ai/agents/reviewer-*.md`
   - `.ai/skills/shortcut-debt.md`
   - any mechanical guard script your project added for this rule

   **Delivery path** — gated when the diff TOUCHES the wiring, because they
   deliver the rule rather than carry it; an unrelated edit in them is harmless
   and must not fire. Both deletions that remove the call or the injection AND
   additions that set the guard's return variable or shadow its function count:
   - `.ai/scripts/verify.sh` (the only place a guard would be called)
   - `.ai/workflows/implement-issue.md` (Step 8 injects this file into every
     reviewer prompt)
   - `.claude/skills/fresh-review/SKILL.md` (same injection for the fresh-eyes
     loop)

   The delivery path was missing entirely from the downstream project's first
   three review rounds: a diff could replace the guard call with
   `SHORTCUT_GUARD_RC=0` and take the shortcut in the same commit. Gating the
   delivery path on *every* change instead produced false positives — and a guard
   whose first real run is a false positive is the guard the next agent unplugs.

   The first version of this condition gated ONLY deletions, reasoning that "a
   pure addition cannot weaken anything". That was false: a return variable read
   by a `case` statement is neutralized by an *appended* assignment without a
   single `-` line. Round 4 demonstrated it with a fixture. Add a bypass route
   here rather than trusting that the next wording happens to be exhaustive.

   If your project has a mechanical guard for this combination, report the
   combination **even when the guard is silent** — the same diff can change the
   guard.

2. **A diff that deletes an entry from the exception list is a `blocker` in
   itself**, even with no marker in the same diff, and needs the user's explicit
   approval. Without this rule the combination splits into two legal halves: one
   PR deletes "security" from the list, a later PR adds the marker once the base
   revision no longer mentions it. Additions and rewordings are free — deletions
   are what is gated. **A rewording that makes an entry NARROWER counts as a
   deletion**: judge the scope, not the line. Otherwise the two-step route
   survives in legal form — narrow "validation at trust boundaries" into
   "validation of webhook payloads" in one PR, add the marker in the next, and all
   three protections fall silent at once.

3. **If you cannot read the list at all** (no file access, no base revision), no
   silence applies: report the shortcut as usual. Doubt falls toward reporting,
   never toward silence.

4. **A ceiling that cannot be checked counts as no ceiling.** The marker then
   silences nothing: report the underlying finding at the severity it would have
   had without the marker. The marker itself is a `nit` — those are the markers
   that rot quietly.

5. **A marker without an upgrade trigger is a `nit`** — even when the ceiling is
   checkable and not yet crossed. `always.md` says why: without a trigger the
   marker rots. The marker still silences the underlying finding; the missing
   trigger is the `nit`. (Unlike rule 4, where an uncheckable ceiling cancels the
   silence entirely.)
   (This rule existed in the five copies and was lost when they were merged — the
   correctness reviewer caught the loss in iteration 3.)

## What a mechanical guard is NOT

A script that greps the diff for `shortcut:` plus a control-file change is a
**tripwire against the careless combination**, not a tight gate. Read the track
record of the downstream implementation before trusting one: it leaked in FOUR
consecutive review rounds in the PR that introduced it, each time through a hole
in the previous patch — a base-revision read that was not a check, a self-fail on
its own diff, a pattern that dropped trailing comments, an ungated delivery path,
and finally an addition that neutralized the gate even though the comment claimed
additions were harmless.

Every patch made the rule longer without making it tight, and every time the hole
was in the previous patch's *justification*, not in its code. Keep going and the
next form is `shortcut:` inside a string literal, inside a template literal, or
in a comment style nobody enumerated.

So the claim is stated here, once, instead of being rediscovered:

- **Not covered:** a marker in a string literal, in a comment form outside
  `// # -- /* * <!--`, in **any `*.md` file** — the exemption is file-type-wide,
  not limited to the convention's own files, and in a repo where
  `.ai/workflows/*.md` and `.ai/skills/*.md` are executable instructions a
  shortcut there is a real shortcut — or in the guard's own files. An object
  property named `shortcut` on its own line is a false positive on top.
- **What carries the protection instead:** that the list is read from the base
  revision, that deleting an entry from it is a `blocker` in itself, and that you
  as reviewer report the combination even when the guard is silent. Rule 1 says
  explicitly that you may not rely on the guard.

  All three are carried by **you**, not by a script: after the tripwire there is
  no mechanical check, and rule 2 never had one. A guard's own comment argues that
  an instruction to a model is not a control — and then points back at the
  instructions. The circle is deliberate, and it is the accepted debt.
- **The threat model is carelessness, not an adversary.** Anyone deliberately
  silencing a reviewer has easier routes than hitting a regex — they can write a
  false `failure_scenario`, or simply not mark the shortcut at all. The guard
  exists to make the unintentional combination hard, not to be impossible to
  circumvent.

Find a new hole in the pattern: judge whether it is the carelessness route or the
adversary route. If it is the latter — do not add a patch, write it down here.
