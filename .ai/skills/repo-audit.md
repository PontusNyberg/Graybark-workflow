# Skill: repo-audit

Reviews the whole repo as the senior developer who just inherited it and will get
the call when it breaks. Priority order, seriously meant: **correct, secure, holds
under load, tested, fast, lean**.

Adapted from [ponytail](https://github.com/DietrichGebert/ponytail) (MIT). Unlike
`shortcut-debt` (which inventories markers and flags crossed ceilings) and
`ideate` (which looks for improvements), this one looks for bugs and risks in code
that already exists.

## Trigger

- Manually: "audit", "review the repo", "what's broken", "what should we fix"
- Before a major release, or after a long stretch of fast fixes

**Not sprint start.** A whole-repo audit is too heavy to run every sprint, and a
conditional step ("run it if the backlog feels ungrounded") is run in practice
never. `backlog-reconcile` covers the sprint-start need. If this skill were ever
given a sprint-start trigger, it must also be added to
`.ai/workflows/sprint-planning.md` Step 0 — that is the only place sprint-start
skills actually run, and exactly that gap cost a fix commit for `shortcut-debt`.

It is NOT part of `implement-issue`. An audit in the middle of an issue
implementation is scope creep.

## Specialist

Orchestrator, or the architecture specialist for an architecture-heavy audit.
Changes **no code** — it writes a report.

## Steps

### 1. Map first

- Review what the user points at: a directory, a package, or the whole repo.
  Nothing named → the whole repo.
- Read `README.md`, `CLAUDE.md`, any development log, deploy and build config, the
  dependency list and the tests.
- **Enumerate the apps/packages from the repo, don't read them out of a list
  here.** A hardcoded list rots when something is added or removed. For a
  monorepo:

  ```bash
  git ls-files apps | cut -d/ -f2 | sort -u     # the apps that EXIST in the repo
  git ls-files packages | cut -d/ -f2 | sort -u # the shared packages
  ```

  A directory on disk with no tracked files is not an app — **but don't skip it
  before checking what is left in it.** A removed app often leaves its `.env`
  behind, and that is the single most likely place for an unrotated credential
  file. Search **only directories without tracked files**, not the whole tree:

  ```bash
  for d in apps/*/; do git ls-files "$d" | grep -q . || git status --porcelain --ignored -uall "$d"; done
  ```

  `-uall` is required — without it git collapses a fully ignored directory into a
  single line with no filename. And running it over the whole tree gives thousands
  of lines of build artifacts, your tool truncates the output, and a leftover
  directory that sorts late is never seen.

  If there is a `.env`, a `.pem` or a key file, that is a finding under *Must
  fix*. Give the file and the **variable names** — extract names with
  `grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' <file> | tr -d =`, which can only produce
  names. Not `cut -d= -f1`: that prints every line without an `=` unchanged, so a
  multi-line PEM body inside a `.env` leaks straight through. **`.pem` and key
  files are not opened at all** — report only the path; there are no variable
  names to collect. **Never run `cat` on an env file**: it pulls the values into
  your context, and a model quotes what it sees. "Never the values" in the report
  does not help if they are already in the context.

  Say explicitly which parts you skipped.

- **Entry points differ per app** — derive them, and account for the boundaries:
  - Route/page directories, server handlers, scheduled jobs, database migrations:
    find them, don't assume a convention.
  - **Find out whether an app is actually deployed before weighting its
    findings.** A deploy target in the repo (a hosting config file) is a sign;
    its absence is not proof that the app is dead, but you then may not assume it
    is alive either.
  - **Shared packages are often not shared by every runtime.** A serverless or
    edge runtime that cannot resolve workspace imports tends to keep local copies
    of shared files with an "update both" note. That duplication is itself a lean
    and bug lead worth naming: a copy that has drifted from the original.
  - **Derive where a flow's logic actually lives — don't assume the module name
    says so.** Logic can sit inline in a handler, in a shared module, in the
    database layer as a trigger or migration, or in a shared package. Grep for the
    imports and consumers before reading a module as if it were a flow step: a
    module with no caller outside its own package is a lean finding, not a step in
    the flow.
- **Find out the load — it is not written here.** Claims about code can be
  verified in the repo; claims about the production situation rot, so this skill
  makes none. Find out the following before weighting anything, and **write in the
  report what you found and what you assumed**:
  - **Is real money moving?** Check which payment/billing key the build uses and
    which distribution mode the app is in. **Read presence and prefix only, never
    the value** — a test-mode prefix means a sandbox, not revenue. Check the file
    the *release* build reads, not the dev one; they can answer differently. If
    paid features are pre-launch, weight their findings as pre-launch risk, not
    revenue risk.
  - **Is real third-party data moving?** Credential-driven integrations usually
    have more than one code path (a managed path with server-side credentials, and
    a bring-your-own-credentials path behind a flag). Absence of one does not mean
    the integration is dead: find out which paths are reachable and under which
    flags, and whether a missing variable breaks a fallback. **Read only WHETHER
    the variables are set, never what they contain** — your secret manager can
    list names without values. Private-key material is multi-line; `cat` on that
    file pulls the whole key into your context and your report.
  - **Which way does data come in?** Several ingestion paths can be live at once,
    and which one carries real user data is decided in production, not in the
    repo. Find out before weighting one against the other.
  - **Load grades performance and races — not security.** A leak between two users
    is as serious as between a thousand; "few users" never turns a missing
    authorization policy into a *Should fix*. This is the one weighting rule that
    holds regardless of what you found above.
- Trace the main flows end to end, including the authorization path for every
  table you touch. Derive where each step lives — several of them may be in the
  database layer or inline in a handler, not where the module name suggests.
- Large repo: go deep where a fault costs most, not file by file. **Write down
  which parts you did not read.**

### 2. Look for

1. **Bug** — wrong result, crash, missed edge case (empty list, zero, last entry,
   rounding, time zones). Calling a UTC serializer on a local date is a recurring
   one.
2. **Risk** — security holes (missing row-level authorization, privilege-elevating
   database functions without a revoke, missing token verification, plaintext
   secrets), data loss (silent `catch`, writes in the wrong order, missing
   transaction).
3. **Load** — check-then-write races, work every process redoes, lists that only
   grow, one query per row, state that should be shared between processes.
4. **Missing test** — risky logic (a branch, a parser, money, security, writes)
   with no test that fails when it breaks. One good test, not a coverage number.
5. **Speed** — large slowdowns are problems, small ones are suggestions.
6. **Lean** — code that should not exist: dead code, unused flags, speculative
   features, two helpers doing the same thing, a package where the platform would
   do, an interface with one implementation, near-copies that must change
   together.

### 3. Check before you report

- **Every finding needs a concrete case**: "this input or this situation produces
  this wrong result". No case → no finding. Same evidence requirement as the
  reviewer profiles.
- Before calling code unused: grep the whole tree, including tests, fixtures,
  config and dynamic references.
- **Open `.ai/rules/on-shortcut-markers.md` before judging a `shortcut:`
  marker.** It is injected into reviewer dispatches only, not into orchestrator
  skills, so it is not in your context.

  **Deliberately not summarized here.** The rules that *grant* silence — rule 4
  on uncheckable ceilings and rule 5 on a missing upgrade trigger — are easy to
  summarize wrongly: rule 5 was already lost once when five copies were merged,
  see the note under rule 5 in the rule file. Read rules 4 and 5 in the file and
  apply them as written. A misreading here may only err toward *report*, never
  toward *silence*.

  Two things always hold and are therefore stated here, because they fail closed:
  - **A marker on anything in the exception list is ALWAYS reported under Must
    fix, whatever the ceiling.** The list lives in `.ai/rules/always.md` ("This
    may never be shortcut") and is not copied here.
  - **If you cannot read the list, no silence applies** — report the shortcut as
    usual.

  Read the list in the **working tree**: an audit has no diff, so the reviewers'
  reason to read from the base revision does not apply. If the working tree's list
  differs from `MSYS_NO_PATHCONV=1 git show origin/master:.ai/rules/always.md`,
  the **union of the two** applies. If the base-revision read fails, rule 3 in the
  rule file applies — no silence; do not quietly fall back to the working tree.
  Not "the broader one" — that is only defined when one list is a subset of the
  other, and on partial overlap (one entry deleted, another added) the auditor
  would get a free choice and would naturally land on the working tree, i.e.
  exactly the list the rule protects against. The union is defined for every pair
  and always falls toward reporting.
- Propose the smallest fix that works. Prefer fixes that delete code. Do not add
  layers, dependencies or config the problem does not need.
- No style taste, no "consider", no vague worries.

## Output

Very plain language: short sentences, everyday words. Explain a technical term the
first time. The reader may have forgotten this code.

Start with `What the repo does:` in two or three sentences, and which load you
assumed.

Then the findings in three groups, most important first, skipping empty groups:

- **Must fix** — bug, security, data loss, breaks at expected load
- **Should fix** — risky code without a test, real slowness, duplication, a
  function mixing jobs, code that should not exist
- **Nice to have** — small speed wins, shorter forms

Number findings consecutively across all groups, so the user can say "fix 2 and
5". Max 20 findings — **but the cap does not apply to Must fix.** Security and
data loss are always listed in full, even if the list then exceeds 20; it is
*Nice to have* and *Should fix* that get trimmed. If you left less important
findings out, say how many.

**Never quote secret content — wherever it ends up.** If you find a key, a token,
`.pem` material, a password or a plaintext connection string: give **file and
line, never the value**. This applies to the report, to any `docs/plans/` file,
**and to every issue or PR description the finding becomes** — a value in an issue
reaches the tracker, notification emails and webhooks, where no history rewrite is
enough, so the only remedy is rotation. It matters especially if the report is
saved to `docs/plans/`, which is committed — otherwise the review that was meant
to find the leak becomes the leak, and cleaning up needs a history rewrite plus
rotation of every key mentioned. A pre-commit secret scan catches a few narrow
patterns and is opt-in per clone; do not rely on it.

Every finding has all four parts, one or two short sentences each.

The example below is MADE UP — the format is the point, not the finding. Never
quote a file and a line range you have not read; an exact line reference is the
least a reader can tell apart from a real finding.

```
2. **Records land on the wrong day** (`path/to/import-handler.ts:L40-52`)
   - **What this is:** The import saves a date for every record.
   - **Problem:** It calls a UTC serializer on a local date. A record on March 1
     at 00:30 local time is stored as February 28.
   - **Fix:** Format in local time instead. One line, nothing else changes.
   - **If we skip it:** Records around month boundaries land in the wrong period,
     and the user corrects them by hand.
```

End with:

- `Verdict:` one line — healthy, or what to fix first
- `Lean: −<N> lines, −<M> dependencies possible` when there are lean findings
- `Not reviewed:` the parts you did not read or could not run

Nothing found — instead of the structure above: `What the repo does:`, then
`Healthy. Nothing to fix.` and one line about what you checked.

**The report changes no code.** If the user wants it kept: write to
`docs/plans/repo-audit-<date>.md` — ask first. If the findings should become
issues: one issue per finding, with the failure scenario in the description, not
one collective post.

## Common mistakes

- **Reporting everything you saw.** A list of 40 findings does not get read.
  Twenty is the cap for *Should fix* and *Nice to have* — Must fix is listed in
  full, and the most important come first.
- **A finding without a failure scenario.** "This function is long" is not a
  finding. "This input gives the wrong balance" is.
- **Mixing audit and fix.** The skill reports. Fixes belong to an issue with its
  own review — an audit that also changes code has nobody reviewing the changes.
- **Forgetting the load.** Without a stated load assumption, "won't hold under
  load" is an opinion.
