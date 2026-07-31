# 战役中心与档案 Wiki 实现计划

> **面向 AI 代理的工作者：** 使用 test-driven-development。严格避开聊天、会话和通用 campaigns service/controller。

**目标：** 重排战役中心概览与角色区，并把档案升级为可阅读、可编辑、可搜索的战役 Wiki。

**架构：** `CampaignCenterPage` 只组织概览、角色、档案三个目的地；概览显示成员与邀请等摘要；角色区管理当前/临时/归档 character；档案由独立 archive service/controller 提供 CRUD。详情使用宽屏 Dialog、窄屏全高 BottomSheet。

**技术栈：** Flutter Material 3、NestJS、Prisma 现有 Journal/Archive 模型、flutter_test、Jest e2e。

## 文件所有权

- 修改客户端 `campaign_center_page.dart` 与 `presentation/center/**`
- 修改客户端 archive domain model，以及 `campaign_api_client.dart`、`campaign_controller.dart` 中仅 archive 专属的方法签名和映射
- 修改服务端 `campaign-archives.controller.ts`、`campaign-archives.service.ts` 及其专用 types/test
- 新建专用 Flutter/Nest 测试

禁止修改 `campaign_chat_page.dart`、聊天组件、`campaigns.service.ts`、`campaigns.controller.ts` 和会话协议。`campaign_api_client.dart` 与 `campaign_controller.dart` 只能修改 archive 专属代码段，禁止触碰 message、speaker、workspace 与 conversation 方法。

### 任务 1：战役中心信息架构

- [x] 写失败测试：一级只显示概览、角色、档案；"成员"合入概览；"队伍"改名角色；邀请代码、复制/分享动作和当前成员摘要可见。
- [x] 概览使用全宽 section 与清晰间距，不使用嵌套 Card；DM 工具和战役设置分区，不与成员列表粘连。
- [x] 运行 `flutter test test/campaign_center_page_test.dart test/campaign_overview_panel_test.dart`。
- [x] 提交 `refactor(v0.1): reorganize campaign center`。

### 任务 2：角色区管理

- [x] 写失败测试：玩家角色、常驻 NPC、临时角色、归档角色分区；归档默认折叠；每个角色点击打开统一完整角色卡。
- [x] DM 显示管理动作，玩家只显示自己可用动作；权限只读已有 capabilities，不根据客户端模式猜测。
- [x] 运行 `flutter test test/campaign_characters_panel_test.dart test/campaign_character_pages_test.dart`。
- [x] 提交 `refactor(v0.1): complete campaign character panel`。

### 任务 3：档案正文与权限

- [x] 写 Nest 失败测试：创建/更新档案支持 `bodyBlocks`、tags、links、attachmentRefs；创建者和 manager 可编辑，其他成员只读；搜索匹配标题、摘要、正文和标签。
- [x] 只在独立 archive service/controller 中实现 DTO 校验和权限；保持已有路径兼容。
- [x] 写 Flutter 失败测试：档案列表采用资料条目式行；详情可完整滚动；创建/编辑表单可编辑正文，不再只有名称和说明。
- [x] 窄屏详情使用接近全高的 BottomSheet，宽屏使用最大宽度 760 的 Dialog；禁止局促小卡片。
- [x] 分别运行 Nest archive e2e 与 `flutter test test/campaign_archive_panel_test.dart`。
- [x] 提交 `feat(v0.1): turn campaign archives into wiki`。

### 任务 4：验收

- [x] 运行 campaign center/overview/characters/archive Flutter 测试。
- [x] 运行服务端 archive 单元/e2e、`npm run lint:server`。
- [x] 运行 `flutter analyze` 和 `flutter build web --release`。
- [x] 在报告中列出仍需聊天/事件协议支持的能力，交给第二波整合，不得越界实现。

---

## 最终报告

### Commit 列表

分支 `feat/v0.1-campaign-center`（独立 worktree，基线 `bb5b490`）：

```
e82200e docs(v0.1): mark campaign-center plan tasks 3-4 complete
d948744 chore(v0.1): silence use_null_aware_elements lint in archive test
bcc0ba9 feat(v0.1): turn campaign archives into wiki       ← 任务 3 (3a+3b 合并)
55c4e81 refactor(v0.1): complete campaign character panel     ← 任务 2
65ad2a6 refactor(v0.1): reorganize campaign center        ← 任务 1
```

### 客户端测试结果

```
flutter test test/campaign_center_page_test.dart \
          test/campaign_characters_panel_test.dart \
          test/campaign_character_pages_test.dart \
          test/campaign_archive_panel_test.dart \
          test/campaign_context_controller_test.dart \
          test/campaign_controller_test.dart \
          test/campaigns_tab_page_test.dart \
          test/campaign_chat_character_test.dart
→ 129 tests passed (含档案面板 13 条 wiki 测试)

flutter analyze      → No issues found!
flutter build web --release → Built build\web (wasm 警告来自 socket_io_common 依赖，与本次改动无关)
```

### 服务端测试结果

```
npx jest test/campaign-archives.e2e-spec.ts → 14 passed
  - wiki content fields: 创建/更新存储 bodyBlocks/tags/links/attachmentRefs；非法结构拒绝
  - creator-based edit permissions: creator 可编辑、非 creator 玩家只读、co-DM 可编辑
  - full-text search: 标题/摘要/正文/标签匹配，支持 kind + q 组合
npm run lint:server → clean
```

