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
- **grill-me**: User-invoked only shortcut that starts a `grilling` session; the agent never fires it on its own. From mattpocock/skills (MIT).
- **improve** — Read-only senior-advisor survey of a codebase that produces prioritized, self-contained implementation plans for other agents to execute.

### Execution & review

- **code-review**: Review a branch against the repo's standards and the originating spec, once per branch before the PR. Fork of mattpocock/skills (MIT).
- **diagnosing-bugs**: Diagnosis loop for hard bugs and performance regressions, built on a tight red-capable feedback loop before any hypothesis. Fork of mattpocock/skills (MIT).
- **no-comments**: Review scoped code comments, fix accepted findings, and offer enforceable encodings for claimed constraints.
- **tdd**: Red-green loop at agreed seams, with red checked by test count, mutation for pinned behaviour, and no code without a runner. Fork of mattpocock/skills (MIT).
- **why**: Evidence-backed answers to "why does X work this way" from source control, issues, docs, and chat. Fork of cursor/plugins pstack (MIT).

### Writing

- **no-ai-slop**: Edit drafts into sharper writing in the author's voice, or flag AI-slop patterns without rewriting; checks change descriptions against the diff. Fork of petergyang/no-ai-slop.

### Tooling & docs

- **archify**: Validated architecture, workflow, sequence, data-flow, and lifecycle diagrams as standalone HTML with inline SVG. Fork of tt-a1i/archify (MIT).
- **gh-axi**: Operate GitHub through the gh-axi CLI. Fork of kunchenguid/gh-axi (MIT).

### Meta & skill authoring

- **handoff** — Compact the current conversation into a handoff document for another agent.
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

## License

MIT, except forked skills, which keep their upstream license: see the LICENSE file in the skill directory, or the upstream repo named in the catalog.
