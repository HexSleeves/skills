---
name: leaving-pr-comments
description: Use when posting any comment, review reply, or dismissal reason on GitHub on the user's behalf.
metadata:
  upstream: t3dotgg/tstack
---

# Leaving PR Comments

Every agent-authored comment opens with this GitHub note callout:

```md
> [!NOTE]
> 🤖 **<model> responding on behalf of <user>**

Actual comment starts here.
```

- `<model>` is the public model name the harness reports (for example `Claude Opus 5.5`). If it reports none, use the harness name.
- `<user>` is the user's GitHub login, read from `gh api user -q .login`.

When the posting path adds the callout itself (resolve-pr-comments' `post_replies.sh` reads the batch's `attribution` field), set it there and write each body without the callout.

The callout covers top-level PR comments, inline review comments, replies to bots and reviewers, and the reason posted before resolving or dismissing feedback. PR descriptions, commit messages, and text the user asked to post verbatim go out without it.

Keep the attribution inside the note and the reply outside it, with the robot emoji opening the context line. The note is the comment's only attribution: end the comment on its last sentence.

Write the comment itself in a direct style:

- Lead with the conclusion.
- Cite the relevant code, behavior, check, or reproduction.
- Separate verified facts from judgment.

Before posting, check the whole comment, quoted text and attachments included, for secrets and private details. After posting, confirm GitHub returned the comment or review URL. Resolve a review thread only after its reply posted.
