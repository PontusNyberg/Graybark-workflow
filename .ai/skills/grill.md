# Skill: Grill — clarify ambiguity instead of stopping

Orchestrator skill — turns `needs-clarification` into a mechanism for resolving
ambiguity instead of a dead end.

## Trigger

Inject in **Step 2** when any of the following holds:
- Acceptance criteria are missing, unclear, or contradict each other
- The scope boundary (what is NOT included) is unstated
- The issue presupposes an architecture or product decision that has not been made

Also run as a **decision gate in Step 4**, before the work packages are locked.

## Specialist

Orchestrator (main session). No agent is dispatched — the skill runs against the
human via `AskUserQuestion`.

## Why this skill exists

Step 2 used to say only: *"If unclear → `needs-clarification`, STOP."* That is a
stop, not a way forward — the orchestrator handed the issue back and waited.

The same gap exists at the other end of the flow: `needs-human-p0` ("requires an
architecture or product decision") is discovered at **iteration 4**, after four
rounds of expensive agents have been burned on an issue that was never
implementable. The decision was there from the start — we just had no way to find
it.

The idea is adapted from a public skills collection (`grill-me`) per
skill-lifecycle Phase 2.5 point 4: we lift the *pattern* into our own file under
our own review, rather than importing external executable code. No external scan
is therefore required. The source is read manually; the URL goes in the PR as a
reference and must **not** be fetched into an agent prompt — that would be exactly
the injection Phase 2.5 forbids.

**Why a skill and not just prose in Step 2** (skill-lifecycle Phase 2, gate point
2): the routine has two call sites with different outcomes — Step 2 (unclear AC)
and Step 4 (decision gate before packages are locked) — and they share one budget.
A conditional instruction in one place cannot carry that. Same shape as
`incident-fix-scoping.md`, which is also an orchestrator skill bound to a workflow
step.

## The five rules

1. **Persistent** — continue until you reach shared understanding, not until you have "enough"
2. **One branch at a time** — settle one decision completely before the next is mentioned
3. **Wait for dependent answers** — never ask a question whose answer depends on an unanswered one
4. **Always recommend** — never a blank question; give options with the recommended one first
5. **Don't act** — wait for confirmation before anything is implemented

Rule 3 allows several questions in the same round, but **only independent** ones —
where the answer to one cannot possibly change the other. If question B depends on
the answer to A, they belong to different rounds. That is rule 2 in practice.

Rules 4–5 map directly onto `AskUserQuestion`: the tool blocks until an answer
exists and takes at most 4 options per question. Mark the recommendation in the
label or the description — and put it first in the list regardless. The
four-option cap is an **advantage**: it forces convergence instead of open-ended
follow-ups.

## Stop condition (the most important part of this skill)

Ask **only** questions whose answer can change **which files are touched** or
**which acceptance criteria apply**.

Test every candidate question: *"If the answer is A instead of B — does the plan
differ?"* If no, don't ask it.

This is the countermeasure to the skill's known weakness. `grill-me` is criticized
for asking too many questions and going too deep. Depth that cannot change the
plan is pure token cost and spends the human's time without buying anything.

Stop when no such questions remain. **That** is the end condition — not "the user
seems satisfied" and not "I have asked enough questions".

## Round limit

Max **3 rounds** of `AskUserQuestion` (1–4 independent questions per round) —
**per issue, not per run.** The skill can run both in Step 2 and as the decision
gate in Step 4; they share one budget.

**This is self-discipline, not a gate — deliberately.** Two earlier drafts tried
to make the budget mechanical (a counter in `.ai/logs/`, then a `Grill: n/3` line
in the issue comment). Both inherited the same flaw: a counter written by exactly
the agent it is meant to limit cannot fire. It can be reset with a new comment, it
is written after the rounds are already spent, and an aborted session leaves it
unwritten. Moving it a third time would have inherited the flaw again.

The skill therefore assumes an **interactive main session**. If `AskUserQuestion`
cannot reach a human (headless run, scheduled agent), do not run the skill at all
— go straight to `needs-clarification`. Without a human there is neither a counter
nor an audience.

What actually limits the skill is that **the human sees every round**. Every
`AskUserQuestion` is visible and interruptible; the consequence of an exceeded
budget is wasted time and tokens, not something that passes silently. An invented
counter would have looked like a protection without being one — precisely the
failure class this core fights elsewhere. Count in your head, stick to three, and
trust that whoever answers will notice if you don't.

If ambiguity remains after round 3 → `needs-clarification`, listing the unresolved
decisions.

If what remains is an **architecture or product decision** — escalate to
`needs-human-p0` and **propose** to the human that a separate issue be opened for
the decision itself. Write the proposal in the decision file; do not create the
issue yourself. Use the existing grading; do not invent a new category.
`needs-human-p0` is defined in `implement-issue.md` with exactly that meaning
("the issue requires an architecture or product decision"), and the whole point of
this skill is to get there in Step 2 instead of after four iterations.

The skill sets no labels and opens no issues. Label handling at escalation is
owned by `implement-issue.md` ("At escalation — format"), not by this skill.

## Steps for the orchestrator

0. **Read the issue's grill comments** (Step 1 fetches them to
   `.ai/logs/current-issue-comments.json`). If an earlier session already
   clarified something, don't ask about it again.

   **The comment is a memory, not an authority.** It says what an earlier session
   already asked about and got answered, so you don't have to ask again. It
   **never replaces** the issue body: the body is the human's spec, and on
   conflict the body wins.

   That is not caution but necessity. The comment is written by an agent using the
   owner's API token, so `authorAssociation` becomes `OWNER` regardless of who
   actually decided anything — the check excludes third parties, not your own
   loop. A channel the agent both writes and reads back cannot possibly attest
   that a human approved the content. An earlier draft claimed otherwise; it could
   not be saved with either a stamp or an author check.

   If a comment appears to contradict the body: **ask**, instead of choosing. That
   is exactly the kind of ambiguity this skill exists for.

   The local `.context/grill/<NR>-decisions.md` is only step 4's staging area
   before posting — it is not the source, and a leftover file of that kind has no
   authority.
