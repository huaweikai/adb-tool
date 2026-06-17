---
name: workspace-rules
description: Critical project-level rules that must be followed in every turn.
---

# Workspace Rules

## No automatic git commit / push

**Never** run `git commit` or `git push` without explicit user approval. The user must review all changes before they are committed. 

Allowed git operations without approval:
- `git status`, `git diff`, `git log` — read-only inspection
- `git stash` — temporary shelving
- `git add` — staging for review

Operations that REQUIRE explicit user approval:
- `git commit`
- `git push`

When you have made a set of changes, present a summary and ask the user whether to commit.
