---
description: Quota-free replacement for the Copilot review loop — iterative fresh-eyes agent review of the current PR until clean.
---

# /fresh-review

Runs the independent **fresh-eyes reviewer** (`.ai/agents/reviewer-fresh-eyes.md`) against the current branch's PR in a fix-loop until a clean round. Drop-in replacement for `/ship-and-watch`'s Copilot gate when you want to save the Copilot quota — same fresh, context-free perspective, but the reviewer is a synchronous subagent: **no polling, no cutoff timestamps, no silent-tick counters.**

**Use AFTER:** verify.sh passed, internal reviewers done, commit pushed, PR exists (or will be created in step 1).
**Cost note:** each round is one reviewer subagent on your Claude quota instead of Copilot minutes.

## Steps

### 1. Sanity + PR

```bash
CURRENT_BRANCH=$(git branch --show-current)
case "$CURRENT_BRANCH" in main|master) echo "ABORT: on the default branch."; exit 1;; esac
[ -z "$(git status --porcelain)" ] || { echo "ABORT: uncommitted changes."; exit 1; }
git push -u origin "$CURRENT_BRANCH"
PR_NR=$(gh pr view --json number -q .number 2>/dev/null) || { echo "No PR — create one first (implement-issue Step 10)"; exit 1; }
```

### 2. Review round (max 4 rounds)

Dispatch the reviewer as a subagent. **Isolation is the point** — the prompt contains ONLY the agent definition, the PR number and the round number. Never include the issue, iteration log, session reasoning, or previous internal reviews.

```
Agent(
  description: "Fresh-eyes review round <N> of PR #<PR_NR>",
  model: "opus",
  prompt: """
    <contents of .ai/agents/reviewer-fresh-eyes.md>

    PR: #<PR_NR>   (repo: run `gh pr diff <PR_NR>` yourself)
    ROUND: <N>
    <if round > 1: REFUTED EARLIER (do not re-report without new evidence): <list of refuted findings + reasons>>
  """
)
```

Parse the returned JSON (invalid JSON → re-dispatch once, does not count as a round).

### 3. Address findings

For each issue, verify against the current code first (the reviewer can be wrong — it has no context by design):

- **Valid blocker/warning** → fix with Edit. After all fixes: run verify.sh (**hard stop on failure — do not commit broken fixes**), then commit with explicit paths and push:
  ```bash
  bash .ai/scripts/verify.sh || exit 1
  git add <changed files>   # NEVER git add -A
  git commit -m "fix: address fresh-eyes review round <N>"
  git push || exit 1
  ```
- **Valid nit** → fix if cheap, otherwise log as deferred in the PR body.
- **False positive** → refute with a concrete reason, and carry the refutation into the next round's prompt (see step 2). Never silently drop a finding.

### 4. Exit conditions

| Outcome | Action |
|---------|--------|
| `verdict: pass` with no blockers/warnings | **DONE** — report summary (rounds, findings fixed/refuted) to the user. |
| Round 4 still has blockers | STOP — `needs-human`. The diff is fighting the reviewer; summarize open findings for the user. |
| verify.sh fails after fixes | STOP — report, do not push. |

One clean round suffices (unlike Copilot's two silent ticks — there is no processing race with a synchronous agent).

## Relation to other reviews

- Internal step-8 reviewers (correctness/security/conventions/lifecycle) run BEFORE this, with issue context — they check "does this solve the problem correctly".
- Fresh-eyes runs AFTER, without context — it checks "does this survive contact with reality".
- `/ship-and-watch` (Copilot) remains available as an optional extra pass on high-stakes PRs; fresh-eyes is the default gate.
