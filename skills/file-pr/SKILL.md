---
name: file-pr
description: Use when the user asks to file, open, or create a PR, or when another skill files one.
metadata:
  upstream: t3dotgg/tstack
  credits:
    body-template: "pr skill, mattpocock/skills, after Dex Horthy's show-me (humanlayer/skills)"
---

# File PR

Before filing, check whether a PR for this branch already exists. Review the
diff locally against the base branch (usually `origin/main`) to make sure its
contents match the goal.

## Title

PR titles usually become commit messages, so follow the repository's title
conventions. Look at recently merged PRs and Git history for examples. Prefer a
concise, human-readable title that explains why the change matters:

BAD

> ❌ perf(server): negotiate permessage-deflate on the websocket

GOOD

> ✅ perf(server): cut websocket frame size by 70%+ with gzipping

## Body

Open with a simple explanation of the problem based on the user's original
prompt, then briefly explain the solution. Do not lead with an implementation
inventory:

BAD

> ❌ Removed implicit workspace carry-over from every "new thread" entry point (cmd+n / cmd+shift+o, sidebar v1/v2 buttons, command palette). New threads inherit only the project from context; branch, worktree, and env mode always come from the configured defaults. Deleted buildContextualThreadOptions, startNewThreadInProjectFromContext, and the v1 sidebar's seed-context machinery.

GOOD

> ✅ My "new worktree" default was ignored when starting new threads on existing worktrees. Super unintuitive. Now your preferences always apply.

After that opening, use these sections. Skip any that would be empty, and keep
prose brief. Use the domain language from the repo's `GLOSSARY.md` when it has
one.

```markdown
## Summary

<one small diagram, diff-sketch, or tree>

## Evidence

- **Before:** <screenshot/output/failing test run>
  **After:** <screenshot/output/passing test run>

## Merge Danger

**Door:** <one-way or two-way>
**Blast Radius:** <one word>, <optional: what could break>
```

- **Summary:** pick the smallest view that makes the point: pseudocode for
  logic, a call tree for control flow, a component tree for UI, a shallow file
  tree for a refactor, Mermaid for interaction between parts, or a `diff`
  sketch of that shape when the point is what changed. One view is usually
  enough.
- **Evidence:** a before and after you observed. Screenshots for visual
  changes, otherwise the exact test or command output that failed and now
  passes.
- **Merge Danger:** a two-way door is cheap to roll back; destructive or
  hard-to-reverse changes are one-way. Blast radius is who or what breaks if
  it is wrong: consumers, layout, mobile, data.

End the body with the attribution lines the harness gives for pull requests.
When it gives none, add `Created with <model> in <harness>.` using the model
name the harness reports, including subagent models that wrote part of the
change. If model identity is unavailable, name the harness without guessing.

Before submission, check the title, body, quotes, and attachments for secrets
and private details.

## Opening it

Open a real PR rather than a draft so review bots run, with an explicit
`--base`. If `gh pr create` fails because the GraphQL rate limit is used up,
open it through REST with
`gh api repos/<owner>/<repo>/pulls -f title=... -f head=... -f base=... -F body=@<file>`.
If the user also asked to babysit it, continue with the `babysit` skill.

Do not post a follow-up PR comment unless it serves the user's request. When a
comment is needed, use the `leaving-pr-comments` skill.
