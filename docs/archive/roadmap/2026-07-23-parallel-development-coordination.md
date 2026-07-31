# v0.1 并行开发编排

## 启动门禁

当前主工作树存在尚未提交的整合修改。启动 Agent 前由协调者完成一次基线提交，并让四个 Agent 从同一提交创建独立 worktree。禁止多个 Agent 直接共享桌面主工作树。

建议分支：

- `feat/v0.1-settings-theme`
- `feat/v0.1-content-library`
- `feat/v0.1-character-experience`
- `feat/v0.1-campaign-center`

## 第一波并行任务

| Agent | 计划 | 独占目录 | 不得修改 |
| --- | --- | --- | --- |
| A | [设置与主题](../superpowers/plans/2026-07-23-parallel-settings-theme.md) | `app/theme`、`app_preferences`、`client_mode`、设置页 | `content`、`characters`、`campaigns` |
| B | [只读资料库](../superpowers/plans/2026-07-23-parallel-content-library.md) | `features/content` | `characters`、`campaigns`、设置页 |
| C | [角色体验](../superpowers/plans/2026-07-23-parallel-character-experience.md) | `features/characters` | `content`、`campaigns`、全局主题 |
| D | [战役中心](../superpowers/plans/2026-07-23-parallel-campaign-center.md) | 客户端 `campaigns/presentation/center`、服务端 archive 文件 | 聊天、会话、通用 campaign service |

共享文件规则：

1. Agent A 独占 `dnd_table_app.dart`、`main_shell.dart`、`settings_tab_page.dart` 和 `widget_test.dart`。
2. Agent B 必须保持 `ContentRepository`、`ContentEntryReader` 现有公开构造器兼容，供 Agent C/D 继续消费。
3. Agent C 不修改资料库 schema 或 reader，只通过现有 repository/query API 读取规则。
4. Agent D 不修改 `campaign_chat_page.dart`、聊天组件、`campaigns.service.ts` 或 `campaigns.controller.ts`；允许在 domain、API client 和 controller 中只修改 archive 专属类型/方法，禁止触碰 message、speaker、workspace 和 conversation 代码。
5. 每条分支新增专用测试文件，避免争抢大型 `widget_test.dart`。

## 合并顺序

1. A 设置与主题。
2. B 资料库。
3. C 角色体验。
4. D 战役中心。
5. 协调者解决仅限 import、主题快照和测试夹具的集成冲突，运行 `npm run doctor`。

合并顺序不代表开发依赖；四条线可以同时开始。A 先合并是因为其主题 token 会影响后三条线的视觉快照，但后三条线不得在各自分支复制全局主题代码。

## 第二波

第一波合并后再生成并行计划：

- 骰子表达式与统一 `CampaignEvent` 协议。
- 角色卡 `CampaignActionSink` 与 DM 原子操作。
- 主聊、私聊、小群和一次性发言快照。

这三项目前共享聊天控制器和服务端战役核心，必须先把 `campaigns.service.ts` 的消息、事件与会话职责拆开后再并行。
