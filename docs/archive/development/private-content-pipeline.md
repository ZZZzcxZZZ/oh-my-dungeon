# 私有资料流水线（本地专用）

本页说明如何在本机提取、校验并构建**包含商业规则正文**的私有测试产物。这些产物
仅供本地自用与自托管测试，**不得提交、分发或用于公开构建**。

> 硬约束：公开仓库、公开构建与公开分发不包含任何商业规则正文。CI 与
> `npm run check` 只跑公开代码路径，不接触 `private-imports/`。

## 目录与忽略规则

```text
private-imports/                       # 已被 .gitignore 排除，本地私有资料
  phb-2024-v2/          + phb-2024-v2-bundle.json
  mm-2024-v1/           + mm-2024-v1-bundle.json
  dmg-2024-items-v1/    + dmg-2024-items-v1-bundle.json
  private-test-all-bundle.json         # build_private_client 聚合中间产物
apps/client_flutter/assets/bundled_content.json
                                       # 公开构建恒为 {}，私有构建临时注入后恢复
```

`apps/server_nest/engines/` 同样被忽略，但它是**服务端部署包**的必需构建输入，
与私有资料无关，见文末「离线 Prisma 引擎」。

## 1. 提取（从自有副本生成私有包）

按需运行，输出写入 `private-imports/`：

| 脚本 | 用途 |
|---|---|
| `python scripts/extract_phb_2024_v2.py` | 玩家手册 2024 → 结构化 v2 包 |
| `python scripts/extract_monster_manual_private.py` | 怪物图鉴 → 怪物模板包 |
| `python scripts/extract_dmg_2024_items.py` | 城主指南物品 → 物品包 |
| `python scripts/generate_phb_private_index.py` | 生成目录/页码索引包（不含正文） |
| `python scripts/extract_phb_from_chm.py` | 旧 CHM 来源的一次性提取（历史工具，新流程用 v2） |
| `python scripts/check_subclass.py` | 校验子职业数据完整性（关系、进度、特性数量） |

## 2. 校验

```powershell
npm run validate:phb-private     # PHB 包 schema/引用/规则 + 真实 Flutter 导入验证
npm run test:scripts             # 脚本层单测（打包、预览服务、提取器）
npm run test:phb-tools           # PHB 工具链单测
```

## 3. 构建私有客户端

`scripts/build_private_client.ps1` 会聚合三个包 → 覆盖 `bundled_content.json` →
执行 `flutter build <target>` → **在 finally 中恢复公开占位文件**。

```powershell
# 仅内嵌资料
pwsh -File scripts/build_private_client.ps1 -Target apk -BuildArgs --release

# 内嵌资料 + 内嵌默认服务器（首启自动加入并设为默认）
pwsh -File scripts/build_private_client.ps1 -Target apk -BuildArgs @(
  '--release',
  '--dart-define=BUNDLED_DEFAULT_SERVER=true',
  '--dart-define=DEFAULT_SERVER_BASE_URL=http://<host>:3000'
)
```

- `-Target`：`apk` / `web` / `windows` / `linux` / `macos`
- 默认服务器开关由 `BundledDefaultServerSeeder` 消费；测试与公开构建默认关闭，
  保持「无服务器也能离线使用」的语义。
- 产物落在 `apps/client_flutter/build/...`；分发副本建议存放 `dist/`（已忽略）。

## 4. 构建服务端 Linux 部署包

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-linux-server-package.ps1
```

产物：`dist/ohmydungeon-server-linux-0.1.0.tar.gz`（含 compose、`.env.example`、
`start.sh`、服务端源码与 `engines/`）。

脚本在缺少 `apps/server_nest/engines/` 时会**立即失败**，避免镜像构建到
`prisma generate` 才报错。

## 5. 离线 Prisma 引擎

`apps/server_nest/engines/` 提供 linux-musl 引擎，使 Docker 构建与运行期不依赖
外网下载。恢复方式（与 `node_modules/@prisma/engines` 中的二进制逐字节一致）：

```powershell
cd apps/server_nest
npm ci
npx prisma generate
Copy-Item node_modules\@prisma\engines\schema-engine-linux-musl-openssl-3.0.x engines\
Copy-Item node_modules\@prisma\engines\libquery_engine-linux-musl-openssl-3.0.x.so.node engines\
```

> Windows 打包会丢失可执行位，`Dockerfile` 已在构建与运行阶段执行
> `chmod +x engines/*`；修改 Dockerfile 时不要删除这两行。

## 6. 合规检查清单

- [ ] `private-imports/` 与 `dist/` 未进入 `git status`；
- [ ] 构建结束后 `apps/client_flutter/assets/bundled_content.json` 为 `{}`；
- [ ] 未把私有产物上传到公开 Release、镜像仓库或第三方网盘；
- [ ] 分享 APK/Web 产物前确认其中不含商业规则正文。
