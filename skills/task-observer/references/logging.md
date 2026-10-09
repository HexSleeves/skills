# Writing an observation

Load before writing any observation file, and before changing one. The
text below is the full rule set that `SKILL.md` keeps only in short form;
where the two differ in detail, this file governs. Every snippet takes the
pinned workspace path, written `[ABSOLUTE PATH]`, and runs under bash.

## Contents

- Write-time checks
- How to Log
  - When to write
  - Id and filename
  - File format
  - Parked, context, confidentiality, and changing an entry
- Referencing Observations
- Taxonomy (quick version)
- Archival on Write

## Write-time checks

**An unresolved defect is an observation, at a bounded point.** When a
defect that is not itself the deliverable takes a second hypothesis, load
`references/signals.md` ("An unresolved defect is an observation, at a
bounded point") and log the evidenced problem report, not a fifth probe.

**Do NOT log:** one-off corrections that don't generalise; preferences
already captured in a skill; tool bugs unrelated to methodology;
observations needing proprietary client information to be useful in an
open-source skill (unless an internal skill is the right home). When
unsure, run `references/signals.md` ("The generalisability test"): mostly
no → task context, not an observation. Before minting a `proposes_skill`
name, reuse a fitting existing candidate — independently logged proposals
for one skill rarely share a name.

**Check for a restatement before writing.** Before creating the file, list
the open observations that name the same target skill (the scan at session
start already holds their titles; otherwise `find observation-log -name
'*.md' -exec grep -l "skill:.*<skill>" {} +`) and read those titles. If the
finding is the same one restated — the same rule, the same failure shape, a
different example — extend the existing entry instead: append the new
instance to its body, add the session to `session_context`, widen `title:`
to cover it. Duplication is only visible in aggregate (measured on one log:
roughly forty of ninety-one open entries were one finding restated), and a
near-duplicate costs a capture every session and a triage every review.

**Validate the target at write time.** `skill:` names a skill that exists
now, written as the skill listing shows it (a plugin skill as `plugin:name`,
never bare). If the right home is not a skill — an instructions file, a
memory note, the register a routine reads — put that path in `target_file:`,
not the nearest skill; a skill not yet built goes in `proposes_skill:`.

**Check the target's siblings at write time, and record that you did.**
Before writing, resolve the target against the family registry
(`skill-observations/skill-families.md`) and for each sibling either add it
to `skill:` or say in the body why it does not apply. Fast test: **could
this sentence survive having the tool's or subject's name removed?** If
yes it belongs to every sibling. Record the outcome in the mandatory
`siblings_checked:` field, including the verdict "checked —
instance-specific, no propagation": a one-entry `skill:` list is
byte-identical whether the siblings were evaluated or never considered,
and only the recorded field makes the *absence* of the judgement visible.
Load `references/observation-log.md` ("Skill families and the sibling
check") for the registry spec, the coherence models and the fallback when
no registry exists.

**Log your own rule violations.** Breaking a rule that a skill or a project
instruction file documents is a first-class observation, not an
embarrassment to move past: it is the only evidence that the rule's
*enforcement* is too weak, and nobody but the agent can see it. Log it in
the same turn, and name which protection was actually in play — written
down, loaded into context, or backed by a checkpoint. The restatement check
above surfaces the earlier entry when one exists, so the count arrives
without extra work.

**Second violation of the same rule: stop proposing text.** A rule that has
failed twice with no intervening `actioned` fix has a protection problem,
not a wording problem. From the second occurrence the proposed improvement
must be a structural barrier — a hook that refuses the call, a lint rule, a
default that makes the wrong path unavailable — never a clearer sentence, a
bolder warning, or the same rule moved somewhere more prominent. Load
`references/signals.md` ("Second violation — why a barrier, not a
rewording") before proposing either.

## How to Log

### When to write

Write the observation file **within the same turn or the next, without
interrupting the user's task** — never batch mentally for later; the act
of writing is the enforcement mechanism.

**Mandatory checkpoint after every 3rd completed todo item.** After marking
the 3rd, 6th, 9th (etc.) item complete you must **write to disk** — not
merely ask yourself whether anything is pending. Write any pending
observation files, or append a one-line `no observations` acknowledgement
to `skill-observations/checkpoints.log`. The required action is a concrete
write; a remembered "ask whether" is not enforcement. Roughly every third
completion is the rule; the count need not be precise. (Exception for a
priced-write workspace: `references/environments.md`.)

**A denied or failed write is not a read-only log.** Retry once before
concluding the workspace is unwritable, and try a second tool reaching the
same path — a classifier can deny one interface while allowing another,
and consecutive denials from a probabilistic gatekeeper are noise, not a
wall. Report "failed N times", never "cannot be done", unless retries and
alternate interfaces are exhausted; otherwise observations are silently
lost for the rest of the session.

**Deliverable-event flush.** Whenever a unit of work is declared complete
to a human — a file handed over, a render, a staged skill file, a
completion notification, a final report, a finished todo batch — write any
pending observation files at that moment. These checkpoints already
involve a tool call, so the flush rides on work you were doing anyway.
(Why both checkpoints are writes rather than questions:
`references/observation-log.md`.)

**A failed write to an external system is a flush trigger in its own
right** — a tool result carrying `permission stream closed`, `permission
denied`, or a harness interrupt. Not a completion, but it has both
properties the flush needs: it is a literal string in the tool record
rather than a judgement about whether the moment qualifies, and it lands
where a run has just found something worth reporting and is most likely to
stop instead. Flush before doing anything else with the failure, including
deciding what to do about it. (Observed: an unattended run completed every
step, took a permission error on its first external write, and ended with
no report and no logged observation.)

**Two gaps this pairing still leaves:** the 3rd-completion checkpoint is
inert in a session using no todos, and "is this a major deliverable?" is a
self-assessment — so the deliverable flush is the only enforcement left
and must be applied deliberately. Before adding or changing any
enforcement trigger, load `references/observation-log.md` ("Two gaps the
checkpoint pairing still leaves — and the rule behind both").

### Id and filename

**Id and filename.** Each observation is `NNNN-short-slug.md` (zero-padded
id + a kebab-case slug from the title). The id is the highest of three
values, plus one: the highest numeric prefix in `observation-log/`, the
highest in `observation-log/archive/`, and the number in
`observation-log/archive/.id-floor` (the highest id ever issued — update it
whenever you issue an id above it, so the counter can never restart from 1
when the active directory is empty). The same command first sweeps stale
resolved files into `archive/` — archival is a side effect of deriving the
id, not a separate duty (see Archival on Write):

```bash
d="[ABSOLUTE PATH]/skill-observations/observation-log"   # the pinned workspace path, never relative to the cwd; it may contain a space, so keep it quoted; bash, not sh
today=$(date +%F)          # archival rides inside this command (see below):
n_files=$(find "$d" -maxdepth 1 -name '*.md' ! -empty | wc -l | tr -d ' ')   # a zero-byte file gives awk no line to count
seen=$(cd "$d" && awk 'FNR==1 {n++; nextfile} END {print n+0}' *.md 2>/dev/null)   # files the sweep's glob reaches, counted apart from the sweep
[ "$n_files" -gt 0 ] && [ "${seen:-0}" -eq 0 ] && { echo "ARCHIVAL SWEEP BROKEN — $n_files files present, 0 examined"; exit 1; }
( cd "$d" && awk -v today="$today" 'FNR==1 {st=""; r=""; fm=/^---[[:space:]]*$/; if (!fm) nextfile; next}
    fm && /^---[[:space:]]*$/ {if (st ~ /^(actioned|declined|superseded)$/ && r ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ && r < today) print FILENAME; nextfile}
    fm && /^status:/ {st=$2}
    fm && /^resolved:/ {r=$2}' *.md 2>/dev/null | while IFS= read -r x; do mv "$x" archive/; done )   # one awk for the set, one mv per stale resolved file; bash
floor=$(sed '1!d; s/[^0-9]//g' "$d/archive/.id-floor" 2>/dev/null); floor=$((10#${floor:-0}))   # digits only: a CRLF or padded floor still reads
ids=$(for p in "$d"/[0-9]*.md "$d"/archive/[0-9]*.md; do [ -e "$p" ] && printf '%s\n' "${p##*/}"; done | grep -oE '^[0-9]+')   # globs and builtins: no `ls` a profile alias can rebind
[ "$(printf '%s' "$ids" | grep -c .)" -eq "$(find "$d" "$d/archive" -maxdepth 1 -name '[0-9]*.md' | wc -l)" ] || { echo "ID COMMAND BROKEN — the listing and find disagree on the prefixed files"; exit 1; }
hi=$(printf '%s\n' "$ids" | sort -n | tail -1); hi=$((10#${hi:-0}))   # from the files alone; 10#: a zero-padded prefix is not octal
[ "$hi" -lt "$floor" ] && echo "NOTE: highest file id $hi is below .id-floor $floor — ids issued without a file; the new id goes above the floor"
next_id=$(( (hi > floor ? hi : floor) + 1 ))      # never below the floor, whatever the listing saw
f="$d/$(printf '%04d' "$next_id")-<slug>.md"      # the target path, built from the id just derived
[ -n "$(find "$d" -maxdepth 2 -name "$(printf '%04d' "$next_id")-*.md")" ] && { echo "COLLISION — id $next_id already used; re-derive"; exit 1; }   # guard the id PREFIX across active + archive, not the path
(set -C; : > "$f") || exit 1                        # noclobber: create, never truncate an existing file
printf '%s\n' "$next_id" > "$d/archive/.id-floor"   # AFTER the create: an id check that writes no file never moves the floor
```

The listing guard tells "the log says zero" from "I could not read
the log", the sweep's count does the same for the archival loop, the prefix
guard refuses a number already in use under any slug, and the `noclobber`
create refuses an existing path — write the body only after that create
succeeds, with the editing tool, or a QUOTED heredoc (never unquoted) where
commands arrive unaltered: `references/observation-log.md` ("Editing an existing observation").
Load `references/observation-log.md` ("The guard line, the sweep's count
and the noclobber create") when any of them fires.

**Run the snippet immediately before EVERY write, including the first and
only one of a session** — an earlier read of the log is not a substitute,
and the id the session-start scan printed is never an input to a write.
Where a helper can run, `bash scripts/new-observation.sh <slug>` is the only
write path: it performs this whole snippet and prints the created path, so
derivation cannot drift from creation (the structural barrier the
second-violation rule demands). Load `references/observation-log.md` ("Run
the snippet immediately before every write") when skipping feels
reasonable, or when two files turn out to share an id.

**Resolve each id at its own write time** — run the snippet before EACH
file, never pre-compute a range, and put the value it printed into both the
filename and the `id:` field. Load `references/observation-log.md`
("Resolve each id at its own write time") before batching or parallelising.

**Every instrument gets the same guard: an empty or zero result is a
claim about the instrument until an independent probe shows the
population is empty.** Load `references/observation-log.md` ("Every
instrument gets the same guard") before writing any new scan, count, grep
or query over the log.

**A structural probe that comes back empty where content existed before is
a stop signal, not a create** — HALT and re-probe; never let an append
recreate a missing target. Load `references/observation-log.md` ("A
structural probe that comes back empty is a stop signal") before writing
anything after such a probe.

### File format

**File format.** YAML frontmatter (the metadata every scan reads) followed
by the Issue → Improvement → Principle body. **The frontmatter is mandatory;
always write `status: open` and a non-empty `siblings_checked:` at creation
time** — an observation without a `status` field is treated as OPEN by
reviews, never as nonexistent, and one without `siblings_checked:` counts
as logged without a sibling check.

```markdown
---
id: 0
title: "Short descriptive title"
status: open            # open | actioned | declined | superseded | parked
type: open-source       # open-source | internal
skill: [skill-a, "plugin:skill-b"]  # existing skills this improves —
                                 # always a list, first entry primary, may be
                                 # empty: []; quote an entry holding a colon
proposes_skill: []               # new skills this argues for, by working
                                 # name; an observation can fill either
                                 # list or both
target_file: []                  # when the right home is not a skill at all:
                                 # the path the fix will be written to
siblings_checked: "family-name: a, b — a added; b excluded (b/SKILL.md §2)"
                                 # MANDATORY, never blank: the family name,
                                 # each member's verdict — every exclusion
                                 # names the section read in it, or the
                                 # literal assumed; none only where the
                                 # target belongs to no family
area: "which part of the skill or workflow"
date: YYYY-MM-DD
session_context: "what task was being worked on"
parked_until:           # MANDATORY when status is parked, empty otherwise:
                        #   one line naming the condition that unparks it
resolved:               # date resolved; leave empty while OPEN
resolution:             # what was done — set only when actioned/declined
reference:              # optional — path to saved session-local evidence
commands_verified:      # MANDATORY when the body quotes a command — each
                        #   `run` with its result, or `NOT RUN` with why; else none
---

**Issue:** [What happened — specific enough to understand weeks later
without the original conversation.]

**Suggested improvement:** [Concrete change. For existing skills, name the
section or rule; for new skills, scope and key components.]

**Principle:** [The generalisable takeaway — the most important field.]
```

**Every prose value is double-quoted, and so is a list entry holding a
colon.** `title`, `siblings_checked`, `area`, `session_context`,
`resolution`, `parked_until` and `reference` carry free text, and free
text contains `: ` as the common case; unquoted, that is invalid YAML —
the scan notices nothing, every consumer that PARSES the header throws.
A plugin-scoped name in a `[]` list (`[plugin:name]`) loads under one
YAML parser and fails under another: quote it (`"…"`, inner `"` as `\"`);
bare kebab-case names, dates and status words stay bare. Load
`references/observation-log.md` ("Frontmatter fields") for the drift.

### Parked, context, confidentiality, and changing an entry

**`parked` means decided, not pending:** sound but blocked on an external
precondition, out of the work queue, never archived, `parked_until:`
mandatory and naming a condition that can actually occur. Load
`references/observation-log.md` ("The `parked` status — decided, not
pending") before setting, reviewing or unparking a parked status.

**Context preservation:** if an observation depends on session-local data,
save it into the workspace first and set `reference:` to a durable path a
fresh session can resolve. Load `references/observation-log.md` ("Context
preservation — the `reference:` field") when setting `reference:`.

**Confidentiality at logging time:** for `type: open-source` observations,
the Issue/Improvement fields may reference specifics for context, but the
Principle must be fully generalised — no client names, domains, or details
traceable to a real project. Full confidentiality layers:
`references/skill-authoring.md`.

**Changing an existing observation:** re-read that one file, edit only the
frontmatter fields you are changing (`status`, `parked_until`, `resolved`,
`resolution`), never batch-rewrite the directory. Archival is a plain `mv`.

## Referencing Observations

Cite an observation by the `id` field in its frontmatter (= the `NNNN-`
filename prefix), never a `grep -n` line number — those are positional
metadata, not identifiers. A cited id must fall inside the range across
`observation-log/`, `archive/` and `.id-floor`; one far outside it is
almost certainly a line number misread as an id.

## Taxonomy (quick version)

**Open-source** — client-agnostic, methodology-driven, useful to other
practitioners. **Internal** — contains user/client/project specifics or
personal preferences. Default to open-source when it could go either way,
stripping specifics. The boundary is also a confidentiality boundary and
the two errors are not symmetric — over-classifying as internal costs only
reach, under-classifying can leak — so when genuinely uncertain, prefer
internal and promote later. Full requirements (attribution, licensing,
structure): `references/skill-authoring.md`.

## Archival on Write

Archival is not a preamble duty to remember before writing — it rides
inside the id-derivation snippet above: the same command that computes the
next id first `mv`s already-resolved files from `observation-log/` to
`observation-log/archive/`, so the sweep runs whenever an id is issued and
cannot be skipped without failing the write. (The prose form — "on every
write, first archive" — under-fires: a duty attached as a preamble to
another action inherits none of that action's enforcement. If a step must
always accompany a tool call, put it inside the same command.) The
scheduled review archives too, at Step 1, as an independent backstop. "Already resolved" is read from the file's
own frontmatter: `status: actioned`, `declined` or `superseded` AND a
`resolved:` date **before today**. Files resolved today stay until the next
day, whichever session resolved them — the grace period lives in the file,
never in session memory. A resolved file with no readable `resolved:` date
gets today's date written to that field instead of being archived (the
snippet skips it; make that one-field edit separately). One file per
`mv`, no rewrite of anything else, and a bulk move outside the sweep is
verified by conservation: `references/observation-log.md` ("Archival").
