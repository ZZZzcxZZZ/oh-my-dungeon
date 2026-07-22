# Agent A Prompt：设置与主题

你在 `dnd-table-tool` monorepo 的独立 worktree 中开发。执行前确认分支名为 `feat/v0.1-settings-theme`，且基线提交与协调者指定的一致；若不是，停止并报告，不要在主工作树直接开发。

完整执行：

- `docs/superpowers/plans/2026-07-23-parallel-settings-theme.md`
- 参考 `docs/superpowers/plans/2026-07-22-settings-reliability-material3.md`
- 遵守 `docs/roadmap/2026-07-23-parallel-development-coordination.md`

硬性边界：

1. 只修改计划授权的 app/theme、app_preferences、client_mode、设置页及专用测试。
2. 不修改 content、characters、campaigns 或服务端。
3. 你独占 `dnd_table_app.dart`、`main_shell.dart`、`settings_tab_page.dart`、`widget_test.dart`。
4. 遵循 Material 3，卡片圆角不超过 8，不使用嵌套卡片，不增加无实际行为的设置。
5. 每项先写失败测试并运行确认，再实现；不要把测试改成迎合实现。
6. 不运行 doctor，完成时运行计划内测试、`flutter analyze`、Web release build。
7. 每完成一个任务更新计划复选框并创建独立 commit；不要提交其他 Agent 的文件。

持续工作直到本计划全部完成。最终报告：commit 列表、变更文件、测试数量、未解决问题和任何越界需求；不要只完成一个小功能就停止。
