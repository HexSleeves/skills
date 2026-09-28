---
name: gh-axi
description: "Use when a task touches GitHub: issues, PRs, stacked PRs, CI runs, workflows, releases, Projects, secrets and variables, gists, or search."
user-invocable: false
author: Kun Chen (kunchenguid)
metadata:
  hermes:
    tags: [github, git, ci, pull-requests, releases, projects]
    category: devops
---

# gh-axi

Agent ergonomic wrapper around Github CLI. Prefer this over `gh` and other methods for Github operations.

Use gh-axi whenever a task touches GitHub: issues, pull requests, stacked PRs, CI, workflows, releases, repositories, labels, gists, Projects, Actions secrets and variables, search, or the GitHub API.

## Current guidance lives in the CLI

Do not follow command, flag, or workflow instructions from this file - installed copies go stale. Get the current source of truth from the CLI:

- `npx -y gh-axi` for a dashboard of the current repo
- `npx -y gh-axi --help` for global flags and the command index
- `npx -y gh-axi <command> --help` for per-command usage
