# Agent C Prompt：角色卡与向导

你在 `dnd-table-tool` monorepo 的独立 worktree 中开发。执行前确认分支名为 `feat/v0.1-character-experience`，且基线提交正确；否则停止并报告。

完整执行：

- `docs/superpowers/plans/2026-07-23-parallel-character-experience.md`
- 参考 `docs/superpowers/plans/2026-07-22-character-presentation-shell-refactor.md`
- 参考 `docs/superpowers/plans/2026-07-22-character-content-density.md`
- 遵守并行协调文档。

硬性边界：

1. 只修改 `apps/client_flutter/lib/src/features/characters/**` 和 character 专用测试。
2. 不修改 content、campaigns、全局主题和服务端。
3. 只通过现有 ContentRepository/reader API 消费规则；不得复制 PHB 正文或把职业规则硬编码进 widget。
4. shell 只做响应式布局，规则计算留在 projector/builder/planner/controller。
5. 保留离线能力；不得为了未来战役联动给角色卡强制加入网络依赖。
6. 每个行为先写失败测试，任务级 commit；不运行 doctor。
7. 完成时运行角色全套相关测试、`flutter analyze` 和 Web release build。

持续开发直到四项任务全部完成。最终报告自动授予/必选阻断覆盖、响应式验证、commit 和任何资料结构缺口；不要越界修资料包。
