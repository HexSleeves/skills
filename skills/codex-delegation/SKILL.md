---
name: codex-delegation
description: How to hand a bounded implementation, review, or second opinion to Codex, including local CLI checks, effort selection, and a precise handoff contract.
---

# Delegating to Codex

Use Codex only when the user has authorized delegation. `codex exec` can implement a decided
specification; `/codex` can review, challenge, or consult. Keep the assignment bounded and
review every result yourself.

## Writing the specification

- Give Codex a decided plan with exact files, behavior, constraints, and verification.
- Keep judgment with the caller. Treat Codex output as a claim until you inspect and test it.
- State an explicit stop point, such as "write the plan and stop" or "address this review
  round and stop."
- Do not expand the user's authorization, repository scope, network access, or write access.

Good assignments include self-contained modules, mechanical refactors, boilerplate, test
scaffolding, and independent review of a concrete diff. Keep unresolved product or architecture
decisions with the caller.

## Model and effort

Use the active Codex CLI model and configuration unless the user requests a supported override.
Do not change `~/.codex/config.toml` automatically and do not pin a model based on this document.
If a requested override depends on CLI support, inspect the installed version's help before using
it. Choose the lowest reasoning effort that fits the task, normally medium for mechanical work and
high for judgment-heavy review or planning.

## Driving `codex exec`

Read [CODEX-INVOCATION.md](CODEX-INVOCATION.md) before writing Bash that invokes `codex exec`.
That contract covers local version checks, stdin-file prompts, separate stream and diagnostic
files, fresh output paths, explicit thread IDs, forced sandbox mode on resume, dirty-tree
protection, and exit/output validation.