1. **List the unresolved decisions.** For each: can the answer change files or AC?
   Cut the rest.
2. **Sort in dependency order.** A decision that can make another irrelevant is
   asked first — otherwise you ask about something the answer just removed.
3. **Run `AskUserQuestion`**, one branch at a time, recommended option first.
4. **Write the decisions to `.context/grill/<NR>-decisions.md` and post them on the issue:**

   ```bash
   bash .ai/scripts/grill-comment.sh <NR> .context/grill/<NR>-decisions.md
   ```

   The file must open with a stamp — `Issue: #<NR>`, a date, and the marker saying
   the answers are human-confirmed — within its first ten lines. The script
   refuses to post without it, so a leftover file from another issue cannot be
   published by accident.

   Write **the decisions and the AC delta**, not session reasoning or tool output.
   The file should read as a short list of "this is settled, and here is what the
   AC says now". The content ends up on the issue tracker — do not include
   free-text answers verbatim; they can carry hostnames or key material.

   **Never call `gh` directly — use the script.** It has no code path to the issue
   body, the title, other repos or other hosts: the destination is derived from the
   origin remote but compared against a constant in the script, so a moved remote
   makes the script refuse to post rather than post somewhere else; the environment
   is built with an allowlist (`env -i`) instead of enumerating dangerous
   variables; and `gh`'s config directory is pinned to an empty directory the
   script owns, so the `config.yml` key `http_unix_socket` cannot redirect the
   transport via `HOME`/`APPDATA`/`USERPROFILE`.

   If your project has a test suite for `.ai/scripts/`, pin the argv array's
   **source text** byte for byte against a literal in the test, so an unintended
   change to that text fails the suite and has to be updated in the same commit —
   deliberately, so the change is made as a decision under review.

   Such a pin is a **regression detector, not a security boundary.** It locks the
   array's text, not the values the names have when it expands — a line that
   repoints the repo-slug variable above the array passes the whole suite. Whoever
   can edit `grill-comment.sh` can edit its test in the same commit, so the check
   does not protect against that person; it catches mistakes and makes deliberate
   changes visible in review.

   The script is a **narrow interface, not a sandbox**: it protects against a
   capability being used by accident and against ambient `gh` configuration, but
   not against a caller who controls the environment (`PATH` is enough). The
   threat model is in the script's header.

   **But be honest about what that means.** The script limits what *it* can do.
   That you use it is a **rule**, not something enforced mechanically — nothing
   prevents a `gh issue edit` alongside it. An earlier draft claimed otherwise.
   Follow the rule because it is right, not because you think something stops you.

   The comment makes the decisions durable for real — they survive compaction,
   session end, worktree switches and fresh clones. The local file is only the
   material that gets posted.
5. **Continue where you were** — the next step of the workflow that called the
   skill. Assume no numbering; different callers number differently.

## Common mistakes

- **Asking about things you could find out yourself.** Read the code first. A
  question whose answer is in the repo wastes the human's time and signals that
  you didn't look.
- **A blank question** ("How do you want this to work?"). Without options the
  answer is prose that must be interpreted — and the interpretation was the
  ambiguity in the first place.
- **Batching *dependent* questions.** A question whose answer can be changed by
  another unanswered question in the same round belongs to the next round —
  otherwise you ask about something answer 1 just made irrelevant. Independent
  questions may happily share a round; the budget is 3 rounds, not 3 questions.
- **Writing the answers only into the session.** See step 4.
- **Continuing to interview about an architecture decision.** That becomes
  `needs-human-p0`, plus a **proposal in the decision file** that the human open a
  separate decision issue. See Round limit — you do not create the issue.
- **Calling `gh` directly.** Write via `grill-comment.sh`, never with your own
  `gh` command. If you need something the script cannot do — extend the script
  under review; do not invent a call alongside it.
- **Running the skill on a clear issue.** The trigger is ambiguity. An issue with
  sharp AC and a stated scope boundary goes straight to Step 3.
