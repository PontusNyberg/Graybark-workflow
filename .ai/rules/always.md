# Rules: Always

These rules apply to EVERY implementation, regardless of file type.

## Scope discipline

- Change ONLY files required for the issue
- No refactoring of existing code outside scope
- No "improvements" that weren't requested
- No extra docstrings, comments, or type annotations on untouched code
- If you discover a bug outside scope — report it, don't fix it

## Strict typing

- Follow strict mode if your language supports it (TypeScript `strict: true`, etc.)
- No `any` types without strong justification
- No type suppression directives without a comment explaining why
- All function parameters and return types should be typed

## Error handling

- All async operations must have error handling
- Show meaningful error messages to the user
- Never log sensitive data (tokens, passwords, PII)
- Don't catch errors silently — handle them or let them bubble

## Interactive prompts (FORBIDDEN)

Never open an interactive prompt that waits for human input mid agent-session. It hangs the entire session — both for subagents and main session.

This applies to:
- Interactive editors (`vim`, `nano`, `git rebase -i`, `git add -i`, `gh pr create` without `--body`)
- CLI prompts without defaults (`npm init` without `-y`, scripts that ask "Continue? [y/N]")
- Git commands that may open an editor (`git commit` without `-m`, `git merge` without `--no-edit`, `git tag -a` without `-m`)

**Instead:** Use flags, HEREDOC input, or pipe via stdin.

```bash
# WRONG — may open editor
git commit
git merge feature-branch

# RIGHT — non-interactive
git commit -m "feat: description"
git merge feature-branch --no-edit -m "merge: description"
```

If a necessary tool only has interactive mode → stop and ask the user to run it instead. Hanging the session wastes tokens and blocks other work.

## Git

- Use Conventional Commits: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`
- Always reference the issue number in the commit message — either in the title `feat: X (#123)` or footer `Resolves #123`. It is your responsibility to link commits to a trackable issue.
- One commit per logical change
- Never commit: `.env`, `node_modules/`, `vendor/`, credentials, API keys
- Check `git diff --cached` before commit

## Code quality

- DRY — but don't abstract too early. Three similar lines are better than a premature abstraction.
- Use existing patterns in the codebase — don't invent new ones without good reason
- Name variables and functions descriptively in English
- No hardcoded magic numbers — use named constants

### Clean Code

- **Single Responsibility** — one function does one thing. If you write "and" in the function name → split.
- **Early returns** — avoid deep nesting. Handle error cases first, happy path last.
- **Command-Query Separation** — a function either changes state OR returns data, not both.
- **Function size** — if a function doesn't fit on one screen (~40 lines) → extract.

### Continuous improvement (Kaizen)

- **Five Whys on bug fixes** — ask "why?" until you find root cause, not just symptoms. Fix the cause, not the effect.
- **Poka-Yoke** — design code that makes it hard to make mistakes (types, enums, required params > optional + runtime validation).
- **Build only what's needed** (YAGNI) — no speculative code for future requirements.

### Decision ladder before generating code

Before writing new code — walk the steps in order and stop at the first one that solves the problem. The best code is the code you never wrote.

1. **Does this need to exist?** Solve the problem away if you can — unneeded code is unneeded maintenance.
2. **Is it in the standard library / language?** (e.g. `Intl`, `structuredClone`, `Array.prototype` methods)
3. **Is there a native platform feature?** (e.g. `<input type="date">` instead of a date-picker package, CSS instead of JS)
4. **Is it already an installed dependency?** Reuse — don't add a new package for something we already have.
5. **Can it be done in one line?** Prefer that over a new abstraction/wrapper.
6. **Only then:** write minimal code with proper error handling and types.

Applies to specialists during implementation AND the orchestrator at scope decisions. Adding a package or an abstraction requires motivating why steps 1–5 weren't enough.

## Testing

- Don't change a test to make it pass — fix the code instead
- New source files need a matching test file (verify.sh fails without one); add tests for changed behavior following the module's existing test patterns
- If the module has no test infrastructure at all, report that instead of building a test setup the issue didn't ask for

## Verification (evidence requirement)

**Never claim something works without fresh verification.** Confidence ≠ evidence.

- Before saying "done" — run verify.sh and show the result
- Before saying "tests pass" — run the tests and show output
- Before saying "type check passes" — run it and show output

**Does NOT count as verification:**
- Previous test runs (code may have changed since)
- "Should work based on the changes"
- Linter pass (doesn't prove correctness)
- Specialist reported success (verify independently)

**Date empirical platform findings.** When you verify a non-obvious platform behavior (GitHub API quirk, framework peculiarity, cloud-provider behavior) and document it in a workflow/skill file — record date + context: *"Verified empirically on PR #X, YYYY-MM-DD"*. It separates proven knowledge from assumption and shows when a finding may have gone stale.

## Systematic debugging

When verify.sh fails or tests don't pass, find the root cause before changing code, and undo fix attempts that didn't help so they don't pile up. Log every attempt in the iteration log. After 3 failed attempts, question the approach rather than the code — the escalation rubric in `implement-issue.md` builds on that log.
