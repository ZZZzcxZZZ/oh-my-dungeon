# 工程规范

## 1. 工程目标

项目以高度工程化为核心要求：

- 模块边界清晰。
- 接口契约稳定。
- 核心逻辑有自动化测试。
- 代码风格统一。
- 部署流程可重复。
- 新功能可以按固定模板加入。

## 2. 根目录脚本

根目录提供统一脚本入口，具体实现可委托给 Flutter、NestJS 和 Docker。

建议脚本：

```text
dev:server
dev:client
test
lint
format
docker:up
docker:down
docker:logs
```

## 3. 服务端规范

### 3.1 模块结构

每个业务模块采用固定结构：

```text
module-name/
  module-name.module.ts
  module-name.controller.ts
  module-name.service.ts
  module-name.repository.ts
  dto/
  policies/
  events/
  tests/
```

### 3.2 层级约束

- controller 不直接访问 Prisma。
- service 不直接读取 HTTP request。
- repository 不做权限判断。
- policy 是权限判断唯一入口。
- event 层负责 JournalEntry 和 WebSocket 广播。

### 3.3 权限策略

服务端提供统一 policy 方法：

```text
canCreateCampaign(user)
canManageCampaign(user, campaignId)
canJoinCampaign(user, inviteCode)
canEditCharacter(user, characterId)
canViewCampaignContent(user, campaignId)
canSendDmOnlyMessage(user, campaignId)
canManageEncounter(user, encounterId)
```

写操作必须调用 policy。客户端传入的 role 不可信。

## 4. Flutter 规范

### 4.1 Feature-first 结构

```text
features/characters/
  data/
    character_api.dart
    character_repository.dart
    character_dto.dart
  domain/
    character.dart
    character_calculator.dart
  presentation/
    character_list_page.dart
    character_sheet_page.dart
    widgets/
```

### 4.2 客户端约束

- 页面不直接调用 Dio。
- 页面通过 Riverpod provider 读取状态。
- 业务计算放 domain。
- REST 调用放 data。
- 可复用 Material 组件放 core/widgets。
- 角色卡、掷骰结果、先攻队列等领域 UI 放各自 feature。

### 4.3 Material 3 约束

- 使用 ThemeData(useMaterial3: true)。
- 主导航使用 NavigationBar 或 NavigationRail。
- 表单使用 TextField、DropdownMenu、SegmentedButton。
- 命令使用 FilledButton、IconButton、MenuAnchor。
- 不使用大量自绘控件替代官方组件。

## 5. API 契约

服务端暴露：

```text
/api/docs
/openapi.json
```

REST 契约以 OpenAPI 为准。Flutter 端应尽量从 OpenAPI 生成 DTO 或 API client，至少保证 DTO 字段由契约驱动。

WebSocket 事件在 `docs/architecture/api-realtime-boundary.md` 中维护。每个事件必须说明：

- eventName
- direction
- payload
- permission
- persistence
- broadcastScope

## 6. 测试策略

### 6.1 服务端单元测试

必须覆盖：

- 骰子表达式解析。
- 权限策略。
- 内容包导入校验。
- 内容覆盖层解析。
- 角色常用计算。
- JournalEntry 生成。

### 6.2 服务端集成测试

必须覆盖：

- 注册和登录。
- 创建战役。
- 邀请码加入战役。
- 创建角色并绑定战役。
- 创建 Session。
- 发送骰子事件。
- DM 暗骰可见性。

### 6.3 Flutter 测试

必须覆盖：

- 服务器添加和测试连接。
- 不同服务器 token 隔离。
- 角色常用计算。
- 掷骰表达式。
- 登录页。
- 战役列表页。
- 角色卡关键组件。

## 7. CI

GitHub Actions 首版流程：

```text
server lint
server test
flutter analyze
flutter test
docker build
```

后续增强：

- OpenAPI diff 检查。
- 数据库迁移检查。
- Flutter 多平台构建。
- Docker image 发布。

## 8. 代码生成

Flutter：

- freezed
- json_serializable
- riverpod_generator 可选
- go_router_builder 可选

服务端：

- Prisma Client
- Swagger/OpenAPI

内容包：

- JSON Schema

## 9. 领域事件

服务端关键动作产生领域事件：

```text
CampaignCreated
CampaignMemberJoined
SessionStarted
DiceRolled
RollRequestCreated
CharacterHpChanged
EffectAdded
EncounterStarted
TurnAdvanced
ContentPackageImported
```

领域事件用于：

- 写 JournalEntry。
- 推 WebSocket。
- 触发通知。
- 形成审计记录。

## 10. 提交和版本

建议使用 Conventional Commits：

```text
feat:
fix:
docs:
test:
refactor:
chore:
ci:
```

当前版本策略：

```text
0.1.0 统一 MVP 开发线
```

历史文档中出现的 `v0.2.0`、`v0.4.0`、`v0.8.0`、`v1.x` 和 `v2.x` 只作为内部迭代记录保留，不代表已经对外封版。后续开发、测试和文档默认都归入 `0.1`，可用 `0.1-chat-01`、`0.1-content-02` 这类内部任务名表达顺序。
