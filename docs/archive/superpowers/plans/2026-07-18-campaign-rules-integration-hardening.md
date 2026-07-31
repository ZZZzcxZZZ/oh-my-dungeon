# 战役与规则联动加固实施计划

> 全部行为变更遵循红-绿-重构；每个批次先运行目标测试，再进入下一批。

## 批次 1：资料关系与子职业

- 为 Drift 条目表增加 `relationsJson`，数据库升至版本 7 并添加迁移。
- 写入和读出 `ContentEntry.relations`。
- 增加 Repository 往返测试和真实私有包安装后 12 职业解析测试。
- 更新资料格式文档的持久化及 facet 约定。

## 批次 2：聊天身份和 Character 状态

- 服务端旁白消息快照固定为旁白身份。
- 客户端增加 narrator 消息样式。
- 提取统一 Character 健康状态解析器，精确 sheet 优先。
- 修复头像生命环的外圈布局并覆盖小尺寸输入栏头像。

## 批次 3：完整角色卡与 DM 工具

- 增加 Character -> CharacterSheet 投影适配器。
- 战役 Character 保存、运行时和库存更新回写同一 Character controller。
- 所有头像和角色条目复用统一 launcher。
- DM 检定改为直接掷骰消息。
- 聊天资料详情改用统一浮动阅读器。

## 批次 4：概览信息架构

- 把平铺 ListTile 重排为摘要、统计、邀请、成员、DM 工具、设置六段。
- 为窄屏和宽屏补 Widget 测试，检查无溢出及权限可见性。

## 批次 5：创建器和资料筛选

- 新增纯领域 `AbilityScoreGenerator`，实现标准数组、购点和随机生成。
- 属性步骤增加紧凑 segmented control、预算和重新生成操作。
- 规则步骤显示 grants、choices 和数据诊断。
- `ContentQuery` 增加 facets；资料库增加法术环位、学派、职业筛选。

## 批次 6：验收

- Flutter 目标测试、全量单并发测试和 analyze。
- 服务端目标测试、全量测试和 lint。
- 私有资料校验、Web 构建、浏览器窄屏/桌面验收。
- 验证私人测试构建脚本会注入资料并在结束后恢复公开占位；APK 与 Linux 分发产物留给独立发布任务。

## 执行结果（2026-07-18）

- 批次 1–5 已实现并通过目标测试。
- Flutter 全量：520 passed，2 skipped（通用套件未传私有路径）；私有包真实路径专项：2 passed。
- 服务端全量：334 passed；Flutter analyze、服务端 lint、Docker Compose 和 diff check 全绿。
- 公开 Web 与内嵌 1106 条私有资料的私人 Web release 均构建成功，临时 asset 已恢复。
- 浏览器自动截图验收因本机浏览器控制沙箱初始化失败未执行；本地站点 HTTP 200，宽窄屏 Widget 测试通过。
- APK 与 Linux 服务端分发包不属于本轮行为修复产物，继续复用现有发布脚本按需生成。
