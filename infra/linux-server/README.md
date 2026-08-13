# OhMyDungeon Server

## 一键部署

1. 在装有 Docker Engine 和 Docker Compose v2 的 Linux 主机上解压本压缩包。
2. 运行 `chmod +x start.sh stop.sh`。
3. 运行 `./start.sh`。
4. 将终端打印的 `PUBLIC_BASE_URL` 填入客户端的「设置 → 服务器」。

首次运行 `start.sh` 会自动：
- 从 `.env.example` 创建 `.env`
- 生成随机 `JWT_SECRET` 与 `POSTGRES_PASSWORD`
- 探测本机 IP 并写入 `PUBLIC_BASE_URL`
- 构建服务器镜像
- 执行 Prisma 迁移与数据库 seed
- 等待 `/health` 通过后宣告就绪

之后再次启动只需 `./start.sh`，会复用已有的 `.env` 与数据卷。

## 常用命令

```bash
./start.sh                       # 启动（已存在则复用数据卷）
./stop.sh                        # 停止并移除容器（数据卷保留）
docker compose logs -f server    # 查看 server 实时日志
docker compose ps                # 查看容器状态
docker compose exec postgres psql -U dnd -d dnd_table  # 进入数据库
docker compose down -v           # ⚠️ 停止并删除所有数据（数据库 + 上传文件）
```

## 配置项（`.env`）

首次启动自动生成，通常无需手动修改。如需调整：

| 变量 | 说明 | 默认值 |
|---|---|---|
| `SERVER_NAME` | 服务器显示名称 | OhMyDungeon |
| `PUBLIC_BASE_URL` | 客户端连接地址 | 自动探测本机 IP |
| `POSTGRES_PASSWORD` | 数据库密码 | 自动随机生成 |
| `JWT_SECRET` | JWT 签名密钥 | 自动随机生成 |
| `REGISTRATION_ENABLED` | 是否开放注册 | true |
| `DEFAULT_LOCALE` | 默认语言 | zh-CN |
| `MAX_UPLOAD_SIZE_MB` | 上传文件大小上限（MB） | 20 |

> 改完 `.env` 后需重新运行 `./start.sh` 使其生效。

## 公网部署

对外暴露前，请完成以下配置：

1. 在 `.env` 中将 `PUBLIC_BASE_URL` 设为公网 HTTPS 地址（如 `https://dnd.example.com`）。
2. 用 nginx/caddy 等反向代理在 3000 端口前套一层 HTTPS。
3. 视情况在反向代理层加速率限制与访问控制。

PostgreSQL 端口默认仅绑定 `127.0.0.1`，不会直接暴露到公网。
