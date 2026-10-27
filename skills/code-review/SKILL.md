---
name: "code-review"
description: "Use when a branch is ready for its PR, or the user asks to review a branch, a PR, work-in-progress changes, or the changes \"since X\"."
metadata:
  upstream: mattpocock/skills
---

Three-axis review of the diff between `HEAD` and a fixed point the user supplies:

- **Standards**: does the code conform to this repo's documented coding standards?
- **Spec**: does the code faithfully implement the originating issue / spec?
- **Failure modes**: what does a malformed, partial, slow or hostile input do at each external boundary in the diff?

All three axes run as **parallel sub-agents** so they don't pollute each other's context, then this skill aggregates their findings.

Run it once per branch, after the last task and before the PR opens. After an individual task or slice, keep implementing; review mid-branch only when the user asks for it.

The issue tracker should have been provided to you. If not, tell the user to run `/setup-matt-pocock-skills`.

## Process

### 1. Pin the fixed point

Whatever the user said is the fixed point (a commit SHA, branch name, tag, `main`, `HEAD~5`, etc.). If they didn't specify one, ask for it.

Capture the diff command once: `git diff <fixed-point>...HEAD` (three-dot, so the comparison is against the merge-base). Also note the list of commits via `git log <fixed-point>..HEAD --oneline`. On uncommitted work (as under `implement`), the three-dot form shows committed changes only: use `git diff $(git merge-base <fixed-point> HEAD)` and list the untracked files for the sub-agents to read.

Before going further, confirm the fixed point resolves (`git rev-parse <fixed-point>`) and the diff is non-empty. A bad ref or empty diff should fail here, not inside three parallel sub-agents.

### 2. Identify the spec source

Look for the originating spec, in this order:

1. Issue references in the commit messages (`#123`, `Closes #45`, GitLab `!67`, etc.), fetched via the workflow in the tracker doc.
2. A path the user passed as an argument.
3. A spec file under `docs/`, `specs/`, or `.scratch/` matching the branch name or feature.
4. If nothing is found, ask the user where the spec is. If they say there isn't one, the **Spec** sub-agent will skip and report "no spec available".

### 3. Identify the standards sources

Search the repo for every file that documents how code should be written. When `CODING_STANDARDS.md` or `CONTRIBUTING.md` exists, it must be on the list.

On top of whatever the repo documents, the Standards axis always carries the **smell baseline** below: a fixed set of Fowler code smells (_Refactoring_, ch.3) that applies even when a repo documents nothing. Two rules bind it:

- **The repo overrides.** A documented repo standard always wins; where it endorses something the baseline would flag, suppress the smell.
- **Always a judgement call.** Each smell is a labelled heuristic ("possible Feature Envy"), never a hard violation. Like any standard here, skip anything tooling already enforces.

Each smell reads *what it is* → *how to fix*; match it against the diff:

- **Mysterious Name**: a function, variable, or type whose name doesn't reveal what it does or holds. → rename it; if no honest name comes, the design's murky.
- **Duplicated Code**: the same logic shape appears in more than one hunk or file in the change. → extract the shared shape, call it from both.
- **Feature Envy**: a method that reaches into another object's data more than its own. → move the method onto the data it envies.
- **Data Clumps**: the same few fields or params keep travelling together (a type wanting to be born). → bundle them into one type, pass that.
- **Primitive Obsession**: a primitive or string standing in for a domain concept that deserves its own type. → give the concept its own small type.
- **Repeated Switches**: the same `switch`/`if`-cascade on the same type recurs across the change. → replace with polymorphism, or one map both sites share.
- **Shotgun Surgery**: one logical change forces scattered edits across many files in the diff. → gather what changes together into one module.
- **Divergent Change**: one file or module is edited for several unrelated reasons. → split so each module changes for one reason.
- **Speculative Generality**: abstraction, parameters, or hooks added for needs the spec doesn't have. → delete it; inline back until a real need shows.
- **Message Chains**: long `a.b().c().d()` navigation the caller shouldn't depend on. → hide the walk behind one method on the first object.
- **Middle Man**: a class or function that mostly just delegates onward. → cut it, call the real target direct.
- **Refused Bequest**: a subclass or implementer that ignores or overrides most of what it inherits. → drop the inheritance, use composition.

