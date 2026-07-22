# 已归档执行计划索引

本目录存放**已执行完成**的 superpowers 计划文件。每份计划保留完整历史，便于追溯决策与实现细节。

## 归档原则

- 计划对应的功能已交付并通过验证（测试/lint/构建）。
- 计划对应的里程碑已在 `docs/roadmap/current-execution-status.md` 登记，或已整合进 `offline-first-0.1` 主线。
- 复选框状态以归档时的真实状态为准：部分计划因后续合并/迭代未回填复选框，但其功能已实际完成。
- 含未完成尾项的计划在下方"含未完成尾项"小节单独标注。

## 已归档计划（按执行时间倒序）

### 2026-07-23 并行批次（4 份并行计划 + 1 份高频减负）

| 文件 | 主题 | 状态 |
|---|---|---|
| `2026-07-23-parallel-settings-theme.md` | 设置持久化与全局 Material 3 | 已完成（合并进 offline-first-0.1） |
| `2026-07-23-parallel-content-library.md` | 只读资料库与分类检索 | 已完成 |
| `2026-07-23-parallel-character-experience.md` | 角色卡密度与创建向导 | 已完成 |
| `2026-07-23-parallel-campaign-center.md` | 战役中心与档案 Wiki | 已完成（含最终报告与整合审查处置） |
| `2026-07-23-high-frequency-ui-simplification.md` | 高频界面减负 | 7/8 完成，1 项（战役中心区块间距）推迟到 P0 收尾 |

### 2026-07-22 壳层重构批次

| 文件 | 主题 | 状态 |
|---|---|---|
| `2026-07-22-character-presentation-shell-refactor.md` | 角色呈现壳层重构 | 已完成 |
| `2026-07-22-character-content-density.md` | 角色卡内容密度 | 已完成 |
| `2026-07-22-campaign-conversations.md` | 战役可展开会话卡片 | 已完成 |
| `2026-07-22-campaign-chat-shell-ui-refactor.md` | 战役聊天壳层 UI 重构 | 已完成 |
| `2026-07-22-global-material3-design-system.md` | 全局 M3 视觉系统（早期规划，后被并行计划执行） | 已完成 |
| `2026-07-22-settings-reliability-material3.md` | 设置可靠性与 M3 设置页（早期规划，后被并行计划执行） | 已完成 |

### 2026-07-18 加固与统一批次

| 文件 | 主题 | 状态 |
|---|---|---|
| `2026-07-18-campaign-rules-integration-hardening.md` | 战役规则联动加固 | 已完成 |
| `2026-07-18-unified-campaign-workspace.md` | 统一战役工作区 | 已完成 |

### 2026-07-16 至 2026-07-17 批次

| 文件 | 主题 | 状态 |
|---|---|---|
| `2026-07-17-workspace-spec-compliance-fixes.md` | 工作区规范合规整改 | 已完成 |
| `2026-07-16-character-sheet-unification.md` | 角色卡信息架构统一 | 已完成 |
| `2026-07-16-character-experience-redesign.md` | 角色体验重设计 | 已完成 |
| `2026-07-16-campaign-workspace-client.md` | 聊天优先战役客户端 | 已完成 |
| `2026-07-16-campaign-foundation-and-media.md` | 战役协作地基与身份 | 已完成 |
| `2026-07-16-campaign-character-integration.md` | 战役角色集成 | 已完成 |
| `2026-07-16-campaign-center-archives.md` | 战役中心档案记录（早期规划） | 已完成 |
| `2026-07-16-auto-login.md` | 正式自动登录 | 已完成 |

### 2026-07-14 至 2026-07-15 离线基础批次

| 文件 | 主题 | 状态 |
|---|---|---|
| `2026-07-15-dnd2024-rules-driven-characters.md` | D&D 2024 规则驱动角色 | 已完成 |
| `2026-07-14-local-compendium.md` | 本地完整资料库 | 已完成 |
| `2026-07-14-local-characters-vault.md` | 本地角色与 Vault | 已完成 |
| `2026-07-14-campaign-actors-content.md` | 战役角色资料聊天协作 | 已完成 |
| `2026-07-14-offline-foundation.md` | 离线基础设施 | 已完成 |

### 2026-07-10 至 2026-07-13 早期批次

| 文件 | 主题 | 状态 |
|---|---|---|
| `2026-07-13-campaign-content-wiki.md` | 战役资料库 Wiki | 已完成 |
| `2026-07-10-v1.1-character-settings-ui.md` | v1.1 角色/设置/M3 UI（最早规划） | 已完成 |

## 含未完成尾项的计划

以下计划主体已完成，但保留明确的未完成尾项，需在后续路线图中追踪：

- `2026-07-23-high-frequency-ui-simplification.md`：战役中心区块间距与层级推迟到 P0 收尾批次。
- `2026-07-23-parallel-campaign-center.md`：档案实时同步/聊天回链/附件上传/角色卡跳转列入第二波整合（详见计划末尾"最终报告"与"整合审查发现处置"）。

## 配套设计文档

设计文档（`docs/superpowers/specs/`）不随计划归档，保留在原位作为设计参考。
