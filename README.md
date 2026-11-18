# HexSleeves Skills

My personal collection of agent skills for [`npx skills`](https://github.com/vercel-labs/skills).

Skills are self-contained instruction sets an AI agent can load on demand. Each lives in its own directory with a `SKILL.md` file (YAML frontmatter + instructions) and is auto-discovered when installed.

## Install

Install all skills:

```bash
npx skills add HexSleeves/skills
```

List available skills without installing:

```bash
npx skills add HexSleeves/skills --list
```

Install a specific skill:

```bash
npx skills add HexSleeves/skills --skill <skill-name>
```

Install globally:

```bash
npx skills add HexSleeves/skills -g
```

## Skills

### Planning & discovery

- **grilling**: Stress-test a plan before building via relentless questioning, one design-tree frontier question at a time. Rebuilt from mattpocock/skills (MIT).
- **improve** — Read-only senior-advisor survey of a codebase that produces prioritized, self-contained implementation plans for other agents to execute.
- **software-factory**: Shared language for designing a system of agents that turns tickets, PRs and schedules into merged code. Fork of mattpocock/skills (MIT).

### Execution & review

- **code-review**: Review a branch against the repo's standards and the originating spec, once per branch before the PR. Fork of mattpocock/skills (MIT).
- **council**: Three reviewers from three model families (Opus, Muse, GPT Sol via Cursor) must each call a PR safe on its current head before it merges; the coordinator owns fixes and reconvenes the council within a 3-round budget, where nits never force a new round.
- **diagnosing-bugs**: Diagnosis loop for hard bugs and performance regressions, built on a tight red-capable feedback loop before any hypothesis. Fork of mattpocock/skills (MIT).
- **file-pr**: Files a PR whose title follows the repo and whose body leads with the problem, then Summary, Evidence and Merge Danger. From t3dotgg/tstack (MIT), body template from mattpocock/skills `pr`.
- **full-stop**: `full-send` that stops with the PR ready for the user to merge. From t3dotgg/tstack (MIT).
- **implement-spec**: Implements a `to-spec` spec and its `to-tickets` task graph on one integration branch with parallel implementer subagents, bounded by the host and checked against the repo's CI target. Fork of mattpocock/skills (MIT).
- **leaving-pr-comments**: Style and safety checks for every GitHub comment an agent posts on the user's behalf. From t3dotgg/tstack (MIT).
- **merged**: After a PR merges (by hand or when its merge watcher exits), removes the branches and worktrees that are provably finished, pulls the default branch, and readies the repo for the next piece of work.
- **modernize**: Rebases an aging PR and decides whether it should still exist (MODERNIZE, REWORK or CLOSE). From t3dotgg/tstack (MIT).
- **no-comments**: Review scoped code comments, fix accepted findings, and offer enforceable encodings for claimed constraints.
- **sol-loop**: Reviews a change with GPT Sol (T3 `delegate_task`, or the Codex CLI) in a loop until both agents agree. From t3dotgg/tstack (MIT).
- **takeover**: Finishes someone else's PR, branch or agent thread and keeps their credit. From t3dotgg/tstack (MIT).
- **tdd**: Red-green loop at agreed seams, with red checked by test count, mutation for pinned behaviour, and no code without a runner. Fork of mattpocock/skills (MIT).

### Writing

- **no-ai-slop**: Edit drafts into sharper writing in the author's voice, or flag AI-slop patterns without rewriting; checks change descriptions against the diff. Fork of petergyang/no-ai-slop.

### Meta & skill authoring

- **task-observer**: Log skill-improvement observations during work and review them into staged skill updates. Fork of rebelytics/one-skill-to-rule-them-all (CC BY 4.0).

## Structure

```bash
skills/
├── <skill-name>/        # directory name matches frontmatter `name:`
│   ├── SKILL.md         # YAML frontmatter (name, description) + instructions
│   └── ...              # support files the skill references (references/, scripts/, formats)
```

## Adding a New Skill

1. Create a directory under `skills/`, named exactly the skill's frontmatter `name`.
2. Add a `SKILL.md` with frontmatter:

```yaml
---
name: my-skill
description: Brief explanation of what this skill does and when to use it
---

# My Skill

Instructions for the agent to follow when this skill is activated.
```

3. Add support files beside it when the skill needs them, and reference them with relative paths.
4. Update the catalog above.
5. Push to GitHub — `npx skills add HexSleeves/skills` will auto-discover it.

## Keeping forks current

Forked skills are pinned to an upstream commit in `upstreams.json`. Every Monday a workflow updates one issue, "Upstream skill changes", with the upstream commits not merged yet. `scripts/upstream pull <skill>` 3-way merges them into the fork; see `AGENTS.md` for the commands.

## License

MIT, except forked skills, which keep their upstream license: see the LICENSE file in the skill directory, or the upstream repo named in the catalog.
