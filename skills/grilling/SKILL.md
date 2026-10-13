---
name: "grilling"
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

## Facts, defaults and decisions

Finding _facts_ is your job. When a question needs a fact from the environment (code, files, docs, tools), look it up instead of asking; dispatch a sub-agent for anything slow. When the fact is what exists in a repo, state it from `origin/<default>` after a fetch, not from the working tree: a local checkout is a cache, and an unfetched one silently describes already-merged work as missing. This covers each option's premises too: before you present options, list the facts each one depends on (formats, paths, limits, permissions of the systems it touches) and look them up. An option whose premise is unverified says so in its body, and your recommendation may not rest on it. A running lookup blocks only the questions downstream of it: keep asking the rest of the frontier while it runs. It blocks claims too: until it reports, state only what has returned, and label any inference about the unexplored system as a guess.

_Direction decisions_ (what, for whom, which first) are the user's. Put each one to them and wait, however obvious your recommendation looks.

_Defaults_ are implementation choices with a defensible default: a recommendation the user would accept unread. State each in one line, keep going, and let the user object. Before asking whether to prototype, check whether an existing artifact (a dashboard, script, or mock the work builds on) already answers the design question; if it does, that artifact is the prototype.

When the plan orders work taken from a stakeholder's document, challenge the order first: state the document's central claim in one sentence and rank each slice by how directly it delivers that claim. "Unblocked" only breaks ties.

## Done

The session is done when the frontier is empty: every branch visited, nothing silently assumed. Then list the settled decisions and stated defaults and ask the user to confirm that list is the shared understanding. Act on it only after they confirm.
