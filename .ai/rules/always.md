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

## Testing

- NEVER change a test to make it pass — fix the code instead
- If you add new functionality — add tests if test patterns already exist
- If there are no tests in the current module — don't create test infrastructure unless requested

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

**Red flags in your own language:** If you write "should", "probably", "seems to work" — STOP. Run the command and show evidence.

## Systematic debugging

When verify.sh fails or tests don't pass — follow this order. Don't guess.

**Phase 1: Understand the error**
- Read the entire error message (not just the first line)
- Identify exactly which file and line fails
- Reproduce the error — run the command again to confirm

**Phase 2: Analyze cause**
- What changed since it last worked?
- Is there similar working code in the codebase? Compare.
- Trace the data flow backwards from the failure point

**Phase 3: One fix at a time**
- Change ONE thing, re-run, evaluate
- If the fix didn't help — undo and try next hypothesis
- Never change multiple things simultaneously

**Phase 4: Escalate on repeated failures**
- If 3+ fix attempts fail → question the approach, not just the code
- Maybe the architecture is wrong, not the implementation
- Log every attempt in the iteration log