### 4. Spawn the three sub-agents in parallel

Issue all three sub-agent calls together, in the foreground, and aggregate the reports they return.

When this skill runs inside a dispatched sub-agent (another agent invoked it, not the user), run the three axes yourself in that context instead: work through the Standards brief, then the Spec brief, then the Failure-modes brief, each against the contents listed below, and keep their findings in separate reports for step 6.

Every axis carries the **permission rule**: a finding or proposed fix that rests on whether a principal may use a cloud resource (KMS key, IAM role, bucket or key policy) names the policy document that decides it, and quotes that document from a read-only call to the live system when access exists; otherwise it labels the claim "docs-only, unverified until apply". Only the policy itself evidences a permission claim; a plan or dry run proves shape, not authority. Paste this rule into every prompt.

Every sub-agent is report-only: to test a suspicion that needs a toolchain shim or installer (mise, asdf, nvm, npx, bunx, pip), it describes the experiment instead of running it, and its before/after snapshot covers global tool dirs (`~/.local/share/mise/installs`, `~/.npm/_npx`) as well as `git status`. A throwaway fuzz a sub-agent runs states its distinct-case count beside its run count and result. Paste these rules into every prompt.

Each sub-agent must run the diff command itself, so dispatch an agent type that has a shell. Read-only agent types (Read/Grep/Glob only) review the working tree instead of the diff. If only read-only types exist, paste the diff into every prompt. When a report says it could not run git, rerun that axis before aggregating.

**Standards sub-agent prompt** should include:

- The full diff command and commit list.
- The list of standards-source files you found in step 3, **plus the smell baseline from step 3** pasted in full (the sub-agent has no other access to it).
- The brief: "Report, per file/hunk where relevant, (a) every place the diff violates a documented standard: cite the standard (file + the rule); and (b) any baseline smell you spot: name it and quote the hunk. Distinguish hard violations from judgement calls: documented-standard breaches can be hard, but baseline smells are always judgement calls, and a documented repo standard overrides the baseline. Skip anything tooling enforces. Report findings only, with no preamble or restatement of the diff."

**Spec sub-agent prompt** should include:

- The diff command and commit list.
- The path or fetched contents of the spec.
- The brief: "Report: (a) requirements the spec asked for that are missing or partial; (b) behaviour in the diff that wasn't asked for (scope creep); (c) requirements that look implemented but where the implementation looks wrong; (d) tests whose seam skips a production wrapper (client settings, caches, middleware), or uses a fake clock that resolves sleeps immediately, that changes how the code under test executes, so the test proves a path production does not run; (e) restructured steps ("build once", "inline", "merge two calls") that stop passing a value one command handed the next: check each value the old steps passed; (f) when the spec claims a defect in merged code (an audit report, a handoff, a bug note), each finding that changes existing behaviour or config, checked against the history of the lines it touches (`git log -S '<token>' -- <file>` and the PR body that introduced them): one that reverses a recorded decision is a decision to revisit, with the recorded reason; (g) when the diff adds or widens storage (a table, column, view, cache, log field or file), for each new place that stores identifiers or user content, its retention or expiry against the strictest retention the source data already has (raw TTLs, retention classes, a spec's privacy window): a copy that outlives its source is a finding even when the spec asked for it; (h) for any change that adds a scoring game, the laziest strategy that scores well, played against the rules; (i) tests whose names claim a universal property ("every", "never", "always") while sampling a subset of the inputs production produces. Quote the spec line for each finding. Report findings only, with no preamble or restatement of the diff."

If the spec is missing, skip the Spec sub-agent and note this in the final report.

**Failure-modes sub-agent prompt** should include:

