# HexSleeves Skills

My personal collection of agent skills for [`npx skills`](https://github.com/vercel-labs/skills).

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

## Structure

```
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

3. Push to GitHub — `npx skills add HexSleeves/skills` will auto-discover it.

## License

MIT