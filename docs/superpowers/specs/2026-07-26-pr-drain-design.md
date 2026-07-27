# PR Drain Skill Design

## Purpose

`pr-drain` is a user-invoked skill for Codex and Claude Code that carries a selected GitHub pull-request queue from review through repair, verification, and merge. A run ends only when every selected pull request is merged, closed, or blocked with evidence.

The skill optimizes for safe completion rather than summary-only review. Invoking it authorizes ordinary branch repairs, pushes, and eligible merges within the limits below.

## Interface

```text
/pr-drain
/pr-drain 42
/pr-drain 42 57 61
```

The repository is resolved from the working directory's Git remote. With no PR numbers, the target set is every open PR in that repository. With PR numbers, only those PRs are processed, but the final report also identifies any other open PRs.

The interface returns one result table:

```text
PR | Result  | Head SHA | Evidence | Merge SHA / Blocker
42 | merged  | abc123   | 8 checks | def456
57 | blocked | 789abc   | 1 failed | migration intent unclear
```

## Authority

Invocation authorizes the skill to:

- inspect complete diffs, metadata, reviews, unresolved threads, checks, and branch relationships;
- create temporary worktrees without modifying the user's existing worktree;
- repair ordinary code, dependency, lockfile, formatting, test, and merge-conflict failures;
- push repairs to branches when the authenticated user has permission;
- wait for fresh required checks;
- squash-merge eligible PRs and delete their branches;
- continue past blocked PRs when remaining PRs are independent.

Invocation does not authorize the skill to:

- bypass branch protection, rulesets, required checks, merge queues, or required reviews;
- force-push;
- choose among ambiguous product behaviors;
- approve destructive migrations, security-sensitive changes, or production-infrastructure changes;
- merge a commit other than the commit that passed final verification;
- retry indefinitely.

Squash merge is the default. If the repository disallows it, the skill follows an explicit repository instruction for another strategy or blocks the PR.

## Architecture

The skill is one deep module. Its small interface hides queue discovery, dependency ordering, review, repair, verification, and merge confirmation. These phases remain internal rather than becoming separate skills because they have no independent invocation need in version one.

No graph DSL, daemon, database, custom scheduler, or workflow runtime is introduced. The skill body defines the control graph. GitHub is the durable source of truth for PRs, head SHAs, checks, reviews, comments, and merge results. Git and repository-native checks provide local evidence.

The session maintains a compact result record for reporting:

```yaml
status: passed | failed | blocked
evidence:
  - command, check, review, or GitHub URL
artifacts:
  - commit, diff, test output, or merge SHA
reason: required when failed or blocked
```

This result record is not a second durable database. A restarted run reconstructs its position from GitHub and the live branches.

## Execution Graph

```text
Discover
  -> order independent and stacked PRs
  -> Inspect
  -> Review
  -> Verify
       -> failure -> classify -> Repair -> push -> Verify
       -> success -> refresh head/reviews/mergeability
  -> Merge
  -> Confirm
  -> reevaluate remaining queue
  -> Reconcile final state
```

### Repository preparation

1. Validate `gh` authentication and resolve the repository identity.
2. Read repository instructions such as `AGENTS.md` and discover repository-native validation commands.
3. Record the user's existing worktree state without changing it.
4. Fetch selected PR metadata from live GitHub state.
5. Order independent PRs before PRs stacked on non-default branches or otherwise dependent on another selected PR.

### Per-PR processing

1. Read the complete diff, commits, reviews, unresolved threads, merge state, base branch, head branch, and head SHA.
2. Classify the PR as ordinary or high-risk. High-risk ambiguity blocks the PR.
3. Review correctness, security, regressions, tests, compatibility, and repository-specific policy.
4. Run repository-native local validation when practical.
5. If an ordinary failure is repairable, create an isolated worktree, repair the root cause, rerun local validation, push, and replace the recorded head SHA.
6. Wait for required GitHub checks attached to the recorded head SHA.
7. Immediately before merging, refresh the head SHA, unresolved threads, approvals, checks, rules, and mergeability. Any change invalidates stale evidence.
8. Squash-merge with branch deletion.
9. Confirm GitHub reports `MERGED` and record the merge commit SHA.
10. Remove successful temporary worktrees and reevaluate the remaining queue against the changed default branch.

