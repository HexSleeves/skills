---
name: lavish
description: Build a local HTML review surface when the user asks to annotate a visual artifact or use an interactive browser feedback loop through lavish-axi.
license: MIT
metadata:
  author: Kun Chen (kunchenguid)
  argument-hint: <what the review surface should show>
  hermes-tags: html, review, annotations
  hermes-category: productivity
---

# Lavish Editor

Use Lavish when the user wants an HTML artifact they can annotate and return through an
interactive review loop. For a lightweight visual explanation without annotations, use
`show-me` instead. Ordinary local review does not require publishing or sharing the artifact.

## Request

$ARGUMENTS

If the request is non-empty, build the requested review surface. If it is empty, use Lavish only
when the conversation clearly asks for annotation or an interactive review session.

## Tool boundary

Prefer an already installed `lavish-axi` binary or local package. If none is available, ask for
explicit approval before downloading or installing it. After approval, `npx -y lavish-axi` may be
used for that approved run. Do not silently install a package.

If a restricted harness cannot run the package, use an already installed local or global module
only when its path is known and inspectable:

```bash
node "$(npm root)/lavish-axi/dist/cli.mjs" <html-file>
node "$(npm root -g)/lavish-axi/dist/cli.mjs" <html-file>
```

## Workflow

1. Create the HTML artifact under `.lavish/<name>.html` unless the user chose another location.
2. Open or resume the local review session:

   ```bash
   lavish-axi <html-file>
   ```

   Use `npx -y lavish-axi` only after the install or download approval above. If the command
   reports `self_paint_warning`, fix the unpainted page surface before polling.
3. **Default to a bounded one-shot review.** Poll for one feedback response, apply that one batch,
   end the session, and stop. If the poll times out or is interrupted, stop cleanly and tell the
   user how to resume. Do not start another poll automatically.

   ```bash
   lavish-axi poll <html-file> --agent-reply "<what to review first>"
   ```

4. Use persistent polling only when the user asks for an ongoing annotation loop. In that mode,
   poll again after each applied batch until the user selects `Send & End` or asks to stop.
5. Treat `layout-warnings` as actionable only after the user queues them. Apply a queued batch in
   one pass. `artifact_failures` may be handled without a separate annotation because the review
   surface is unusable.
6. A `whiteboard` feedback prompt carries a bounded edit summary plus local `scenePath`
   (`.excalidraw` JSON) and `previewPath` (PNG) files. Read the summary first and open those files
   only when needed. Apply requested changes by updating the Mermaid source in the HTML artifact.
   Never write the Excalidraw scene back.
7. End the session after the one-shot batch or when ongoing review finishes:

   ```bash
   lavish-axi end <html-file>
   ```

   Do not reopen a user-ended session unless the user asks.

Keep a foreground poll when practical. A background poll is allowed only through a harness-native
tracked job that will notify the same agent. Do not use `nohup`, shell `&`, `disown`, or an
untracked detached terminal.

## Visual guidance

- Make decisions, risks, tradeoffs, and next actions easy to scan.
- Use sections, cards, tables, diagrams, annotated snippets, and comparisons when they clarify the
  review target.
- Prevent horizontal overflow. Give nested grid and flex children `min-width: 0`, use
  `minmax(0, 1fr)`, and wrap or contain long strings.
- When the artifact describes an existing interface, prefer a real read-only screenshot over a
  prose reconstruction.
- Match the named design system. Otherwise inspect the subject project's styles and tokens. Use a
  generic Lavish design only when neither source exists.

Use the matching local playbooks before writing an artifact that needs them:

- `diagram` for relationships, flow, state, or architecture
- `table` for dense records
- `comparison` for alternatives and tradeoffs
- `plan` for an implementation plan
- `code` for source, patches, or diffs
- `input` for structured user decisions
- `slides` when the user requested slides

```bash
lavish-axi playbook <id>
lavish-axi design
```

## Local files, export, and sharing

Lavish serves the HTML through a local server. Put local assets beside the HTML and reference them
with relative paths. A local export stays on the machine:

```bash
lavish-axi export <html-file> --out <path>
```

`lavish-axi share` uploads the artifact to the third-party service `ht-ml.app`. Get explicit
approval immediately before every third-party upload, including a password-protected share. Explain
that public shares are link-accessible and that protected shares still leave the machine. Never
infer upload approval from a request for local review, export, or password protection.

After approval, run only the approved share shape:

```bash
lavish-axi share <html-file>
lavish-axi share <html-file> --password <password>
```

Use `lavish-axi stop` to stop the local server when requested or after all review sessions end.
