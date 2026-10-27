---
name: handoff
description: Use when the user wants to hand the current conversation off to another agent with a compact handoff document.
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work. Save it in the repo's git-ignored scratch area (or a path listed in `.git/info/exclude`), never in /tmp, and tell the user the path.

Include a "suggested skills" section in the document, naming which skills the next agent should call the Skill tool for.

Do not duplicate content already captured in other artifacts (specs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Build the next-work list from the newest entries of the status files, not earlier lines, and confirm each open PR, issue or branch live (one `gh pr view` / `gh issue view` batch) before writing; mark each item with the time it was checked. Before listing a defect in merged code as next work, read the PR body of the change that introduced it and check later merges: record "deliberate per #N" or "still live as of <time>". Tell the receiving agent the document is a snapshot: re-check claims (worktrees, branches, open PRs, live sessions) before acting.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.
