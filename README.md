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

- **staff-brainstorming** / **staff-design-and-discovery** — Explore user intent, requirements, and design before any creative or implementation work.
- **staff-writing-plans** / **staff-planning-and-backlog** — Turn a spec or requirements into a step-by-step implementation plan before touching code.
- **grill-me** — A relentless interview to sharpen a plan or design.
- **grilling** — Stress-test a plan before building via relentless questioning.
- **grill-with-docs** — Same relentless interview, while producing ADRs and a glossary along the way.
- **improve** — Read-only senior-advisor survey of a codebase that produces prioritized, self-contained implementation plans for other agents to execute.
- **teach** — Teach the user a new skill or concept within the current workspace.

### Execution & delegation

- **staff-executing-plans** / **staff-execution-engine** — Execute a written implementation plan in a separate session with review checkpoints.
- **staff-subagent-driven-development** / **staff-delegation** — Execute implementation plans with independent tasks in the current session.
- **staff-dispatching-parallel-agents** / **staff-orchestration** — Coordinate 2+ independent tasks with no shared state or sequential dependencies.
- **staff-using-git-worktrees** / **staff-worktree-management** — Create isolated git worktrees for feature work, with smart directory selection and safety checks.

### Testing & debugging

- **tdd** — Test-driven development: build features or fix bugs test-first (red-green-refactor).
- **staff-test-driven-development** / **staff-tdd-discipline** — Enforce writing tests before implementation code.
- **staff-systematic-debugging** / **staff-forensic-debugging** — Investigate bugs, test failures, and unexpected behavior before proposing fixes.

### Verification & code review

- **staff-verification-before-completion** / **staff-evidence-verification** — Run verification commands and confirm output before claiming work is complete.
- **staff-requesting-code-review** / **staff-review-requesting** — Verify work meets requirements when completing tasks or before merging.
- **staff-receiving-code-review** / **staff-review-reception** — Apply technical rigor to review feedback instead of blindly implementing it.
- **staff-finishing-a-development-branch** / **staff-release-engineering** — Decide how to integrate completed work (merge, PR, or cleanup).

### Design

- **gstack-design-shotgun** — Generate multiple AI design variants, open a comparison board, and collect structured feedback.

### Meta & skill authoring

- **staff-using-senior-staff-engineer** — Establishes how to find and use skills at the start of a conversation.
- **staff-writing-skills** / **staff-skill-academy** — Create, edit, and verify skills before deployment.
- **find-skills** — Help discover and install skills that provide a requested capability.
- **handoff** — Compact the current conversation into a handoff document for another agent.
- **example-skill** — A starter skill demonstrating the `SKILL.md` format.

## Structure

```bash
skills/
├── <skill-name>/
│   └── SKILL.md      # YAML frontmatter (name, description) + instructions
├── .curated/          # High-quality, ready-to-use skills
```

## Adding a New Skill

1. Create a directory under `skills/` (or `skills/.curated/` for polished ones)
2. Add a `SKILL.md` with frontmatter:

```yaml
---
name: my-skill
description: Brief explanation of what this skill does and when to use it
---

# My Skill

Instructions for the agent to follow when this skill is activated.
```

1. Push to GitHub — `npx skills add HexSleeves/skills` will auto-discover it.

## License

MIT
