---
name: fix-merge-conflicts
description: Use when a branch has unresolved merge conflicts that need resolving to a buildable, tested state.
---

# Fix merge conflicts

## Workflow

1. Detect all conflicting files from git status and conflict markers.
2. For each conflict, check whether one side deleted or moved the text (split file, rename, extraction). If so, resolve the file to that side, find the text's new home (`grep` for its heading, route or symbol in the new files), and apply the other side's change there.
3. Resolve the remaining conflicts with minimal, correctness-first edits.
4. Prefer preserving both sides when safe. Otherwise, choose the variant that compiles and keeps public behavior stable.
5. Regenerate lockfiles with package manager tools instead of hand-editing.
6. Run compile, lint, and relevant tests.
7. Stage resolved files and summarize key decisions.
8. If the branch has a PR, check its description for paths and SHAs the merge made stale.

## Guardrails

- Keep changes minimal and readable.
- Do not leave conflict markers in any file.
- Avoid broad refactors while resolving conflicts.
- Do not push or tag during conflict resolution.

## Output

- Files resolved
- Notable resolution choices, including any change moved to relocated text
- Build/test outcome
