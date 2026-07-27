---
name: pr-drain
description: Use when the user explicitly invokes pr-drain, asks to drain pull requests, or requests repair-and-merge work across GitHub pull requests.
---

# PR Drain

## Contract

Carry every selected pull request to a verified terminal state: merged, closed, or blocked with evidence.

Mutation requires explicit drain or repair-and-merge intent. Review-only requests stay read-only. Without PR numbers, select all open PRs; with numbers, change only those and report the others.

Drain intent authorizes ordinary repairs, pushes, squash merges, and safe remote-branch deletion. Owner-approval authority must be explicit and separate. Neither authorizes protection bypass, force-push, or ambiguous product, security, migration, or production-infrastructure changes.

## Invariants

- Treat GitHub live state as truth; distrust cached counts and prior narration.
- Preserve the user's existing worktree exactly. Make repairs in temporary worktrees.
- Review the complete diff. Never merge while any review thread remains unresolved.
- Tie checks, approvals, and review evidence to the exact current head SHA.
- Use gh pr merge --match-head-commit with the verified SHA.
- Never merge with required checks pending or failing.
- Never bypass rulesets, merge queues, required reviews, or branch protection.
- Agent-authored tests cannot independently prove correctness.
- Confirm every mutation from GitHub before advancing.
- One blocked PR does not stop independent PRs.
- Allow one transient retry and two repair attempts per deterministic failure.

## Workflow

### 1. Resolve scope

1. Run gh auth status.
2. Resolve the repository and permission with gh repo view --json nameWithOwner,viewerPermission.
3. Read repository instructions, including AGENTS.md and equivalents.
4. Snapshot the existing worktree's branch, HEAD, status, staged and unstaged diffs, and untracked-file hashes without changing it.
5. Fetch live selected PRs, including number, URL, author login, draft, base/head refs, headRefOid, mergeability, reviewDecision, and checks.
6. Query every review-thread page through the GitHub connector or GraphQL; flat comments cannot prove resolution.
7. Order stacked PRs after selected parents; treat others as independent until proven otherwise.

Prefer a GitHub connector for structured reads; use gh for live checks, logs, git operations, watching, and merges.

### 2. Inspect and review

For each PR:

1. Refresh its head SHA and metadata.
2. Read every changed file and commit, not only the summary.
3. Inspect unresolved threads and requested changes.
4. Review correctness, regressions, security, compatibility, tests, and repository policy.
5. Block unclear security, destructive migration, production-infrastructure, or product intent unless repository evidence resolves it.
6. Use only preexisting fresh Graphify output as advisory evidence; never generate, commit, install, hook, start, or gate on it.

### 3. Verify or repair

Run repository-native formatting, lint, typecheck, build, and tests when practical.

For an ordinary repair:

1. Fetch the PR head.
2. Create a detached temporary worktree from that head under a path returned by mktemp -d.
3. Fix the root cause and inspect the resulting diff.
4. Run repository-native validation in the temporary worktree.
5. Resolve the writable head repository and branch; block when it cannot be updated safely.
6. Push without force and refresh headRefOid.

For every selected head, wait for required checks on that SHA with gh pr checks --required --watch --fail-fast when supported. Zero checks pass only when live policy proves none are configured; missing, inaccessible, or ambiguous policy blocks. Refresh headRefOid afterward; changed heads invalidate the result.

Retry transient GitHub or CI failure once without code changes. After two deterministic repair attempts, block.

Preserve and report only useful unpushed repair worktrees; remove successful or empty ones.

### 4. Gate and merge

Immediately before merge, refresh:

- headRefOid;
- draft state;
- unresolved review threads;
- required approvals;
- required checks and their associated SHA;
- mergeability, rulesets, branch protection, and merge-queue state.

Changed heads invalidate review and verification; reinspect the delta and rerun applicable checks.

If approval is the only unmet gate and the user explicitly authorized owner approval for this run:

1. Verify live `viewerPermission: ADMIN`, an authenticated login different from the PR author, and the exact verified head.
2. Only after every non-review gate passes, submit `gh pr review "$pr" --repo "$repo" --approve`.
3. Confirm an `APPROVED` review by that login, its `commitOid` equals the verified head, and GitHub now reports an approved review decision.
4. Refresh every gate. A changed head discards approval evidence and requires complete reinspection, reverification, and a new review under the same authorization.

Never use administrative merge bypass. If any prerequisite or confirmation fails, block.

Merge only after every applicable refreshed gate passes.

For an immediate merge, use:

~~~bash
gh pr merge "$pr" --repo "$repo" --squash --delete-branch --match-head-commit "$verified_sha"
~~~

Keep explicit `--repo`: in gh 2.96 it prevents `--delete-branch` from changing or deleting a local branch while allowing remote deletion.

Outside queues, squash by default. If unavailable, replace only `--squash` with `--merge` or `--rebase` when repository instructions explicitly permit it; otherwise block.

For a required merge queue, use no delete or strategy flag:

~~~bash
gh pr merge "$pr" --repo "$repo" --match-head-commit "$verified_sha"
~~~

Poll until GitHub reports `MERGED`; enqueue success is not completion. If ejected, reverify or block. Then re-resolve the writable non-default head, confirm its SHA and no open PR uses it, and delete only that remote ref.

Record mergedAt and mergeCommit only after `MERGED`. Compare the complete worktree snapshot and report any difference.

### 5. Continue and reconcile

After each merge, refresh the default branch and reevaluate remaining PRs for changed bases, conflicts, invalidated approvals, and newly required checks.

A run ends only when every selected PR is:

- merged, with merge SHA;
- closed outside the run; or
- blocked, with the unmet condition and evidence.

Fetch the live open-PR list at the end. An all-PR run reports zero remaining open PRs or names every blocked PR. A targeted run also lists unselected open PRs.

## Resume

Reconstruct from live state: record merged and externally closed PRs, and process open remote heads. Reuse checks only on the same SHA. Count durable repair commits and check reruns against existing budgets; if prior attempts are uncertain, grant no new budget. Never assume an unpushed repair occurred.

## Failure Policy

| Failure | Action |
| --- | --- |
| Transient CI or GitHub outage | Retry once without code changes |
| Ordinary deterministic failure | Repair and reverify, maximum two attempts |
| Changed head or base | Invalidate stale evidence and reverify |
| Missing required approval | Block unless the explicit owner-approval review succeeds |
| Security, migration, infrastructure, or product ambiguity | Block that PR |
| Missing branch permission | Block; preserve a useful unpushed repair |
| Authentication or repository-wide policy failure | Stop the run |
| Independent broken PR | Continue with other PRs |

## Output

Return only after final reconciliation:

~~~text
PR | Result | Verified head | Evidence | Merge SHA / Blocker
~~~

Include failed repairs, preserved worktrees, and owner-approval login, `commitOid`, and submission time. Never claim a drain from a stale count.