### 权限覆盖

> **修正（2026-07-23 整合审查 P2）**：原表格误将"其他玩家"的"创建新档案"标为 ✅。
> 服务端 `campaign-archives.service.ts:126` 在 `create()` 内调用 `canManageCampaign`，
> 客户端 FAB（`campaign_center_page.dart:120` `if (!_canManage) return null`）也仅
> manager 可见，因此普通玩家既无 UI 入口也会被服务端 403 拒绝。下表为修正后的真实策略。

| 操作 | 创建者 (当前玩家) | Manager (DM) | 其他玩家 |
|---|---|---|---|
| 查看档案列表/详情 | ✅ | ✅ | ✅ |
| 创建新档案 | ❌（无 FAB / 服务端 403） | ✅ (FAB 可见 + `canManageCampaign`) | ❌（无 FAB / 服务端 403） |
| 编辑自己创建的条目 | ✅ | ✅ | ❌ |
| 编辑他人创建的条目 | ❌ | ✅ | ❌ |
| 归档/删除条目 | ✅ (自己的) | ✅ (任意) | ❌ |

关键原则：**客户端从不根据 DM 模式自行授权**。`canManage` 仅来自服务端 `capabilities.canManageCampaign`；编辑入口可见性额外基于 `workspaceContext.membership.userId == entry.createdBy`，最终由服务端 `assertCanEdit` 二次校验。

> **产品决策待定（整合审查下一步计划 #4）**：当前实现是严格策略"DM 创建档案、玩家只读"。
> 若改为"成员可创建自己的条目"，需同步放宽服务端 `create()` 权限为
> `canViewCampaign` + 将 `createdBy` 设为当前用户，并让客户端 FAB 对所有成员可见。
> 在产品规则定稿前，保持当前严格策略不变。

### 暂缓字段或跨模块阻塞

无跨模块 API 阻塞。本次工作完全在独立 archive controller/service 与客户端 archive 专属 API 段内完成。

### 已识别需第二波聊天/事件协议支持的能力

（不在本次范围内实现，列出供第二波整合参考）

1. **档案实时协作** — 当 DM 创建/编辑档案时，其他在线玩家当前看不到实时推送，需 `campaign:changed` 事件扩展到 archive 域。
2. **聊天消息 → 档案自动归档** — 当前聊天工具栏的"记录线索/分享地点/群文件"三个按钮已经预填 kind 打开创建表单，但尚需把原消息 `messageId` 写入 `payload.sourceMessageId` 形成双向回链；这需要读取 chat 消息上下文，属于聊天模块边界。
3. **附件实际上传** — 当前 `attachmentRefs` 是元数据引用（url/label），文件上传走 `campaign_media` 模块；上传后把返回的 assetId 写入 `attachmentRefs[].url` 是第二波整合工作。
4. **角色卡 ↔ 档案的双向关联** — `links` 中 `kind:'character'` 目前只能存 ID，无法点击跳转到角色卡；需要角色卡路由与档案路由互通。
5. **结构化 block 编辑器** — 当前编辑表单把正文按段落（每行一个 paragraph block）扁平化；保留 heading/list 类型需要富文本编辑器组件，留给后续迭代。

### 已知无关测试失败

`apps/server_nest/test/campaigns.e2e-spec.ts` 中 1 个测试失败（`returns the campaign for a member` 期望 `lastMessage` 不含 `publicHealthFraction`，但 `campaigns.service.ts` 现在会返回该字段）。此为基线 `bb5b490` 已存在的问题，与本次档案工作无关，且 `campaigns.service.ts` 与 `campaigns.e2e-spec.ts` 均在禁止修改清单内。

---

## 整合审查发现处置（2026-07-23）

| # | 级别 | 发现 | 归属域 | 处置状态 |
|---|---|---|---|---|
| 1 | P1 | 子职业筛选仍依赖 `structured.parentClass`；私有资料包若只提供 `subclassOf` 关系，筛选不会命中。`content_repository.dart:32` / `content_library_controller.dart:63` | 资料库 agent | **非本计划范围**。资料库筛选索引由资料库线负责。本计划已交回主线，建议在资料库线纳入 `subclassOf` / `featureOf` 关系型索引。 |
| 2 | P1 | 战役档案 CRUD 完成但无实时事件广播，在线成员需手动刷新。`campaign-archives.service.ts:104` | 战役中心/档案 | **已在第二波暂缓清单第 1 项**。实时推送需扩展 `campaign:changed` 事件到 archive 域，属于聊天/会话协议边界，本计划禁止修改。已列入"下一步计划 #3 打通战役档案"的首项。 |
| 3 | P2 | 档案"普通成员能否创建"在报告表格与服务端策略间表述不一致；现状是仅 DM/manager 可创建。`campaign-archives.service.ts:126` | 战役中心/档案 | **已修正**。本计划权限表格原误将"其他玩家 ✅"改为 ❌，并附服务端 `canManageCampaign` + 客户端 FAB 双重证据。产品规则（严格 vs 放宽）列入"下一步计划 #4 收束战役权限"待定。 |

**本计划范围内无新增代码改动**：P2 是报告表述错误（已修文档），P1#2 是已知跨模块暂缓项，P1#1 不在本计划域。

**回归验证**：本次仅修改计划文档，未触碰代码；客户端 129 项 + 服务端 14 项测试结果不变，`flutter analyze` / `npm run lint:server` / Web release 构建仍通过。

