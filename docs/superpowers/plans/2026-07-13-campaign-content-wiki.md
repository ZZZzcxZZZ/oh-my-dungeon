# 战役资料库 Wiki 实现计划

> 面向执行 agent：每个行为先写失败测试、运行确认红灯、最小实现、运行绿灯。每个任务
> 单独提交，提交前不运行无关重型检查。

## 文件与职责

- `apps/server_nest/prisma/schema.prisma`：战役包、Wiki 链接和个人收藏持久化。
- `apps/server_nest/src/modules/content/`：导入校验、成员权限、战役内容 API。
- `apps/server_nest/test/content.e2e-spec.ts`：跨角色、跨战役与导入事务验证。
- `apps/client_flutter/lib/src/features/content/domain/`：内容详情、链接、收藏模型。
- `apps/client_flutter/lib/src/features/content/data/`：战役内容 HTTP 客户端。
- `apps/client_flutter/lib/src/features/content/presentation/`：控制器、页面与拆分后的
  Material 3 widgets。
- `apps/client_flutter/test/`：客户端契约、状态和 widget 交互。

## 任务 1：战役 DM 专属资料包导入

1. 在 `content.e2e-spec.ts` 写两个失败测试：DM `POST
   /campaigns/:campaignId/content/packages/import` 返回 `scope: campaign` 和对应
   `campaignId`；Player 同请求得到 403。
2. 运行 `npm --prefix apps/server_nest test -- content.e2e-spec.ts`，确认端点不存在而失败。
3. 在 controller/service 增加战役导入端点，使用 `CampaignPolicy` 校验 `owner/dm`，在
   事务内创建包、条目、默认启用记录和日志。
4. 重跑目标测试至通过。
5. 提交：`feat(0.1): scope content imports to campaigns`。

## 任务 2：Wiki 链接与收藏

1. 在 schema 新增 `ContentItemLink` 与 `UserContentFavorite`，在导入类型中加入
   `references: [{type, slug, relation, label?}]`。
2. 先写 e2e 红灯：职业链接到“动作如潮”特性；未解析引用拒绝导入；用户收藏只对本人
   的 `favoriteOnly=true` 查询生效。
3. 运行目标服务端测试确认红灯，创建 Prisma migration；实现事务内先建条目、后解析链接。
4. 增加成员范围的详情、收藏、取消收藏和收藏筛选 API，重跑至绿。
5. 提交：`feat(0.1): add linked content and favorites`。

## 任务 3：Flutter 战役内容契约

1. 在 `content_api_client_test.dart` 先写红灯，验证战役详情、链接及收藏状态的 URL、
   Bearer header 与 JSON 解析。
2. 在 `content_controller_test.dart` 先写红灯，验证切换收藏会刷新对应条目。
3. 补充 `ContentItemDetail`、`ContentItemLink` 和收藏模型；API 客户端与控制器迁移到
   `campaignId` 范围。
4. 运行 `flutter test test/content_api_client_test.dart test/content_controller_test.dart` 至绿。
5. 提交：`feat(0.1): load campaign wiki content in Flutter`。

## 任务 4：Material 3 Wiki 浏览与职业详情

1. 在 widget 测试先写红灯：收藏筛选只显示收藏；职业“等级特性”按等级展开，点击
   “动作如潮”进入独立特性详情。
2. 将 `content_library_page.dart` 拆为筛选、列表、详情、职业详情与导入 widgets。使用
   `SearchBar`、`FilterChip`、`ListTile`、`IconButton`、`TabBar`、`ExpansionTile`、
   `MenuAnchor` 与 `Divider`。
3. 用 `LayoutBuilder` 实现窄屏列表到详情路由、宽屏列表/详情双栏；职业元数据放在概览，
   级别特性来自 `structured.levelFeatures`，缺失分级的特性单列显示。
4. 运行相关 widget 测试和 `flutter analyze` 至绿。
5. 提交：`feat(0.1): redesign campaign library as Material wiki`。

## 任务 5：DM 导入流程与角色创建接入

1. 先写 widget 红灯：DM 从 `MenuAnchor` 打开导入对话，dry-run 显示计数，确认后导入
   当前战役；Player 不显示管理入口。
2. 实现粘贴 JSON、预览、错误展示、确认导入；不新增公开或本地持久化的 PHB 文件入口。
3. 先写角色创建红灯测试：有战役上下文时只能看到该战役启用的职业、法术和装备。
4. 让角色创建读取战役可用条目，无战役时保留内置兜底。
5. 运行 `npm run check` 与 `flutter build web --release --pwa-strategy=none`，更新
   `current-execution-status.md`，提交：`feat(0.1): use campaign wiki content in character creation`。
