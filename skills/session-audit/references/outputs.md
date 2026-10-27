# session_audit.py outputs

What each file in `$OUT` holds, how its numbers are made, and what it cannot see. Every string copied from a transcript has passed the script's `mask()`; the file lists only counts, lengths, ids and masked text.

## Friction cut

- `digests/<start-date>_<project>_<sid8>.md`, one per main session with at least one user turn:
  - header: project, cwd, time span, `cost_usd` (last `cost-state` record), user prompts, tool calls, tool errors, denials/hook refusals (error text mentions denied, hook or refus), interrupts, compactions, top 8 tools;
  - every user turn, clipped to 900 chars (400 for slash-command turns, 160 for continuation, handoff, restart and attachment notices), each after the last assistant text before it (280 chars);
  - up to 40 tool errors: tool name with its masked input (160 chars), error class, and the first line of the masked error (200 chars).
  System reminders, `isMeta` turns, local-command echoes and sidechain records are skipped.
- `index.tsv`: one row per digest (start, project, sid prefix, prompts, tools, errors, denials, interrupts, compactions, cost), sorted by start.
- `stats.md`: per-project totals, slash-command counts, short replies of 12 chars or fewer (approvals and picks), continuity notices (compaction continuations, context handoffs, harness-restart notices), and tool errors by tool and by class. Error counts are sampled: at most 40 per session.
- `bundles/bundle-N.md`: digests concatenated in filename (date) order, each bundle up to `--size` bytes (default 650,000, sized for one reader's context). A single digest larger than the limit gets a bundle to itself.

## Usage cut

- `mains.json` / `subs.json`: per transcript, token totals deduplicated by `message.id` (usage repeats on every streamed chunk of one message), models, tool counts, first and last timestamp, final-text length, and for mains the delegation calls (Agent, Task, Workflow, SendMessage and thread-launch tools: type, model override, background flag, masked description, prompt length). Subagent records carry their `.meta.json` fields (agentType, masked description, spawnDepth, worktree, requestShape, model, workflowPhase), the brief length and whether it was a Workflow agent.
- `usage.md`:
  - weighted token share, main vs subagents, in input-equivalent tokens: uncached input ×1, cache write ×1.25, cache read ×0.1, output ×5. These are relative weights for a share, not a bill; `cost_usd` in `index.tsv` is the billed figure.
  - delegation calls by tool, `subagent_type`, model overrides, agents per session;
  - per agentType: count, token share, median tool calls, median result length;
  - purpose buckets: a keyword match over description and agentType (first match wins, in the order of `PURPOSES` in the script), so treat a bucket as approximate and spot-check it against `subs.json`;
  - spawn depth, worktree use, brief and result lengths;
  - repeat passes: the same agentType or purpose run several times in one session (a review gate looping shows here);
  - subagents with 2 or fewer tool calls, which are candidates to fold back into the main loop.
- `skills.md`: Skill-tool calls and slash commands, each with call and session counts (main transcripts only).
- `mcp.md`: MCP tool calls per server with session counts, over main and subagent transcripts.
- `user_turns.txt`: user turns of 1,500 chars or fewer matching `--pattern` (default: delegation words such as subagent, fork, delegate, in parallel, handoff, context, thread), one per line with date, project and sid prefix, masked, clipped to 400 chars.

## Limits for "Method and limits"

- Only transcripts under `--root` on this machine: sessions on other machines and other agent CLIs are absent.
- The digests skip subagent transcripts; the usage cut reads them.
- Tool errors are capped at 40 per session in the digests and in `stats.md`.
- Masking is pattern-based: it catches the common shapes and over-masks some plain values; it cannot recognise a secret with no recognisable shape.
- The current session is excluded only when its id was passed with `--exclude`.
