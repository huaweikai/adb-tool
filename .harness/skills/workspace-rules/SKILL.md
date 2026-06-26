---
name: workspace-rules
description: 关键工作区规则 —— 不要自动 commit / push，任何 git commit / push / PR 创建必须用户明确同意。
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
- `gh pr create` / `glab mr create`

When you have made a set of changes, present a summary and ask the user whether to commit. Do not commit until they explicitly say so.