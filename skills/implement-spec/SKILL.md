---
name: implement-spec
description: "Use when the user wants the result of /to-spec and /to-tickets implemented in code."
disable-model-invocation: true
metadata:
  upstream: mattpocock/skills
---

You have been provided a spec. This spec should have tickets associated with it, describing how to implement the spec.

The issue tracker should have been provided to you. If not, tell the user to run `/setup-matt-pocock-skills`.

The goal is the entire spec implemented on a single **integration branch**, with every ticket resolved the way the issue tracker closes work.

The tickets are not a list of steps. They are a **task graph** with blocking relationships between them. This means there is always a **frontier** of tickets which are ready to be grabbed.

Communication to and from subagents should be sparse. Communicate primarily through **context pointers**: to the spec, tickets, research notes, and previous commits. Don't duplicate information already available via pointers.

**Implementer subagents** should be run in the background where possible for maximum concurrency.

## Steps

1. Read the spec and tickets to understand the task graph.

2. (optional) Use an **exploration subagent** to conduct any exploration required by the tickets - relevant codebase files or external documentation. Ensure the exploration subagent can save files - it should save its markdown notes in a directory outside the repo, accessible by all future subagents. This lets **implementer subagents** focus on implementation rather than exploration.

3. Create the integration branch and record its base commit. Open a draft PR only when the user asked for one, after the first merge in step 5 (a branch with no commits ahead of main can't open one), marked as closing the spec and tickets. Otherwise the PR opens at step 8.

4. Use **implementer subagents** to implement each ticket, each in its own worktree on its own branch. Each prompt names the integration branch and its base commit, because isolated worktrees start from the default branch. Implementers that run full local test suites run at most two at a time on one workstation (through a host lock such as `heavy` where one exists), and each commits its slice before the next starts: a harness restart kills background subagents and their uncommitted work. Each implementer subagent:
   - confirms its worktree is based on the integration branch before starting, and resets onto it if not;
   - calls the Skill tool with `tdd` to build the ticket;
   - merges the integration branch tip into its own branch before reporting done
   - reproduces any intermittent failure in a test file the branch touched by running the touched files together in one process, in each order, before calling it pre-existing or flaky (a shared mock under `isolate: false` leaks this way)

5. Once an **implementer subagent** completes, verify `git merge-base --is-ancestor <base> <branch>`, then merge its work to the integration branch. When the ticket tip descends from the integration branch, fast-forward it yourself; use a **merger subagent** only when the merge has conflicts to resolve.

6. If this changes the **frontier** of available tickets, kick off more **implementer subagents** to work on the new tickets. This allows for maximum concurrency. A frontier ticket that depends on a precondition a still-running sibling changes (auth required, a signature, a shared data shape) stacks on that sibling's branch instead of the integration branch.

7. Once all tickets are complete, call the Skill tool with `code-review` on the integration branch. Fix all issues raised by the code review in a single **implementer subagent**.

8. Read the repo's CI entry point (its CI workflow, `make ci` or the equivalent) and run each of its steps locally, or list the ones skipped and why. A containerised target that mounts the checkout fails from a worktree, whose `.git` file points outside the mount: run it from a `git clone --branch <integration>`, and delete the clone through the same container user. A PR that closes several tickets writes one closing keyword per ticket ("Closes #1. Closes #2."); confirm with `gh pr view --json closingIssuesReferences`. Then, if a draft PR exists, mark it ready for review; otherwise open the PR, or resolve each ticket the way the issue tracker closes work, and report the integration branch. For a product with a user-facing UI, the done report says whether visual design was done and shows one screenshot.

9. Clean up all **implementer subagent** worktrees. Delete a ticket branch only after `git merge-base --is-ancestor <branch> <integration>` succeeds, then with `git branch -D` (`-d` refuses branches merged by squash or rebase).
