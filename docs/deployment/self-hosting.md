# 自托管与部署规划

## 1. 部署目标

项目支持三种使用方式：

- 本地开发：给开发者调试 Flutter、NestJS 和 PostgreSQL。
- 朋友团自托管：DM 或社群管理员在 VPS、NAS 或家用服务器上一键部署。
- 公共服务器：有人愿意运营一个面向多人注册的服务器。

首版优先级：

1. Docker Compose 自托管。
2. 本地开发体验。
3. 公共服务器管理能力预留。

## 2. 运行组件

MVP 组件：

```text
NestJS Server
PostgreSQL
```

可选组件：

```text
Caddy 或 Nginx
```

暂不引入 Redis。WebSocket 在线状态先存在服务端内存，关键事件全部落库。未来需要多实例部署时再引入 Redis Pub/Sub。

## 3. Docker Compose

应提供：

```text
docker-compose.yml
docker-compose.dev.yml
.env.example
```

生产自托管版包含：

```text
server
postgres
```

HTTPS 参考版包含：

```text
server
postgres
caddy
```

## 4. 环境变量

`.env.example` 至少包含：

```text
SERVER_NAME=My DnD Table
PUBLIC_BASE_URL=https://dnd.example.com
DATABASE_URL=postgresql://dnd:dnd@postgres:5432/dnd
JWT_SECRET=change-me
REGISTRATION_ENABLED=true
DEFAULT_LOCALE=zh-CN
UPLOAD_DIR=/data/uploads
MAX_UPLOAD_SIZE_MB=20
```

## 5. 一键部署流程

v1.0 推荐流程：

```bash
git clone https://github.com/<your-org>/dnd-table-tool.git
cd dnd-table-tool
cp .env.example .env
docker compose up -d
curl http://localhost:3000/health
```

如果需要修改端口、域名或数据库密码，先编辑 `.env`，再执行 `docker compose up -d`。

常用维护命令：

```bash
docker compose ps
docker compose logs -f server
docker compose config
docker compose pull
docker compose up -d --build
```

## 6. 服务器发现

服务端提供：

```text
GET /health
GET /.well-known/dnd-tool-server
```

示例响应：

```json
{
  "name": "某某跑团服务器",
  "version": "0.1.0",
  "apiBaseUrl": "https://example.com/api",
  "websocketUrl": "wss://example.com/realtime",
  "registrationEnabled": true,
  "serverMode": "self_hosted",
  "supportedSystems": ["dnd5e"]
}
```

客户端添加服务器时先请求该接口，确认服务器兼容。

## 7. 客户端多服务器配置

客户端本地保存：

```text
serverProfiles
activeServerId
perServerAuthTokens
perServerCachedUser
perServerClientMode
perServerRecentCampaigns
```

账号、token、缓存和偏好按服务器隔离。切换服务器时，用户、战役列表和默认模式跟随服务器切换。

## 8. 备份

详见 [备份与恢复](backup-restore.md)。

最小备份对象：

```text
PostgreSQL 数据库
uploads 目录
.env 配置文件
```

备份脚本职责：

1. 使用 pg_dump 导出数据库。
2. 打包 uploads。
3. 提示用户保存 .env。
4. 输出带时间戳的备份目录。

恢复脚本职责：

1. 停止 server 容器。
2. 恢复数据库。
3. 恢复 uploads。
4. 启动 server 容器。
5. 检查 /health。

## 9. 升级策略

升级时关注：

- Docker image tag。
- Prisma migrate。
- 基础内容包版本。
- content package schemaVersion。
- Flutter 客户端兼容范围。

推荐升级流程：

1. 先按 `backup-restore.md` 做备份。
2. 拉取新 tag 或新镜像。
3. 执行 `docker compose up -d --build`。
4. 检查 `/health`。
5. 用客户端登录并检查战役、场次、角色、内容库和日志。

服务端启动时应检查：

- 必要环境变量。
- 数据库连接。
- 数据库迁移状态。
- 上传目录权限。
- 基础内容包版本。

## 10. 反向代理提示

生产环境建议把 NestJS server 放在 Caddy、Nginx 或同类反向代理后面。

需要转发：

- HTTP API：`/api/*`
- 服务器发现：`/.well-known/dnd-tool-server`
- 健康检查：`/health`
- WebSocket：`/sessions`

反向代理必须保留 WebSocket upgrade headers。公开域名应与 `.env` 中的 `PUBLIC_BASE_URL` 保持一致。

## 11. 开源项目文件

仓库根目录应包含：

```text
README.md
LICENSE
CONTRIBUTING.md
CODE_OF_CONDUCT.md
SECURITY.md
CHANGELOG.md
.env.example
docker-compose.yml
```

部署文档应覆盖：

- Docker Compose 部署。
- 反向代理配置。
- HTTPS 配置。
- 备份恢复。
- 版本升级。
- 客户端添加服务器。

## 12. 许可证建议

如果希望改动回流，建议 AGPL-3.0。

如果希望传播和二次使用门槛更低，建议 MIT。

正式开源前需要确认许可证。该决策会影响社区贡献、商用集成和托管服务形态。
