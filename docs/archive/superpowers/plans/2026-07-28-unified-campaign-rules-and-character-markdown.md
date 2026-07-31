# 统一战役、规则构筑与 Character Markdown 实施计划

**规格：** `docs/superpowers/specs/2026-07-28-unified-campaign-rules-and-character-markdown-design.md`

## Phase 1：消息身份与统一命令

1. 为显式消息身份封包增加服务端失败测试。
2. 扩展消息 DTO 与发送服务，保存不可变身份和 HP 快照。
3. 更新 Flutter API 模型和发送链，移除成员身份的隐式推断。
4. 增加四种身份切换与临时身份不落 Character 的 Widget/E2E 测试。
5. 提取 `CampaignCommandCatalog`，让头像面板和战役中心共用。
6. 接入伤害/治疗、给予物品、添加状态和直接检定。

## Phase 2：Material 3 UI 收敛

1. 为 360/600/1024 px 输入栏写布局测试。
2. 重构 `CampaignChatComposer` 和头像工具 BottomSheet。
3. 提取 `KnowledgeEntryPreview`，迁移内容库和战役档案。
4. 重构内容库筛选摘要与 BottomSheet。
5. 整理战役展开卡片和设置页；隐藏无实现入口。
6. 使用浏览器截图检查移动端和桌面端。

## Phase 3：声明式角色创建

1. 为自定义职业资料夹具增加法术、装备、子职业和等级特性测试。
2. 扩展 v2 choice/structured 解析模型，保留未知字段。
3. 删除按职业名称判断法术资格的路径。
4. 将法术数量、环位和法表过滤全部改为 choice 解析结果。
5. 将装备步骤改为价格列表、数量选择、详情预览和预算提示。
6. 增加无自动规则职业的手工回退提示。

## Phase 4：Character Markdown 与模板实例

1. 定义 `CharacterDocument`、`CharacterKind` 和模板引用模型。
2. 先写 Markdown 解析、校验、往返和错误提示测试。
3. 实现 `dnd-table-character/v1` 解析器与导出器。
4. 角色库增加 Markdown 导入预览与导出入口。
5. 角色卡外壳支持 player/npc/monster/companion 专属区块。
6. 从怪物模板创建可编辑本地 Character，并可发布到战役。
7. 物品模板授予后生成独立物品实例。

## Phase 5：私有提取与兼容清理

1. 编写 GB2312/GBK CHM HTML 怪物 stat-block 提取器。
2. 编写城主指南 2024 魔法物品提取器。
3. 输出到 `private-imports/mm-2024-v1` 与 `private-imports/dmg-2024-items-v1`。
4. 执行 schema、引用和真实 Flutter 导入校验。
5. 修复人工复核项，并生成不含正文的统计报告。
6. 删除重复详情、硬编码规则和临时 Character 新建路径。
7. 对 `CharacterCampaignBinding` 与旧 CheckRequest 做引用清零后迁移。

## Phase 6：验证

1. 运行相关 Dart 与 Nest 测试。
2. 运行 `npm run lint:server` 与 `flutter analyze`。
3. 运行 `npm run doctor`。
4. 构建注入私有资料包的 Web 测试版。
5. 在 360、600、1024 px 完成聊天、筛选、角色创建和 Markdown 导入截图验收。