- The diff command and commit list.
- The brief: "Walk every external boundary in the diff (request parsing, child-process and network streams, third-party responses that can be partially successful, timers and retries on the client) and report, per boundary, what a malformed, partial, slow or hostile input does. For every element the diff resizes or moves, check the hit areas, zones and layout constants tied to it; for every observer, listener or locator a test attaches, check the observed node outlives the action under test. For each async step between a user input and the state it produces, say what every action the UI offers does during the wait. A crash, data corruption or unbounded work is a hard finding. Report findings only, with no preamble or restatement of the diff."

### 5. Check the CI target was the gate

Read the repo's CI entry point (its CI workflow, `make ci` or the equivalent target, or the gate its docs name) and list its steps. Check the evidence offered for this branch ran each of those steps, or name the ones skipped and why in the final report. The evidence for a step is the output only that step prints (a test count, a build line), not an exit code alone: a package-manager built-in can take a script's name (`pnpm ci` is a clean install that exits 0), so package scripts run as `<pm> run <name>`. A green subset is not a green CI; for example, typecheck and tests passing locally say nothing about a bundle-budget step the CI target also runs. Start a long CI run (a Docker build, a full suite) after the review's findings are fixed and committed, on the head the PR will carry: a run started alongside the review is wasted whenever the review finds anything. A run already in flight may stand if the review comes back with no findings.

When the change claims to close a code-scanning alert, the PR's CodeQL check is diff-informed: it is evidence only for alerts inside the diff. For the rest, run the scanner locally at the analysis's tool version and suite on the base and the head, and keep a probe that shows the query still fires without the fix.

Then confirm the CI system runs it. For GitHub Actions, `gh api repos/<o>/<r>/actions/permissions` shows `enabled: true` and `gh run list --workflow <file> --limit 1` shows a recent run. If either fails, report "CI configured but not running", treat the local runs as the only gate, and keep any claim that CI enforces the check out of the PR body.

### 6. Aggregate

Present the three reports under `## Standards`, `## Spec` and `## Failure modes` headings, verbatim or lightly cleaned. The comment pass runs later (step 8) and adds its `## Comments` section to the final report then. Do **not** merge or rerank findings, because the three axes are deliberately separate (see _Why three axes_).

End with a one-line summary: total findings per axis, and the worst issue _within each axis_ (if any). Don't pick a single winner across axes: that's the reranking the separation exists to prevent.

### 7. Fix round

Grade each finding yourself: **blocker** (the intended case is wrong), **should** (a real bug callers will hit, within the spec), **nit** (other paths, rare cases, small perf costs, extra compatibility, style). Another path or a rare case is a nit whatever label the sub-agent gave it.

- Fix blockers and shoulds with the smallest change, preferring the one that deletes or narrows code. A rewrite keeps every guard, `?.`, default and `try` of the old code unless `git log -S` shows its reason is gone.
- Decline nits in one line each and list them as follow-ups in the final report.
- Then compare `git diff --shortstat` against the reviewed head's. If the fixes grew the diff past what the findings need, cut first.

The budget is one re-check. When a fix changed behaviour code, rerun the axis that raised it on the fix diff only (`git diff <reviewed-head>..HEAD`) with the original brief, told to check the changed code and the open findings. Fixes that touch only comments, docs, or formatting need none. Whatever the re-check leaves open goes to the user, with both sides in 2-3 lines.

### 8. Comment pass

When a `Comment Sicko` agent type is available, spawn it once, report-only, on the diff command after the review's fixes are committed, or right away when the review returned no findings. The push gate counts only a pass that runs after the last commit that changed files, so a pass spawned beside the review is voided by any fix commit. Report its verdicts on comments and on workaround code under `## Comments`.

## Why three axes

A change can pass one axis and fail another:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the issue asked but breaks the project's conventions → **Spec pass, Standards fail.**
- Code that follows the standards and the spec but crashes, corrupts data or does unbounded work on a malformed, partial or slow input → **Standards and Spec pass, Failure modes fail.**

Reporting them separately stops one axis from masking another.
