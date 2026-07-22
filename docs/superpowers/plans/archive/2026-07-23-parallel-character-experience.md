# 角色卡密度与创建向导实现计划

> **面向 AI 代理的工作者：** 使用 test-driven-development。只消费资料库公开 API，不修改资料库实现或 schema。

**目标：** 收紧角色卡信息层级，让角色创建/升级清楚区分自动授予、必选项和阻断原因。

**架构：** shell 只负责响应式导航；角色规则仍由 projector/builder/planner 计算；页面把规则结果映射为紧凑 section。编辑草稿与已保存角色分离，横竖屏切换不重建业务状态。

**技术栈：** Flutter、现有 DND 2024 rule projector、ContentRepository、flutter_test。

## 文件所有权

- 修改 `apps/client_flutter/lib/src/features/characters/**`
- 新建 `character_overview_density_test.dart`、`character_builder_choices_test.dart`、`character_responsive_state_test.dart`
- 可修改现有 character/guided builder 测试

禁止修改 `features/content`、`features/campaigns`、全局主题和服务端。

### 任务 1：角色头部与总览密度

- [x] 写失败测试覆盖 360/390/900/1280 宽度和超长角色名。
- [x] 头部只保留头像、姓名、物种、职业/子职、等级、HP、AC、先攻；属性与技能移到独立目的地。
- [x] HP 修改采用可直接输入数值的 Dialog/BottomSheet，不保留只能逐点加减的主操作。
- [x] 运行 `flutter test test/character_overview_density_test.dart test/character_sheet_shell_test.dart`。
- [x] 提交 `refactor(v0.1): tighten character overview`（commit `258e08e`）。

### 任务 2：统一业务列表

- [x] 写失败测试：动作、法术、装备、资源、特性使用同一紧凑行规范；条目点击打开已有浮层 reader；列表尾部提供明确的添加/编辑命令。
- [x] 法术按环位分组；货币位于装备顶部；资源使用多列自适应布局并支持短休/长休/不恢复。
- [x] 保持所有快速编辑调用既有 quick edit service/controller，不在 widget 内直接改 JSON。
- [x] 运行 `flutter test test/character_pages_test.dart test/character_quick_edit_service_test.dart`。
- [x] 提交 `refactor(v0.1): unify character sections`（commit `ba44fef`）。

### 任务 3：创建与升级选择

- [x] 写失败测试：职业、子职、物种、背景产生的自动授予单独显示；熟练、装备、法术等必选项未完成时不能创建。
- [x] 子职业根据职业 progression 的 choice 与 `subclassOf` 关系加载；不得硬编码职业名称或商业规则正文。
- [x] 属性生成支持标准数组、购点和随机生成，并在审核页显示来源。
- [x] 升级页面逐级显示新增特性、子职、法术与资源变化；点击关联条目使用当前 reader。
- [x] 运行 `flutter test test/guided_character_builder_test.dart test/character_upgrade_page_test.dart test/rules_driven_character_builder_test.dart`。
- [x] 提交 `feat(v0.1): clarify character rule choices`（commit `da72e76`）。

### 任务 4：响应式状态与验收

- [x] 写测试：旋转和宽度变化后保持当前 section、向导步骤和未保存草稿。
- [x] 360/390 使用紧凑步骤导航，900 以上使用 NavigationRail 与固定摘要列。
- [x] 运行全部 `test/character_*_test.dart`、`guided_character_builder_test.dart`、`rules_driven_character_builder_test.dart`。
- [x] 运行 `flutter analyze` 和 `flutter build web --release`。
- [x] 提交 `feat(v0.1): preserve character state across viewports`（commit `715925b`）。

---

## 执行报告（2026-07-23）

**分支：** `feat/v0.1-character-experience`（独立 worktree `.worktrees/character-experience`）

**Commit 列表：**

| Commit | Message | 任务 |
|---|---|---|
| `258e08e` | `refactor(v0.1): tighten character overview` | 任务 1 |
| `ba44fef` | `refactor(v0.1): unify character sections` | 任务 2 |
| `da72e76` | `feat(v0.1): clarify character rule choices` | 任务 3 |
| `715925b` | `feat(v0.1): preserve character state across viewports` | 任务 4 |

**测试结果：**
- 角色相关全量测试：88 项全部通过
- `flutter analyze`：No issues found
- `flutter build web --release --pwa-strategy=none`：构建成功
- 未运行 `npm run doctor`（按约束要求）

**自动授予和必选项覆盖：**
- 自动授予通过 `_RuleGrantPreview` 卡片（标题"自动获得"）与必选项 `_RuleChoiceSection` 分离渲染。
- `minimum > 0` 的必选项未完成时审核页"创建角色"按钮 `onPressed` 为 null；选中后变为非 null。
- 子职业通过 progression `choice` + `subclassOf` 关系加载，`RuleChoiceResolver` 原生支持，未硬编码职业名。
- 属性生成三种方法（标准数组/27 点购点/随机）的 `SegmentedButton` 均存在并可切换。

**响应式布局验证（`character_responsive_state_test.dart`，3 项测试）：**
- 角色卡 390→1280 宽度切换后保持当前 section（装备 tab）。
- 标准创建 1280→390 宽度切换后保持向导步骤（属性）和未保存草稿（角色名"莱娅"）。
- 360/390 紧凑下拉步骤导航，900+ NavigationRail + 固定摘要列。

**资料结构缺口（已修复）：**

1. **`_normalizeInventoryItem` 丢失字段**
   - 文件：`character_detail_page.dart`（任务 2）
   - 现象：原实现只保留 name/quantity/consumable，导致装备行无法打开 reader。
   - 修复：保留 `entryId`/`equipped`/`attuned`/`description` 字段，装备行点击可打开 `showContentEntryPreviewDialog`。

2. **升级页选项无 reader 入口**
   - 文件：`character_upgrade_page.dart`（任务 3）
   - 现象：`_ChoiceOptions` 只有 FilterChip，没有打开资料详情的按钮，与编辑器的 `_RuleChoiceSection` 不一致。
   - 修复：添加 `IconButton`（key `builder-open-entry-<id>`），点击打开 `showContentEntryPreviewDialog`。

3. **审核页未显示属性来源**
   - 文件：`character_editor_page.dart`（任务 3）
   - 现象：`_BuilderReviewStep` 不展示属性生成方式。
   - 修复：添加 `abilityMethodLabel`（标准数组 / 27 点购点 / 随机）。

4. **Builder shell 宽屏阈值不一致**
   - 文件：`character_builder_shell.dart`（任务 4）
   - 现象：`CharacterBuilderShell` 宽屏阈值原为 1000，与 `CharacterSheetShell`（900）和计划要求（"900 以上"）不一致。
   - 修复：对齐为 900。

**后续待跟进项：**
- 计划文件（本文件）在 worktree 中为未跟踪状态，任务执行期间无法在 worktree 内更新复选框，已由主仓库单独补齐。
- `RuleChoiceResolver` 已原生支持 `subclassOf` 关系过滤，无需额外改造；如未来资料结构变化需复测子职业加载链路。
