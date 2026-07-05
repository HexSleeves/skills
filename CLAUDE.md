# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A personal library of **agent skills** consumed via [`npx skills`](https://github.com/vercel-labs/skills). There is no application code and no build, lint, or test step — each skill is a directory under `skills/` holding a single `SKILL.md` (YAML frontmatter + markdown instructions) that an agent loads on demand. Work here is authoring and editing those documents; skills are auto-discovered on push, so there is nothing to build or deploy.

## Commands

```bash
npx skills add HexSleeves/skills                  # install all (consumer side)
npx skills add HexSleeves/skills --list           # list without installing
npx skills add HexSleeves/skills --skill <name>   # install one
```

## SKILL.md contract

Frontmatter has two fields, `name` and `description`:

- `name` — letters, numbers, hyphens only. **This, not the directory name, is the skill's identity**, and the two often differ (dir `gstack-design-shotgun` → `name: design-shotgun`).
- `description` — third-person, starts with `Use when…`, and states *triggering conditions only*. Do **not** summarize the skill's workflow in it: a description that describes the process causes agents to follow the description and skip the skill body.

When creating or editing any skill, follow the repo's own authoring guide — the **staff-writing-skills** skill (TDD-for-docs: baseline the failure, write the minimal skill, close loopholes).

## Architecture: two skill families

- **`staff-*`** — an adaptation of the "superpowers" skill suite (brainstorming, planning, TDD, debugging, code review, worktrees, verification, etc.). **~14 of these are duplicate directory pairs: two directories, same `name:`, byte-identical content** — e.g. `staff-writing-plans` and `staff-planning-and-backlog` are the same skill under a plain name and a "senior-staff-engineer"-themed name (39 directories collapse to 25 distinct `name:` values). Before editing a `staff-*` skill, grep its `name:` value across `skills/*/SKILL.md`; if a twin exists, mirror the edit or the pair will silently diverge.
- **Standalone skills** — original, single-directory: `find-skills`, `grill-me` / `grilling` / `grill-with-docs`, `improve`, `handoff`, `teach`, `tdd`, `sdd-html`, `vhs`, `gstack-design-shotgun`.

`skills/.curated/` is reserved for polished, ready-to-use skills (currently empty); `skills/` holds everything else in one flat namespace. `README.md` carries a hand-maintained catalog grouped by category — update it when adding or removing a skill.
