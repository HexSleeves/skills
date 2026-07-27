# PR Drain Owner Approval Design

## Purpose

Allow an explicitly authorized repository owner or administrator to satisfy a missing pull-request approval without weakening any other merge gate.

## Decision

Record owner approval as a real GitHub `APPROVE` review, then use the existing normal exact-head merge path. Do not use `gh pr merge --admin`.

This lets GitHub enforce checks, unresolved-thread policy, draft state, merge queues, branch rules, and the exact reviewed head while satisfying only the missing-review requirement.

## Authorization

The user must explicitly authorize owner approval for the selected run or pull requests. A normal `pr-drain` invocation does not imply this authority.

Before submitting a review, verify live that:

- the authenticated GitHub account has `ADMIN` permission on the repository;
- the authenticated account is not the pull-request author;
- the pull request still has the reviewed head SHA;
- every applicable non-review gate passes;
- no review thread is unresolved; and
- missing approval is the only unmet merge requirement.

## Workflow

1. Complete the existing diff review and verification workflow.
2. Refresh the head SHA, threads, checks, draft state, risk classification, rulesets, protection, and queue state.
3. If explicit owner approval exists and the prerequisites pass, submit an `APPROVE` review through GitHub using the authenticated administrator account.
4. Confirm the submitted review belongs to that account, applies to the verified head, and produces an approved review decision.
5. Refresh every merge gate again.
6. Merge through the existing exact-head non-admin path.

If the head changes, discard the approval evidence, reinspect and reverify the new head, then resubmit only under the same still-applicable run authorization.

## Failure Handling

Block without using an administrative bypass when:

- owner approval was not explicit;
- repository `ADMIN` permission cannot be proven;
- the authenticated account authored the pull request;
- GitHub rejects or cannot confirm the approval;
- any non-review gate is failing, pending, inaccessible, or ambiguous; or
- the head changes and cannot be fully reverified.

## Evidence

The final result records the approving login, review state and submission time, verified head SHA, refreshed gate evidence, and merge SHA or blocker.

## Scope

Change only `skills/pr-drain/SKILL.md`. Add no helper, configuration, dependency, admin-merge path, or repository-specific bot policy.
