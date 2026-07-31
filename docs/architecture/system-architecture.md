# 系统架构设计

## 1. 总体架构

项目采用 monorepo、Flutter 离线优先客户端和 NestJS 模块化单体服务端。

```text
dnd-table-tool/
  apps/client_flutter/   Flutter 多端客户端
  apps/server_nest/      NestJS + Prisma 服务端
  docs/                  产品、架构、计划与部署文档
  infra/                 Docker Compose 与部署配置
  scripts/               验证、私有测试构建和分发脚本
```

客户端本地功能不依赖服务器。服务器负责账号、战役聊天室、战役 Character/资料/档案/遭遇协作，以及用户主动启用的 Personal Vault。

## 2. 技术栈现状

### 客户端

- Flutter + Material 3
- Drift / SQLite 本地数据库
- `http` REST 客户端
- `socket_io_client` 战役实时通知
- ChangeNotifier/controller 形式的轻量状态管理
- `file_picker`、`archive`、`crypto` 用于资料导入和本地备份

项目当前未采用 Riverpod、go_router、freezed 或 dio。新增代码应遵循现有 controller、repository 和 Navigator 结构，除非另有已批准的迁移计划。

### 服务端与部署

- NestJS、PostgreSQL、Prisma、JWT、Socket.IO
- Docker Compose；可选 Caddy/Nginx 反向代理

## 3. Flutter 边界

客户端使用 feature-first 目录：

```text
lib/src/
  core/                  数据库、网络、同步、通用展示
  features/
    app_preferences/
    auth/
    campaigns/
    characters/
    client_mode/
    content/
    encounters/
    server_home/
    server_profiles/
    vault/
```

- `characters`：个人本地角色和规则投影。
- `content`：本地资料包、Wiki、收藏、笔记和导入；正文只在客户端。
- `campaigns`：联网工作区、聊天、Character、战役资料和 cursor 缓存。
- `encounters`：战役内 DM 控场。
- `vault`：可选个人跨设备同步，不得同步资料正文。
- `client_mode`：本机界面偏好，不是权限来源。

本地角色、资料和设置以 Drift 为事实源。战役 Character 是服务器角色快照，本地通过 backlink 和 revision 做双向同步，冲突必须显式解决。

## 4. NestJS 模块

当前挂载模块：

- `auth`、`server-settings`、`server-info`、`health`
- `campaigns`：战役、成员、邀请、聊天、日志和档案
- `campaign-sync`：Character、战役资料和增量 change cursor
- `encounters`：NPC、遭遇和参与者
- `realtime`：campaign room、消息和变更通知
- `vault`：个人实体跨设备同步
- `media`：头像等媒体资源
- `characters`：旧服务器角色兼容与导入边界，个人角色主路径已迁到本地

`RoomsModule`、`SessionsModule`、`SessionsGateway` 和独立 `CheckRequestsModule` 已删除。Prisma 中残留的 Session/CheckRequest 表仅用于预发布数据兼容和后续迁移，不代表可调用 API。

## 5. 数据流

### 离线个人数据

```text
UI -> controller -> repository -> Drift
                         -> Vault outbox（仅允许的个人实体）
```

### 战役协作

```text
UI -> REST policy/write -> PostgreSQL transaction -> Socket.IO notice
                                                 -> HTTP cursor pull
                                                 -> Drift campaign cache
```

WebSocket 不是持久层。客户端必须能用 REST 和本地 cursor 在重连后恢复完整状态。

### 资料边界

- 本地导入包：完整正文、rules、relations、assets 留在客户端。
- Vault：只同步 manifest、收藏、笔记等允许实体。
- 战役：只同步 DM 明确创建或发布的 `CampaignContentEntry`。

## 6. 工程约束

1. 权限以服务端 policy 和 membership 为准。
2. 关键跨表写入使用事务，广播发生在提交之后。
3. Character 更新必须推进 revision；本地角色更新必须推进本地 revision。
4. 资料条目稳定 ID 和结构化 rules 是角色创建、升级、角色卡和聊天动作的共同输入。
5. Material 3 组件优先；页面状态、空态、错误态和窄屏布局必须有测试。
6. 不新增第二套 Session、角色详情、资料详情或检定模型；先复用现有统一入口。
