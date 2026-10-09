# Surfacing and acting on observations

Load before surfacing observations to the user, and before acting on any
observation (resolving, dismissing, fixing, citing or staging). `SKILL.md`
keeps only the short form; this file holds the full rules.

## Surfacing Protocol

Default: at end of session, as a grouped summary — improvements grouped by
skill, new-skill candidates listed separately; for each, one sentence plus
suggested type; ask which to act on. Surface earlier when an observation
needs user input to be complete, when a skill is actively producing wrong
output, or when observations cluster on one skill.

**Deferral wears a second disguise: not a promise, but an argument** ("let's
gather more data first"). Before writing any "later" into a
recommendation, load `references/signals.md` ("Deferral disguised as
diligence") and name which specific observation would change the decision
and when it could arrive.

**Default to log-and-defer.** Surfacing an observation is not an invitation
to act on it: state that it is logged for the next review, and stop.
Reserve in-session application strictly for the triggers under "Acting on
Observations". Do NOT routinely offer a binary "apply now vs leave for next
review" choice; for users who run regular reviews that offer is unwanted
friction, and if a user has said they always defer, suppress it entirely.

**Log-and-defer means the observation is the sole carrier of the change**,
and applying an insight to the work in front of you is not the same act.
Letting an open observation change what you do in THIS task is the point of
the log. Writing the rule anywhere a later run reads it — a state file the
skill loads (registry, dossier, config note), a prompt, a handoff doc, a
project instruction file — is acting on it. The test: **does it leave a
durable change outside the observation log?** The disguise is a bridge —
"the rule has to live somewhere until the review runs". It does, and that
somewhere is the observation; a parked copy has no update path, so when the
review edits the skill the next run reads both. A state file that genuinely
needs to point at the rule gets one line naming the owner and the pending
change, never a restatement. A harness's skill-save control is the sharper
version: it installs a copy rather than parking one, possibly over what a
parallel review has staged. See "Acting on Observations".

**Self-check before surfacing:** observations were logged throughout the
whole session (including discussion phases) without interrupting the task; each follows
Issue → Improvement → Principle; each is typed; existing-skill items name
the section; no open-source Principle contains client-identifying info;
every file carries `status:` and a non-empty `siblings_checked:` (if one lacks
it, do the sibling check now, never back-fill `none`); every id the summary
names is one a create printed this session, re-listed this turn, never recalled.

## Acting on Observations

Act only in three contexts: (1) the comprehensive review (load
`references/weekly-review.md`); (2) an explicit user request ("update X
skill", "act on observation #N"); (3) in-session correction when a skill is
producing wrong output the user should know about. Otherwise: log, don't
act.

**An outcome-level ask is not trigger (2).** The test: an explicit request
NAMES THE ARTEFACT — "update the X skill", "edit the skill file", "restage
it", "act on observation #N". A statement naming only the behaviour —
"from now on", "stop doing X", "always do Y", "make this part of the
workflow", "leave that out of the process" — is a decision whose carrier
is the observation, however urgent it sounds: forward scope makes deferral
feel unsafe, the same disguise the bridge argument wears above. Ambiguous
wording gets a one-line question, not a guess, since a wrong guess is an
unrequested artefact to review; log → review → stage → install always wins.

**A harness's own skill-proposal or skill-save control is an install path,
not a staging path.** Where the environment offers to save or propose a
skill from inside the conversation — and its tool description may well say
that is how a skill change is delivered — that control writes the installed
copy; it produces nothing under `skill-updates/`. Never use it in a
workspace that stages there. And before any in-session skill change, check
the staging manifest (`skill-updates/PENDING.md`) and today's
`skill-updates/<date>/` for the same skill: a review running in parallel
may already have staged it, built on the live file plus other changes.
Installing a conversation-side copy over that drops those changes, and
installing the review's copy afterwards silently reverts the one the
control installed — a shortcut taken while another session stages the same
artefact turns a one-line rule into a merge conflict the user has to catch.

**Read the full body before resolving, dismissing, fixing, or citing** — a
title is an index entry, not content. **A change you did not make resolves
an observation point by point, never title against title:** list the points
the body makes, name the line of the fix covering each, and any point
without a line stays open on a carrier. Load
`references/observation-log.md` ("Read the full body before resolving,
dismissing, fixing or citing") before any resolve, dismiss or cite step.

When acting: small, clearly-additive, low-risk changes (a new rule, a
clarification, a factual fix) may be applied without waiting for the next
review — "directly" means *now*, not *in place*: the edit is still made on
a staged copy based on a fresh read of the live file and handed to the user
to install, in every environment and every context. Staging-only has no
interactive exception; an exception the user has to remember is a gate
that eventually gets left open. Substantial changes (restructuring, new
capabilities, changed methodology) and all new-skill creation: load
`references/skill-authoring.md` first and follow its editing and staging
rules. A principle that applies to skills generally goes to the
cross-cutting principles file (same reference).

**Set the status in the same turn you act.** An observation acted on
in-session must have its frontmatter updated — `status: actioned`,
`resolved: YYYY-MM-DD`, `resolution: what was done, and where it now lives`
— before the turn ends. The work and the bookkeeping are two acts, and the
second is the one that gets dropped; a stale `open` entry then invites
redoing finished work over a section that has since moved on. The write is
the enforcement, exactly as it is for logging. **"Acted on" includes a fix
that lands as ordinary work** — the rule written into the instructions file,
the code corrected — with the observation not in mind; and a later session
finding the remedy already in place closes the entry the same way. Neither
looks like acting on an observation, which is why both are missed (measured
on one first review: 10 of 27 entries were already applied while `open`).

**Acting on only a subset of a multi-skill observation's `skill:` list?**
Neither plain move is honest — left `open`, the finished portion gets
re-applied by another session; marked `actioned`, the unfinished portions
silently leave every future queue. Use the carrier pattern: mark the
observation `actioned` with a `resolution:` naming the portions applied,
then log a carrier holding the remainder, with only the outstanding skills
in its `skill:` list. Full protocol: `references/observation-log.md`.
