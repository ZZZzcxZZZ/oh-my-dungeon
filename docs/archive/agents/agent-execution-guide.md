# Agent 执行指南

## 必读顺序

1. `README.md`
2. `AGENTS.md`
3. `docs/README.md`
4. `docs/roadmap/current-execution-status.md`
5. `docs/superpowers/specs/2026-07-29-private-workspaces-and-campaign-convergence-design.md`
6. 与任务直接相关的 `docs/architecture/`、`docs/content/` 或 `docs/deployment/` 文档

`docs/archive/` 只用于追溯，不能作为当前待办或现行接口依据。

## 当前硬约束

- 对外版本统一为 `0.1`。
- 领域统一称 Character，不新增 Actor 产品接口。
- 战役是长期聊天和协作工作区，不恢复 Room/Session 前置流程。
- 客户端离线优先；只有战役协作和可选 Vault 同步需要服务器。
- UI 与未来 Agent 必须调用相同业务接口，不能直接修改数据库。
- 当前不实现战斗系统、AI Agent 运行时或通用 TRPG 引擎。
- 商业规则正文不得提交到公开仓库或公开构建。
- `private-imports/` 只供本地私人验证。

## 实施方式

1. 先阅读现有代码和测试，确认所有权边界。
2. 为行为变化先增加失败测试。
3. 通过业务服务修改状态，并记录结构化事件。
4. 复用 Material 3 主题和共享组件。
5. 不暴露没有完整实现的入口。
6. 只删除经 `rg` 和静态分析确认没有消费者的代码。
7. 不覆盖工作树中来源不明的用户或其他 Agent 改动。

## 验证

常规改动至少运行相关测试和静态分析。阶段收口运行：

```powershell
npm run check
npm --prefix apps/server_nest run build
$env:DATABASE_URL='postgresql://dnd:dnd@localhost:5432/dnd_table?schema=public'
Push-Location apps/server_nest
npx prisma validate
Pop-Location
git diff --check
```

私人内容只使用专用脚本验证和构建：

```powershell
npm run validate:phb-private
pwsh -File scripts/build_private_client.ps1 -Target web -BuildArgs --release
```
