# Agent B Prompt：只读资料库

你在 `dnd-table-tool` monorepo 的独立 worktree 中开发。执行前确认分支名为 `feat/v0.1-content-library`，且基线提交与协调者指定的一致；若不是，停止并报告。

完整执行：

- `docs/superpowers/plans/2026-07-23-parallel-content-library.md`
- 参考 `docs/roadmap/2026-07-23-integrated-product-hardening-roadmap.md` 的 P2
- 遵守 `docs/roadmap/2026-07-23-parallel-development-coordination.md`

硬性边界：

1. 只修改 `apps/client_flutter/lib/src/features/content/**` 和 content 专用测试。
2. 不修改角色、战役、设置、全局主题、服务端和资料包 schema。
3. 保持 `ContentRepository`、`ContentEntryReader` 的现有公开构造器兼容，因为其他并行分支正在消费它们。
4. 资料库是只读查阅平台；导入与包管理实现保留，但浏览页面不得出现编辑、笔记或复制创作入口。
5. 筛选必须读取结构化字段；禁止从中文正文或名称猜测职业、环位、学派和关系。
6. 每项执行 TDD，完成一项提交一次；不运行 doctor。
7. 最终运行 content 测试、`flutter analyze`、Web release build，并检查 360/390/900/1280 宽度。

持续工作直到计划全部完成。最终报告 commit、测试、兼容性保证和发现的数据缺口；数据缺口只报告，不越界修改 character/campaign 模块。
