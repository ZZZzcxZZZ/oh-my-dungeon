# 系统架构设计

## 1. 总体架构

项目采用 monorepo + 模块化单体服务端。

```text
dnd-table-tool/
  apps/
    client_flutter/
    server_nest/
  packages/
    api_contracts/
    dnd_rules/
  docs/
  infra/
  scripts/
```

## 2. 技术栈

### 2.1 客户端

- Flutter
- Material 3
- go_router
- Riverpod
- freezed
- json_serializable
- dio
- web_socket_channel
- flutter_secure_storage 或等价安全存储

### 2.2 服务端

- NestJS
- PostgreSQL
- Prisma
- JWT
- REST
- WebSocket Gateway
- OpenAPI / Swagger

### 2.3 部署

- Docker Compose
- PostgreSQL volume
- 可选 Caddy 或 Nginx 反向代理

## 3. Monorepo 目录职责

```text
apps/client_flutter
  Flutter 多端客户端。

apps/server_nest
  NestJS 服务端，可通过 Docker 部署。

packages/api_contracts
  OpenAPI 文件、WebSocket 事件协议、共享 DTO 生成配置。

packages/dnd_rules
  D&D 5e 规则计算核心，优先沉淀纯函数和可测试逻辑。

docs
  产品规划、架构设计、部署文档、开发指南和决策记录。

infra
  Docker Compose、反向代理配置样例、数据库初始化相关文件。

scripts
  开发、安装、更新、备份、恢复脚本。
```

## 4. Flutter 客户端结构

客户端采用 feature-first 结构。

```text
lib/
  app/
    app.dart
    router.dart
    theme.dart
  core/
    network/
    realtime/
    storage/
    errors/
    widgets/
  features/
    server_profiles/
    auth/
    campaigns/
    table/
    character_sheet/
    compendium/
    dm_panel/
    settings/
```

### 4.1 客户端模块边界

- app：应用启动、主题、路由、全局 provider。
- core/network：REST 客户端、拦截器、错误映射。
- core/realtime：WebSocket 连接、重连、事件分发。
- core/storage：服务器配置、token、偏好和缓存。
- server_profiles：添加、编辑、测试和切换服务器。
- auth：登录、注册、当前用户状态。
- campaigns：战役列表、创建、加入、成员关系。
- table：跑团桌面、聊天、骰子、事件流、在线成员。
- character_sheet：角色卡、角色列表、角色创建和编辑。
- compendium：资料库浏览、搜索、引用和内容详情。
- dm_panel：DM 战役工作台、成员、遭遇、NPC、内容管理入口。
- settings：模式切换、主题、服务器、账号设置。

### 4.2 Material 3 使用原则

客户端尽量使用官方 Material 3 组件：

- NavigationBar
- NavigationRail
- ListTile
- Card
- FilledButton
- IconButton
- SegmentedButton
- DropdownMenu
- TextField
- Dialog
- BottomSheet
- MenuAnchor
- Badge

不为常规按钮、选择器、导航和表单发明自定义组件。自定义组件只用于角色卡、骰子结果、先攻队列和资料条目等领域特定 UI。

## 5. NestJS 服务端结构

服务端采用模块化单体，每个业务模块内部保持固定结构。

```text
src/modules/campaigns/
  campaigns.module.ts
  campaigns.controller.ts
  campaigns.service.ts
  campaigns.repository.ts
  dto/
  policies/
  events/
  tests/
```

### 5.1 服务端模块

- auth：注册、登录、刷新 token、会话。
- users：用户资料、偏好。
- server-settings：服务器名称、注册开关、管理员。
- campaigns：战役、成员、邀请。
- sessions：跑团会话。
- characters：角色卡、战役绑定、角色快照。
- compendium：内容包、内容条目、覆盖层、导入导出。
- chat：聊天消息。
- dice：掷骰表达式、结果、可见性。
- roll-requests：DM 检定请求。
- journal：事件流和跑团日志。
- encounters：遭遇、参与者、先攻队列。
- effects：状态和临时效果。
- npcs：NPC 与怪物实例。
- realtime：WebSocket 网关、房间广播、在线状态。
- files：头像、附件和未来地图资源。

### 5.2 层职责

- controller：HTTP 入参、认证上下文和返回 DTO。
- service：业务流程编排。
- repository：Prisma 查询封装。
- policy：权限判断。
- event：领域事件、Journal 写入和 WebSocket 广播。
- dto：输入输出契约。

Controller 不直接访问 Prisma。Service 不直接信任客户端传来的角色或权限。所有写操作必须走 policy。

## 6. REST 与 WebSocket 分工

REST 负责稳定资源：

- 登录注册
- 服务器元信息
- 战役、成员、邀请
- 角色 CRUD
- 内容库查询、导入、启用、覆盖
- 日志查询
- 遭遇管理

WebSocket 负责实时事件：

- 聊天消息实时分发
- 掷骰结果实时分发
- 检定请求和响应
- 在线成员
- HP、状态、资源变化
- 遭遇开始、回合推进、遭遇结束

关键实时事件必须落库。WebSocket 不是数据的唯一来源。

## 7. 数据一致性原则

1. 权限以服务端数据库为准。
2. 重要业务状态落 PostgreSQL。
3. WebSocket 只作为实时同步通道，不作为持久层。
4. JournalEntry 记录关键事件，支撑回顾、检索和审计。
5. 运行时实例保存必要快照，避免基础资料更新影响已发生事件。

## 8. 可扩展原则

新增功能必须优先回答四个问题：

1. 它属于哪个业务模块。
2. 它是否需要 REST 契约。
3. 它是否需要 WebSocket 事件。
4. 它是否需要写 JournalEntry。

如果一个功能跨越多个模块，应通过领域事件连接，而不是让模块互相读写内部实现。

