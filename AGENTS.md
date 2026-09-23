# AGENTS.md

Guidance for AI agents working in this repository. (`CLAUDE.md` is a symlink to this file; edit here.)

## What this is

A personal library of **agent skills** consumed via [`npx skills`](https://github.com/vercel-labs/skills). There is no application code and no build, lint, or test step. Each skill is a directory under `skills/` holding a `SKILL.md` (YAML frontmatter + markdown instructions) plus whatever support files it needs. Work here is authoring and editing those documents; skills are auto-discovered on push, so there is nothing to build or deploy.

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
