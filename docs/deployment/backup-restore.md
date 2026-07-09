# 备份与恢复

本文档面向 v1.0 自托管部署。目标是让 DM 或服务器管理员能把数据迁移到另一台机器，或在升级前做可恢复备份。

## 需要备份什么

必须备份：

- PostgreSQL 数据库。
- `.env` 配置文件。
- `uploads` 目录（当前版本预留上传目录；即使为空也建议保留结构）。

建议一起记录：

- 当前 Git commit 或 Docker image tag。
- `docker compose config` 输出。
- 服务器域名和反向代理配置。

## Docker Compose 备份

在项目根目录执行：

```bash
mkdir -p backups
docker compose exec -T postgres pg_dump -U dnd -d dnd_table > backups/dnd_table_$(date +%Y%m%d_%H%M%S).sql
tar -czf backups/uploads_$(date +%Y%m%d_%H%M%S).tar.gz uploads .env
```

Windows PowerShell 可使用：

```powershell
New-Item -ItemType Directory -Force backups | Out-Null
docker compose exec -T postgres pg_dump -U dnd -d dnd_table | Out-File -Encoding utf8 backups\dnd_table.sql
tar -czf backups\uploads_and_env.tar.gz uploads .env
```

## 恢复

先停止服务端，保留数据库容器：

```bash
docker compose stop server
```

恢复数据库：

```bash
cat backups/dnd_table.sql | docker compose exec -T postgres psql -U dnd -d dnd_table
```

恢复 `.env` 和 uploads：

```bash
tar -xzf backups/uploads_and_env.tar.gz
```

重启并检查：

```bash
docker compose up -d
curl http://localhost:3000/health
```

## 升级前建议流程

1. 运行一次备份。
2. 记录当前 tag：`git describe --tags --always`。
3. 拉取新版本。
4. 执行 `docker compose up -d --build`。
5. 检查 `/health` 和 `/.well-known/dnd-tool-server`。
6. 登录客户端，确认战役、场次、内容库和角色卡可见。

## 注意事项

- 不要把 `.env` 提交到 Git。
- `JWT_SECRET` 丢失会导致旧 token 失效，但不会删除用户数据。
- 恢复到旧版本前先确认 Prisma schema 是否兼容。
- 生产环境建议定期把备份复制到另一台机器或对象存储。
