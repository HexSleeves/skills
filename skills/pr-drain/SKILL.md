---
name: pr-drain
description: Use when the user asks to review, repair, merge, or drain multiple GitHub pull requests in a repository, especially when failures must be fixed before the queue is finished.
---

# PR Drain

## Contract

Carry every selected pull request to a verified terminal state: merged, closed, or blocked with evidence. A summary is not completion.

Run only after the user explicitly asks to review or merge PRs. With no PR numbers, select every open PR in the repository resolved from the working directory. With numbers, process only those PRs and report other open PRs without changing them.

Invocation authorizes ordinary branch repairs, pushes, squash merges, and branch deletion. It never authorizes bypassing protection, force-pushing, choosing ambiguous product intent, or approving unclear security, migration, or production-infrastructure changes.

## Invariants

- Treat GitHub live state as truth. Do not trust cached UI counts or prior narration.
- Preserve the user's existing worktree. Make repairs in temporary worktrees.
- Review the complete diff. Never merge while any review thread remains unresolved.
- Tie checks, approvals, and review evidence to the exact current head SHA.
- Use gh pr merge --match-head-commit with the verified SHA.
- Never merge with required checks pending or failing.
- Never bypass rulesets, merge queues, required reviews, or branch protection.
- Agent-authored tests are supporting evidence, not sufficient independent evidence.
- Confirm every mutation from GitHub before advancing.
- One blocked PR does not stop independent PRs.
- Stop retrying after one transient retry or two repair attempts for the same deterministic failure.

## Workflow

### 1. Resolve scope

1. Run gh auth status.
2. Resolve the repository with gh repo view --json nameWithOwner.
3. Read repository instructions, including AGENTS.md and equivalents.
4. Record git status without changing the existing worktree.
5. Fetch selected PRs from live GitHub state. Include number, URL, draft state, base and head branches, headRefOid, mergeable, mergeStateStatus, reviewDecision, and statusCheckRollup.
6. Query all review-thread pages through the GitHub connector or gh api graphql; a flat comment list cannot prove every thread is resolved.
7. Order stacked PRs after their selected parents. Treat other PRs as independent until evidence shows a dependency.

Prefer a purpose-built GitHub connector for structured reads when available. Use gh for live head checks, GraphQL pagination, Actions logs, checkout/push, check watching, and merge operations.

### 2. Inspect and review

For each PR:

1. Refresh its head SHA and metadata.
2. Read every changed file and commit, not only the summary.
3. Inspect unresolved threads and requested changes.
4. Review correctness, regressions, security, compatibility, tests, and repository policy.
5. Classify security-sensitive changes, destructive or unclear migrations, production infrastructure, and ambiguous product behavior as blocked unless intent is already explicit in repository evidence.
6. Treat Graphify output, when already installed and fresh, only as optional impact-analysis evidence. Never install it or use it as a merge gate.

### 3. Verify or repair

Discover and run the repository's own formatting, lint, typecheck, build, and test commands when practical.

For an ordinary repair:

1. Fetch the PR head.
2. Create a detached temporary worktree from that head under a path returned by mktemp -d.
3. Fix the root cause and inspect the resulting diff.
4. Run repository-native validation in the temporary worktree.
5. Resolve the actual writable head repository and branch before pushing. Block fork PRs when the authenticated user cannot safely update their head.
6. Push without force and refresh headRefOid.

For every selected PR, including an unchanged head, record headRefOid and wait for required checks on that SHA with gh pr checks --required --watch --fail-fast when supported. After the watcher exits, refresh headRefOid; if it changed, discard the result and repeat on the new head.

Retry a transient GitHub or CI failure once without changing code. Permit at most two repair attempts for one deterministic failure. A repeated or materially different failure becomes a blocker.

Preserve an unpushed repair worktree only when it contains useful work and report its path. Remove successful or empty temporary worktrees.

### 4. Gate and merge

Immediately before merge, refresh:

- headRefOid;
- draft state;
- unresolved review threads;
- required approvals;
- required checks and their associated SHA;
- mergeability, rulesets, branch protection, and merge-queue state.

Any changed head invalidates earlier review and verification. Reinspect the delta and rerun applicable checks.

Merge only when every applicable gate passes. Use:

~~~bash
gh pr merge "$pr" --squash --delete-branch --match-head-commit "$verified_sha"
~~~

If repository policy requires a merge queue, enqueue without bypassing it and wait for the terminal result. If squash is unavailable, follow an explicit repository instruction for another allowed strategy or block.

After the command, fetch the PR again. Record mergedAt and mergeCommit only when GitHub reports MERGED. Do not call queued, auto-merge-enabled, or command-success states merged.

### 5. Continue and reconcile

After each merge, refresh the default branch and reevaluate remaining PRs for changed bases, conflicts, invalidated approvals, and newly required checks.

A run ends only when every selected PR is:

- merged, with merge SHA;
- closed outside the run; or
- blocked, with the unmet condition and evidence.

Fetch the live open-PR list at the end. An all-PR run reports zero remaining open PRs or names every blocked PR. A targeted run also lists unselected open PRs.

## Resume

Reconstruct a restarted run from live state: skip already merged PRs while recording their merge SHAs, report externally closed PRs, and process open PRs from their current remote heads. Reuse checks only when GitHub attaches them to the same head SHA. Resume pushed repairs from the remote branch and never assume an unpushed local repair occurred.

## Failure Policy

| Failure | Action |
| --- | --- |
| Transient CI or GitHub outage | Retry once without code changes |
| Ordinary deterministic failure | Repair and reverify, maximum two attempts |
| Changed head or base | Invalidate stale evidence and reverify |
| Missing required approval | Block that PR |
| Security, migration, infrastructure, or product ambiguity | Block that PR |
| Missing branch permission | Block; preserve a useful unpushed repair |
| Authentication or repository-wide policy failure | Stop the run |
| Independent broken PR | Continue with other PRs |

## Output

Return only after final reconciliation:

~~~text
PR | Result | Verified head | Evidence | Merge SHA / Blocker
~~~

Include failed repair attempts and preserved worktree paths. Never claim the queue is drained from a stale PR count.
