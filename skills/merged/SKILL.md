---
name: merged
description: Use when the user runs /merged to say a pull request has merged and the local repo should be cleaned up for the next piece of work.
argument-hint: "PR number or URL (optional; defaults to the current branch's PR)"
disable-model-invocation: true
---

The user has merged a PR. Leave the repo on an up-to-date default branch, with every finished branch and worktree gone and nothing that anyone still needs touched. This skill never merges anything: if the PR is still open, merging is the user's call, and `/merged` is not that call.

Other agents may share this repo, so "clean up everything" means everything that is provably finished. A branch or worktree that might still hold someone's work stays, and the report says why.

## 1. Confirm the merge

Find the PR from the argument, the conversation, or the current branch:

```bash
gh pr view [<pr>] --json number,title,state,headRefName,baseRefName,mergedAt
```

If `state` is not `MERGED`, stop and say so. If the repo has no GitHub remote (`gh` fails), take the user's word for it; the script below still demands proof of the merge before anything is removed.

## 2. Leave the worktree first

Run every later command from the main checkout, the first entry in `git worktree list`. If the shell is still inside a worktree when that worktree is removed, the shell's working directory disappears.

Any step that writes to whatever the main checkout has checked out (the pull, the install) first checks `git branch --show-current` against the branch it means to update. When they differ, the checkout holds a branch the script kept, so use a form that names the target instead (`git fetch . origin/<default>:<default>` fast-forwards the default without touching the checkout and refuses anything else), or skip the step, and say in the report which step changed and why.

## 3. Classify

```bash
bash <this skill's dir>/scripts/classify.sh <main checkout>
```

It fetches with `--prune` and prints one row per branch, worktree and relevant stash, each with a verdict and a reason. Read every row before acting on any of them.

Use the script's verdicts as the whole delete list, and add nothing to it on judgment. Squash merges, which most of these repos use, leave branches that `git branch --merged` reports as unmerged, and a freshly cut branch looks merged to it. The script marks a branch `delete` only when GitHub merged that exact tip, or when the branch's changes are already in the default branch and the merge left evidence (a merged PR, or an upstream the remote deleted). A worktree is marked `delete` only when it is clean and unlocked.

## 4. Clean up, in this order

1. **Worktrees marked `delete`:** run `git worktree remove <path>` without `--force`. If git refuses, something changed after the scan: keep that worktree and its branch, and report it. A row saying "directory is gone" needs `git worktree prune` once instead.
2. **A branch marked `switch`:** in the main checkout, run `git switch <default>`. If no local default branch exists, this creates it from `origin`.
3. **Pull:** in the main checkout, run `git pull --ff-only`, after noting the old tip with `git rev-parse <default>`. First check `git branch --show-current`: if the main checkout is on a branch other than `<default>` (a kept branch, with no `switch` row), a pull would merge into that branch. Run `git fetch . origin/<default>:<default>` instead; it moves only `<default>` and refuses anything but a fast-forward. If the fast-forward fails, or the script's `default` row says `local=` with commits ahead, the local default branch has commits of its own. Leave them where they are, skip the pull and step 5's dependency check (both need the new tip), and carry on with step 4. The report shows `git log --oneline origin/<default>..<default>` and asks whether to rebase those commits or move them to a branch; never reset or move the branch without that answer.
4. **Branches marked `delete` or `switch`:** run `git branch -D <name>`, copying each name exactly as the script printed it. `-D` is needed because `-d` refuses squash-merged branches; the script has already proved them finished against `origin`, so a failed pull does not change that.
5. **The merged PR's remote branch:** read its tip and the PR's merged head in one command (`gh api repos/<o>/<r>/git/ref/heads/<headRefName> -q .object.sha` and `gh pr view <n> -R <o>/<r> --json headRefOid -q .headRefOid`). When they match, delete it with `gh api -X DELETE repos/<o>/<r>/git/refs/heads/<headRefName>`; running /merged is the approval for this one deletion. On Adobe repos run it through `with-adobe-route`, whose merged-branch guard refuses `git push --delete`. When the tip has moved since the merge, ask first. Leave every other remote branch alone.

Never drop a stash. The script lists stashes made on finished branches, and the report passes them on.

## 5. Get ready for the next piece of work

- **Dependencies:** if `git diff --name-only <old tip>..<default>` touches a lockfile (`pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`, `bun.lock`, `bun.lockb`, `Cargo.lock`, `go.sum`, `uv.lock`, `poetry.lock`, `Gemfile.lock`, `flake.lock`), run the repo's install command. Take the command from its AGENTS.md, README or task runner, or failing that from the lockfile's tool. If the main checkout is not on `<default>`, skip the install, because it would run against the branch that is checked out, and say in the report that it was skipped and why.
- **This session's leftovers for the PR:** delete the babysit ledger `$(git rev-parse --git-dir)/babysit-<pr>.json` if it exists, mark the PR merged in the repo's `STATUS.md` or the session's todo list, and close the matching work-state item.
- **Next work:** if `STATUS.md`, a handoff doc or the tracker names what comes next, name it. If nothing does, ask the user.

## 6. Report

```
Merged: #<n> <title>. <default> is at <short sha> (<k> new commits).
Removed: <worktree paths>; <branch names>; remote <headRefName>
Kept:
- <name>: <reason from the script, or what git refused>
Stashes: <refs, or none>
Next: <named next item, or the question>
```

A kept branch that the script says was built on a finished one needs the `git rebase --onto` command it printed. Give the user that command, and run it only if they ask, because another session may have that branch checked out.
