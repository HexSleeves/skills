---
name: stop-slop
description: Remove common AI writing habits from prose while preserving facts, quotations, technical precision, and the user's voice.
metadata:
  trigger: Writing or editing prose deliverables such as docs, ADRs, PR descriptions, and release notes
  author: Hardik Pandya (https://hvpandya.com), vendored from github.com/hardikpandya/stop-slop
---

# Stop Slop

Use these patterns as clarity heuristics, not grammar laws. Revise only when a change makes the
text clearer without changing meaning, technical precision, quoted material, or the user's voice.

## Scope

Apply this guidance to prose you are authoring for a human reader, including READMEs, ADRs, specs,
PR descriptions, commit bodies, release notes, and long explanations.

Do not apply it mechanically to:

- code, identifiers, configuration, or logs;
- text the user wrote unless they asked for a rewrite;
- quotations, citations, error messages, and API or CLI output;
- fixed-format text whose convention requires a specific shape.

Accuracy wins. Keep a deliberate repetition, parallel structure, passive construction, adverb, or
technical term when it carries meaning or matches the author's voice.

## Clarity heuristics

1. **Cut filler that adds no meaning.** Scrutinize throat-clearing openers, emphasis crutches,
   redundant hedges, and promotional jargon. See
   [references/phrases.md](references/phrases.md).
2. **Avoid formulaic structures when they add drama instead of clarity.** Binary contrasts,
   rhetorical setups, negative listing, and punchy fragments can be useful, but repeated templates
   often flatten the prose. See [references/structures.md](references/structures.md).
3. **Prefer active voice when the actor matters.** Passive voice is appropriate when the actor is
   unknown, irrelevant, intentionally omitted, or conventional in the technical context.
4. **Be specific.** Replace vague claims and unsupported extremes with the concrete fact, actor,
   condition, or consequence.
5. **Respect viewpoint and user voice.** Use "you" only when the text addresses the reader. Do not
   force a conversational viewpoint into neutral documentation.
6. **Vary rhythm when repetition becomes distracting.** Keep a three-item list when there are three
   real items. Preserve sentence structure when consistency helps scanning.
7. **Keep necessary qualifiers.** Adverbs and hedges can express frequency, confidence, timing, or
   scope. Remove them only when they are empty emphasis.
8. **Keep grammar subordinate to meaning.** A sentence may start with a question word, use an
   inanimate subject, or end in a short line when that wording is accurate and natural.

## Quick review

Before delivering prose, ask:

- Does an opener delay the point?
- Does a modifier change meaning, confidence, timing, or scope? Keep it if it does.
- Would naming the actor improve this sentence, or is passive voice more accurate here?
- Does a repeated template sound mechanical?
- Is a vague claim hiding the concrete implication?
- Did the edit preserve facts, quotations, technical terms, and the user's voice?
- Did the edit introduce a broader claim than the evidence supports?

## Examples

See [references/examples.md](references/examples.md) for before and after transformations. Treat
them as examples, not mandatory rewrites.

## License

MIT. Rules and references by Hardik Pandya; the Scope section is a local addition.
