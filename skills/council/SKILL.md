---
name: council
description: Use when the user asks to consult the council, wants several models to sign off on a PR, branch, or plan before it merges or ships, or says to merge "once they're happy".
---

The council is three reviewers from three model families, each reading the same change in a fresh context and returning a verdict. One model's blind spot is rarely another's, so a change that all three call safe has survived three different kinds of scrutiny. The council never changes anything; you, the coordinator, own every fix and the merge.

## 1. Frame the questions

Read the change yourself first: `gh pr view <pr> --json number,title,headRefName,headRefOid,baseRefName,body` and `gh pr diff <pr>` (for a plan or branch, the document or `git diff <base>...HEAD`). Record the head SHA; every verdict is about that SHA and no other.

Write 3 to 6 questions specific to this change: where it can lose data, what happens under failure or load, what the platform limits, whether the tests prove the behaviour. "Is this safe?" alone gets three generic reviews. "Can a batch be lost with no `batch_lost` log when the Pipeline is down?" gets an answer.

## 2. Seat the council

Call `orchestrator_capabilities` and seat one member per family. Defaults:

| Seat | providerInstanceId | model | options |
|---|---|---|---|
| Opus | `claudeAgent` | `claude-opus-5-5` | `{"effort": "xhigh"}` |
| Muse | `muse` | `muse-wonder-full-1.0` | `{"reasoningEffort": "xhigh"}` |
| Sol | `cursor` | `gpt-6.1-sol` | `{"reasoning": "xhigh"}` |

If Cursor's catalog lacks `gpt-6.1-sol`, seat Sol on `codex_api_codex_api` / `gpt-6.1-sol` with `{"reasoningEffort": "xhigh"}` and say so in the convene message.

Ids drift: resolve each seat against the live catalog, and if one is missing or disabled, name it and ask the user whether to seat a substitute from another family or sit two. Never fill a seat silently, and never seat two members from one family: a council of one family is one opinion asked twice.

## 3. Convene

Snapshot the checkout before dispatch: `git rev-parse HEAD` and `git status --porcelain`. Members are read-only by instruction only (a narrower `runtimeMode` is not a read-only switch), so the snapshot is how you catch one that wrote anyway.

Dispatch all three in one turn with `delegate_task`, `mode: "async"`, `role: "review"`, title `Council: <PR #N | subject> (<Seat>)`, and `clientRequestId: council-<subject>-r<round>-<seat>`. Give every member the same brief:

```text
You are one of three independent reviewers on a council deciding whether <PR #N in owner/repo | the plan at path> is safe to <merge | ship>.
Head SHA: <sha>. Read it with `gh pr view`, `gh pr diff`, and the repo itself.

You are read-only. Do not edit files, commit, push, comment on the PR, approve, or merge. Report only.

Answer these questions:
1. <question>
...

Then anything else that would make this unsafe to merge.

Verify each finding in the code before you report it. A finding without a file:line and a concrete failure scenario is an opinion, label it as one.

End with exactly one verdict line:
VERDICT: SAFE | FIX | BLOCK
SAFE = merge as is. FIX = merge after the listed fixes. BLOCK = the approach is wrong, not just the code.
Under it, list each finding as: [severity] file:line, what fails, under what input or state.
```

Then tell the user in a few lines what the council is reviewing, who sits on it, and the questions, and end the turn. Completion notifications wake you; do not poll.

## 4. Weigh the verdicts

When all three have reported, re-run the snapshot. A changed HEAD or status that you did not make means a member wrote: stop and show the user the difference before anything else.

Check every finding against the code yourself before acting on it or relaying it. A member's confidence is not evidence, and a finding raised by one member is not outvoted by two SAFE verdicts: settle it on the code. Sort each into confirmed, refuted (say why), or out of scope for this change (say where it belongs).

Report to the user: one line per member with verdict and headline finding, then the confirmed findings, then what you refuted.

## 5. Fix and reconvene

If any member returned FIX or BLOCK on a confirmed finding:

- **BLOCK** means the approach is in question. Stop and bring it to the user; do not redesign on the council's say-so.
- **FIX**: change only what the confirmed findings need, run the repo's verification, and push through the repo's normal pre-push rules. The council does not exempt the change from them.

Then reconvene every member, not just the dissenters, because the fix changed the code they all approved. Each round is a new `delegate_task` call with a new `clientRequestId`. Its brief carries the original brief, the new head SHA, every prior finding, your response to each (fixed at commit X, or refuted because Y), and any objection still open. Never continue a round through `t3_thread_send` on a member's child thread.

After 3 rounds without unanimous SAFE, stop and hand the open disagreement to the user.

## 6. Merge

Merge only when all of these hold:

- Every seated member returned SAFE in the same round, on the head SHA that is still the PR's head.
- Required checks are green on that SHA.
- The user gave merge authority in this session ("merge it once they're happy" counts; "consult the council" alone does not). Without it, report the unanimous SAFE and ask.

Merge with `gh pr merge <pr> --match-head-commit <sha>` and the repo's usual method, where `<sha>` is the head SHA you put in the approving round's brief, copied from that brief rather than typed. A push that lands after the verdict then fails the merge instead of riding through on stale approval. Confirm `state` is `MERGED` afterwards, then offer `/merged` for cleanup.

For a plan or decision rather than a PR, stop after step 4 or 5: the unanimous verdict is the deliverable.
