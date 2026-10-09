# Session Start Protocol, full text

`SKILL.md` carries step 2 (the scan and its snippet) in full and the other
steps in short form. Load this file when a step's short form does not
settle the case in front of you. Where the two differ in detail, this file
governs.

## Step 1: Storage

1. **Storage.** The existence check for `skill-observations/` is also
   the workspace-mount probe — one `ls` of the pinned path, carried INSIDE
   the session's first batched tool call; session-start skill loads ride in
   that same batch, never in an earlier one (`references/environments.md`,
   "The probe rides inside the first batched call"). If it fails, the first
   response is the environment's folder-picker tool (in Cowork,
   `request_cowork_directory`; elsewhere, its equivalent), not the "no
   filesystem" branch: handoff-doc mode (`references/environments.md`) is
   for environments with no filesystem at all, and it is reached too easily
   when a missing mount is read as one. That request can itself come back
   refused by the harness's permission classifier rather than by the user
   (a classifier denial names the classifier and carries a bracketed
   reason; a user decline does not), so retry it once identically before
   treating the folder-picker path as failed or even considering the "no
   filesystem" branch: the **How to Log** rule — consecutive denials from a
   probabilistic gatekeeper are noise, not a wall — governs every gated
   call, this one included. Never assert the mount's state, connected or
   not, from an environment flag, a config file's presence in context, or
   memory of an earlier turn: that claim needs a probe in the same turn.
   **A successful probe does not mean the activation config fired.**
   On turn 1 a merely late config is indistinguishable from an absent one:
   load the session-start skills directly rather than assuming it did, and
   read the config file yourself if the mount resolves but its content is
   not in context. Why this guard is only the backup, and where the primary
   one belongs, is in `references/environments.md` ("Activation config —
   late, intermittent, and why the guard cannot live inside it") — load it
   when setting up or diagnosing activation. Before creating or writing
   anything: if the resolved workspace sits under an ephemeral path
   (`.claude/worktrees/`, a temporary clone), warn and re-anchor on the
   stable project path — state written there is lost at teardown; where
   none resolves (a disposable worker), use report-back mode:
   `references/environments.md` ("Claude Code Projects"). Then RUN the one
   idempotent command in `references/observation-log.md` ("Workspace
   creation"): it creates the four workspace artefacts and asserts each,
   and refuses a pre-3.0 `log.md` layout (load `references/migration.md`
   and convert first) — never create them by working down a list by hand.
   Then the **starter-set reconciliation**, due whenever
   `skill-observations/starter-principles-reviewed.txt` is absent or holds
   a starter-set version older than the one in
   `references/starter-principles.md` — a fresh install, an upgrade to a
   bundle that ships the file, and every later growth of the set. Load that
   file and follow its **Reconciliation** section: match by substance,
   offer once in one line, import only what the adopter picks, then write
   the shipped version into the marker file so the offer never repeats
   until the set changes. Never pre-populate silently. Name the loaded
   skill's frontmatter `version:` in the start-up lines — read from the
   file, never fetched.

## Steps 3 to 7

3. **Review trigger.** Read `skill-observations/last-review-date.txt`. The
   value carries the truth: a date = when the last review actually ran;
   `never` = no review has run yet. A missing file is abnormal (step 1
   creates it) — recreate it with `never`, don't invent a date. An existing
   `skill-observations/review-started.txt` not reading `completed`, or a
   registered scheduler reporting a later last run, is a run that completed
   no review: say "fired YYYY-MM-DD, no review recorded" and treat the
   review as due. If the value is `never` or 7 or more days old AND there
   are OPEN observations: in an interactive session, offer the review in
   one line and proceed with the user's task unless they opt in; never gate
   their work on the review. Scale the offer's CONTENT with the backlog,
   never its frequency: up to ~15 open observations, offer the full review
   ("the backlog hasn't been reviewed [in N days / yet] — N open; run it
   now, or carry on?"); above that, offer a bounded slice whose unit of
   work stays constant as the backlog grows — "review the 10 oldest",
   "review just the ones targeting <the skill most named>" — and state both
   numbers, how many are open and roughly how many distinct findings they
   represent (cluster on the `title` and `skill` fields you just scanned;
   why: `references/weekly-review.md`). Only a scheduled/autonomous run
   loads `references/weekly-review.md` and runs the review unprompted; a
   session whose output a caller owns does neither: `references/environments.md`
   ("Sessions whose output channel is owned by a caller").
4. **Activation.** Once per session: if no CLAUDE.md (or equivalent)
   activation instruction for this skill exists, briefly suggest adding one
   (see `references/environments.md`). Skip if already configured. Be clear
   about what this step is: it runs only after the skill has been invoked,
   so it verifies a working setup and structurally cannot detect the
   missing one — it is not the safety net for a never-activated install;
   the checks from outside the runtime are in `references/environments.md`.
5. **Concurrency.** There is no shared log file to guard: each observation
   is its own file, so creating one never collides with another session's
   entry; re-read one before changing its *status* (How to Log).
6. **Targets and staged work.** Resolve each distinct `skill:` value in
   the scanned frontmatter against the installed skill set and mention, in
   one line, any that no longer resolve — and any that resolve but cannot
   run, because presence in a listing is not capability (`references/skill-
   authoring.md`, "Runtime prerequisites"). A deleted skill accumulates
   observations unnoticed; a dead one more so. Say what you resolved against
   (this checkout, this install): an unresolved target is a fact about where
   you looked, not about the world.
   If `skill-updates/` holds anything, reconcile it before announcing it —
   installation happens outside any session, so no session observes it, and
   the session that reads the ledger owns its cleanup. `diff -rq` each staged
   copy against live and classify it (a bare "differs" is not a verdict:
   live moves on legitimately), and name every directory no manifest entry
   covers. The cases are in `references/weekly-review.md` ("Staged-work
   reconciliation gate") — load it before judging any entry. Then say "N
   staged updates awaiting review" in one line.
   **Past 3 days, the count alone is noise.** When any staged item is older
   than 3 days, replace the bare count with the oldest item, its age in
   days, and the open observations still recurring because it is not
   installed (entries logged since it was staged against the same skill or
   file, and entries whose body or `resolution:` names its staged path),
   then ask for the install go. An approved fix that is not installed
   protects nothing, and every day it waits live drifts further from it
   (observed: approved fixes staged for a week, none installed, each
   staged copy now differing from live, and the observations they would
   have stopped still being logged). The install side of this rule is
   Step 8 of `references/weekly-review.md`.
7. **First run, or a named past session.** If the log is empty and the
   project has history (handover or decision docs, commit history, test
   scripts, a notes or memory directory, an existing CLAUDE.md), offer a
   one-off backfill pass over those artefacts; when the user names a
   finished session, run the same pass scoped to it. Entries cite the
   durable artefact (file and section) in `session_context`, never a
   session. Procedure: `references/environments.md` ("First-run backfill").
