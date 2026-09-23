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

- **domain-modeling** — Build and sharpen a project's domain model: codebase terminology, CONTEXT.md, ADRs, and glossary.
- **grill-me** — A relentless interview to sharpen a plan or design.
- **grilling** — Stress-test a plan before building via relentless questioning, worked as design-tree rounds.
- **grill-with-docs** — Same relentless interview, while producing ADRs and a glossary along the way.
- **improve** — Read-only senior-advisor survey of a codebase that produces prioritized, self-contained implementation plans for other agents to execute.
- **teach** — Teach the user a new skill or concept within the current workspace.

### Execution & review

- **tdd** — Test-driven development: build features or fix bugs test-first (red-green-refactor).
- **pr-drain** — Review, repair, verify, and safely merge a GitHub pull-request queue through final reconciliation.

### Design

- **design-shotgun** — Generate multiple AI design variants, open a comparison board, and collect structured feedback.

### Tooling & docs

- **vhs** — Record terminal sessions as GIF/MP4/WebM with VHS (Charm.sh): tape-file syntax, recording patterns, the Windows/WSL shell gotcha, and TUI recording.

### Meta & skill authoring

- **find-skills** — Help discover and install skills that provide a requested capability.
- **handoff** — Compact the current conversation into a handoff document for another agent.

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

MIT
