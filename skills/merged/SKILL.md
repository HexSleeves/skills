---
name: merged
description: Use when a pull request has merged and the local repo should be cleaned up for the next piece of work, whether the user says so, runs /merged, or wait_merged.sh exits 0.
argument-hint: "PR number or URL (optional; defaults to the current branch's PR)"
---

The PR has merged. Leave the repo on an up-to-date default branch, with every finished branch and worktree gone and nothing that anyone still needs touched. This skill never merges anything: if the PR is still open, merging is the user's call, and this skill is not that call.

Other agents may share this repo, so "clean up everything" means everything that is provably finished. A branch or worktree that might still hold someone's work stays, and the report says why. A worktree a thread is bound to is still in use: removing it kills that thread.

On Adobe repos (`github.com-adobe` remotes, or orgs such as Adobe-DesignTechnology, Adobe-Prototype, OneAdobe), every `git` command that reaches the remote (`fetch`, `pull`, `push`), every `gh` call, and every script below that calls either runs inside `~/Projects/adobe/scripts/with-adobe-route --wait -- ...`. Batch a section's commands into one `sh -c '...'` so they share one tunnel, as step 3 shows.

## Watching for the merge

After opening a PR, start the watcher with `run_in_background`, from the PR's checkout:

```bash
bash <this skill's dir>/scripts/wait_merged.sh <pr> --repo <owner/repo>
```

It only reads. It polls once a minute and exits:

- **0**, printing `MERGED #<pr> head=<branch> mergeCommit=<sha>`: run this skill from step 1 yourself, without asking. The user's merge is the go.
- **3**: the PR closed unmerged. Report it and clean nothing.
- **2** (GitHub unreachable 10 polls in a row) or **4** (still open after its timeout): start it again.

## 1. Confirm the merge

Find the PR from the argument, the conversation, the watcher's output, or the current branch:

```bash
gh pr view [<pr>] --json number,title,state,headRefName,baseRefName,mergedAt
```

If `state` is not `MERGED`, stop and say so. If the repo has no GitHub remote (`gh` fails), take the user's word for it; the script below still demands proof of the merge before anything is removed.

## 2. Classify, from where this session runs

In a T3 thread, call `t3_worktree_status` first and note this thread's `worktreePath`. Then run the script from the session's own working directory, naming the main checkout (the first entry in `git worktree list`) as its argument:

```bash
bash <this skill's dir>/scripts/classify.sh [--keep-worktree <this thread's worktreePath>] <main checkout>
```

Running it from the session's directory is what lets it keep the worktree this session runs in. It also keeps every worktree an unarchived T3 thread is bound to, read from T3's state; `--keep-worktree` adds bindings from any other harness. If it exits 3, origin is Adobe GitHub and `gh` could not reach it: rerun it inside `with-adobe-route --wait` as its message says. Its verdicts are trustworthy only when the `default` row shows `gh=1` on a GitHub repo.

It fetches with `--prune` and prints one row per branch, worktree and relevant stash, each with a verdict and a reason. Read every row before acting on any of them.

Use the script's verdicts as the whole delete list, and add nothing to it on judgment. Squash merges, which most of these repos use, leave branches that `git branch --merged` reports as unmerged, and a freshly cut branch looks merged to it. The script marks a branch `delete` only when GitHub merged that exact tip, when its tip is an ancestor of the default branch that the default has moved past, or when the branch's changes are already in the default branch and the merge left evidence (a merged PR, or an upstream the remote deleted). A branch at the default branch's exact tip stays, since it may be freshly cut for new work. A branch whose every commit only shares its subject with a commit on the default branch is marked `review`: it may have been squash- or rebase-merged under new hashes, but a matching subject is not proof, so it is never deleted. Report it under `Kept` and let the user decide. Two more cases count as finished. A sub-branch cherry-picked into a batch PR is absorbed when every one of its commits has the patch-id of a commit on a merged PR's head, and that PR's squash commit has the head's tree; one unmatched commit keeps it. A `worktree-agent-*` branch left by the Agent tool's worktree isolation is finished when it points at an ancestor of the default branch and no worktree uses it. Long-lived branches (`dev`, `develop`, `stage`, `staging`, `main`, `master`, `release/*`, and the base of any open PR) always stay. A worktree is marked `delete` only when it is clean, unlocked, and bound to no thread.

## 3. Clean up from the main checkout, in this order

Run every command from here on in the main checkout. On an Adobe repo, wrap steps 2 to 5 in one route call, so no step that reaches the remote runs bare and the whole sequence shares one tunnel:

