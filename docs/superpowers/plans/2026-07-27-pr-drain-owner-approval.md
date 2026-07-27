# PR Drain Owner Approval Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan.

**Goal:** Let explicit repository-owner approval satisfy only the missing-review gate by recording a real GitHub approval review.

**Architecture:** Keep `pr-drain` as one self-contained skill. Add a conditional owner-approval path before merge. GitHub reviews and live repository permission remain the only authority and evidence. Preserve the normal exact-head merge path; never add an admin merge path.

**Files:**

- Modify: `skills/pr-drain/SKILL.md`
- Verify: `README.md`

## Task 1: Prove the behavioral gap

1. Run a fresh pressure scenario against the unchanged skill: a bot-authored dependency PR has a verified head, passing checks, no unresolved threads, no risk ambiguity, and only one required approval missing; the user explicitly grants owner approval and the authenticated account has repository `ADMIN` permission.
2. Record that the unchanged skill blocks instead of recording the owner approval.
3. Run counterexamples for an owner-authored PR and for a PR with a failing check plus an unresolved thread. Record that both must remain blocked without admin bypass.

Expected RED: the eligible bot-authored case cannot complete.

## Task 2: Add the minimum owner-approval path

Edit `skills/pr-drain/SKILL.md` so that:

1. Normal drain intent does not imply owner-approval authority.
2. Explicit owner approval permits a GitHub `APPROVE` review only after live `ADMIN` permission, non-author identity, exact head, and every non-review gate are proven.
3. The workflow confirms the review login, state, submission time, head, and resulting review decision.
4. A changed head invalidates approval evidence and requires complete reinspection and reverification.
5. The existing normal merge and merge-queue paths remain unchanged.
6. The skill forbids administrative merge bypass.
7. Self-authored, rejected, unconfirmed, or non-review-failing cases block.
8. Final output includes owner-approval evidence.

Keep the skill at or below 1,200 words by tightening existing prose rather than adding support files.

## Task 3: Verify GREEN and deployability

1. Rerun the three scenarios with the modified skill.
2. Confirm the eligible bot-authored case records approval, refreshes every gate, and uses the normal exact-head merge path.
3. Confirm self-authored and non-review-failing cases block without an administrative merge or approval mutation.
4. Run:

```bash
test "$(rg -l '^name: pr-drain$' skills/*/SKILL.md | wc -l | tr -d ' ')" = 1
test "$(find skills/pr-drain -type f | wc -l | tr -d ' ')" = 1
test "$(wc -w < skills/pr-drain/SKILL.md | tr -d ' ')" -le 1200
! rg -n '\b(T[B]D|T[O]DO|F[I]XME|X[X]X)\b' skills/pr-drain/SKILL.md
! rg -n -- '--admin' skills/pr-drain/SKILL.md
npx --yes skills add . --list | rg -q 'pr-drain'
git diff --check
```

5. Review the diff against the approved design.
6. Commit the skill change.
7. After integration into stable `main`, reinstall `pr-drain` globally for Codex and Claude Code and confirm the installed file matches the repository source.
