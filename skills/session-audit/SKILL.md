---
name: session-audit
description: "Use when the user asks to audit or find patterns in their own past agent sessions or transcripts (\"audit my sessions\", \"what did I do across sessions\", \"find patterns in my transcripts\", how they use subagents, skills or MCP tools), or a research skill is invoked on a question whose evidence is their local session history. Not for web research."
---

# Session audit

Answer questions about the user's own work from their local Claude Code transcripts (`~/.claude/projects/<project>/<session>.jsonl`, subagents under `<session>/subagents/`). Raw transcripts are gigabytes of JSON and full of secrets, so the bundled script reduces them to masked digests and counts first; readers and the synthesis work from those, and every count in the report is re-checked against them.

The evidence is local. When a research or deep-research skill was invoked on such a question, say that its web fan-out would answer a question about the world, not about the user's history, and run this skill instead. Web search adds nothing here.

`$SKILL_DIR` below is the directory holding this file.

## Privacy

Transcripts hold pasted tokens, env values and tool output. These rules bind every step, every subagent brief and the final reply:

- All output goes to one `mktemp -d` directory under `/var/tmp`, outside any checkout. The script refuses a directory inside a git work tree, and one an earlier run already filled.
- Quote only user turns, as masked in the digests. Describe a tool error by tool name and error class. Tool output, command lines, tool inputs and env values stay out of the report and the chat.
- Read transcripts only through the script. To find a file, use `grep -l` or `ls`, which print paths, never matching lines.

## 1. Scope

Settle three things with the user, recommending a default for each:

- **Projects**: a glob over the directory names in `~/.claude/projects` (`--projects='*acme*'`; the home-directory prefix may be left off; keep the `=`, since the full names start with `-`). Default `*`.
- **Dates**: `--since` / `--until` (`YYYY-MM-DD`, by session start). Default: all.
- **Cut**: *friction* (where the user had to step in, wait, repeat or recover, and what to fix) or *usage* (delegation, subagent token share, skill, slash-command and MCP use, user turns on a theme). Both is fine.

Then find the current session, so the audit leaves out the session doing it. List the newest transcripts and pick the one holding a distinctive phrase of the user's request:

```sh
ls -t ~/.claude/projects/*/*.jsonl | head -5
grep -l -F 'distinctive phrase from the request' $(ls -t ~/.claude/projects/*/*.jsonl | head -5)
```

Its file name without `.jsonl` is the session id; pass it as `--exclude <id>` to every subcommand below. Run as a subagent, this finds the parent session, which is the right one to leave out. Done when the glob, the dates, the cut and the excluded id are fixed.

## 2. Extract

```sh
mktemp -d /var/tmp/session-audit-XXXXXX
```

Use the printed path as `$OUT` in every command below, written out literally: shell variables do not survive between tool calls. Each subcommand runs as

```sh
python3 -I "$SKILL_DIR/scripts/session_audit.py" <subcommand> --out "$OUT" --projects='<glob>' --since <date> --until <date> --exclude <id>
```

leaving out the scope flags not in use. It prints one line of counts. On a corpus of gigabytes, run them in the background.

- Friction: `extract`, then `stats`, then `bundle`. Note `bundles=N`.
- Usage: `usage`, `skills`, `mcp`, and `user-turns --pattern '<regex>'` when the question is about a theme in what the user said (the default pattern matches delegation talk).

Done when every subcommand exited 0 and its count line is plausible: `digests` close to `transcripts` (sessions without a user turn drop out), `subs` nonzero when the user delegates. Read [`references/outputs.md`](references/outputs.md) before interpreting any output file or writing the method section.

## 3a. Read, friction cut

With a Workflow tool, run `$SKILL_DIR/scripts/workflow.js` with `args`:

```json
{"dir": "<$OUT>", "bundles": N, "question": "<the user's question>",
 "context": "<two lines on who the user is and how they work, from their CLAUDE.md or AGENTS.md>",
 "controls": ["<observation or retro log dir>", "<CLAUDE.md>", "<hooks dir>"]}
```

`controls` is optional: list what the user already records and enforces (notes on past friction, instruction files, hook scripts), so fixes do not duplicate them.

Without a Workflow tool, dispatch the same work by hand from the prompts and schema in `workflow.js`: one subagent per bundle with `readerPrompt(i)` and the `THEMES` schema, one with `controlsPrompt` when there are controls, then one with the synthesis prompt over their JSON. Done when every bundle has a reader result, or the gaps are named in the report.

## 3b. Read, usage cut

Read `usage.md`, `skills.md`, `mcp.md` and `user_turns.txt` in full, and answer the user's question from them; when it compares against a text (an article, a rule), take each of its claims and say what the numbers show. Pull a figure the summaries lack from `mains.json` / `subs.json` with a short script in a scratch dir, printing counts only.

## 4. Report

Write `$OUT/report.md` (the synthesis result, for the friction cut): one-line bottom line, ranked findings with bold lead-ins, each carrying its number and the command that produced it, structural fixes before new rules, then **Method and limits** (scope, excluded session, and the limits in `references/outputs.md`).

Before delivering, run the pre-flight:

1. `python3 -I "$SKILL_DIR/scripts/session_audit.py" scan "$OUT/report.md"` exits 0. A hit is masked or paraphrased in the report, then scanned again.
2. Every number in the report traces to a command over `$OUT`; one that does not is re-counted or dropped.
3. Every quote is a user turn; tool output, command lines and env values are absent.
4. The current session id is in the method section as excluded.

Reply with the bottom line, the top findings and the path to `$OUT/report.md`, under the same privacy rules. `$OUT` stays under `/var/tmp` until the user deletes it.
