# AGENTS.md

Guidance for AI agents working in this repository. (`CLAUDE.md` is a symlink to this file; edit here.)

## What this is

A personal library of **agent skills** consumed via [`npx skills`](https://github.com/vercel-labs/skills). There is no application code and no build or lint step. The only code is the scripts some skills bundle; `skills/merged/scripts/test_scripts.sh` tests merged's scripts, `scripts/test_upstream.sh` tests `scripts/upstream`, and `skills/task-observer/scripts/validate-skill-bundle.py` checks a staged skill directory. Each skill is a directory under `skills/` holding a `SKILL.md` (YAML frontmatter + markdown instructions) plus whatever support files it needs. Work here is authoring and editing those documents; skills are auto-discovered on push, so there is nothing to build or deploy.

## Commands

```bash
npx skills add HexSleeves/skills                  # install all (consumer side)
npx skills add HexSleeves/skills --list           # list without installing
npx skills add HexSleeves/skills --skill <name>   # install one
```

## SKILL.md contract

- `name` must equal the directory name. The frontmatter value is the skill's identity; keeping the two identical is what makes installs predictable.
- `description` is third-person, starts with `Use when…`, and states *triggering conditions only*. Do **not** summarize the skill's workflow in it: a description that describes the process causes agents to follow the description and skip the skill body.

## Layout

One flat namespace: every skill lives directly under `skills/`. `README.md` carries a hand-maintained catalog grouped by category. Update it when adding, removing, or renaming a skill.

## Upstream forks

`upstreams.json` pins each forked skill to the upstream commit it last matched. A weekly workflow keeps one open issue, "Upstream skill changes", listing upstream commits that a fork has not merged yet.

```bash
scripts/upstream check [skill...]        # upstream commits since each pin
scripts/upstream diff <skill>            # upstream's diff since the pin
scripts/upstream pull <skill...>         # 3-way merge into the fork; moves the pin when clean
scripts/upstream pin <skill> <sha>       # after resolving a conflicted pull
scripts/upstream add <skill> <owner/repo> <path>   # track a new fork from upstream HEAD
```

When resolving a conflicted pull, the fork's wording wins: descriptions follow the contract above, and the fork's rules are deliberate. Take upstream's new behaviour or facts, rewritten in the fork's voice, then `pin` to the SHA that `pull` printed. task-observer and council are not tracked: they no longer resemble their sources.