```bash
~/Projects/adobe/scripts/with-adobe-route --wait -- sh -c '
  git switch <default> &&
  git pull --ff-only &&
  git branch -D <names> &&
  bash <skill dir>/scripts/delete_head.sh <pr> --repo <owner/repo>'
```

Leave out `git switch` when no row says `switch`, and use the `git fetch . origin/<default>:<default>` form below in place of the pull when it applies. Any step that writes to whatever the main checkout has checked out (the pull, the install) first checks `git branch --show-current` against the branch it means to update. When they differ, the checkout holds a branch the script kept, so use a form that names the target instead (`git fetch . origin/<default>:<default>` fast-forwards the default without touching the checkout and refuses anything else), or skip the step, and say in the report which step changed and why.

1. **Worktrees marked `delete`:** run `git worktree remove <path>` without `--force`. If git refuses, something changed after the scan: keep that worktree and its branch, and report it. A row saying "directory is gone" needs `git worktree prune` once instead. Rows saying "bound to a thread" stay, including this session's own worktree.
2. **A branch marked `switch`:** in the main checkout, run `git switch <default>`. If no local default branch exists, this creates it from `origin`.
3. **Pull:** in the main checkout, run `git pull --ff-only`, after noting the old tip with `git rev-parse <default>`. First check `git branch --show-current`: if the main checkout is on a branch other than `<default>` (a kept branch, with no `switch` row), a pull would merge into that branch. Run `git fetch . origin/<default>:<default>` instead; it moves only `<default>` and refuses anything but a fast-forward. If the fast-forward fails, or the script's `default` row says `local=` with commits ahead, the local default branch has commits of its own. Leave them where they are, skip the pull and section 4's dependency check (both need the new tip), and carry on with step 4. The report shows `git log --oneline origin/<default>..<default>` and asks whether to rebase those commits or move them to a branch; never reset or move the branch without that answer.
4. **Branches marked `delete` or `switch`:** run `git branch -D <name>`, copying each name exactly as the script printed it. `-D` is needed because `-d` refuses squash-merged branches; the script has already proved them finished against `origin`, so a failed pull does not change that.
5. **The merged PR's remote branch:** run `bash <this skill's dir>/scripts/delete_head.sh <pr> --repo <owner/repo>`. This skill running is the approval for this one deletion; leave every other remote branch alone. The script reads the PR's merged head and the branch's tip in one run and prints one row:
   - `deleted`: done.
   - `gone`: GitHub's auto-delete or someone else already removed it, which also counts as done. When the row carries a `restore:` command, the head was a long-lived branch (a release PR from `dev`, say) that a deploy may build from: report it and ask the user before running that command.
   - `kept`: long-lived, or in a fork. Report it.
   - `ask`: the tip moved after the merge. Ask the user before touching it.

Never drop a stash. The script lists stashes made on finished branches, and the report passes them on.

## 4. Get ready for the next piece of work

- **Dependencies:** if `git diff --name-only <old tip>..<default>` touches a lockfile (`pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`, `bun.lock`, `bun.lockb`, `Cargo.lock`, `go.sum`, `uv.lock`, `poetry.lock`, `Gemfile.lock`, `flake.lock`), run the repo's install command. Take the command from its AGENTS.md, README or task runner, or failing that from the lockfile's tool. If the main checkout is not on `<default>`, skip the install, because it would run against the branch that is checked out, and say in the report that it was skipped and why.
- **This session's leftovers for the PR:** delete the babysit ledger `$(git rev-parse --git-dir)/babysit-<pr>.json` if it exists, mark the PR merged in the repo's `STATUS.md` or the session's todo list, and close the matching work-state item.
- **Next work:** if `STATUS.md`, a handoff doc or the tracker names what comes next, name it. If nothing does, ask the user.

## 5. Report

```
Merged: #<n> <title>. <default> is at <short sha> (<k> new commits).
Removed: <worktree paths>; <branch names>; remote <headRefName>
Kept:
- <name>: <reason from the script, or what git refused>
Stashes: <refs, or none>
Next: <named next item, or the question>
```

A kept branch that the script says was built on a finished one needs the `git rebase --onto` command it printed. Give the user that command, and run it only if they ask, because another session may have that branch checked out. A worktree kept because T3 threads are bound to it goes once the user archives every thread the row names; say so in its `Kept` line. Archiving a parent thread leaves its subagent threads (reviews, no-ai-slop and comment passes) bound to the same worktree, so the row gives the count of unarchived threads bound to it, up to three titles, and their parent ids; find them with `t3_thread_list includeSubagents:true`, filtered to `parentThreadId == <parent>`.
