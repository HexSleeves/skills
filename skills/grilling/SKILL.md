---
name: grilling
description: Use when the user wants a plan, decision, or idea stress-tested before acting on it, or uses any 'grill' trigger phrase.
---

Interview the user relentlessly about every aspect of the subject until you reach a shared understanding. Model it as a **design tree**: every decision branches into the decisions that hang off it.

## The frontier

The **frontier** is every open decision whose prerequisites are settled: the questions you can ask now without guessing at answers you haven't heard. Each answer reshapes the tree. It settles a node, unblocks the decisions below it, and can reopen an earlier branch it contradicts. Recompute the frontier after every answer; it is never a pre-written list.

## Asking

Ask **one question at a time**, then wait for the answer. Pick the frontier decision whose answer unblocks the most of the tree. Several questions at once is bewildering.

Format each question like so:

```
❓ **Q<n>** - **<question title>** (<k> more on the frontier)

<question body, might be multiple paragraphs, including the choices>

➡️ <your recommended answer, and why>
```

Word the recommendation as an answer to the question as asked, so agreeing with it means saying yes.

When the user asks for rounds, ask the whole frontier at once instead: number every question in the format above, separate them with `---`, and keep any question that depends on another one in the same round for the next round.

## Facts and decisions

Finding _facts_ is your job. When a question needs a fact from the environment (code, files, docs, tools), look it up instead of asking; dispatch a sub-agent for anything slow. A running lookup blocks only the questions downstream of it: keep asking the rest of the frontier while it runs.

The _decisions_ are the user's. Put each one to them and wait, however obvious your recommendation looks.

## Done

The session is done when the frontier is empty: every branch visited, nothing silently assumed. Then list the settled decisions and ask the user to confirm that list is the shared understanding. Act on it only after they confirm.
