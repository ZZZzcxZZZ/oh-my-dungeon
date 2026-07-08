# 本地开发环境

## 推荐工具版本

- Flutter：稳定版，当前已验证 `3.41.4`
- Dart：随 Flutter SDK 安装，当前已验证 `3.11.1`
- Node.js：推荐 `22 LTS`，仓库通过 `.nvmrc` 和 `.node-version` 声明
- npm：推荐 `10+`
- Docker Desktop：可选，但自托管部署和 Compose 校验需要它

当前开发机上 Node.js 是 `24.14.0`，在 `package.json` 中允许 `>=22 <25`，但开源协作时推荐使用 Node 22 LTS 作为默认开发版本。

## 首次启动

在仓库根目录执行：

```powershell
npm run bootstrap
```

它会完成三件事：

1. 安装 NestJS 服务端依赖；
2. 生成 Prisma Client；
3. 获取 Flutter 客户端依赖。

如果你不使用 PowerShell，也可以手动执行：

```bash
npm --prefix apps/server_nest install
npm --prefix apps/server_nest run prisma:generate
cd apps/client_flutter
flutter pub get
```

## 日常检查

```powershell
npm run check
```

这会依次运行：

- 服务端 lint；
- Flutter analyze；
- 服务端和客户端测试；
- 如果本机存在 Docker CLI，则额外校验 `docker compose config`。

## 本地开发

服务端：

```powershell
npm run dev:server
# 或 scripts/dev-server.ps1
```

客户端：

```powershell
npm run dev:client
# 或 scripts/dev-client.ps1
```

## VS Code

仓库提交了共享的 `.vscode/settings.json` 和 `.vscode/extensions.json`。建议安装推荐扩展后再开发 Flutter、NestJS、Prisma 相关代码。