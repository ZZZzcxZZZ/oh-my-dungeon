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

- [ ] 写失败测试覆盖 360/390/900/1280 宽度和超长角色名。
- [ ] 头部只保留头像、姓名、物种、职业/子职、等级、HP、AC、先攻；属性与技能移到独立目的地。
- [ ] HP 修改采用可直接输入数值的 Dialog/BottomSheet，不保留只能逐点加减的主操作。
- [ ] 运行 `flutter test test/character_overview_density_test.dart test/character_sheet_shell_test.dart`。
- [ ] 提交 `refactor(v0.1): tighten character overview`。

### 任务 2：统一业务列表

- [ ] 写失败测试：动作、法术、装备、资源、特性使用同一紧凑行规范；条目点击打开已有浮层 reader；列表尾部提供明确的添加/编辑命令。
- [ ] 法术按环位分组；货币位于装备顶部；资源使用多列自适应布局并支持短休/长休/不恢复。
- [ ] 保持所有快速编辑调用既有 quick edit service/controller，不在 widget 内直接改 JSON。
- [ ] 运行 `flutter test test/character_pages_test.dart test/character_quick_edit_service_test.dart`。
- [ ] 提交 `refactor(v0.1): unify character sections`。

### 任务 3：创建与升级选择

- [ ] 写失败测试：职业、子职、物种、背景产生的自动授予单独显示；熟练、装备、法术等必选项未完成时不能创建。
- [ ] 子职业根据职业 progression 的 choice 与 `subclassOf` 关系加载；不得硬编码职业名称或商业规则正文。
- [ ] 属性生成支持标准数组、购点和随机生成，并在审核页显示来源。
- [ ] 升级页面逐级显示新增特性、子职、法术与资源变化；点击关联条目使用当前 reader。
- [ ] 运行 `flutter test test/guided_character_builder_test.dart test/character_upgrade_page_test.dart test/rules_driven_character_builder_test.dart`。
- [ ] 提交 `feat(v0.1): clarify character rule choices`。

### 任务 4：响应式状态与验收

- [ ] 写测试：旋转和宽度变化后保持当前 section、向导步骤和未保存草稿。
- [ ] 360/390 使用紧凑步骤导航，900 以上使用 NavigationRail 与固定摘要列。
- [ ] 运行全部 `test/character_*_test.dart`、`guided_character_builder_test.dart`、`rules_driven_character_builder_test.dart`。
- [ ] 运行 `flutter analyze` 和 `flutter build web --release`。
