# Skill: shortcut-debt

Collects every deliberate shortcut in the codebase into a ledger, so a deferral
does not quietly become permanent.

## Trigger

- Sprint start (together with `backlog-reconcile`) — see which ceilings have been crossed
- Manually: "shortcut-debt", "shortcuts", "tech-debt ledger", "what shortcuts do we have"
- After an incident — a shortcut past its ceiling is a common root cause

## Specialist

Orchestrator. Reads and reports; changes no code.

## The convention it builds on

`.ai/rules/always.md` requires every deliberate shortcut to be marked like this:

```ts
// shortcut: <the limit>, <what should trigger the upgrade>
```

The ceiling says where the solution stops holding; the trigger says what should
make us revisit it. Without a trigger the marker rots.

## Steps

1. **Scan.** Grep for markers in code, migrations and scripts. Adjust the
   `--include` list and the search roots to your project's layout:

   ```bash
   grep -rnEi --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build \
     --include='*.ts' --include='*.tsx' --include='*.js' --include='*.mjs' \
     --include='*.go' --include='*.py' --include='*.sql' --include='*.sh' \
     --include='*.yml' --include='*.yaml' --include='*.html' \
     '(^[[:space:]]*|.*(//|#|--|/\*+|\*|<!--)[[:space:]]*)(shortcut|TODO|FIXME|HACK|XXX)(\([^)]*\))? *:' \
     src scripts .ai/scripts .github
   ```

   `--exclude-dir=node_modules` is not optional: one single typings package can
   contribute dozens of `TODO:` markers that are not your debt. Verified
   empirically 2026-10-09 — without the exclusion the whole ledger is dependency
   noise. Exclude your own guard scripts too (they document the marker form; they
   carry no deferrals).

   **If your project has a mechanical shortcut guard, keep this pattern in phase
   with the guard's marker regex** — it is the single source of what counts as a
   marker. Two patterns that disagree ARE a bypass: in the downstream project the
   ledger matched `// shortcut(#123):` before the guard did, and the guard dropped
   trailing comments a round later. Three differences are deliberate and expected:
   the ledger also looks for `TODO/FIXME/HACK/XXX`, it reads file lines rather than
   diff lines, and **it has a scope while the guard has none** — a guard counts a
   marker in any non-`.md` file, the ledger only in the directories and file types
   above. A marker outside that list hard-fails the guard but is invisible to the
   ledger, so widen the list rather than trusting it.

   The pattern allows extra whitespace and a parenthesis between the keyword and
   the colon, because `// TODO(#123):` is the form ESLint and most style guides
   use. Verified empirically 2026-10-09 against a fixture with nine variants
   (including the JSDoc form `/** shortcut: ... */` and the continuation line
   ` * shortcut:` inside a block comment): a narrower `?`-based pattern missed
   three of them (`//  shortcut:`, `// TODO(#123):`, `// FIXME :`) and would have
   reported them as absence — exactly the silent rot this skill exists to prevent.

   If the user names their own marker (`shortcut-debt FIXME`) — grep only that one.

2. **Filter out non-deferrals.** A hit that merely mentions the convention, or a
   `TODO:` that is a question to the reader, is not a ledger row. A deferral is
   code that deliberately does less than it should.

3. **Read the ceiling.** For each hit: open the file and read the code around the
   marker. The ceiling is either in the comment or has to be read out of the code.
   Do not guess — if there is no ceiling, that absence is the finding to report.

4. **Decide whether the ceiling is crossed.** Compare against what you actually
   run: users in production, data volume, platform versions you support. A
   shortcut whose ceiling is already crossed is not debt any more — it is a bug,
   and should be proposed as an issue.

5. **Report** in the format below.

## Output

One line per marker, grouped by file:

```
<file>:<line>, <what was simplified>. ceiling: <the limit>. upgrade: <the trigger>.
```

Tags:
- `no-trigger` — the marker names no upgrade trigger. These are the ones that rot quietly.
- `no-ceiling` — no limit given. Impossible to know when it stops holding.
- `crossed` — the ceiling is already crossed by today's reality. Propose an issue.

End with `<N> markers, <M> without trigger, <K> crossed.`
Nothing found: `No shortcut debt. Clean ledger.`

If the user wants it kept: write to `docs/plans/shortcut-debt-<date>.md` (durable
per the artifact lifecycle) — ask first.

## Interaction with reviewers

A shortcut with a correct `shortcut:` marker is a **decision, not a finding**.
Reviewers must not flag it — except when the ceiling is already crossed. That is
in the reviewer profiles under "Shortcut markers", and in full in
`.ai/rules/on-shortcut-markers.md`.

## Common mistakes

- **Counting markers without reading the code.** A `TODO:` can be a leftover note
  about code that was later finished. Verify the deferral still exists.
- **Writing the ledger without asking.** It is a report by default; a file in
  `docs/` is a commitment to keep it updated.
- **Mixing in findings that have no marker.** This is not an audit — if you find
  real bugs along the way, report them separately and do not fix them here.
