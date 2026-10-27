---
name: "grilling"
description: Use when the user wants a plan, decision, or idea stress-tested before acting on it, or uses any 'grill' trigger phrase.
---

Interview the user relentlessly about every aspect of the subject until you reach a shared understanding. Model it as a **design tree**: every decision branches into the decisions that hang off it.

## The frontier

The **frontier** is every open decision whose prerequisites are settled: the questions you can ask now without guessing at answers you haven't heard. Each answer reshapes the tree. It settles a node, unblocks the decisions below it, and can reopen an earlier branch it contradicts. Recompute the frontier after every answer; it is never a pre-written list.

## Asking

Ask **one question at a time** while the answers keep changing the design, then wait for the answer. Pick the frontier decision whose answer unblocks the most of the tree. After two answers in a row that take your recommendation, or once what is left is lower-stakes or independent (placement, naming, dates, ADR form), send the rest of the frontier as one numbered batch, each with a recommended default, and ask for "rest approved" or exceptions. Batch only what the user would approve unread. A batched default is approved unread, so each premise it names (path, namespace, auth, limit) carries a file:line before it enters the batch. A default of the form "covered by existing X", or any concurrency or race default, also carries the interleaving as numbered steps (who reads what, when) and names the value that carries state across those steps, with the file:line where that value is read. A race default that cannot name that value does not enter a batch and goes out as its own question. A question that reverses a recorded decision, creates an ADR, or offers more than two options stays one at a time, however many recommendations they have taken: quick acceptance shows trust in the recommendations, not spare attention.

Format each question like so:

```
❓ **Q<n>** - **<question title>** (<k> more on the frontier)

<question body, might be multiple paragraphs, including the choices>

➡️ <your recommended answer, and why>
```

Word the recommendation as an answer to the question as asked, so agreeing with it means saying yes.

When an option is named by a label from earlier work (a prototype variant, another ticket's decision, a codename), the question body shows what it is: the artifact itself where one exists (an image path or link), otherwise one plain sentence. Never assume the user remembers a label across sessions.

When the user asks for rounds, ask the whole frontier at once instead: number every question in the format above, separate them with `---`, and keep any question that depends on another one in the same round for the next round.

## Facts, defaults and decisions

Finding _facts_ is your job. When a question needs a fact from the environment (code, files, docs, tools), look it up instead of asking; dispatch a sub-agent for anything slow. When the fact is what exists in a repo, state it from `origin/<default>` after a fetch, not from the working tree: a local checkout is a cache, and an unfetched one silently describes already-merged work as missing. This covers each option's premises too: before you present options, list the facts each one depends on (formats, paths, limits, permissions of the systems it touches) and look them up. An option whose premise is unverified says so in its body, and your recommendation may not rest on it. A name is not a premise: a table, function or role name says what its author meant, so open the code that reads the data before relying on it, and give each premise a file:line. A default that carries numbers from another codebase or an earlier design is checked against the target's own scale (the values it compares against and the modifiers that scale them), and the option shows the comparison ("a hit of 6 or more; hits here do 3 to 6"). When review rounds on a glossary, spec or ADR built from these answers each find one new factual error, stop reviewing and run one fact-check pass that reads the code paths the design runs through. A running lookup blocks only the questions downstream of it: keep asking the rest of the frontier while it runs. It blocks claims too: until it reports, state only what has returned, and label any inference about the unexplored system as a guess.

_Direction decisions_ (what, for whom, which first) are the user's. Put each one to them and wait, however obvious your recommendation looks.

_Defaults_ are implementation choices with a defensible default: a recommendation the user would accept unread. State each in one line, keep going, and let the user object. Before asking whether to prototype, check whether an existing artifact (a dashboard, script, or mock the work builds on) already answers the design question; if it does, that artifact is the prototype.

When the plan orders work taken from a stakeholder's document, challenge the order first: state the document's central claim in one sentence and rank each slice by how directly it delivers that claim. "Unblocked" only breaks ties.

## Done

The session is done when the frontier is empty: every branch visited, nothing silently assumed. Then list the settled decisions and stated defaults and ask the user to confirm that list is the shared understanding. Act on it only after they confirm.
