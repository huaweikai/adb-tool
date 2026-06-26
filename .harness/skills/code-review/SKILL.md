---
name: code-review
description: 审查代码变更，优先发现缺陷、回归和缺失测试。
---

# Code Review

Use this skill when reviewing a code change. Prioritize correctness, regressions, security, performance, and missing tests. Lead with concrete findings and file references.

For the adb_tool project, additionally verify:

- Backend: envelope `{ok, data, error}` consistency, `api/README.md` sync, `recoverHTTP` / `goSafe` usage, loopback-only unchanged, shell injection risk on user input passed to `adb shell`, dangerous commands without `?confirm=true` flag.
- Flutter: i18n key 双侧同步（zh + en files），endpoint 客户端与后端 envelope 对齐，drift schema 迁移完整，partial unique index 等约束保留，桌面端 lifecycle 正确处理（Provider dispose、controller cancel）。
- Platform: WiX 5.0.2 + UI ext 5.0.2（**不要用 WiX 7+**），ANDROID_HOME 不反推，codesign / signing 路径无误，CI 三路（windows-latest / macos-14 / macos-13）触发条件正确。

Output format: each finding includes `[severity]` + `file:line` + one-line reason + suggested fix. Sort by severity. Distinguish blocking from nit.