### Completion

A run ends only after every selected PR is classified as:

- `merged`: GitHub reports `MERGED` and the merge SHA is recorded;
- `closed`: the PR was closed outside the run and was not merged;
- `blocked`: a concrete unmet condition and supporting evidence are recorded.

The skill then fetches the live open-PR list. A default all-PR run must report zero remaining open PRs or name every blocked PR. A targeted run reports the status of unselected open PRs without processing them.

## Verification Gates

A PR may merge only when every applicable gate passes:

- complete diff review is finished;
- unresolved review-thread count is zero;
- repository-defined local validation passes when practical;
- required GitHub checks pass on the exact current head SHA;
- GitHub reports the PR mergeable under repository policy;
- required approvals remain valid for the current head SHA;
- no unreviewed changes appeared after verification;
- the merge operation's postcondition is confirmed from GitHub.

Agent-authored tests are supporting evidence, not sufficient independent evidence by themselves. Repository tests, compiler/typechecker results, CI, branch policy, and GitHub postconditions supply independent anchors.

## Failure Handling

| Failure | Action |
| --- | --- |
| Transient CI or GitHub outage | Retry once without changing code |
| Ordinary repairable failure | Repair and reverify, with at most two repair attempts for that failure |
| Changed head or base state | Invalidate stale evidence and reverify |
| Missing required approval | Block that PR |
| Security, migration, infrastructure, or product ambiguity | Block that PR |
| Missing branch permission | Block and preserve a useful unpushed patch/worktree |
| Authentication or repository-wide policy failure | Stop the run |
| One independently broken PR | Continue with independent PRs |

Repeated failures or materially different failures after the repair budget become blockers. Failed attempts remain visible in the final evidence.

Successful temporary worktrees are removed. A worktree containing useful unpushed repairs is preserved and its path reported.

## Resume and Idempotency

A restarted invocation reconstructs state rather than trusting prior narration:

- merged PRs are skipped and reported with their merge SHAs;
- closed PRs are reported as closed;
- changed head SHAs invalidate old checks and review evidence;
- completed checks are reused only when GitHub attaches them to the same head SHA;
- partially repaired branches resume from their live remote state;
- abandoned local repairs are not assumed to have been pushed.

GitHub mutation postconditions are checked before advancing, making repeated invocations safe without a local workflow database.

## Graphify Decision

Graphify is not part of version one. It builds a knowledge graph of code entities and relationships; it is not an execution-graph runtime and does not supply exact-SHA gates, repair loops, merge mutations, or policy enforcement.

If a repository already maintains a fresh Graphify graph, a future optional read-only step may use it for affected-symbol, graph-community, or overlapping-PR hints. Such output must remain advisory and cannot satisfy or override a merge gate. No run installs Graphify, generates committed graph output, enables hooks, or starts a graph service automatically.

## Acceptance Scenarios

1. **Green PR:** review, verify, merge, and record the merge SHA.
2. **Repairable PR:** observe failure, repair, push, wait for checks on the new head SHA, and merge.
3. **Protected PR:** report blocked without bypassing repository policy.
4. **Changed head:** discard stale evidence and repeat verification.
5. **Mixed queue:** merge independent safe PRs while reporting one blocked PR.
6. **Stacked queue:** merge in dependency order and reverify descendants.
7. **Final reconciliation:** account for every selected PR and fetch the live remaining queue.

Version one needs no custom test harness. Validate the skill's structure and safety wording, then perform an end-to-end acceptance run against a real repository under the same merge gates the skill enforces.

## Deferred Capabilities

Add a durable workflow runtime only when runs must survive terminated agent sessions without reconstruction, operate across many repositories unattended, or react to webhooks. Split internal phases into separate skills only when they gain independent invocation use cases. Add Graphify only after repeated review failures demonstrate that graph-based impact analysis catches useful issues ordinary review misses.
