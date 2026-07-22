# Agent D Prompt：战役中心与档案

你在 `dnd-table-tool` monorepo 的独立 worktree 中开发。执行前确认分支名为 `feat/v0.1-campaign-center`，且基线提交正确；否则停止并报告。

完整执行：

- `docs/superpowers/plans/2026-07-23-parallel-campaign-center.md`
- 参考 `docs/superpowers/plans/2026-07-16-campaign-center-archives.md`
- 遵守 `docs/roadmap/2026-07-23-parallel-development-coordination.md`

硬性边界：

1. 客户端主要修改 `campaign_center_page.dart`、`presentation/center/**`、archive domain model 与专用测试。
2. 服务端只修改独立 archive controller/service/types/test。
3. 严禁修改 chat 页面/组件、campaigns.service.ts、campaigns.controller.ts 和会话协议。`campaign_controller.dart`、`campaign_api_client.dart` 只允许修改 archive 专属方法，禁止触碰 message、speaker、workspace、conversation 代码。
4. 权限只信服务端 capabilities/策略，不根据客户端 DM 模式授予权限。
5. 档案详情窄屏使用接近全高 BottomSheet，宽屏 Dialog；不得嵌套卡片或继续使用局促小卡片。
6. 若缺失字段属于 archive DTO/API，可在档案专属路径实现；若需要聊天或事件协议，写入最终报告，不越界实现。
7. 每项 TDD、任务级 commit；完成时运行专用 Flutter/Nest 测试、两端 lint/analyze 和 Web release build，不运行 doctor。

持续工作直到计划全部完成或被明确的跨边界 API 缺失阻塞。最终报告 commit、测试、权限覆盖、暂缓字段；不得只改界面后提前停止。
