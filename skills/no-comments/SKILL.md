---
name: no-comments
description: "Review scoped comments, fix accepted findings, and offer enforceable encodings for claimed constraints."
disable-model-invocation: true
---

# No comments

Review comments with a skeptical fresh perspective, then act only on accepted findings.

## Scope

Use the caller's files or diff. Otherwise use the current diff against the base branch,
default `main`, including the working tree. Do not expand beyond that fence.

## Review capability

Check available capabilities before naming an agent or skill.

- If `Comment Sicko` is available, ask it to review the exact scope.
- If it is unavailable, perform a concise direct review of the same scope. The review must
  not fail because a named subagent is missing.
- If `/how`, `/why`, `/architect`, or a `principle-*` skill is unavailable, inspect the
  relevant symbol and surrounding code directly. Record the fallback instead of widening
  scope or inventing a capability.

## Steps

1. Review comments, lint suppressions, and TypeScript suppressions in scope. Treat
   correctness and safety suppressions as actionable unless the surrounding code proves
   they remain necessary.
2. Vet each finding against the code. Reject application edits, scope escapes, protected
   constraint changes, incorrect reasons, and findings that blame intentional code. If a
   finding remains ambiguous, preserve the comment and report the uncertainty.
3. Fix accepted findings with the smallest justified in-scope code change. Delete a comment
   only after that change, or a replacement encoding, makes the comment obsolete. Do not
   remove comments merely to reduce the comment count.
4. For a constraint comment such as `do not remove`, `do not change wording`, or
   `talk to X before changing`, identify the cheapest in-scope type, runtime check, test, or
   CI lint that could enforce it. Honor any protected wording or approval requirement.
5. Wait for approval before encoding a protected constraint. When approval is absent,
   approval is refused, or the finding remains ambiguous, preserve the comment and report
   the constraint as unresolved. Unattended work requires caller pre-approval.
6. After an approved encoding or another justified in-scope replacement lands, verify it,
   then delete only the now-redundant comment. If the root cause is out of scope, leave the
   comment in place and report the open work.
7. Report deleted comments, preserved or restored comments, review fallbacks, reruns,
   accepted fixes, encoding offers, approved encodings, unenforced constraints, and other
   open work.
