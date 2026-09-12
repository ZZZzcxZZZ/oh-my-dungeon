# 选择系统运行时语义（P5）实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 把规格 §3.10 的选择系统从"声明即导入报错"改成**真正生效的运行时语义**：内联选项的 `grants` 选中即应用（含字符串简写自动授予）、`repeatable` 可重复选取、`countsToward` 计入共享额度池、`requires` 前置条件隐藏/阻塞并在 UI 说明原因、`group`/`help` 落到选择面板、编辑器的选择状态由 `Set` 改为**有序 `List`**（顺序即声明顺序，可表达"同一选项重复 N 次"）、`optionType: "spell"` 走法术池、装备 A/B 写入 `inventory`/`currency`；同时把 `invalidAutoGrant` 落地为字符串简写无法推断 grants 时的导入 error。

**架构：** 新增一个纯函数语义层 `RuleChoiceSemantics`（候选合并 / 选中规范化 / 自动授予推断 / `requires` 判定 / 键 → 定义解析）与一个额度层 `RuleChoiceQuota`（`countsToward` → 上限）。`CharacterRulesEngine` 只调用它们，不再自己写第二套判断；编辑器三处选择界面（创建向导、编辑器升级队列、独立升级页）收敛到**一个共享组件** `RuleChoiceSection`，它也只调用 `RuleChoiceSemantics.candidatesFor`。字符串简写的自动授予在解析层**不**推断（保持形状层纯净），由 `RuleChoiceSemantics.autoGrantsFor` 一处推断，导入器与运行时共用它。导入期的原始 JSON 校验从"存在即拒收"收窄为真正的取值/引用校验，并新增 `invalidAutoGrant`。

**技术栈：** Flutter 3.41 / Dart 3.11、`flutter_test`、Material 3（`DESIGN.md` token）、`npm run check` 门禁。

**规格：** `docs/specs/2026-09-10-rules-contract-design.md` §3.10（全节）、§3.5、§5.1、§6.3、§10.8、§11。文档事实来源：`docs/README.md` §7.7、§9.2.3、§9.2.5。

**先决条件：**
- 工作区干净；`git log -1` 为 `2aa655a` 或其后（上一条：`ci: 新增 scripts job 并刷新 §16 实测基线`）。
- 计划 1（P0–P2 + P3/P4）已完成：`classRules` / `RuleProfile` / `RuleProfileResolver` 已在主线，`grant.kind` 已收敛为 9 项，`progression[].levels` 数组已落地——本次不重做任何一项。
- `apps/client_flutter` 能跑通一次 `flutter test`（基线以最近一次全绿为准），`npm run test:scripts` 与 `npm run lint:design` 全绿。

---

## 背景

规格 §11「本轮延后」把选择系统的运行时语义整体划给计划 2，并明确了当前状态：

- `rules.choices[].repeatable` / `group` / `help` / 内联选项 `options[].grants` 一导入就报 `unsupportedChoiceField`（`ContentPackageImporter._unsupportedChoiceFields` = `{'repeatable','group','help'}`，`_validateRawChoice` 第 1159–1189 行）。
- `countsToward` / `requires` **存在即拒收**，分别报 `invalidCountsToward` / `invalidRequires`（同函数第 1170–1189 行），与它们的取值无关。
- `invalidAutoGrant` 是 §5.1 里**唯一还没有产生点**的 code（规格 §10.5 明说"由计划 2 承接"）。
- 运行时侧：`RuleChoiceResolver.optionsFor` 只解析**条目候选**（按 `entry.type` / 标签 / 等级过滤），内联 `options` 对引擎完全不可见；`CharacterRulesEngine._resolveChoices` 把选中值一律当条目 id 塞进队列，并用 `resolver.allows` 过滤——因此一个只写内联 `options` 的选择，选中任何内联 id 都会被判为"非法选项"并进 pending。
- 编辑器侧：创建向导的 `_ruleChoices`（`character_editor_builder_page.dart:54`）与升级队列的 `_upgradeRuleChoices`（`character_editor_page.dart:83`）都是 `Map<String, Set<String>>`，独立升级页的 `_ChoiceOptions`（`character_upgrade_page.dart:198`）已经是 `List<String>`——三套状态、三套 chip 交互。
- 专用 UI 的现状判据是 `RuleChoiceDefinition.usesDedicatedOptionUi`（"内联选项是唯一候选载体"），而技能选择的选中值不进 `build.choices`，走草稿 `skillProficiencies`；升级预览必须靠"排除 `usesDedicatedOptionUi` 的键"来绕开升级死锁（`character_editor_page.dart:613-625`、`character_upgrade_planner.dart:43-50`）。
- 渲染位置有缺口（本次核对发现）：`_builderStepFor` 允许 `abilities`（步骤 3）与 `details`（步骤 7），但这两个步骤没有 `...ruleChoiceWidgets`（`character_editor_builder_page.dart`，`ruleChoiceWidgets` 只出现在步骤 0/1/2/4/5/6）。示例包里 `builderStep: "details"` 的 `asi-or-feat` 因此在创建向导里**不可见**——一旦升级/创建校验不再豁免它，就会变成"看不见却要求选"的静默阻塞。任务 6b 一并修掉并加结构守卫测试。

计划 2 的目标状态：**声明了就必须生效**（§3.10.3-7），且每类语义只有一处实现。

## 范围（做什么）

1. **内联选项的 `grants` 消费**：选中该选项时把它的 grants 应用进 `CharacterGrantLedger`（`ability` / `hitPoints` / `proficiency` / … 走计划 1 已实现的派生前置顺序：属性加值先于 HP/AC/豁免/技能/DC）。
2. **字符串简写自动推断 grants**：`skill` / `ability` / `language` / `damageType` / `weaponMastery` / `value` 六类值类型按 §3.10.2 的表格推断；无法推断（条目类型 + 字符串元素）→ 导入期 `invalidAutoGrant`。
3. **`repeatable`**：同一选项可重复选，`maximum` 随之变成"次数上限"；重复次数影响 `grants` 结算次数、`resolvedChoices` 落库形状与 pending 判定。
4. **`countsToward`**：声明计入哪个数量池（`spellbook` / `known` / `prepared` / 省略），与 `maximum` 取小、跨选择共享同一池。
5. **`requires`**：`{choice, option}` 或 `{ability, minimum}`；不满足时该选择不可选（UI 隐藏并说明原因），已有选中值进 pending 且**不静默丢弃**。
6. **`group` / `help`**：纯呈现，落到选择面板（Material 3 + `DESIGN.md` token）。
7. **编辑器选择面板改造**：值类型与条目选项分组展示；选择状态 `Set` → 有序 `List`；`optionType: "spell"` 走法术池（`maximumOptionLevel` / 标签 / 职业 `listTags` 过滤）；装备 A/B 写入 `inventory` 与 `currency`。
8. **`invalidAutoGrant` 诊断**落地。
9. **导入期"声明即拒收"改为真正的校验**：`repeatable` / `group` / `help` / 内联 `grants` 正常解析 + 语义校验；`countsToward` / `requires` 收窄为取值/引用校验。
10. **文档同步**：规格 §3.10 顶部注记、§5.1 表与注记、§10.5/§10.8 状态、§11 延后块；`docs/README.md` §7.7 已知限制行、§9.2.3 选择字段段、§9.2.5 error code 清单。

## 不做什么

- **不重开计划 1 的契约**：`classRules` 的 4 个数值字段、`RuleProfile` / `RuleProfileResolver` / `Table` / `MaxSpec`、`grant.kind` 的 9 项枚举、`progression[].levels` 数组，一律不动。
- **不做 S3**：`patch` / `replace` / `priority` / 覆盖冲突 UI / 来源显示（`ResolvedClassRules.fieldSources` 仍只在数据层记录）。
- **不做 S4**：作者 GUI、`.dndpack` 导出。
- **不做 §11 的"仍不建模"清单**：多职业、专精、武器精通结算、抗性/免疫结算、资源池具体效果（引导神力选项、野性形态、术法点转法术位…）。
- **不改 Drift schema**（`schemaVersion` 保持 13）；`CharacterBuild.abilities` 只加进 `data['build']` 的 JSON，不进表结构。
- **不改服务端任何代码**；不动 `scripts/`（提取器不产出这批字段，`npm run test:scripts` 作为回归门禁保留）。
- **不改 `DESIGN.md`**（不新增 token；`lint:design` 作为回归门禁保留）。

## 用户已定的取舍

| 取舍 | 依据 | 本计划的遵守方式 |
|---|---|---|
| 一个概念只有一种写法（无别名、无兼容写法） | 规格 §0 需求二 | 不新增任何字段别名；`countsToward` 只有 3 个合法取值 |
| 选择状态只有一处 | §3.10.3-4 + 本任务"唯一实现"约束 | 选中值一律存进 `build.choices`（含技能、法术）；`skillProficiencies` 退回"背景预设"单一职责 |
| 声明了但用不了必须导入报 error | §3.10.3-7 | 放行（任务 10）排在消费实现（任务 3–9）**之后**，中间不留"导入放行、运行期无效"的提交 |
| 不背兼容包袱 | §0 需求二 | 旧存档缺失的 `build.abilities` 按"未记录"处理（可见的 pending/提示），不做迁移脚本 |
| 部分声明是一等功能 | §3.12 | 选择字段一律可缺省，缺省即默认值（`repeatable: false` / `countsToward: null` / `requires: []` / `group: null` / `help: null`） |

## 待用户确认的口径（规格含糊处，本计划的默认处置）

以下是规格没有写死、但实现必须选一个口径的地方。**本计划按"默认处置"执行**，并在任务 12 把选定的口径写进文档；若用户否决，改动集中在单个任务内，不影响其它任务的结构。

| # | 含糊点 | 规格原文 | 本计划默认处置 | 影响任务 |
|---|---|---|---|---|
| D1 | `countsToward` 的额度从哪来 | §3.10.2 只列出 `spellbook`/`known`/`prepared` 三个池名，没有给出数值来源 | `prepared` 与 `known` → `ResolvedClassRules.preparedLimit(level)`（客户端只有"已知/准备"这一列数值）；`spellbook` → **无额度上限**（`classRules` 没有法术书容量列；§3.10.2 的法师法术书例子 `minimum: 6` 在 1 级 `prepared = 4` 时若共用 prepared 列就不可用，故只能是无上限）；省略 / `null` → 不占池，只受 `maximum` | 5、10、12 |
| D2 | `requires` 的 `ability` 门槛用哪份属性 | §3.10.2 表格只写 `{ability, minimum}` | 用 `CharacterBuild.abilities`（**入参基础属性**，即玩家输入的属性值），不用结算后的有效属性。理由：`kind: ability` 加值由"选择"产生，用结算值会让 `requires` 与选择互相引用（求值不成不动点）；代价是"由另一个选择授予的属性加值不满足前置"（记入风险与 §7.7 已知限制） | 4、12 |
| D3 | `requires` 的 `option` 指什么 | §3.10.2 写 `{choice, option}`，未说 `option` 是内联选项 id 还是条目 id | 指**该选择的选中值**：内联选项 id 或条目 id 都算；存在性校验 = 该 choice 的候选集（`RuleChoiceSemantics.candidatesFor`）里存在该 id | 2、10 |
| D4 | `ability` 值类型选项的加值写在哪 | §3.10.2 写 `value: <choice.value ?? 1>`，但 `options` 的字段集是 `{id, label, description?, data?, grants?}`，没有 `value` | 读内联选项的 `data['value']`（整数，缺省 1）；不为 `options` 新增 `value` 字段（不扩字段集） | 2 |
| D5 | `invalidAutoGrant` 到底对哪些 `optionType` 触发 | §5.1 的示例消息写的是 `optionType "value"`，但 §3.10.2 表格明说 `value`/`damageType`/`weaponMastery` 只记录选择、代码里 `value` 是**值类型**（`kValueOptionTypes` 成员） | 只对**条目类型**（`subclass`/`feat`/`spell`/`item`/`classFeature`/`equipmentBundle`/`custom`…）的**字符串元素**触发（无法推断 grants 且未显式写对象）；`value`/`language`/`damageType`/`weaponMastery` 属"只记录选择"，**不报** `invalidAutoGrant`。§5.1 的示例消息在任务 12 改写 | 2、10、12 |
| D6 | `language` 选项落到哪 | §3.10.2 写"记录到角色卡的『语言』列表（`data.languages`）" | 写入既有存储 `data['profile']['languages']`（`CharacterProfile.fromCharacter` 读的就是它，`data['languages']` 没有读取方）；`data['choices']` 另外保留一份选中值镜像 | 7、12 |
| D7 | `group` 相同的选择如何排序 | §3.10.2 只说"分组标题" | 分组按**首次声明的顺序**，组内保持声明顺序；未声明 `group` 的选择归入一个无标题组并排在最后 | 6b |
| D8 | 池被多个选择共享时谁先占额度 | §3.10.2 只说"计入哪个池" | 按引擎的确定遍历顺序**先声明先占**（条目 → `rules.choices` → `progression[].choices`），超出部分进 `invalidSelected` 并在 pending 里给理由；不按"哪个选择更小"重排（避免不可复现的截断） | 5 |
| D9 | 三处选择界面是否合并 | 规格未提 | 合并为一个共享组件 `RuleChoiceSection`（`presentation/widgets/`），三处只传参；`usesDedicatedOptionUi` 从"值写在别处"的**校验判据**退化为"有专门渲染器"的**渲染判据** | 6a、6b、7、9 |

---

## 唯一实现点总表

| 语义 | 唯一实现点（文件 · 符号） | 调用方（必须复用，不得重写） |
|---|---|---|
| 选择字段的形状与取值合法性（`repeatable`/`countsToward`/`requires`/`group`/`help`） | `lib/src/features/rules/domain/character_rule_definition.dart` · `RuleChoiceDefinition.fromJson` / `isCountsTowardPool` / `RuleRequiresDefinition.fromJson` | 解析层、导入器原始 JSON 校验、测试 |
| 候选枚举（内联 + 条目合并、顺序、过滤） | `lib/src/features/rules/domain/rule_choice_semantics.dart` · `RuleChoiceSemantics.candidatesFor` | 引擎、共享 UI 组件、导入器引用校验、`StructuredClassRules.skillChoice` |
| 选中值规范化（成员过滤 / `repeatable` / `maximum` / 超额） | 同上 · `RuleChoiceSemantics.normalizeSelection` | 引擎、编辑器三处界面 |
| 内联选项的 grants 展开（含字符串简写自动推断） | 同上 · `RuleChoiceSemantics.grantsForSelection` / `autoGrantsFor` | 引擎（进 ledger）、导入器（`invalidAutoGrant`） |
| `requires` 判定（作用域 + 能力门槛） | 同上 · `RuleChoiceSemantics.requiresSatisfied` / `scopeEntryIdsFor` | 引擎、编辑器创建向导、升级规划器、导入器引用校验 |
| 选择键 → 定义解析（含等级段） | 同上 · `RuleChoiceSemantics.definitionForKey` | 引擎、builder（`data['choices']` / 语言落库）、UI |
| `countsToward` 额度（池上限、池占用、有效上限） | `lib/src/features/rules/domain/rule_choice_quota.dart` · `RuleChoiceQuota.limitsFor` / `effectiveMaximum` | 引擎 `evaluate(poolLimits:)`、编辑器、升级规划器 |
| 选择单元的键（grant 生效单元 / 内联选项实例） | `lib/src/features/rules/domain/character_rules_engine.dart` · `ruleUnitKey` / `ruleChoiceGrantKey` | 引擎、编辑器 diff、builder 落库 |
| grant 施加顺序（属性先于派生） | `lib/src/features/characters/domain/rules_driven_character_builder.dart` · `build` + `_abilityGrantBonuses` / `_hitPointGrantBonus` | 所有派生入口（创建 / 升级 / 项目器） |
| `requires` 能力门槛的数据源 | `lib/src/features/rules/domain/character_build.dart` · `CharacterBuild.abilities` | 引擎、项目器、升级规划器、编辑器 |
| 装备方案的物品与货币 | `lib/src/features/characters/domain/equipment_bundle_items.dart` · `EquipmentBundleItems.from` | builder（`inventory` / `currency`） |
| 选择界面渲染（chip / 分组 / 帮助 / 重复计数 / 前置提示） | `lib/src/features/characters/presentation/widgets/rule_choice_section.dart` · `RuleChoiceSection` | 创建向导、编辑器升级队列、独立升级页 |

---

## 任务门禁（每个任务结束时都必须全绿，缺一不可）

在**每一个任务**的 Commit 之前跑完这三条（Windows/WSL 环境；`flutter` 直接调用会因 CRLF 失败，必须走 `cmd.exe`）：

```
# ① 客户端静态分析 + 全量测试（含 npm run check 的客户端部分）
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib test"
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test"

# ② 阶段门禁（服务端 lint + 客户端 analyze + 服务端/客户端全量测试）
npm run check

# ③ 脚本门禁 + 设计门禁（本计划不碰 scripts/ 与 DESIGN.md，作回归保护）
npm run test:scripts
npm run lint:design
```

约定：
- **不允许**"改了签名让调用方下一任务再修"——任何签名/状态类型的变更必须在**同一任务**内改完全部调用方，且当次 `flutter test` 全绿。
- 每个任务自己的**目标测试**命令写在该任务「步骤：运行」里；**验收 = 目标测试 PASS ∧ 本门禁三条全绿**（不允许只跑目标测试就提交）。
- 不要跑全仓 `dart format`；不要用 `--plain-name` 带中文。

---

## 文件结构

**新增**

| 文件 | 职责 |
|---|---|
| `apps/client_flutter/lib/src/features/rules/domain/rule_choice_semantics.dart` | 选择语义纯函数层：`RuleChoiceCandidate`、`candidatesFor`、`normalizeSelection`、`RuleChoiceSelection`、`autoGrantsFor`、`grantsForSelection`、`requiresSatisfied`、`definitionForKey` |
| `apps/client_flutter/lib/src/features/rules/domain/rule_choice_quota.dart` | `countsToward` 额度：`RuleChoiceQuota.limitsFor` / `effectiveMaximum` |
| `apps/client_flutter/lib/src/features/characters/presentation/widgets/rule_choice_section.dart` | 共享选择组件（chip 交互 + `group` 标题 + `help` 小字 + 重复计数 + `requires` 提示） |
| `apps/client_flutter/lib/src/features/characters/domain/equipment_bundle_items.dart` | `equipmentBundle.structured.items` / `structured.currency` 的解析（唯一实现点） |
| `apps/client_flutter/test/rules/rule_choice_definition_test.dart` | 选择字段解析/序列化 + 值集合判据 |
| `apps/client_flutter/test/rules/rule_choice_semantics_test.dart` | 候选合并 / 规范化 / 自动授予 / requires 判定 |
| `apps/client_flutter/test/rules/rule_choice_quota_test.dart` | 池上限与有效上限 |
| `apps/client_flutter/test/rule_choice_section_test.dart` | 共享组件 widget 测试 |

**修改**

| 文件 | 变化 |
|---|---|
| `apps/client_flutter/lib/src/features/rules/domain/character_rule_definition.dart` | `RuleChoiceDefinition` 增 `repeatable` / `countsToward` / `requires` / `group` / `help`；新增 `RuleRequiresDefinition`、`kCountsTowardPools` / `isCountsTowardPool`、`kAutoGrantOptionTypes`；`usesDedicatedOptionUi` 语义收窄为"有专门渲染器" |
| `apps/client_flutter/lib/src/features/rules/domain/character_build.dart` | 新增 `abilities`（`Map<String,int>`，JSON 往返） |
| `apps/client_flutter/lib/src/features/rules/domain/character_rules_engine.dart` | `ruleChoiceGrantKey`；`_resolveChoices` 用语义层；内联 grants 进 ledger；只把**条目**候选入队；`ActiveRuleChoice` / `PendingRuleChoice` 扩展（`requiresSatisfied` / `repeatable` / `group` / `help` / `pool` / `poolCap` / `reason`）；`evaluate` 增可选 `poolLimits` |
| `apps/client_flutter/lib/src/features/characters/domain/rules_driven_character_builder.dart` | 持久化 `build.abilities`；内联 grants 经 ledger 派生（无需新代码，但 `data` 新增 `choices` / `profile.languages` / `manualOverrides`）；装备方案写 `inventory`/`currency`；`skillProficiencies` 只承接背景预设 |
| `apps/client_flutter/lib/src/features/characters/domain/character_rule_projector.dart` | 重建 `CharacterBuild` 时带上 `abilities`（用 `baseAbilitiesFrom` 的结果回填）；合并键增加 `choices` |
| `apps/client_flutter/lib/src/features/characters/domain/character_upgrade_planner.dart` | 传 `abilities` 与 `poolLimits`；`isComplete` 不再靠 `usesDedicatedOptionUi` 免检 |
| `apps/client_flutter/lib/src/features/characters/domain/structured_class_rules.dart` | `skillChoice` 改为基于 `RuleChoiceSemantics.candidatesFor`（候选/标签单一来源） |
| `apps/client_flutter/lib/src/features/characters/domain/character_manual_overrides.dart` | 新增 `alwaysPreparedEntryIds`（JSON 往返） |
| `apps/client_flutter/lib/src/features/characters/presentation/character_editor_page.dart` + part 文件 | `_upgradeRuleChoices` → `Map<String, List<String>>`；升级预览 pending 规则改为"只统计本级新增的选择"；技能选择写入 `_ruleChoices`；法术步骤走 spell choice 池；`_submitQuickBuild` 合并（而非覆盖）`manualOverrides` |
| `apps/client_flutter/lib/src/features/characters/presentation/character_upgrade_page.dart` | `_ChoiceOptions` 迁移到共享组件 |
| `apps/client_flutter/lib/src/features/content/data/import/content_package_importer.dart` | 删 `_unsupportedChoiceFields` 与内联 grants 拒收；`countsToward` / `requires` 真校验；新增 `invalidAutoGrant` |
| `apps/client_flutter/test/rules/import_rule_diagnostics_test.dart` | §3.10.3-7 分组由"拒收"改为"按语义校验 + 放行" |
| `samples/homebrew-astral-knight/entries.json` | `invocations` 声明 `repeatable: true`；选择补 `group` / `help`；`spells-1` 补 `countsToward`（示范） |
| `docs/specs/2026-09-10-rules-contract-design.md` | §3.10 注记、§5.1 表与注记、§10.5/§10.8 状态、§11 延后块 |
| `docs/README.md` | §7.7 已知限制行、§9.2.3 选择字段段、§9.2.5 error code 清单 |

**不修改**：Drift schema、`apps/server_nest/`、`scripts/`、`DESIGN.md`、`assets/rules/dnd5e-2024.rules.json`。

---

## 任务 1：选择字段的值对象与解析（唯一判据点）

**文件：**
- 修改：`apps/client_flutter/lib/src/features/rules/domain/character_rule_definition.dart`
- 测试：`apps/client_flutter/test/rules/rule_choice_definition_test.dart`（新建）

- [ ] **步骤 1：先写失败测试**

```dart
// test/rules/rule_choice_definition_test.dart
import 'package:dnd_table_client/src/features/rules/domain/character_rule_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('选择系统字段（契约 §3.10.2）', () {
    test('repeatable / countsToward / group / help 无损往返', () {
      const source = <String, Object?>{
        'id': 'invocations',
        'label': '祈唤',
        'optionType': 'classFeature',
        'minimum': 1,
        'maximum': 3,
        'optionTags': ['eldritch-invocation'],
        'repeatable': true,
        'countsToward': 'prepared',
        'group': '1 级祈唤',
        'help': '同一祈唤最多选 3 次。',
      };

      final choice = RuleChoiceDefinition.fromJson(source);

      expect(choice.repeatable, isTrue);
      expect(choice.countsToward, 'prepared');
      expect(choice.group, '1 级祈唤');
      expect(choice.help, '同一祈唤最多选 3 次。');
      expect(choice.toJson(), source);
    });

    test('缺省即默认：repeatable=false，其余为 null 且不写回 JSON', () {
      final choice = RuleChoiceDefinition.fromJson(const {
        'id': 'pick',
        'optionType': 'feat',
      });

      expect(choice.repeatable, isFalse);
      expect(choice.countsToward, isNull);
      expect(choice.requires, isEmpty);
      expect(choice.group, isNull);
      expect(choice.help, isNull);
      final encoded = choice.toJson();
      for (final key in ['repeatable', 'countsToward', 'requires', 'group', 'help']) {
        expect(encoded.containsKey(key), isFalse, reason: key);
      }
    });

    test('countsToward 取值判据只有一处（isCountsTowardPool）', () {
      expect(isCountsTowardPool(null), isTrue);
      for (final pool in ['spellbook', 'known', 'prepared']) {
        expect(isCountsTowardPool(pool), isTrue, reason: pool);
      }
      expect(isCountsTowardPool('rituals'), isFalse);
      expect(isCountsTowardPool(7), isFalse);

      expect(
        () => RuleChoiceDefinition.fromJson(const {
          'id': 'x',
          'optionType': 'spell',
          'countsToward': 'rituals',
        }),
        throwsFormatException,
      );
      expect(
        () => RuleChoiceDefinition.fromJson(const {
          'id': 'x',
          'optionType': 'spell',
          'countsToward': 3,
        }),
        throwsFormatException,
      );
    });

    test('requires 两种形态可解析且往返', () {
      const source = <String, Object?>{
        'id': 'invocations',
        'optionType': 'classFeature',
        'requires': [
          {'choice': 'spellbook', 'option': 'spell-a'},
          {'choice': 'pact', 'option': null},
          {'ability': 'cha', 'minimum': 13},
        ],
      };

      final choice = RuleChoiceDefinition.fromJson(source);

      expect(choice.requires, hasLength(3));
      expect(choice.requires[0].choice, 'spellbook');
      expect(choice.requires[0].option, 'spell-a');
      expect(choice.requires[0].ability, isNull);
      expect(choice.requires[0].minimum, isNull);
      expect(choice.requires[1].option, isNull);
      expect(choice.requires[2].ability, 'cha');
      expect(choice.requires[2].minimum, 13);
      expect(choice.requires[2].choice, isNull);
      // 省略 option 的形态不写回 null，避免制造第二种写法。
      expect(
        (choice.toJson()['requires']! as List)[1],
        {'choice': 'pact'},
      );
      expect(
        RuleChoiceDefinition.fromJson(choice.toJson()).toJson(),
        choice.toJson(),
      );
    });

    test('requires 元素混写或取值非法一律抛 FormatException', () {
      for (final bad in <Object?>[
        <String, Object?>{},                                        // 两种形态都不是
        {'choice': 'a', 'ability': 'cha', 'minimum': 13},            // 混写
        {'ability': 'cha'},                                          // 缺 minimum
        {'ability': 'cha', 'minimum': 0},                            // 非正
        {'ability': 'cha', 'minimum': '13'},                         // 非数字
        {'choice': 5},                                               // 非字符串
        {'ability': 'cha', 'minimum': 13, 'extra': 1},               // 未定义字段
      ]) {
        expect(
          () => RuleChoiceDefinition.fromJson(<String, Object?>{
            'id': 'x',
            'optionType': 'feat',
            'requires': <Object?>[bad],
          }),
          throwsFormatException,
          reason: '$bad',
        );
      }
      expect(
        () => RuleChoiceDefinition.fromJson(const {
          'id': 'x',
          'optionType': 'feat',
          'requires': <String, Object?>{},
        }),
        throwsFormatException,
      );
    });

    test('group / help 必须是非空字符串（空串拒绝，不允许"声明了但等于没写"）', () {
      for (final field in ['group', 'help']) {
        expect(
          () => RuleChoiceDefinition.fromJson({
            'id': 'x',
            'optionType': 'feat',
            field: '   ',
          }),
          throwsFormatException,
          reason: field,
        );
      }
    });

    test('repeatable 必须是 bool', () {
      expect(
        () => RuleChoiceDefinition.fromJson(const {
          'id': 'x',
          'optionType': 'feat',
          'repeatable': 'yes',
        }),
        throwsFormatException,
      );
    });
  });
}
```

- [ ] **步骤 2：运行确认失败**

运行：`cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test\rules\rule_choice_definition_test.dart"`
预期：FAIL（`repeatable` / `countsToward` / `requires` / `group` / `help` 未定义、`isCountsTowardPool` 不存在）。

- [ ] **步骤 3：实现字段与判据点**

在 `character_rule_definition.dart` 里加：

```dart
/// `countsToward` 的合法取值（契约 §3.10.2 表）。
///
/// 这是取值集合的**唯一实现点**：解析层用它抛 [FormatException]，导入器用它报
/// 精确到字段的 `invalidCountsToward`。两处不得各写一份白名单。
const kCountsTowardPools = <String>{'spellbook', 'known', 'prepared'};

/// `null`（省略 = 不占上限）与三个池名合法；其它（含非字符串）非法。
bool isCountsTowardPool(Object? value) =>
    value == null || (value is String && kCountsTowardPools.contains(value));

/// 字符串简写**能推断** grants 的 `optionType`（契约 §3.10.2 的自动授予表）。
/// `skill` / `ability` / `language` 产出 grants；`damageType` / `weaponMastery` /
/// `value` 只记录选择（产出空 grants，不算"无法推断"）。
const kAutoGrantOptionTypes = <String>{
  'skill',
  'ability',
  'language',
  'damageType',
  'weaponMastery',
  'value',
};

class RuleRequiresDefinition {
  const RuleRequiresDefinition({
    this.choice,
    this.option,
    this.ability,
    this.minimum,
  });

  final String? choice;
  final String? option;
  final String? ability;
  final int? minimum;

  bool get isChoiceForm => choice != null;
  bool get isAbilityForm => ability != null;

  factory RuleRequiresDefinition.fromJson(Map<String, Object?> json) {
    final choice = json['choice'];
    final option = json['option'];
    final ability = json['ability'];
    final minimum = json['minimum'];
    final allowed = <String>{'choice', 'option', 'ability', 'minimum'};
    final extra = json.keys.where((key) => !allowed.contains(key)).toList();
    if (extra.isNotEmpty) {
      throw FormatException('requires 出现未定义字段：$extra');
    }
    final hasChoice = choice != null;
    final hasAbility = ability != null;
    if (hasChoice == hasAbility) {
      throw const FormatException(
        'requires 必须是 {choice, option?} 或 {ability, minimum} 之一',
      );
    }
    if (hasChoice) {
      if (choice is! String || choice.trim().isEmpty) {
        throw const FormatException('requires.choice 必须是非空字符串');
      }
      if (option != null && (option is! String || option.trim().isEmpty)) {
        throw const FormatException('requires.option 必须是非空字符串');
      }
      return RuleRequiresDefinition(
        choice: choice.trim(),
        option: option is String ? option.trim() : null,
      );
    }
    if (ability is! String || ability.trim().isEmpty) {
      throw const FormatException('requires.ability 必须是非空字符串');
    }
    if (minimum is! num || minimum.toInt() <= 0) {
      throw const FormatException('requires.minimum 必须是正整数');
    }
    return RuleRequiresDefinition(
      ability: ability.trim(),
      minimum: minimum.toInt(),
    );
  }

  Map<String, Object?> toJson() => isChoiceForm
      ? {'choice': choice, if (option != null) 'option': option}
      : {'ability': ability, 'minimum': minimum};
}
```

`RuleChoiceDefinition` 增字段与解析：

```dart
  final bool repeatable;
  final String? countsToward;
  final List<RuleRequiresDefinition> requires;
  final String? group;
  final String? help;
```

`fromJson` 里（在既有 `builderStep` 校验之后）：

```dart
    final repeatable = json['repeatable'];
    if (repeatable != null && repeatable is! bool) {
      throw const FormatException('choice.repeatable must be a boolean');
    }
    final countsToward = json['countsToward'];
    if (!isCountsTowardPool(countsToward)) {
      throw FormatException(
        'countsToward 必须是 ${kCountsTowardPools.join(' / ')} 或省略：$countsToward',
      );
    }
    String? nonEmptyText(Object? raw, String field) {
      if (raw == null) return null;
      if (raw is! String || raw.trim().isEmpty) {
        throw FormatException('choice.$field must be a non-empty string');
      }
      return raw;
    }
    final group = nonEmptyText(json['group'], 'group');
    final help = nonEmptyText(json['help'], 'help');
    final rawRequires = json['requires'];
    if (rawRequires != null && rawRequires is! List) {
      throw const FormatException('choice.requires must be a list');
    }
    final requires = rawRequires == null
        ? const <RuleRequiresDefinition>[]
        : rawRequires
              .map((item) {
                if (item is! Map) {
                  throw const FormatException(
                    'choice.requires item must be an object',
                  );
                }
                return RuleRequiresDefinition.fromJson(
                  Map<String, Object?>.from(item),
                );
              })
              .toList(growable: false);
```

同时把 `usesDedicatedOptionUi` 改成"有专门渲染器"的语义（完整实现留到任务 6b，本任务只改文档注释并保持**行为等价**：`isValueTypeChoice || (options.isNotEmpty && optionEntryIds.isEmpty && optionTags.isEmpty)` 原样保留，注释标注"语义将在任务 6b 收窄，届时改为 `optionType == 'skill' || isSpellChoice`"）。

- [ ] **步骤 4：运行测试**

运行：`cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test\rules\rule_choice_definition_test.dart"`
预期：PASS。

**实现要点**
- 判据只写一次：`isCountsTowardPool` 供解析层与导入器共用；`RuleRequiresDefinition.fromJson` 是 `requires` 形状的唯一入口。
- 不写"看似生效"的字段：`repeatable` / `countsToward` / `requires` / `group` / `help` 在本任务只是**可解析**，导入期仍在拒收（任务 10 才放行），因此本任务不会制造"导入放行、运行期无效"的窗口。
- `requires` 元素只允许 `choice`+可选 `option`，或 `ability`+`minimum`；混写一律抛错（避免运行期猜测）。

**验收：** 上一步「运行」里的目标测试命令 → PASS；再跑「任务门禁」三条命令 → 全绿（`dart.exe analyze lib test` 0 问题、`flutter.bat test` 全绿、`npm run check` / `npm run test:scripts` / `npm run lint:design` 全绿）。

- [ ] **步骤 5：Commit**

```bash
git add apps/client_flutter/lib/src/features/rules/domain/character_rule_definition.dart apps/client_flutter/test/rules/rule_choice_definition_test.dart
git commit -m "feat(rules): 选择定义解析 repeatable/countsToward/requires/group/help"
```

---

## 任务 2：`RuleChoiceSemantics` 纯函数语义层

**文件：**
- 创建：`apps/client_flutter/lib/src/features/rules/domain/rule_choice_semantics.dart`
- 测试：`apps/client_flutter/test/rules/rule_choice_semantics_test.dart`（新建）

- [ ] **步骤 1：先写失败测试**

```dart
// test/rules/rule_choice_semantics_test.dart
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/rules/domain/character_rule_definition.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_choice_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final featA = _entry(
    id: 'p:feat/a',
    type: 'feat',
    name: 'A 专长',
    tags: const ['fighting-style'],
  );
  final featB = _entry(
    id: 'p:feat/b',
    type: 'feat',
    name: 'B 专长',
    tags: const ['fighting-style'],
  );
  final entries = {featA.id: featA, featB.id: featB};

  group('candidatesFor', () {
    test('内联选项在前（声明顺序），条目候选在后（等级→名称排序）', () {
      const definition = RuleChoiceDefinition(
        id: 'pick',
        label: '选一个',
        optionType: 'feat',
        minimum: 1,
        maximum: 1,
        optionTags: ['fighting-style'],
        options: [
          RuleChoiceOption(id: 'inline-1', label: '内联一'),
          RuleChoiceOption(id: 'inline-2', label: '内联二'),
        ],
      );

      final candidates = RuleChoiceSemantics.candidatesFor(
        definition,
        entries: entries,
      );

      expect(candidates.map((c) => c.id), ['inline-1', 'inline-2', featA.id, featB.id]);
      expect(candidates.first.isInline, isTrue);
      expect(candidates.last.entry, same(featA));
    });

    test('过滤（标签 / 等级 / 白名单）与 RuleChoiceResolver 同源', () {
      final highLevel = _entry(
        id: 'p:feat/high',
        type: 'feat',
        name: '高阶专长',
        tags: const ['fighting-style'],
        structured: const {'level': 8},
      );
      const definition = RuleChoiceDefinition(
        id: 'pick',
        label: '选一个',
        optionType: 'feat',
        minimum: 1,
        maximum: 1,
        optionTags: ['fighting-style'],
        maximumOptionLevel: 4,
      );

      final candidates = RuleChoiceSemantics.candidatesFor(
        definition,
        entries: {...entries, highLevel.id: highLevel},
      );

      expect(candidates.map((c) => c.id), [featA.id, featB.id]);
    });
  });

  group('normalizeSelection', () {
    const definition = RuleChoiceDefinition(
      id: 'pick',
      label: '选两个',
      optionType: 'feat',
      minimum: 1,
      maximum: 2,
      options: [
        RuleChoiceOption(id: 'a', label: 'A'),
        RuleChoiceOption(id: 'b', label: 'B'),
        RuleChoiceOption(id: 'c', label: 'C'),
      ],
    );

    test('非 repeatable：重复项只保留第一次，其余进 invalidSelected', () {
      final result = RuleChoiceSemantics.normalizeSelection(
        definition,
        const ['a', 'a', 'b'],
        entries: const {},
      );

      expect(result.selected, ['a', 'b']);
      expect(result.invalidSelected, ['a']);
      expect(result.violations, contains(RuleChoiceViolation.notRepeatable));
    });

    test('repeatable：同一 id 保留 N 次，maximum 是次数上限', () {
      const repeatable = RuleChoiceDefinition(
        id: 'pick',
        label: '选两个',
        optionType: 'feat',
        minimum: 1,
        maximum: 2,
        repeatable: true,
        options: [RuleChoiceOption(id: 'a', label: 'A')],
      );

      final ok = RuleChoiceSemantics.normalizeSelection(
        repeatable,
        const ['a', 'a'],
        entries: const {},
      );
      expect(ok.selected, ['a', 'a']);
      expect(ok.invalidSelected, isEmpty);

      final over = RuleChoiceSemantics.normalizeSelection(
        repeatable,
        const ['a', 'a', 'a'],
        entries: const {},
      );
      expect(over.selected, ['a', 'a']);
      expect(over.invalidSelected, ['a']);
      expect(over.violations, contains(RuleChoiceViolation.aboveMaximum));
    });

    test('不在候选集里的值进 invalidSelected（条目与内联一视同仁）', () {
      final result = RuleChoiceSemantics.normalizeSelection(
        definition,
        const ['a', 'p:feat/zzz'],
        entries: entries,
      );

      expect(result.selected, ['a']);
      expect(result.invalidSelected, ['p:feat/zzz']);
      expect(result.violations, contains(RuleChoiceViolation.notACandidate));
    });

    test('顺序即声明/用户选择顺序，不被排序改写', () {
      final result = RuleChoiceSemantics.normalizeSelection(
        definition,
        const ['c', 'a'],
        entries: const {},
      );

      expect(result.selected, ['c', 'a']);
    });
  });

  group('autoGrantsFor（字符串简写，契约 §3.10.2 表）', () {
    test('skill → proficiency: skill:<选项 id>', () {
      final grants = RuleChoiceSemantics.autoGrantsFor(
        optionType: 'skill',
        optionId: '察觉',
      )!;

      expect(grants, hasLength(1));
      expect(grants.single.kind, RuleGrantKind.proficiency);
      expect(grants.single.target, 'skill:察觉');
    });

    test('ability → ability，加值取 data[value]，缺省 1', () {
      final def = RuleChoiceSemantics.autoGrantsFor(
        optionType: 'ability',
        optionId: 'cha',
      )!;
      expect(def.single.kind, RuleGrantKind.ability);
      expect(def.single.target, 'cha');
      expect(def.single.value, 1);

      final plusTwo = RuleChoiceSemantics.autoGrantsFor(
        optionType: 'ability',
        optionId: 'cha',
        data: const {'value': 2},
      )!;
      expect(plusTwo.single.value, 2);
    });

    test('language / damageType / weaponMastery / value 只记录选择，不产出 grants', () {
      for (final type in ['language', 'damageType', 'weaponMastery', 'value']) {
        expect(
          RuleChoiceSemantics.autoGrantsFor(optionType: type, optionId: 'x'),
          isEmpty,
          reason: type,
        );
      }
    });

    test('条目类型无法推断 → null（导入期据此报 invalidAutoGrant）', () {
      for (final type in ['feat', 'spell', 'item', 'classFeature', 'equipmentBundle']) {
        expect(
          RuleChoiceSemantics.autoGrantsFor(optionType: type, optionId: 'x'),
          isNull,
          reason: type,
        );
      }
    });
  });

  group('grantsForSelection', () {
    test('显式 grants 优先于自动推断；重复项按次数展开', () {
      const definition = RuleChoiceDefinition(
        id: 'asi',
        label: '属性提升',
        optionType: 'ability',
        minimum: 1,
        maximum: 2,
        repeatable: true,
        options: [
          RuleChoiceOption(
            id: 'str',
            label: '力量 +1',
            grants: [
              RuleGrantDefinition(
                id: 'asi-str',
                kind: RuleGrantKind.ability,
                label: '力量提升',
                target: 'str',
                value: 1,
              ),
            ],
          ),
        ],
      );

      final grants = RuleChoiceSemantics.grantsForSelection(
        definition,
        const ['str', 'str'],
        entries: const {},
      );

      expect(grants, hasLength(2));
      expect(grants.every((g) => g.id == 'asi-str'), isTrue);
    });
  });

  group('requiresSatisfied', () {
    test('{choice, option} 命中同一 sourceEntryId 的已选值', () {
      const requires = [
        RuleRequiresDefinition(choice: 'spellbook', option: 'p:spell/a'),
      ];
      expect(
        RuleChoiceSemantics.requiresSatisfied(
          requires,
          sourceEntryId: 'p:class/mage',
          selectedByKey: const {
            'p:class/mage#spellbook': ['p:spell/a'],
          },
          abilities: const {},
          entries: entries,
        ),
        isTrue,
      );
    });

    test('多等级键（带 #等级）同样命中；祖先条目的选择也算', () {
      final subclass = _entry(
        id: 'p:subclass/x',
        type: 'subclass',
        name: 'X',
        relations: const [ContentRelation(type: 'subclassOf', targetId: 'p:class/mage')],
      );
      const requires = [
        RuleRequiresDefinition(choice: 'spellbook', option: 'p:spell/a'),
      ];
      expect(
        RuleChoiceSemantics.requiresSatisfied(
          requires,
          sourceEntryId: 'p:subclass/x',
          selectedByKey: const {
            'p:class/mage#spellbook#3': ['p:spell/a'],
          },
          abilities: const {},
          entries: {...entries, subclass.id: subclass},
        ),
        isTrue,
      );
    });

    test('{ability, minimum} 用入参基础属性判定', () {
      const requires = [RuleRequiresDefinition(ability: 'cha', minimum: 13)];
      expect(
        RuleChoiceSemantics.requiresSatisfied(
          requires,
          sourceEntryId: 'p:class/warlock',
          selectedByKey: const {},
          abilities: const {'cha': 13},
          entries: const {},
        ),
        isTrue,
      );
      expect(
        RuleChoiceSemantics.requiresSatisfied(
          requires,
          sourceEntryId: 'p:class/warlock',
          selectedByKey: const {},
          abilities: const {'cha': 12},
          entries: const {},
        ),
        isFalse,
      );
      // 属性键缺失 = 未记录 → 不满足（不猜成 10 或 0）。
      expect(
        RuleChoiceSemantics.requiresSatisfied(
          requires,
          sourceEntryId: 'p:class/warlock',
          selectedByKey: const {},
          abilities: const {},
          entries: const {},
        ),
        isFalse,
      );
    });

    test('空 requires 恒满足', () {
      expect(
        RuleChoiceSemantics.requiresSatisfied(
          const [],
          sourceEntryId: 'p:class/x',
          selectedByKey: const {},
          abilities: const {},
          entries: const {},
        ),
        isTrue,
      );
    });
  });

  group('definitionForKey', () {
    test('解析 <entryId>#<choiceId>[#<level>]，条目缺失返回 null', () {
      final classEntry = _entry(
        id: 'p:class/mage',
        type: 'class',
        name: '法师',
        rules: const CharacterRuleDefinition(
          choices: [
            RuleChoiceDefinition(
              id: 'spellbook',
              label: '法术书',
              optionType: 'spell',
              minimum: 1,
              maximum: 1,
            ),
          ],
        ),
      );

      final found = RuleChoiceSemantics.definitionForKey(
        'p:class/mage#spellbook#3',
        entries: {classEntry.id: classEntry},
      );

      expect(found, isNotNull);
      expect(found!.definition.id, 'spellbook');
      expect(found.sourceEntryId, 'p:class/mage');
      expect(found.level, 3);
      expect(
        RuleChoiceSemantics.definitionForKey(
          'p:class/missing#spellbook',
          entries: {classEntry.id: classEntry},
        ),
        isNull,
      );
    });
  });
}
```

> `test/support/content_test_support.dart` 里**没有** `testEntry` 这一层包装，本测试文件自带
> 一个与 `test/character_rules_engine_test.dart` 同形的局部 helper（构造 `ContentEntry.fromJson`）：

```dart
ContentEntry _entry({
  required String id,
  required String type,
  required String name,
  List<String> tags = const [],
  Map<String, Object?> structured = const {},
  List<ContentRelation> relations = const [],
  CharacterRuleDefinition? rules,
}) => ContentEntry.fromJson({
  'id': id,
  'type': type,
  'slug': id.split('/').last,
  'name': name,
  'body': <Object?>[],
  'revision': 1,
  'tags': tags,
  'structured': structured,
  'relations': [
    for (final relation in relations)
      {'type': relation.type, 'targetId': relation.targetId},
  ],
  if (rules != null) 'rules': rules.toJson(),
});
```

> `CharacterRuleDefinition.toJson()` 存在（`character_rule_definition.dart:459`），因此夹具可以直接
> 传 `CharacterRuleDefinition` 对象而不是手写 map。

- [ ] **步骤 2：运行确认失败**

运行：`cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test\rules\rule_choice_semantics_test.dart"`
预期：FAIL（`rule_choice_semantics.dart` 不存在）。

- [ ] **步骤 3：实现语义层**

```dart
// lib/src/features/rules/domain/rule_choice_semantics.dart
import '../../content/domain/content_entry.dart';
import 'character_rule_definition.dart';
import 'rule_choice_resolver.dart';

/// 一个候选选项的**统一视图**：内联选项与条目候选在 UI/引擎里不再分叉。
class RuleChoiceCandidate {
  const RuleChoiceCandidate({
    required this.id,
    required this.label,
    this.description,
    this.entry,
    this.grants = const <RuleGrantDefinition>[],
    this.data = const <String, Object?>{},
  });

  final String id;
  final String label;
  final String? description;
  final ContentEntry? entry;
  final List<RuleGrantDefinition> grants;
  final Map<String, Object?> data;

  bool get isInline => entry == null;
}

enum RuleChoiceViolation { notACandidate, notRepeatable, aboveMaximum }

class RuleChoiceSelection {
  const RuleChoiceSelection({
    required this.selected,
    required this.invalidSelected,
    required this.violations,
  });

  final List<String> selected;
  final List<String> invalidSelected;
  final Set<RuleChoiceViolation> violations;
}

/// 选择系统**纯函数语义层**：候选、选中值规范化、自动授予、前置条件、键解析。
///
/// 唯一实现点约定（规格 §3.10；本计划的「唯一实现点总表」）：
/// - 候选枚举只有 [candidatesFor] 一处（内联在前、条目在后，顺序稳定）；
/// - 选中值合法性只有 [normalizeSelection] 一处；
/// - 字符串简写自动授予只有 [autoGrantsFor] 一处（导入器与运行时共用）；
/// - `requires` 判定只有 [requiresSatisfied] 一处。
/// 任何调用方都不得再写"条目 vs 内联"或"重复 vs 非重复"的第二套判断。
abstract final class RuleChoiceSemantics {
  static List<RuleChoiceCandidate> candidatesFor(
    RuleChoiceDefinition definition, {
    required Map<String, ContentEntry> entries,
    String? sourceEntryId,
  }) {
    final inline = definition.options
        .map(
          (option) => RuleChoiceCandidate(
            id: option.id,
            label: option.label,
            description: option.description,
            grants: option.grants,
            data: option.data,
          ),
        )
        .toList(growable: false);
    final entryOptions = RuleChoiceResolver(entries: entries)
        .optionsFor(definition, sourceEntryId: sourceEntryId)
        .map(
          (entry) => RuleChoiceCandidate(
            id: entry.id,
            label: entry.name,
            entry: entry,
          ),
        )
        .toList(growable: false);
    return List<RuleChoiceCandidate>.unmodifiable([...inline, ...entryOptions]);
  }

  static RuleChoiceSelection normalizeSelection(
    RuleChoiceDefinition definition,
    List<String> requested, {
    required Map<String, ContentEntry> entries,
    String? sourceEntryId,
    int? effectiveMaximum,
  }) {
    final candidateIds = candidatesFor(
      definition,
      entries: entries,
      sourceEntryId: sourceEntryId,
    ).map((candidate) => candidate.id).toSet();
    final maximum = effectiveMaximum ?? definition.maximum;
    final selected = <String>[];
    final invalid = <String>[];
    final violations = <RuleChoiceViolation>{};
    for (final id in requested) {
      if (!candidateIds.contains(id)) {
        invalid.add(id);
        violations.add(RuleChoiceViolation.notACandidate);
        continue;
      }
      if (!definition.repeatable && selected.contains(id)) {
        invalid.add(id);
        violations.add(RuleChoiceViolation.notRepeatable);
        continue;
      }
      if (selected.length >= maximum) {
        invalid.add(id);
        violations.add(RuleChoiceViolation.aboveMaximum);
        continue;
      }
      selected.add(id);
    }
    return RuleChoiceSelection(
      selected: List<String>.unmodifiable(selected),
      invalidSelected: List<String>.unmodifiable(invalid),
      violations: Set<RuleChoiceViolation>.unmodifiable(violations),
    );
  }

  /// 字符串简写自动授予（契约 §3.10.2 表）。返回 `null` = **无法推断**（条目类型的
  /// 字符串元素）；返回空列表 = "只记录选择、不产出 grants"的值类型
  /// （`damageType` / `weaponMastery` / `value` / `language`）。
  static List<RuleGrantDefinition>? autoGrantsFor({
    required String optionType,
    required String optionId,
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    switch (optionType) {
      case 'skill':
        return [
          RuleGrantDefinition(
            id: 'skill:$optionId',
            kind: RuleGrantKind.proficiency,
            label: optionId,
            target: 'skill:$optionId',
          ),
        ];
      case 'ability':
        final raw = data['value'];
        final value = raw is num && raw > 0 ? raw.toInt() : 1;
        return [
          RuleGrantDefinition(
            id: 'ability:$optionId',
            kind: RuleGrantKind.ability,
            label: optionId,
            target: optionId,
            value: value,
          ),
        ];
      case 'language':
      case 'damageType':
      case 'weaponMastery':
      case 'value':
        return const <RuleGrantDefinition>[];
      default:
        return null;
    }
  }

  static List<RuleGrantDefinition> grantsForSelection(
    RuleChoiceDefinition definition,
    List<String> selected, {
    required Map<String, ContentEntry> entries,
    String? sourceEntryId,
  }) {
    final candidates = {
      for (final candidate in candidatesFor(
        definition,
        entries: entries,
        sourceEntryId: sourceEntryId,
      ))
        candidate.id: candidate,
    };
    final result = <RuleGrantDefinition>[];
    for (final id in selected) {
      final candidate = candidates[id];
      if (candidate == null) continue;
      if (candidate.grants.isNotEmpty) {
        result.addAll(candidate.grants);
        continue;
      }
      final auto = autoGrantsFor(
        optionType: definition.optionType,
        optionId: candidate.id,
        data: candidate.data,
      );
      if (auto != null) result.addAll(auto);
    }
    return List<RuleGrantDefinition>.unmodifiable(result);
  }

  static bool requiresSatisfied(
    List<RuleRequiresDefinition> requires, {
    required String sourceEntryId,
    required Map<String, List<String>> selectedByKey,
    required Map<String, int> abilities,
    required Map<String, ContentEntry> entries,
  }) {
    if (requires.isEmpty) return true;
    final scope = scopeEntryIdsFor(sourceEntryId, entries);
    for (final requirement in requires) {
      if (requirement.isAbilityForm) {
        final score = abilities[requirement.ability];
        if (score == null || score < requirement.minimum!) return false;
        continue;
      }
      final chosen = _selectedOptions(
        selectedByKey,
        scope: scope,
        choiceId: requirement.choice!,
      );
      if (chosen.isEmpty) return false;
      final option = requirement.option;
      if (option != null && !chosen.contains(option)) return false;
    }
    return true;
  }

  static ({RuleChoiceDefinition definition, String sourceEntryId, int? level})?
  definitionForKey(
    String key, {
    required Map<String, ContentEntry> entries,
  }) {
    final parts = key.split('#');
    if (parts.length < 2) return null;
    final entry = entries[parts[0]];
    if (entry == null) return null;
    final level = parts.length >= 3 ? int.tryParse(parts[2]) : null;
    for (final definition in _definitionsOf(entry)) {
      if (definition.id == parts[1]) {
        return (
          definition: definition,
          sourceEntryId: entry.id,
          level: level,
        );
      }
    }
    return null;
  }

  /// `<sourceEntryId>` 及其沿 `featureOf` / `subclassOf` 向上找到的祖先（§3.11 A4）。
  ///
  /// 公开实现点：运行期 [requiresSatisfied] 与导入期 `requires` 引用校验都调它，
  /// 导入器**不得**自己再写一遍关系链遍历。
  static Set<String> scopeEntryIdsFor(
    String sourceEntryId,
    Map<String, ContentEntry> entries,
  ) {
    final scope = <String>{sourceEntryId};
    var pending = <String>{sourceEntryId};
    while (pending.isNotEmpty) {
      final next = <String>{};
      for (final id in pending) {
        final entry = entries[id];
        if (entry == null) continue;
        for (final relation in entry.relations) {
          if (relation.type != 'featureOf' && relation.type != 'subclassOf') {
            continue;
          }
          if (scope.add(relation.targetId)) next.add(relation.targetId);
        }
      }
      pending = next;
    }
    return scope;
  }

  static List<String> _selectedOptions(
    Map<String, List<String>> selectedByKey, {
    required Set<String> scope,
    required String choiceId,
  }) {
    final values = <String>[];
    selectedByKey.forEach((key, selected) {
      final parts = key.split('#');
      if (parts.length < 2) return;
      if (!scope.contains(parts[0]) || parts[1] != choiceId) return;
      for (final value in selected) {
        if (!values.contains(value)) values.add(value);
      }
    });
    return values;
  }

  static Iterable<RuleChoiceDefinition> _definitionsOf(ContentEntry entry) sync* {
    final rules = entry.rules;
    if (rules == null) return;
    yield* rules.choices;
    for (final step in rules.progression) {
      yield* step.choices;
    }
  }
}
```

- [ ] **步骤 4：运行测试**

运行：`cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test\rules\rule_choice_semantics_test.dart"`
预期：PASS。

**实现要点**
- `candidatesFor` 的条目侧**必须**复用 `RuleChoiceResolver.optionsFor`（过滤/排序语义已在那里），不得复制一份过滤逻辑。
- `normalizeSelection` 不排序：顺序即用户选择顺序（`Set` → `List` 的关键行为）。
- `autoGrantsFor` 对 `ability` 读 `data['value']`（决策 D4）；对条目类型返回 `null`（决策 D5）。
- `requiresSatisfied` 的 `ability` 一律读入参 `abilities`（决策 D2），缺失即不满足。

**验收：** 上一步「运行」里的目标测试命令 → PASS；再跑「任务门禁」三条命令 → 全绿（`dart.exe analyze lib test` 0 问题、`flutter.bat test` 全绿、`npm run check` / `npm run test:scripts` / `npm run lint:design` 全绿）。

- [ ] **步骤 5：Commit**

```bash
git add apps/client_flutter/lib/src/features/rules/domain/rule_choice_semantics.dart apps/client_flutter/test/rules/rule_choice_semantics_test.dart
git commit -m "feat(rules): 新增选择语义纯函数层（候选/规范化/自动授予/前置条件）"
```

---

## 任务 3：引擎消费内联选项 grants 与 `repeatable`

**文件：**
- 修改：`apps/client_flutter/lib/src/features/rules/domain/character_rules_engine.dart`
- 测试：`apps/client_flutter/test/character_rules_engine_test.dart`（追加分组）

- [ ] **步骤 1：先写失败测试**

```dart
// test/character_rules_engine_test.dart（追加一个 group）
group('内联选项与 repeatable（契约 §3.10.2 / §3.10.3）', () {
  final plan = _entry(
    id: 'test:class/ascendant-choices',
    type: 'class',
    name: '晋升者',
    rules: const {
      'choices': [
        {
          'id': 'asi',
          'label': '属性提升',
          'optionType': 'ability',
          'minimum': 1,
          'maximum': 2,
          'repeatable': true,
          'options': [
            {
              'id': 'str',
              'label': '力量 +1',
              'grants': [
                {
                  'id': 'asi-str',
                  'kind': 'ability',
                  'label': '力量提升',
                  'target': 'str',
                  'value': 1,
                },
              ],
            },
          ],
        },
        {
          'id': 'training',
          'label': '技能训练',
          'optionType': 'skill',
          'minimum': 1,
          'maximum': 1,
          'options': ['察觉'],
        },
      ],
    },
  );
  final engine = CharacterRulesEngine(entries: {plan.id: plan});

  test('内联 grants 选中即进 ledger；option id 不被当条目排进 missing', () {
    final ledger = engine.evaluate(
      const CharacterBuild(
        level: 1,
        selections: {'class': 'test:class/ascendant-choices'},
        choices: {'test:class/ascendant-choices#asi': ['str']},
      ),
    );

    expect(ledger.missingEntryIds, isEmpty, reason: 'str 是内联选项，不是条目 id');
    expect(ledger.resolvedChoiceEntryIds, isEmpty);
    final grant = ledger.grants.singleWhere((g) => g.id == 'asi-str');
    expect(grant.kind, RuleGrantKind.ability);
    expect(grant.target, 'str');
    expect(grant.value, 1);
  });

  test('repeatable: true 同一选项选两次 → 两份生效单元；resolvedChoices 保留重复', () {
    final ledger = engine.evaluate(
      const CharacterBuild(
        level: 1,
        selections: {'class': 'test:class/ascendant-choices'},
        choices: {
          'test:class/ascendant-choices#asi': ['str', 'str'],
          'test:class/ascendant-choices#training': ['察觉'],
        },
      ),
    );

    expect(ledger.grants.where((g) => g.id == 'asi-str'), hasLength(2));
    expect(ledger.resolvedChoices['test:class/ascendant-choices#asi'], ['str', 'str']);
    expect(ledger.pendingChoices, isEmpty);
  });

  test('repeatable: false 的重复选中进 invalidSelected，且不重复结算', () {
    final ledger = engine.evaluate(
      const CharacterBuild(
        level: 1,
        selections: {'class': 'test:class/ascendant-choices'},
        choices: {
          'test:class/ascendant-choices#asi': ['str'],
          'test:class/ascendant-choices#training': ['察觉', '察觉'],
        },
      ),
    );

    final pending = ledger.pendingChoices.singleWhere(
      (choice) => choice.choiceId == 'training',
    );
    expect(pending.selected, ['察觉']);
    expect(pending.invalidSelected, ['察觉']);
    expect(pending.reason, RuleChoicePendingReason.notRepeatable);
    expect(
      ledger.grants.where((g) => g.kind == RuleGrantKind.proficiency),
      hasLength(1),
    );
  });

  test('字符串简写 skill 选项自动授予熟练（无需显式 grants）', () {
    final ledger = engine.evaluate(
      const CharacterBuild(
        level: 1,
        selections: {'class': 'test:class/ascendant-choices'},
        choices: {'test:class/ascendant-choices#training': ['察觉']},
      ),
    );

    final grant = ledger.grants.singleWhere(
      (g) => g.kind == RuleGrantKind.proficiency,
    );
    expect(grant.target, 'skill:察觉');
  });
});
```

- [ ] **步骤 2：运行确认失败**

运行：`cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test\character_rules_engine_test.dart"`
预期：FAIL（内联 id 被判非法 / grants 缺失 / `reason` 未定义）。

- [ ] **步骤 3：改 `character_rules_engine.dart`**

1) 新增键函数（放在 `ruleUnitKey` 旁）：

```dart
/// 内联选项授予的**生效单元键**：`<选择键>#<选项 id>#<第几次>`。
///
/// `repeatable: true` 时同一选项的每一次选择都是独立生效单元（选两次"力量 +1"
/// 要累计 +2），因此第几次（从 0 起）必须进键；非 repeatable 时下标恒为 0。
/// 这是该键格式的**唯一实现点**：`resolvedGrants` 落库、升级 diff、属性逆运算
/// 都只经过它。
String ruleChoiceGrantKey(String choiceKey, String optionId, int occurrence) =>
    '$choiceKey#$optionId#$occurrence';
```

2) `PendingRuleChoice` 增 `reason`（可选，默认 null）与 `RuleChoicePendingReason` 枚举：

```dart
enum RuleChoicePendingReason {
  belowMinimum,
  aboveMaximum,
  notACandidate,
  notRepeatable,
  requiresUnsatisfied,
  poolExceeded,
}
```

3) `ActiveRuleChoice` 增（全部给默认值，避免任务 4/5 再改构造点）：

```dart
  final bool repeatable;
  final bool requiresSatisfied;
  final String? group;
  final String? help;
  final String? pool;
  final int? poolCap;
```

`isValid` 增加 `requiresSatisfied` 条件（`invalidSelected.isEmpty && 长度区间 && requiresSatisfied`）。

4) `_resolveChoices` 改为：

```dart
    final resolver = RuleChoiceResolver(entries: entries);
    for (final definition in definitions) {
      final key = ruleUnitKey(entry.id, definition.id, sourceLevel);
      final requested = build.choices[key] ??
          (sourceLevel == null
              ? const <String>[]
              : build.choices[ruleUnitKey(entry.id, definition.id, null)] ??
                    const <String>[]);
      final normalized = RuleChoiceSemantics.normalizeSelection(
        definition,
        requested,
        entries: entries,
        sourceEntryId: entry.id,
      );
      final selection = normalized.selected;
      // 内联选项的 grants 进同一本账：每次出现都是一个独立生效单元
      // （`repeatable` 选两次"力量 +1"就要累计 +2），键带出现序号。
      final occurrences = <String, int>{};
      for (final optionId in selection) {
        final occurrence = occurrences.update(
          optionId,
          (count) => count + 1,
          ifAbsent: () => 0,
        );
        final optionGrants = RuleChoiceSemantics.grantsForSelection(
          definition,
          <String>[optionId],
          entries: entries,
          sourceEntryId: entry.id,
        );
        for (final grant in optionGrants) {
          final grantKey = ruleChoiceGrantKey(key, optionId, occurrence);
          target[grantKey] = ResolvedRuleGrant(
            id: grant.id,
            kind: grant.kind,
            label: grant.label,
            sourceEntryId: entry.id,
            sourceEntryName: entry.name,
            sourceLevel: sourceLevel,
            target: grant.target,
            entryId: grant.entryId,
            value: grant.value,
            formula: grant.formula,
            data: grant.data,
          );
        }
      }
      ...
      final accepted = selection;              // 已按 maximum 截断
      resolvedChoices[key] = accepted;
      // 只把**条目**候选排进队列：内联 id 不是条目，入队只会污染 missingEntryIds。
      final entryBacked = accepted
          .where((id) => entries.containsKey(id))
          .toList(growable: false);
      resolvedChoiceEntryIds.addAll(entryBacked);
      queue.addAll(entryBacked);
    }
```

> 上面是**结构示意**，不是逐字代码：内联 grants 的展开必须调
> `RuleChoiceSemantics.grantsForSelection`（唯一实现点），不得在引擎里再写一份自动推断。

`_resolveGrants` 需要能接收 `target` map（已有），因此把内联 grants 的写入放在 `_resolveChoices` 里通过一个新增的 `target` 参数完成；`_resolveChoices` 的调用点（`evaluate` 内两处）补传 `grants`。

5) `pending` 的构造：把 `reason` 按优先级给出（`requiresUnsatisfied` > `notACandidate` > `notRepeatable` > `aboveMaximum` > `belowMinimum`），并把 `normalized.violations` 映射成对应枚举。

- [ ] **步骤 4：运行测试与全量回归**

运行：`cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test\character_rules_engine_test.dart"`
预期：PASS，且原有 700+ 行引擎断言不变。
再跑一次 `flutter.bat test`（全量）确认三处 UI 未因 `ActiveRuleChoice` 新字段而红。

**实现要点**
- 选中值里**只有** `entries.containsKey(id)` 的才入队（修掉当前"内联 id 污染 `missingEntryIds`"）。
- `resolvedChoiceEntryIds`（内容引用）同样只收条目 id；`repeatable` 的重复值靠 `Set` 天然去重。
- `resolvedChoices` 保留重复（落库形状 = "同一选项出现 N 次"），这是 §3.10.3-4 要求的表达力。
- 非 repeatable 的重复值进 `invalidSelected` 而不是静默去重：§3.10.3-7。

**验收：** 上一步「运行」里的目标测试命令 → PASS；再跑「任务门禁」三条命令 → 全绿（`dart.exe analyze lib test` 0 问题、`flutter.bat test` 全绿、`npm run check` / `npm run test:scripts` / `npm run lint:design` 全绿）。

- [ ] **步骤 5：Commit**

```bash
git add apps/client_flutter/lib/src/features/rules/domain/character_rules_engine.dart apps/client_flutter/test/character_rules_engine_test.dart
git commit -m "feat(rules): 引擎消费内联选项 grants 与 repeatable"
```

---

## 任务 4：`requires` 接线（`CharacterBuild.abilities` + 引擎判定）

**文件：**
- 修改：`apps/client_flutter/lib/src/features/rules/domain/character_build.dart`
- 修改：`apps/client_flutter/lib/src/features/rules/domain/character_rules_engine.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/domain/rules_driven_character_builder.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/domain/character_rule_projector.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/domain/character_upgrade_planner.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_editor_page.dart`
- 测试：`apps/client_flutter/test/character_rules_engine_test.dart`、`apps/client_flutter/test/character_rule_projector_test.dart`、`apps/client_flutter/test/character_upgrade_planner_test.dart`

- [ ] **步骤 1：先写失败测试**

```dart
// test/character_rules_engine_test.dart（追加）
group('requires（契约 §3.10.2 / §3.10.3-5）', () {
  final plan = _entry(
    id: 'test:class/warlockish',
    type: 'class',
    name: '契术师',
    rules: const {
      'choices': [
        {
          'id': 'spellbook',
          'label': '法术书',
          'optionType': 'feat',
          'minimum': 1,
          'maximum': 1,
          'optionTags': ['grimoire'],
        },
        {
          'id': 'invocations',
          'label': '祈唤',
          'optionType': 'classFeature',
          'minimum': 1,
          'maximum': 1,
          'optionTags': ['invocation'],
          'requires': [
            {'ability': 'cha', 'minimum': 13},
            {'choice': 'spellbook', 'option': 'test:feat/grimoire'},
          ],
        },
      ],
    },
  );
  final grimoire = _entry(
    id: 'test:feat/grimoire',
    type: 'feat',
    name: '魔典',
    tags: const ['grimoire'],
  );
  final invocation = _entry(
    id: 'test:class-feature/agonizing',
    type: 'classFeature',
    name: '苦痛祈唤',
    tags: const ['invocation'],
  );
  final engine = CharacterRulesEngine(
    entries: {plan.id: plan, grimoire.id: grimoire, invocation.id: invocation},
  );

  CharacterGrantLedger evaluate({required int cha, required List<String> book}) =>
      engine.evaluate(
        CharacterBuild(
          level: 1,
          abilities: {'cha': cha},
          selections: {'class': plan.id},
          choices: {
            'test:class/warlockish#spellbook': book,
            'test:class/warlockish#invocations': [invocation.id],
          },
        ),
      );

  test('能力门槛不满足 → requiresSatisfied=false 且进 pending', () {
    final ledger = evaluate(cha: 12, book: [grimoire.id]);
    final active = ledger.activeChoices.singleWhere(
      (c) => c.definition.id == 'invocations',
    );
    expect(active.requiresSatisfied, isFalse);
    expect(active.isValid, isFalse);
    expect(
      ledger.pendingChoices
          .firstWhere((p) => p.choiceId == 'invocations')
          .reason,
      RuleChoicePendingReason.requiresUnsatisfied,
    );
  });

  test('引用的选择未满足 → 不可选；两项都满足 → 生效', () {
    expect(
      evaluate(cha: 13, book: const [])
          .pendingChoices
          .firstWhere((p) => p.choiceId == 'invocations')
          .reason,
      RuleChoicePendingReason.requiresUnsatisfied,
    );
    expect(evaluate(cha: 13, book: [grimoire.id]).pendingChoices, isEmpty);
  });

  test('CharacterBuild.abilities JSON 往返，缺省为空 map', () {
    const build = CharacterBuild(level: 3, abilities: {'cha': 15});
    expect(CharacterBuild.fromJson(build.toJson()).abilities, {'cha': 15});
    expect(const CharacterBuild(level: 1).abilities, isEmpty);
    expect(CharacterBuild.fromJson(const {'level': 1}).abilities, isEmpty);
  });
});
```

```dart
// test/character_rule_projector_test.dart（追加）
test('项目器回填 build.abilities，使 requires 不因旧存档永远 pending', () {
  final character = _characterWithSavedBuildWithoutAbilities(abilities: {'cha': 15});
  final projected = CharacterRuleProjector(entries: _entries()).project(character);
  expect(
    (projected.dataMap['build']! as Map)['abilities'],
    {'cha': 15},
  );
});
```

- [ ] **步骤 2：运行确认失败**

运行：`cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test\character_rules_engine_test.dart test\character_rule_projector_test.dart"`
预期：FAIL（`CharacterBuild.abilities` 不存在；`requiresSatisfied` 恒为 true）。

- [ ] **步骤 3：实现**

1) `character_build.dart`：

```dart
class CharacterBuild {
  const CharacterBuild({
    required this.level,
    this.selections = const <String, String>{},
    this.choices = const <String, List<String>>{},
    this.abilities = const <String, int>{},
  });

  final int level;
  final Map<String, String> selections;
  final Map<String, List<String>> choices;

  /// `requires: {ability, minimum}` 的**唯一数据源**（决策 D2）：入参基础属性，
  /// 不是结算后的有效属性——`kind: ability` 加值由选择产生，用结算值会让
  /// `requires` 与选择互相引用。缺省空 map = "未记录属性"，能力型 requires 一律
  /// 判定为不满足（可见的 pending），绝不猜成 10。
  final Map<String, int> abilities;
```

`toJson` 增 `if (abilities.isNotEmpty) 'abilities': abilities`；`fromJson` 解析 `abilities`（`num` → `int`，非 map 视为空）。

2) `character_rules_engine.dart`：`_resolveChoices` 在 `normalizeSelection` 之后计算

```dart
      final requiresSatisfied = RuleChoiceSemantics.requiresSatisfied(
        definition.requires,
        sourceEntryId: entry.id,
        selectedByKey: build.choices,
        abilities: build.abilities,
        entries: entries,
      );
```

写入 `ActiveRuleChoice.requiresSatisfied`；当 `!requiresSatisfied` 时把该选择加入 `pending`（`reason: requiresUnsatisfied`），并**保留** `selected`/`invalidSelected` 供 UI 说明"为什么不生效"。

3) 各构造点带上 `abilities`：
- `RulesDrivenCharacterBuilder.build`：`effectiveBuild` 增 `abilities: build.abilities`；
- `CharacterRuleProjector.project`：`baseAbilitiesFrom` 的结果既传给 `builder.build(abilities:)`，也写回重建的 `CharacterBuild.abilities`（旧存档自愈）；
- `CharacterUpgradePlanner`：`plan` / `apply` 里的 `CharacterBuild` 增 `abilities`（从 `character.dataMap['build']['abilities']` 读出，缺失时用 `RulesDrivenCharacterBuilder.baseAbilitiesFrom`）；
- `character_editor_page._submitQuickBuild`：构造 `CharacterBuild(...)` 时增 `abilities: quickDraft.abilities ?? Dnd5eRules.defaultAbilities`；
- `character_editor_page._upgradePreview`：`nextBuild` / `previousBuild` 沿用 `previousBuild.abilities`。

- [ ] **步骤 4：运行测试与全量回归**

运行：
```
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test\character_rules_engine_test.dart test\character_rule_projector_test.dart test\character_upgrade_planner_test.dart"
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test"
```
预期：PASS 且全绿。

**实现要点**
- `abilities` 是**基础属性**（决策 D2）。`RulesDrivenCharacterBuilder._abilityGrantBonuses` 之后的有效属性**不**回写到 `build`，否则下次派生会双重叠加。
- 缺 `abilities` 的旧存档：项目器一次回填；不再有"永远 pending"。
- `requires` 不满足时**不丢弃**选中值（§3.10.3-5）；pending 里带 `reason`。

**验收：** 上一步「运行」里的目标测试命令 → PASS；再跑「任务门禁」三条命令 → 全绿（`dart.exe analyze lib test` 0 问题、`flutter.bat test` 全绿、`npm run check` / `npm run test:scripts` / `npm run lint:design` 全绿）。

- [ ] **步骤 5：Commit**

```bash
git add apps/client_flutter/lib apps/client_flutter/test/character_rules_engine_test.dart apps/client_flutter/test/character_rule_projector_test.dart apps/client_flutter/test/character_upgrade_planner_test.dart
git commit -m "feat(rules): requires 前置条件生效（能力门槛 + 选择引用）"
```

---

## 任务 5：`countsToward` 额度语义

**文件：**
- 创建：`apps/client_flutter/lib/src/features/rules/domain/rule_choice_quota.dart`
- 修改：`apps/client_flutter/lib/src/features/rules/domain/character_rules_engine.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/domain/rules_driven_character_builder.dart`、`character_upgrade_planner.dart`、`character_rule_projector.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_editor_page.dart`
- 测试：`apps/client_flutter/test/rules/rule_choice_quota_test.dart`（新建）、`test/character_rules_engine_test.dart`

- [ ] **步骤 1：先写失败测试**

```dart
// test/rules/rule_choice_quota_test.dart
import 'package:dnd_table_client/src/features/characters/domain/dnd5e_rules.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_choice_quota.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rule_profile_test_support.dart';

void main() {
  test('没有 countsToward：只受 maximum 约束', () {
    expect(
      RuleChoiceQuota.effectiveMaximum(
        countsToward: null,
        maximum: 6,
        poolLimit: 4,
        usedByOthers: 3,
      ),
      6,
    );
  });

  test('prepared / known 共用同一数值列；spellbook 无独立列 → 无额度（决策 D1）', () {
    expect(
      RuleChoiceQuota.effectiveMaximum(
        countsToward: 'prepared',
        maximum: 6,
        poolLimit: 4,
        usedByOthers: 1,
      ),
      3,
    );
    expect(
      RuleChoiceQuota.effectiveMaximum(
        countsToward: 'known',
        maximum: 6,
        poolLimit: 4,
        usedByOthers: 0,
      ),
      4,
    );
    expect(
      RuleChoiceQuota.effectiveMaximum(
        countsToward: 'spellbook',
        maximum: 6,
        poolLimit: 4,
        usedByOthers: 2,
      ),
      6,
      reason: '法术书容量未建模，不能被 prepared 列反向限制',
    );
  });

  test('池被占满时有效上限为 0（不是负数）', () {
    expect(
      RuleChoiceQuota.effectiveMaximum(
        countsToward: 'prepared',
        maximum: 3,
        poolLimit: 2,
        usedByOthers: 5,
      ),
      0,
    );
  });

  test('未知池名（程序化构造绕过解析层）按"不占池"处理，不抛异常', () {
    expect(
      RuleChoiceQuota.effectiveMaximum(
        countsToward: 'rituals',
        maximum: 2,
        poolLimit: 1,
        usedByOthers: 0,
      ),
      2,
    );
  });

  test('limitsFor：prepared 与 known 取职业 prepared 表，spellbook 不出现', () async {
    await Dnd5eRules.configure(await loadBuiltinProfileForTest());
    addTearDown(Dnd5eRules.resetForTests);
    final wizard = Dnd5eRules.resolveClassRules(
      entryId: 'x:class/wizard',
      classSummary: '法师',
    );

    final limits = RuleChoiceQuota.limitsFor(rules: wizard, level: 1);

    // 法师 1 级 prepared = 4（`assets/rules/dnd5e-2024.rules.json`，
    // 见 `builtin_rule_profile_test.dart` 的同表断言）。
    expect(limits, {'prepared': 4, 'known': 4});
    expect(limits.containsKey('spellbook'), isFalse);
  });
}
```

```dart
// test/character_rules_engine_test.dart（追加）
test('两个选择共享 prepared 池：先声明先占，超出部分进 pending（poolExceeded）', () {
  final plan = _entry(
    id: 'test:class/spellkeeper',
    type: 'class',
    name: '持法者',
    rules: const {
      'choices': [
        {
          'id': 'book',
          'label': '法术书',
          'optionType': 'spell',
          'minimum': 0,
          'maximum': 3,
          'countsToward': 'prepared',
          'optionTags': ['spell-list:mage'],
        },
        {
          'id': 'extra',
          'label': '额外法术',
          'optionType': 'spell',
          'minimum': 0,
          'maximum': 2,
          'countsToward': 'prepared',
          'optionTags': ['spell-list:mage'],
        },
      ],
    },
  );
  // 4 个 spell 条目（test:spell/a..d），标签均为 ['spell-list:mage']；
  // `_entry` 沿用 test/character_rules_engine_test.dart 的夹具，条目对象在此省略。
  final engine = CharacterRulesEngine(entries: {...});
  final ledger = engine.evaluate(
    const CharacterBuild(
      level: 1,
      selections: {'class': 'test:class/spellkeeper'},
      choices: {
        'test:class/spellkeeper#book': ['test:spell/a', 'test:spell/b', 'test:spell/c'],
        'test:class/spellkeeper#extra': ['test:spell/d'],
      },
    ),
    poolLimits: const {'prepared': 3},
  );

  expect(ledger.resolvedChoices['test:class/spellkeeper#book'], hasLength(3));
  expect(ledger.resolvedChoices['test:class/spellkeeper#extra'], isEmpty);
  expect(
    ledger.pendingChoices.single.reason,
    RuleChoicePendingReason.poolExceeded,
  );
  expect(ledger.activeChoices.last.poolCap, 3);
});
```

- [ ] **步骤 2：运行确认失败**

运行：`cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test\rules\rule_choice_quota_test.dart test\character_rules_engine_test.dart"`
预期：FAIL。

- [ ] **步骤 3：实现**

```dart
// lib/src/features/rules/domain/rule_choice_quota.dart
import 'rule_profile.dart';   // ResolvedClassRules（rules/domain，不是 characters/domain）

/// `countsToward` 的额度语义（契约 §3.10.2）。
///
/// 池上限的**唯一来源**是 [limitsFor]：`prepared` 与 `known` 共用职业 `prepared`
/// 表，`spellbook` **不出现**（`classRules` 没有法术书容量列，见决策 D1）。
/// 本文件只做算术，不查内容仓库、不读 `Dnd5eRules`：调用方把已解析的
/// [ResolvedClassRules] 与等级传进来。
abstract final class RuleChoiceQuota {
  static Map<String, int> limitsFor({
    required ResolvedClassRules rules,
    required int level,
  }) {
    final prepared = rules.preparedLimit(level);
    if (prepared == null) return const <String, int>{};
    return <String, int>{'prepared': prepared, 'known': prepared};
  }

  static int effectiveMaximum({
    required String? countsToward,
    required int maximum,
    required Map<String, int> poolLimits,
    required int usedByOthers,
  }) {
    // 未知池名（只可能来自程序化构造）按"不占池"处理：解析层与导入器已把非法
    // 取值挡在门外，运行期不再制造第二种失败模式。
    if (countsToward == null) return maximum;
    final limit = poolLimits[countsToward];
    if (limit == null) return maximum;
    final remaining = limit - usedByOthers;
    if (remaining <= 0) return 0;
    return remaining < maximum ? remaining : maximum;
  }
}
```

`CharacterRulesEngine.evaluate` 增可选参数：

```dart
  CharacterGrantLedger evaluate(
    CharacterBuild build, {
    Map<String, int> poolLimits = const <String, int>{},
  }) {
```

在 `_resolveChoices` 里，池占用按**确定遍历顺序**先声明先占（决策 D8）：`evaluate` 维护 `poolUsage: Map<String, int>`，处理每个选择前算出 `usedByOthers = 池总占用`，处理完把本选择的 `selected.length` 累加进池；`effectiveMaximum = RuleChoiceQuota.effectiveMaximum(...)` 传给 `normalizeSelection`；若 `normalized.violations.contains(aboveMaximum)` 且 `definition.countsToward != null` 且池上限存在 → `reason: poolExceeded`（否则 `aboveMaximum`）。`ActiveRuleChoice` 增 `pool` / `poolCap`。

生产调用点补 `poolLimits:`（都用 `RuleChoiceQuota.limitsFor(rules: classRules, level: level)`）：
- `RulesDrivenCharacterBuilder.build`（已有 `classRules`）；
- `RulesDrivenCharacterBuilder.baseAbilitiesFrom`（同上）；
- `CharacterRuleProjector.project`（同上）；
- `CharacterUpgradePlanner`（已有 `classRules`）；
- `character_editor_page._upgradePreview`（`Dnd5eRules.resolveClassRules` 取职业条目后算）。

- [ ] **步骤 4：运行测试与全量回归**

运行：`cmd.exe /c "cd /d ... && C:\Flutter\flutter\bin\flutter.bat test test\rules\rule_choice_quota_test.dart test\character_rules_engine_test.dart test\rules_driven_character_builder_test.dart"`
预期：PASS；再跑全量 `flutter.bat test` 全绿。

**实现要点**
- 池是**角色级**共享，不是选择级：`usedByOthers` 是同一池内其它选择的已选总数。
- `maximum` 与池上限取小；两者都不满足时以更小者为准，超出部分进 `invalidSelected`（可见）。
- `spellbook` 永不因 `prepared` 列被限制（决策 D1）；文档任务 12 必须写明。

**验收：** 上一步「运行」里的目标测试命令 → PASS；再跑「任务门禁」三条命令 → 全绿（`dart.exe analyze lib test` 0 问题、`flutter.bat test` 全绿、`npm run check` / `npm run test:scripts` / `npm run lint:design` 全绿）。

- [ ] **步骤 5：Commit**

```bash
git add apps/client_flutter/lib apps/client_flutter/test/rules/rule_choice_quota_test.dart apps/client_flutter/test/character_rules_engine_test.dart
git commit -m "feat(rules): countsToward 计入共享额度池"
```

---

## 任务 6a：共享选择组件 + 三处界面迁移到有序 `List`

**文件：**
- 创建：`apps/client_flutter/lib/src/features/characters/presentation/widgets/rule_choice_section.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_editor_rule_choices.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_editor_builder_page.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_editor_creation_flow.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_editor_page.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_upgrade_page.dart`
- 测试：`apps/client_flutter/test/rule_choice_section_test.dart`（新建）、`test/character_builder_choices_test.dart`

- [ ] **步骤 1：先写失败测试**

```dart
// test/rule_choice_section_test.dart
import 'package:dnd_table_client/src/features/characters/presentation/widgets/rule_choice_section.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/rules/domain/character_rule_definition.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_choice_semantics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const definition = RuleChoiceDefinition(
    id: 'pick',
    label: '选择战斗风格',
    optionType: 'feat',
    minimum: 1,
    maximum: 2,
    options: [
      RuleChoiceOption(id: 'a', label: '决斗'),
      RuleChoiceOption(id: 'b', label: '防御'),
    ],
  );

  testWidgets('选中顺序即点击顺序（有序 List，不是 Set）', (tester) async {
    var selected = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => RuleChoiceSection(
              definition: definition,
              candidates: RuleChoiceSemantics.candidatesFor(
                definition,
                entries: const <String, ContentEntry>{},
              ),
              selected: selected,
              onChanged: (next) => setState(() => selected = next),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('防御'));
    await tester.pump();
    await tester.tap(find.text('决斗'));
    await tester.pump();

    expect(selected, ['b', 'a'], reason: '顺序即点击顺序，不被排序改写');
  });

  testWidgets('取消选择按 id 移除，不影响其它项', (tester) async {
    List<String>? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RuleChoiceSection(
            definition: definition,
            candidates: RuleChoiceSemantics.candidatesFor(
              definition,
              entries: const <String, ContentEntry>{},
            ),
            selected: const ['a', 'b'],
            onChanged: (next) => changed = next,
          ),
        ),
      ),
    );

    await tester.tap(find.text('决斗'));
    await tester.pump();

    expect(changed, ['b']);
  });
}
```

```dart
// test/character_builder_choices_test.dart（追加）
testWidgets('选择顺序按用户点击顺序落进 build.choices（Set → List）', (tester) async {
  CharacterEditDraft? submitted;
  // 夹具：职业 1 级有 minimum 2 / maximum 2 的条目类型选择 + 两个候选条目。
  // 依次点第二个、第一个 → 断言
  // submitted.data['build']['choices']['guide:class/x#style'] == [第二, 第一]
  ...
});
```

- [ ] **步骤 2：运行确认失败**

运行：`cmd.exe /c "cd /d ... && C:\Flutter\flutter\bin\flutter.bat test test\rule_choice_section_test.dart test\character_builder_choices_test.dart"`
预期：FAIL（组件不存在 / 回调仍是 `Set`）。

- [ ] **步骤 3：写共享组件**

`RuleChoiceSection` 的契约（**唯一的选择渲染器**）：

```dart
class RuleChoiceSection extends StatelessWidget {
  const RuleChoiceSection({
    required this.definition,
    required this.candidates,
    required this.selected,
    required this.onChanged,
    this.sourceLabel,
    this.blockedReason,
    this.onOpenEntry,
    this.showTitle = true,
    super.key,
  });

  final RuleChoiceDefinition definition;
  final List<RuleChoiceCandidate> candidates;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final String? sourceLabel;
  final String? blockedReason;               // requires 不满足时的原因
  final ValueChanged<ContentEntry>? onOpenEntry;
  final bool showTitle;
```

实现要点：
- 校验显示：`selected.length` 与 `definition.minimum`–`maximum` 对比，`blockedReason != null` 时用 `colorScheme.error` 图标 + 文案；
- `FilterChip` 的 `onSelected`：
  - 选中：`maximum == 1 && !repeatable` → `[id]`；`repeatable` → `[...selected, id]`（允许重复）；否则 `selected.length < maximum ? [...selected, id] : selected`；
  - 取消：移除**第一次出现**的该 id（保持顺序）；
- 已选且 `repeatable` 的 chip 标签显示 `名称 ×N`；
- 条目候选（`candidate.entry != null`）右侧保留"查看"`IconButton`（`tooltip`、`key: Key('builder-open-entry-${id}')`，与既有测试键名一致）；
- 颜色/圆角只用 `Theme.of(context).colorScheme` 与既有 Chip/卡片（`DESIGN.md` 契约，无新 token）。

- [ ] **步骤 4：三处界面迁移到 `List<String>`**

| 位置 | 变化 |
|---|---|
| `character_editor_builder_page.dart:54` | `Map<String, Set<String>> _ruleChoices` → `Map<String, List<String>>`；`_replaceSet` 删除；`_selection()` 的 `ruleChoices` 直接 `toList(growable: false)`（已经是 List） |
| `character_editor_page.dart:83` | `Map<String, Set<String>> _upgradeRuleChoices` → `Map<String, List<String>>`；`onChoiceChanged(key, List<String>)` |
| `character_editor_creation_flow.dart:122` `_UpgradeRuleChoiceSection` | 改为薄包装：用 `RuleChoiceSemantics.candidatesFor` + `RuleChoiceSection`，`onChanged` 直传 `List<String>` |
| `character_upgrade_page.dart:198` `_ChoiceOptions` | 同样改为 `RuleChoiceSection`（它已经是 `List<String>`，只换渲染） |
| `character_editor_rule_choices.dart:4` `_RuleChoiceSection` | 删除，由 `RuleChoiceSection` 取代；`_MultiChoiceSection` / `_ChoiceSection` 保持不变（它们不是规则选择） |

同时把 `RuleChoiceDefinition.usesDedicatedOptionUi` 的**校验用途**保留到任务 6b 再摘除，本任务只做状态类型与渲染器迁移（行为等价），保证既有测试可红可绿地逐步改。

- [ ] **步骤 5：更新既有测试中的类型与键**

`test/character_builder_choices_test.dart`、`test/character_pages_test.dart`、`test/rules_upgrade_dedicated_choice_test.dart` 里凡是断言 `Set` 或依赖旧组件内部结构的，按新组件调整（预计主要是"点击顺序"与"重复选择"）。

- [ ] **步骤 6：运行测试与全量回归**

运行：
```
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test\rule_choice_section_test.dart test\character_builder_choices_test.dart"
cmd.exe /c "cd /d ... && C:\Flutter\flutter\bin\flutter.bat test"
```
预期：PASS 且全绿。

**实现要点**
- 三处界面必须**同任务**迁移完（这是"改了签名让调用方下一任务再修"的高发点）。
- 组件只接收 `List<RuleChoiceCandidate>`；候选枚举一律走 `RuleChoiceSemantics.candidatesFor`，组件内不出现 `entry.type` 过滤。

**验收：** 上一步「运行」里的目标测试命令 → PASS；再跑「任务门禁」三条命令 → 全绿（`dart.exe analyze lib test` 0 问题、`flutter.bat test` 全绿、`npm run check` / `npm run test:scripts` / `npm run lint:design` 全绿）。

- [ ] **步骤 7：Commit**

```bash
git add apps/client_flutter/lib apps/client_flutter/test
git commit -m "refactor(ui): 选择面板收敛为共享组件，状态改为有序 List"
```

---

## 任务 6b：`group` / `help` / `repeatable` / `requires` 的呈现与校验收口

**文件：**
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/widgets/rule_choice_section.dart`
- 修改：`apps/client_flutter/lib/src/features/rules/domain/character_rule_definition.dart`（`usesDedicatedOptionUi` 语义收窄）
- 修改：`character_editor_builder_page.dart`、`character_editor_page.dart`、`character_editor_creation_flow.dart`、`character_upgrade_planner.dart`、`character_upgrade_page.dart`
- 测试：`test/rule_choice_section_test.dart`、`test/character_builder_choices_test.dart`、`test/rules_upgrade_dedicated_choice_test.dart`

- [ ] **步骤 1：先写失败测试**

```dart
// test/rule_choice_section_test.dart（追加）
testWidgets('group 标题按首次声明顺序出现；help 以小字展示', (tester) async {
  // 两条选择：group: '甲组'（带 help）+ 无 group。
  // 断言 find.text('甲组') 一个；帮助文案一个；无 group 的标题不出现空标题。
});

testWidgets('requires 不满足：隐藏该选择并说明原因', (tester) async {
  // blockedReason: '需要魅力 13' → 断言 find.textContaining('需要魅力 13')；
  // 且候选 chip 不渲染。
});

testWidgets('repeatable：同一 chip 点两次，标签出现 ×2，回调带两个同一 id', (tester) async {
  // 断言 changed == ['a', 'a']。
});
```

```dart
// test/character_builder_choices_test.dart（追加）
testWidgets('requires 不满足时创建被阻塞且给原因，不静默跳过', (tester) async {
  // 夹具：职业 1 级选择 cha>=13 的 requires；把魅力改到 12 →
  // 断言出现 '需要魅力 13'，且『创建角色』不可用。
});
```

- [ ] **步骤 2：运行确认失败**

运行：`cmd.exe /c "cd /d ... && C:\Flutter\flutter\bin\flutter.bat test test\rule_choice_section_test.dart test\character_builder_choices_test.dart"`
预期：FAIL。

- [ ] **步骤 3：实现分组、帮助、重复计数、前置提示**

1) 在 `rule_choice_section.dart` 增一个**分组容器**：

```dart
class RuleChoiceGroup {
  const RuleChoiceGroup({this.title, required this.choices});
  final String? title;
  final List<Widget> choices;
}

/// `group` 相同的选择归一组；组按**首次声明顺序**，无 `group` 的组排最后（决策 D7）。
List<RuleChoiceGroup> groupRuleChoiceSections(Iterable<...> choices) { ... }
```

2) `help` 用 `theme.textTheme.bodySmall` + `theme.colorScheme.onSurfaceVariant`（`DESIGN.md` 的 `text-secondary` 角色；不得用 `outline` 作正文色）。

3) `usesDedicatedOptionUi` 收窄：

```dart
  /// 该选择是否由**专门渲染器**承担（技能选择器 / 法术池），因此不出现在通用
  /// 选择卡片里。**只是渲染判据**：选中值一律进 `build.choices`，校验/额度/升级
  /// 判定都按普通选择处理（不再有"值写在别处所以免检"的例外）。
  bool get usesDedicatedOptionUi => optionType == 'skill' || isSpellChoice;

  bool get isSpellChoice => optionType == 'spell';
```

4) 摘除三处"专门 UI 免检"逻辑：
- `character_editor_builder_page.dart:209` / `:259`：`ruleChoicesAreValid` 与 pending 计数**不再排除**任何选择（技能选择也在 `_ruleChoices` 里，任务 7 完成写入）；
- `character_editor_page.dart:613-625` `_upgradePreview`：删 `dedicatedChoiceKeys`，`pendingChoices` 过滤改为"只统计**本级新增**的选择"：

```dart
      pendingChoices: nextLedger.pendingChoices
          .where((pending) => !previousChoiceKeys.contains(pending.key))
          .toList(growable: false),
```

- `character_upgrade_planner.dart:49` `isComplete`：`choices.every((choice) => choice.isValid)`（去掉 `usesDedicatedOptionUi ||`）；
- `character_upgrade_page.dart:215`：删"该选择由对应界面选择。"分支，改由共享组件渲染（技能/法术由专门页面承担时仍用中性文案，但判据换成 `usesDedicatedOptionUi` 的**渲染**含义）。

5) `requires` 的隐藏语义：`RuleChoiceSection(blockedReason: ...)` 时**不渲染候选**，只渲染标题 + 原因小字；若该选择已有选中值，则保留一个"已选但未生效"的列表（§3.10.3-5）。创建向导里 requires 不满足的选择用它自己的 `requiresSatisfied`（由 `RuleChoiceSemantics.requiresSatisfied(..., abilities: _abilityScores, selectedByKey: _ruleChoices)` 现算，唯一实现点）；升级队列用引擎 `ActiveRuleChoice.requiresSatisfied`。

6) **补上缺失的渲染位置（否则又是"声明了但用不了"）**：`_builderStepFor`（`character_editor_builder_page.dart:793-802`）把 `abilities` 映到步骤 3、`details` 映到步骤 7，但步骤 3（`_AbilityScoreSection` 之后）与步骤 7（`_DetailsStep`）**没有** `...ruleChoiceWidgets`——当前一个 `builderStep: "details"` 的选择（示例包 `asi-or-feat` 就是）在创建向导里根本不显示。本任务把 `...ruleChoiceWidgets` 补进这两个步骤，并加一条**结构守卫测试**：

```dart
// test/character_builder_choices_test.dart（追加）
testWidgets('每个 allowedBuilderSteps 的取值都有渲染位置', (tester) async {
  // 对 RuleChoiceDefinition.allowedBuilderSteps 的每一项构造一条**本级新增**、
  // minimum 1 / maximum 1 的选择，进入创建向导后断言：
  //   1) 该选择标题可见（或由专门界面承担：skill/spell）；
  //   2) 不选它时 canCreate 为 false（不能"看不见却要求选"）。
});
```

> 这条测试的意义：`allowedBuilderSteps` 是契约白名单，导入期放行它；任何一项没有渲染位置就是静默失效。专门渲染器（技能 / 法术）用 `usesDedicatedOptionUi` 白名单豁免第 1 条，但第 2 条仍然必须成立。

- [ ] **步骤 4：更新升级死锁测试与新语义对齐**

`test/rules_upgrade_dedicated_choice_test.dart` 的意图（"专门 UI 选择不得堵塞 canApply"）在**任务 7 完成后**仍然成立，但机制从"免检"变成"只统计本级新增"。本任务把它改成"1 级未完成的技能/法术选择不阻塞 2 级升级；**本级新增**的未完成选择才阻塞"，并保留 `没有符合` 假错误不出现的断言。

- [ ] **步骤 5：运行测试与全量回归**

运行：
```
cmd.exe /c "cd /d ... && C:\Flutter\flutter\bin\flutter.bat test test\rule_choice_section_test.dart test\character_builder_choices_test.dart test\rules_upgrade_dedicated_choice_test.dart"
cmd.exe /c "cd /d ... && C:\Flutter\flutter\bin\flutter.bat test"
```
预期：PASS 且全绿。

**实现要点**
- `usesDedicatedOptionUi` 只决定**渲染位置**；校验/额度/升级判定统一走 `RuleChoiceSemantics` 与引擎。
- 隐藏 = 不渲染候选 + 给原因，**不**等于静默丢掉已选值。

**验收：** 上一步「运行」里的目标测试命令 → PASS；再跑「任务门禁」三条命令 → 全绿（`dart.exe analyze lib test` 0 问题、`flutter.bat test` 全绿、`npm run check` / `npm run test:scripts` / `npm run lint:design` 全绿）。

- [ ] **步骤 6：Commit**

```bash
git add apps/client_flutter/lib apps/client_flutter/test
git commit -m "feat(ui): 选择面板支持 group/help/repeatable/requires 呈现"
```

---

## 任务 7：技能选择写入 `build.choices`（统一状态）+ 记录型选择落库

**文件：**
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_editor_builder_page.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_editor_level_sections.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/domain/structured_class_rules.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/domain/rules_driven_character_builder.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/domain/character_rule_projector.dart`
- 测试：`apps/client_flutter/test/rules_driven_character_builder_test.dart`、`test/character_builder_choices_test.dart`、`test/class_rule_summary_display_test.dart`

- [ ] **步骤 1：先写失败测试**

```dart
// test/rules_driven_character_builder_test.dart（追加；沿用该文件既有的 _entry(...) 夹具）
test('技能选择写在 build.choices，经自动授予进 skills（不再走 skillProficiencies）', () {
  final ranger = _entry(
    id: 'test:class/ranger',
    type: 'class',
    name: '游侠',
    structured: const {'classRules': {'hitDie': 10}},
    rules: const {
      'progression': [
        {
          'levels': [1],
          'choices': [
            {
              'id': 'class-skills',
              'label': '选择两项技能熟练',
              'optionType': 'skill',
              'minimum': 2,
              'maximum': 2,
              'options': ['察觉', '求生', '隐匿'],
            },
          ],
        },
      ],
    },
  );
  final builder = RulesDrivenCharacterBuilder(entries: {ranger.id: ranger});
  final draft = builder.build(
    name: '测试角色',
    build: const CharacterBuild(
      level: 1,
      selections: {'class': 'test:class/ranger'},
      choices: {
        'test:class/ranger#class-skills': ['察觉', '求生'],
      },
    ),
    abilities: const {'wis': 14},
  );

  expect(draft.skills['察觉'], isTrue);
  expect(draft.skills['求生'], isTrue);
  expect((draft.data['build']! as Map)['choices'], {
    'test:class/ranger#class-skills': ['察觉', '求生'],
  });
  expect(draft.data['choices'], {
    'test:class/ranger#class-skills': ['察觉', '求生'],
  });
});

test('语言选项记录到 data.profile.languages，不做数值派生', () {
  final ranger = _entry(
    id: 'test:class/ranger',
    type: 'class',
    name: '游侠',
    structured: const {'classRules': {'hitDie': 10}},
    rules: const {
      'choices': [
        {
          'id': 'languages',
          'label': '额外语言',
          'optionType': 'language',
          'minimum': 1,
          'maximum': 1,
          'options': ['龙语', '精灵语'],
        },
      ],
    },
  );
  final builder = RulesDrivenCharacterBuilder(entries: {ranger.id: ranger});
  final draft = builder.build(
    name: '测试角色',
    build: const CharacterBuild(
      level: 1,
      selections: {'class': 'test:class/ranger'},
      choices: {
        'test:class/ranger#languages': ['龙语'],
      },
    ),
    abilities: const {'wis': 14},
  );

  expect((draft.data['profile']! as Map)['languages'], ['龙语']);
  expect(draft.data['choices'], contains('test:class/ranger#languages'));
});
```

> `test/rules_driven_character_builder_test.dart` 现有的 `_entry(...)` 接受 `rules`
> 为原始 map；上面的 `const` map 与该文件既有写法一致（`positional`/具名参数见文件底部）。

```dart
// test/character_builder_choices_test.dart（追加）
testWidgets('熟练步骤的选择写进 build.choices 并按声明顺序保存', (tester) async {
  // 夹具：class 1 级 optionType: 'skill' + options ['察觉','求生','隐匿']，minimum/maximum 2。
  // 依次点『求生』『察觉』→ 提交 → 断言
  // submitted.data['build']['choices']['... #class-skills'] == ['求生','察觉']。
});
```

- [ ] **步骤 2：运行确认失败**

运行：`cmd.exe /c "cd /d ... && C:\Flutter\flutter\bin\flutter.bat test test\rules_driven_character_builder_test.dart test\character_builder_choices_test.dart"`
预期：FAIL。

- [ ] **步骤 3：实现**

1) `character_editor_builder_page.dart`：
- 删 `_selectedSkillProficiencies`（或降级为"仅背景预设"的只读集合，改名 `_backgroundSkillProficiencies`，只在背景切换时更新）；
- '熟练' 步骤对每个 `optionType == 'skill'` 的 active choice 渲染 `_SkillProficiencySection`（保留既有的全技能网格 UI），`selected` 传 `_ruleChoices[active.key] ?? const []`，`onChanged` 写回 `_ruleChoices[active.key]`；`fixed` 传背景预设；`maximum` 传 `definition.maximum`，`minimum` 传 `definition.minimum`（供校验文案）；
- `_selection()` 的 `skillProficiencies` 只输出背景预设；技能选择由 `ruleChoices` 承担；
- `_applyRecommendedRuleChoices` 不再跳过 `usesDedicatedOptionUi`（值类型选择也可以有 `recommendedEntryIds`；技能选择通常没有）。

2) `character_editor_level_sections.dart` 的 `_SkillProficiencySection`：`onChanged` 类型 `ValueChanged<List<String>>`；选中/取消逻辑与 `RuleChoiceSection` 一致（顺序 + 去重规则），实现上**抽取共用函数** `List<String> toggleRuleChoiceSelection({required List<String> selected, required String id, required bool repeatable, required int maximum})` 放在 `widgets/rule_choice_section.dart`，两个组件都调它（唯一实现）。背景 `fixed` 技能不参与该列表。

3) `StructuredClassRules.skillChoice`（`structured_class_rules.dart:65`）改为基于 `RuleChoiceSemantics.candidatesFor` 取候选 label（保留 `count` / `restricted` 语义与 `ClassRuleSummary` 的展示契约），保证展示与交互同一份候选。

4) `RulesDrivenCharacterBuilder.build` 的 `data` 增：

```dart
        // 记录型选择（language/damageType/weaponMastery/value）的落库镜像：与
        // build.choices 同形，便于内容显示按 key 读取；不值派生。
        'choices': {
          for (final entry in ledger.resolvedChoices.entries)
            entry.key: entry.value,
        },
        if (_languagePicks(ledger).isNotEmpty)
          'profile': {'languages': _languagePicks(ledger)},
```

`_languagePicks` 用 `RuleChoiceSemantics.definitionForKey` 判断 `optionType == 'language'`，取候选 label（唯一实现点）。

5) `CharacterRuleProjector.project` 的合并键列表 `const ['build', 'resolvedGrants', 'pendingChoices', 'spellSlots', 'spellcastingAbility', 'preparedSpellLimit', 'hitDie', 'savingThrowAbilities', 'classResources', 'actions']` 增 `'choices'`（**不**增 `profile`：语言是用户可编辑字段，项目器不得覆盖）。

**实现要点**
- 技能熟练现在只有一条路径：`build.choices` → 自动授予 `proficiency: skill:<名>` → builder 的 `skills` map；背景预设仍走 `skillProficiencies` 入参。
- `repeatable` 的技能选择：同一技能选两次时，`skills` 是 `Map<String,bool>`，第二次不会产生第二个 `true`；`build.choices` 仍如实保留两次（落库形状正确）。

- [ ] **步骤 4：运行测试与全量回归**

运行：`cmd.exe /c "cd /d ... && C:\Flutter\flutter\bin\flutter.bat test test\rules_driven_character_builder_test.dart test\character_builder_choices_test.dart test\class_rule_summary_display_test.dart test\quick_build_test.dart"` → PASS；再全量 `flutter.bat test` 全绿。

**验收：** 上一步「运行」里的目标测试命令 → PASS；再跑「任务门禁」三条命令 → 全绿（`dart.exe analyze lib test` 0 问题、`flutter.bat test` 全绿、`npm run check` / `npm run test:scripts` / `npm run lint:design` 全绿）。

- [ ] **步骤 5：Commit**

```bash
git add apps/client_flutter/lib apps/client_flutter/test
git commit -m "feat(ui): 技能与记录型选择统一写入 build.choices"
```

---

## 任务 8：装备 A/B 写入 `inventory` 与 `currency`

**文件：**
- 创建：`apps/client_flutter/lib/src/features/characters/domain/equipment_bundle_items.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/domain/rules_driven_character_builder.dart`
- 测试：`apps/client_flutter/test/rules_driven_character_builder_test.dart`

- [ ] **步骤 1：先写失败测试**

```dart
// test/equipment_bundle_items_test.dart（新建）
import 'package:dnd_table_client/src/features/characters/domain/equipment_bundle_items.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('structured.items = [{name, quantity}]，quantity 缺省 1，非法项跳过', () {
    final items = EquipmentBundleItems.from(const {
      'items': [
        {'name': '长剑', 'quantity': 1},
        {'name': '背包'},
        {'quantity': 3},
        'junk',
      ],
      'currency': {'gp': 10, 'sp': 5},
      'itemTemplate': {'ignored': true},
    });

    expect(items.items, [
      {'name': '长剑', 'quantity': 1},
      {'name': '背包', 'quantity': 1},
    ]);
    expect(items.currency, {'cp': 0, 'sp': 5, 'ep': 0, 'gp': 10, 'pp': 0});
  });

  test('无 items / 无 currency 一律返回空，不猜', () {
    final items = EquipmentBundleItems.from(const {});
    expect(items.items, isEmpty);
    expect(items.currency.values.every((v) => v == 0), isTrue);
  });
}
```

```dart
// test/rules_driven_character_builder_test.dart（追加）
test('选中的装备方案把 items 与 currency 写进 inventory/currency（忽略 itemTemplate）', () {
  final draft = builder.build(
    name: '测试角色',
    build: const CharacterBuild(
      level: 1,
      selections: {'class': 'test:class/warden'},
      choices: {
        'test:class/warden#starting-equipment': ['test:equipment-bundle/a'],
      },
    ),
    abilities: const {'str': 14},
  );

  expect(
    draft.inventory,
    contains(containsPair('name', '链甲')),
  );
  expect(draft.currency['gp'], 15);
});
```

- [ ] **步骤 2：运行确认失败**

运行：`cmd.exe /c "cd /d ... && C:\Flutter\flutter\bin\flutter.bat test test\equipment_bundle_items_test.dart test\rules_driven_character_builder_test.dart"`
预期：FAIL。

- [ ] **步骤 3：实现**

```dart
// lib/src/features/characters/domain/equipment_bundle_items.dart
/// `equipmentBundle` 条目的物品与货币（契约 §3.11 A2）：
/// `structured.items = [{name, quantity}]`、`structured.currency = {cp,sp,ep,gp,pp}`。
/// `structured.itemTemplate` 一律忽略（客户端不消费）。
///
/// 这是该结构的**唯一解析点**：builder 与详情页若要展示方案内容都调它，
/// 不得各自读 `structured` 字段名。
class EquipmentBundleItems {
  const EquipmentBundleItems({required this.items, required this.currency});
  final List<Map<String, Object?>> items;
  final Map<String, int> currency;
  static const currencyKeys = ['cp', 'sp', 'ep', 'gp', 'pp'];
  static EquipmentBundleItems from(Map<String, Object?> structured) { ... }
}
```

`RulesDrivenCharacterBuilder.build`：
- 遍历 `ledger.resolvedChoices` 的每个选中 id，若 `entries[id]?.type == 'equipmentBundle'` → `EquipmentBundleItems.from(entry.structured)`：
  - `items` 逐条 append 到 `inventory`（`{'name': …, 'quantity': …}`，有条目 id 时**不**编造）；与 `rules.grants` 带出的 `entryId` 行按 entryId 去重（既有 `itemRefs` 逻辑不变）；
  - `currency` 累加到 `currency`（当前硬编码 `{'cp':0,…}` 的位置改为累加结果）。

**实现要点**
- `_choiceEntryRefs(ledger, {'equipment','item'})` **不**加 `'equipmentBundle'`：方案条目本身不是库存物品。
- 方案自身的 `rules.grants`（如示例包里的 `kind: equipment`）仍照旧生效；两种写法各自只有一条路径。

- [ ] **步骤 4：运行测试与全量回归**

运行：`cmd.exe /c "cd /d ... && C:\Flutter\flutter\bin\flutter.bat test test\equipment_bundle_items_test.dart test\rules_driven_character_builder_test.dart test\guided_character_builder_test.dart"` → PASS；再全量 `flutter.bat test` 全绿。

**验收：** 上一步「运行」里的目标测试命令 → PASS；再跑「任务门禁」三条命令 → 全绿（`dart.exe analyze lib test` 0 问题、`flutter.bat test` 全绿、`npm run check` / `npm run test:scripts` / `npm run lint:design` 全绿）。

- [ ] **步骤 5：Commit**

```bash
git add apps/client_flutter/lib apps/client_flutter/test
git commit -m "feat(character): 装备方案 A/B 写入 inventory 与 currency"
```

---

## 任务 9：`optionType: "spell"` 走法术池 + 已准备法术镜像

**文件：**
- 修改：`apps/client_flutter/lib/src/features/characters/domain/character_manual_overrides.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/domain/rules_driven_character_builder.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_editor_builder_page.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_editor_spell_sections.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_editor_page.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_detail_spells_panel.dart`
- 测试：`apps/client_flutter/test/character_manual_overrides_test.dart`、`test/spell_selection_policy_test.dart`、`test/character_builder_choices_test.dart`

- [ ] **步骤 1：先写失败测试**

```dart
// test/character_manual_overrides_test.dart（追加）
test('alwaysPreparedEntryIds 往返且去重', () {
  const overrides = CharacterManualOverrides(
    preparedSpellEntryIds: ['a', 'b'],
    alwaysPreparedEntryIds: ['b', 'c'],
  );
  final restored = CharacterManualOverrides.fromJson(overrides.toJson());
  expect(restored.alwaysPreparedEntryIds, ['b', 'c']);
  expect(restored.preparedSpellEntryIds, ['a', 'b']);
});
```

```dart
// test/character_builder_choices_test.dart（追加）
testWidgets('显式 optionType: "spell" 的选择由法术池渲染并计入 countsToward', (tester) async {
  // 夹具：class 1 级带 choices [{id:'spells-1', optionType:'spell', minimum:0,
  // maximum:2, optionTags:['spell-list:x'], maximumOptionLevel:0,
  // countsToward:'prepared'}] + spell 条目 spark(0 环) / ward(1 环)。
  // 断言：法术步骤显示两个法术；1 环的 ward 因 maximumOptionLevel:0 不出现；
  // 选 spark 后提交 → data['manualOverrides']['spells']['preparedEntryIds'] 含 spark。
});
```

```dart
// test/rules_driven_character_builder_test.dart（追加）
test('countsToward: null 的法术选择额外记 alwaysPreparedEntryIds', () { ... });
```

- [ ] **步骤 2：运行确认失败**

运行：`cmd.exe /c "cd /d ... && C:\Flutter\flutter\bin\flutter.bat test test\character_manual_overrides_test.dart test\character_builder_choices_test.dart"`
预期：FAIL。

- [ ] **步骤 3：实现**

1) `CharacterManualOverrides` 增 `alwaysPreparedEntryIds`（`fromJson` / `toJson` / `copyWith`；沿用既有的 `_unique` 去重）。

2) `RulesDrivenCharacterBuilder.build` 增：

```dart
        'manualOverrides': {
          'spells': {
            'preparedEntryIds': _preparedSpellIds(ledger),
            if (_alwaysPreparedSpellIds(ledger).isNotEmpty)
              'alwaysPreparedEntryIds': _alwaysPreparedSpellIds(ledger),
          },
        },
```

语义（契约 §3.11 A3）：**所有** `optionType == 'spell'` 选择选中的法术都进 `preparedEntryIds`（不论 `countsToward`）；`countsToward == null` 的那些**额外**记 `alwaysPreparedEntryIds`（仅用于展示"始终准备"标记）。判定用 `RuleChoiceSemantics.definitionForKey` + `RuleChoiceSemantics.candidatesFor`（唯一实现点），不得自己 split 键或读 `entry.type`。

3) `character_editor_page._submitQuickBuild`（第 866–873 行，现在只在有自定义法术时**覆盖**写 `manualOverrides`）：改为**合并**——保留 builder 产出的 `preparedEntryIds` / `alwaysPreparedEntryIds`，只补 `customSpells`（`CharacterManualOverrides.copyWith` 已支持）：

```dart
      final mergedOverrides = CharacterManualOverrides.fromJson(
        Map<String, Object?>.from(
          (baseDraft.data['manualOverrides'] as Map?) ?? const <String, Object?>{},
        ),
      ).copyWith(customSpells: quickDraft.customSpells);
      final draft = baseDraft.copyWith(
        data: {
          ...baseDraft.data,
          'story': quickDraft.storyData,
          'manualOverrides': mergedOverrides.toJson(),
        },
      );
```

4) 法术步骤渲染：共享组件 `RuleChoiceSection` 不渲染 `isSpellChoice` 的选择（任务 6b 已把 `isSpellChoice` 并入 `usesDedicatedOptionUi`）。对每个 `optionType == 'spell'` 的 active choice，用**既有法术池**（`SpellSelectionPolicy.eligibleSpells` 的过滤语义：`entry.type == 'spell'` + `structured['level'] <= maximumOptionLevel` + 标签全含）得到候选，接入 `_SpellChoiceSection` 的法术列表（每个 spell choice 一组 chip/标签 + 自己的计数上限）；选中值写 `_ruleChoices[active.key]`（有序 `List`），`countsToward` 的有效上限用 `RuleChoiceQuota.effectiveMaximum`（池来自 `SpellSelectionPolicy.rulesFor` 的 `maximumLeveledSpells` → `limitsFor`）。
- **若职业声明了任何 `optionType: "spell"` 选择，法术步骤只由这些选择驱动**（不再同时显示"自由挑选"的 `_SpellChoiceSection.entries` 全量列表），这正是 §3.10.3-3「声明与选择分离」：`classRules.spellcasting` 只给数值，选择由显式选择承担。没有显式 spell 选择的职业保持现状。
- `_SpellChoiceSection` 增可选参数 `choiceKey` / `maximum` / `optionTags` / `maximumOptionLevel`，内部筛选复用 `SpellSelectionPolicy`（不新写过滤）。

5) `character_detail_spells_panel.dart`：把 `alwaysPreparedEntryIds` 里的法术行加一个"始终准备"小标签（`Chip`/`labelSmall`，用 `secondaryContainer`/`onSecondaryContainer`，无新 token）。

**实现要点**
- 法术池的候选过滤唯一实现点是 `SpellSelectionPolicy`（`eligibleSpells` / `spellLevel` / `spellSchool`）；本任务只增"按选择过滤"的入参，不复制标签/等级判断。
- `countsToward` 决策 D1 在法术上第一次可见：`prepared`/`known` 受 `prepared` 列约束，`spellbook` 不设上限。

- [ ] **步骤 4：运行测试与全量回归**

运行：`cmd.exe /c "cd /d ... && C:\Flutter\flutter\bin\flutter.bat test test\spell_selection_policy_test.dart test\character_builder_choices_test.dart test\character_manual_overrides_test.dart test\rules_driven_character_builder_test.dart"` → PASS；再全量 `flutter.bat test` 全绿。

**验收：** 上一步「运行」里的目标测试命令 → PASS；再跑「任务门禁」三条命令 → 全绿（`dart.exe analyze lib test` 0 问题、`flutter.bat test` 全绿、`npm run check` / `npm run test:scripts` / `npm run lint:design` 全绿）。

- [ ] **步骤 5：Commit**

```bash
git add apps/client_flutter/lib apps/client_flutter/test
git commit -m "feat(character): 显式法术选择走法术池并镜像已准备法术"
```

---

## 任务 10：导入期放行与收窄 + `invalidAutoGrant`

**文件：**
- 修改：`apps/client_flutter/lib/src/features/content/data/import/content_package_importer.dart`
- 测试：`apps/client_flutter/test/rules/import_rule_diagnostics_test.dart`

- [ ] **步骤 1：先改测试（原"拒收"分组变成"按语义校验"）**

把 `import_rule_diagnostics_test.dart` 的 `group('§3.10.3-7：选择系统字段声明了但用不了必须报 error')`（第 1568–1661 行）整组替换为：

```dart
  group('选择系统字段（§3.10）：放行 + 真正的取值/引用校验', () {
    Future<ContentImportReport> reportFor(Map<String, Object?> extra) => ...; // 沿用原夹具

    test('repeatable / group / help 放行', () async {
      final report = await reportFor({
        'repeatable': true,
        'group': '1 级',
        'help': '说明',
      });
      expect(report.valid, isTrue, reason: report.errors.toString());
    });

    test('内联选项的 grants 放行，且仍做 kind 校验', () async {
      final ok = await reportFor({
        'options': <Object?>[
          {
            'id': 'poise',
            'label': '星界之势',
            'grants': <Object?>[
              {'id': 'g', 'kind': 'feature', 'label': '星界之势'},
            ],
          },
        ],
      });
      expect(ok.valid, isTrue, reason: ok.errors.toString());

      final bad = await reportFor({
        'options': <Object?>[
          {
            'id': 'poise',
            'label': '星界之势',
            'grants': <Object?>[
              {'id': 'g', 'kind': 'resource', 'label': '旧写法'},
            ],
          },
        ],
      });
      expect(bad.valid, isFalse);
      expect(
        bad.errors.single.path,
        r'$.entries[0].rules.choices[0].options[0].grants[0].kind',
      );
      expect(bad.errors.single.message, contains('unknownGrantKind'));
    });

    test('countsToward：合法值放行，非法值报 invalidCountsToward', () async {
      expect((await reportFor({'countsToward': 'prepared'})).valid, isTrue);
      expect((await reportFor({'countsToward': 'spellbook'})).valid, isTrue);
      expect((await reportFor({'countsToward': 'known'})).valid, isTrue);
      expect((await reportFor({})).valid, isTrue, reason: '省略合法');

      final bad = await reportFor({'countsToward': 'rituals'});
      expect(bad.valid, isFalse);
      final error = bad.errors.single;
      expect(error.path, r'$.entries[0].rules.choices[0].countsToward');
      expect(error.message, contains('invalidCountsToward'));
    });

    test('requires：合法形态放行；引用不存在 / 能力非法 / minimum 非正报 invalidRequires', () async {
      expect(
        (await reportFor({
          'optionType': 'classFeature',
          'optionTags': ['x'],
          'requires': [
            {'ability': 'cha', 'minimum': 13},
          ],
        })).valid,
        isTrue,
      );

      for (final (bad, path) in <(Map<String, Object?>, String)>[
        (
          {'requires': [{'choice': 'missing-choice', 'option': 'x'}]},
          r'$.entries[0].rules.choices[0].requires[0].choice',
        ),
        (
          {'requires': [{'ability': 'luck', 'minimum': 13}]},
          r'$.entries[0].rules.choices[0].requires[0].ability',
        ),
        (
          {'requires': [{'ability': 'cha', 'minimum': 0}]},
          r'$.entries[0].rules.choices[0].requires[0].minimum',
        ),
      ]) {
        final report = await reportFor(bad);
        expect(report.valid, isFalse, reason: '$bad');
        expect(
          report.errors.map((e) => e.path),
          contains(path),
          reason: '$bad → ${report.errors}',
        );
        expect(
          report.errors.firstWhere((e) => e.path == path).message,
          contains('invalidRequires'),
        );
      }
    });

    test('invalidAutoGrant：条目类型的字符串选项无法推断 grants', () async {
      final report = await reportFor({
        'optionType': 'classFeature',
        'optionTags': ['x'],
        'options': <Object?>['星界之势'],
      });
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.message.contains('invalidAutoGrant'),
      );
      expect(error.path, r'$.entries[0].rules.choices[0].options[0]');
      expect(error.message, contains('星界之势'));
    });

    test('invalidAutoGrant 不适用于只记录选择的值类型与显式 grants 的对象选项', () async {
      // skill / ability / language / damageType / weaponMastery / value 的字符串元素
      for (final type in ['skill', 'ability', 'language', 'damageType', 'weaponMastery', 'value']) {
        final report = await reportFor({
          'optionType': type,
          'options': <Object?>[type == 'skill' ? '察觉' : 'cha'],
        });
        expect(report.valid, isTrue, reason: '$type → ${report.errors}');
      }
      // 条目类型的**对象**选项（显式给 id/label）不需要 grants
      final object = await reportFor({
        'optionType': 'classFeature',
        'optionTags': ['x'],
        'options': <Object?>[
          {'id': 'poise', 'label': '星界之势'},
        ],
      });
      expect(object.valid, isTrue, reason: object.errors.toString());
    });

    test('字符串简写的 ability 候选必须是档案属性键（unknownAbility）', () async {
      final report = await reportFor({
        'optionType': 'ability',
        'options': <Object?>['luck'],
      });
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.message.contains('unknownAbility'),
      );
      expect(error.path, r'$.entries[0].rules.choices[0].options[0]');
      expect(error.message, contains('luck'));
    });
  });
```

- [ ] **步骤 2：运行确认失败**

运行：`cmd.exe /c "cd /d ... && C:\Flutter\flutter\bin\flutter.bat test test\rules\import_rule_diagnostics_test.dart"`
预期：FAIL（放行项仍被拒；`invalidAutoGrant` 无产生点）。

- [ ] **步骤 3：改导入器**

1) 删 `static const _unsupportedChoiceFields`（第 40 行）与 `_validateRawChoice` 末尾的三个拒收块（第 1157–1189 行）。

2) 删内联选项 `grants` 的 `unsupportedChoiceField`（第 1079–1093 行），**保留**紧随其后的 `_validateRawGrantKinds(option['grants'], ...)`（kind 仍在 9 项枚举内）。

3) `countsToward` 校验（放在 `optionType` 校验附近）：

```dart
    final countsToward = choice['countsToward'];
    if (!isCountsTowardPool(countsToward)) {
      errors.add(
        ContentValidationError(
          path: '$path.countsToward',
          message:
              'countsToward 必须是 ${kCountsTowardPools.join(' / ')} 或省略'
              '（invalidCountsToward）',
        ),
      );
    }
```

4) 字符串元素的 `invalidAutoGrant`（在 `item is String` 分支里）：

```dart
          if (item is String) {
            final text = item.trim();
            if (text.isEmpty) { ...原样... continue; }
            id = text;
            name = text;
            // §5.1 invalidAutoGrant：字符串简写无法为该 optionType 推断 grants，
            // 且作者没有写成对象给显式 grants。判据与运行时同源
            // （RuleChoiceSemantics.autoGrantsFor 返回 null）。
            if (optionType is String &&
                RuleChoiceSemantics.autoGrantsFor(
                      optionType: optionType,
                      optionId: text,
                    ) ==
                    null) {
              errors.add(
                ContentValidationError(
                  path: itemPath,
                  message:
                      'optionType "$optionType" 的选项 "$text" 缺少 grants，'
                      '且无法自动推断（invalidAutoGrant）',
                ),
              );
            }
          }
```

5) `requires` 的**取值**校验在 `_validateRawChoice` 里做（形状由解析层兜底），**引用**校验在 `_validateRuleReferences`（第二遍，已有 `entries` 与祖先链信息）里做：

```dart
    // _validateRawChoice 内：取值
    if (choice.containsKey('requires')) {
      final rawRequires = choice['requires'];
      if (rawRequires is! List) {
        errors.add(... path: '$path.requires', '（invalidRequires）');
      } else {
        for (var index = 0; index < rawRequires.length; index++) {
          final item = rawRequires[index];
          final itemPath = '$path.requires[$index]';
          if (item is! Map) { errors.add(...'$itemPath'...); continue; }
          final map = Map<String, Object?>.from(item);
          final ability = map['ability'];
          final minimum = map['minimum'];
          if (ability != null && ability is! String) { ... '$itemPath.ability' ... }
          if (ability is String && !Dnd5eRules.profile.abilities.contains(ability)) {
            errors.add(... '$itemPath.ability', '未知属性键 "$ability"（invalidRequires）');
          }
          if (minimum != null && (minimum is! num || minimum.toInt() <= 0)) {
            errors.add(... '$itemPath.minimum', '（invalidRequires）');
          }
        }
      }
    }
```

`_validateRuleReferences` 里对每个 choice 的 `requires`：`choice` 形态的引用按"同一 `sourceEntryId` 或沿 `relations` 的 `featureOf` / `subclassOf` 祖先"解析（`RuleChoiceSemantics.requiresSatisfied` 的 `_scopeEntryIds` 语义——把作用域解析暴露成一个公开小函数 `RuleChoiceSemantics.scopeEntryIdsFor(sourceEntryId, entries)`，导入器与运行期共用，**不得**在导入器里重写一遍链遍历）；找不到 `choice` → `invalidRequires`，path 到 `requires[i].choice`；`option` 不在该 choice 的候选集（`candidatesFor`）里 → path 到 `requires[i].option`。

6) **字符串简写的 `optionType: "ability"` 候选必须是档案属性键**（否则自动推断出的 `kind: ability / target: <选项 id>` 会在运行期被 `_abilityGrantBonuses` 静默跳过——正是"声明了但用不了"）。放在 `item is String` 分支里、`invalidAutoGrant` 检查旁边；**对象选项不检查**（它的 id 只是标签载体，真正的 target 在显式 `grants` 里，已由 `_validateGrantFormulas` 的 `unknownAbility` 管）：

```dart
            if (optionType == 'ability') {
              final abilityKeys = Dnd5eRules.profile.abilities;
              if (!abilityKeys.contains(text)) {
                errors.add(
                  ContentValidationError(
                    path: idPath,
                    message:
                        '未知属性键 "$text"，可用：${abilityKeys.join(', ')}'
                        '（unknownAbility）',
                  ),
                );
              }
            }
```

> 与导入期已有的 `_validateGrantFormulas`（`kind: ability` 的 `target` → `unknownAbility`，第 1320–1331 行）互补：那条管**显式** grants，这条管**自动推断**出来的 grants。判据都是"档案 `abilities` 是唯一权威"。

- [ ] **步骤 4：运行测试与全量回归**

运行：
```
cmd.exe /c "cd /d ... && C:\Flutter\flutter\bin\flutter.bat test test\rules\import_rule_diagnostics_test.dart test\content_package_importer_test.dart test\rules\sample_packages_import_test.dart"
cmd.exe /c "cd /d ... && C:\Flutter\flutter\bin\flutter.bat test"
```
预期：PASS 且全绿。

**实现要点**
- 放行发生在**所有消费实现之后**：到本任务为止，`repeatable` / `countsToward` / `requires` / `group` / `help` / 内联 `grants` 都已生效，不存在"导入通过但运行期无效"的提交。
- 判据复用：`isCountsTowardPool`、`RuleChoiceSemantics.autoGrantsFor`、`RuleChoiceSemantics.candidatesFor`、`RuleChoiceSemantics.scopeEntryIdsFor`。
- `unsupportedChoiceField` 这个 code 从此刻起**没有任何产生点**；文档任务 12 从规格 §5.1 与 README 清单中删除它。

**验收：** 上一步「运行」里的目标测试命令 → PASS；再跑「任务门禁」三条命令 → 全绿（`dart.exe analyze lib test` 0 问题、`flutter.bat test` 全绿、`npm run check` / `npm run test:scripts` / `npm run lint:design` 全绿）。

- [ ] **步骤 5：Commit**

```bash
git add apps/client_flutter/lib/src/features/content/data/import/content_package_importer.dart apps/client_flutter/lib/src/features/rules/domain/rule_choice_semantics.dart apps/client_flutter/test/rules/import_rule_diagnostics_test.dart
git commit -m "feat(content): 选择系统字段放行并收窄为取值/引用校验"
```

---

## 任务 11：示例包与端到端验收

**文件：**
- 修改：`samples/homebrew-astral-knight/entries.json`
- 测试：`apps/client_flutter/test/rules/homebrew_class_end_to_end_test.dart`（追加）、`test/rules/sample_packages_import_test.dart`（应保持绿）

- [ ] **步骤 1：给示例包补上新契约能力（作者抄写模板必须是"最新写法"）**

在 `samples/homebrew-astral-knight/entries.json` 的 `astral-knight:class/astral-knight` 条目里：

1) `level 2` 的 `invocations` 选择（标签 `astral-invocation`，`label` 已写"可重复选取"）补：

```jsonc
"repeatable": true,
"group": "2 级祈唤",
"help": "同一祈唤可以重复选取，最多 2 次。"
```

2) `level 1` 的 `spells-1` 选择（它是**戏法**：`maximumOptionLevel: 0`）只补呈现字段，**不加 `countsToward`**——`countsToward` 只有 `spellbook` / `known` / `prepared` 三个池名，戏法不在其中（对应的 `classRules.spellcasting.cantrips` 列是另一套数值），给戏法硬塞 `known` 会让示例包自相矛盾：

```jsonc
"group": "1 级法术",
"help": "戏法自星界骑士法术列表选择，不占准备上限。"
```

3) 在 `level 1` 的 `class-skills` 选择补 `"group": "技能"`（示范分组呈现）。

> 只改这三个选择对象；不要动 `classRules`、grant、条目 id，也不要给示例包引入 `requires`（示例要能"照抄即用"，`requires` 的门槛语义需要属性值配合，放进文档示例即可）。
> `countsToward` 的端到端覆盖放在本任务步骤 2 的**合成包**测试里（示例包没有"计入 prepared 上限"的 1 环法术选择，硬加会改变示例的语义）。

- [ ] **步骤 2：写端到端测试（核心验收，对应规格 §6.3 的选择系统专项）**

```dart
// test/rules/homebrew_class_end_to_end_test.dart（追加 group）
group('选择系统运行时语义端到端（§6.3）', () {
  test('字符串简写技能选项自动授予熟练', () {
    // 用 samples/homebrew-astral-knight/entries.json 真实导入 → 建角色
    // 选 ['奥秘', '察觉'] → 断言 draft.skills['奥秘'] && draft.skills['察觉']。
  });

  test('内联 ability 选项真的改变派生（AC/豁免/技能）', () {
    // 合成 class 条目：choice optionType 'ability' + inline option
    // {id:'str', data:{value:2}} → 建角色选它 → 断言 abilities['str'] 比入参 +2，
    // 且 AC/豁免随 effectiveAbilities 变化（不是只落库）。
  });

  test('repeatable: true 同一选项选两次 → grants 结算两次', () {
    // samples 的 invocations（classFeature 条目候选）+ repeatable: true →
    // 同一 classFeature 条目选两次 → 断言 ledger.grants 中该条目 grants 出现两次，
    // 且 resolvedChoices 保留两份。
  });

  test('repeatable: false 的重复选中被拒（导入期不报错，运行期进 pending）', () { ... });

  test('requires 不满足时选择不可用（能力门槛 + 选择引用）', () { ... });

  test('group/help 出现在编辑器选择面板', () {
    // 用 samples 包建角色 → 找到 '2 级祈唤' 分组标题与 help 文案。
  });

  test('装备 A/B 方案写入 inventory', () { ... });

  test('optionType: "spell" + countsToward 受 prepared 上限约束', () {
    // 用**合成包**（不走 samples）：class 1 级 prepared = 2，声明一条
    // optionType:'spell' / countsToward:'prepared' / maximum:3 的选择 +
    // 3 个 spell 条目 → 断言只接受 2 个、第 3 个进 pending（poolExceeded）。
  });

  test('countsToward: null 的法术选择记 alwaysPreparedEntryIds', () {
    // samples 的 oath-spells（标注"始终准备，不占上限"）→ 断言
    // manualOverrides.spells.alwaysPreparedEntryIds 含所选法术。
  });
});
```

- [ ] **步骤 3：运行测试**

运行：`cmd.exe /c "cd /d ... && C:\Flutter\flutter\bin\flutter.bat test test\rules\homebrew_class_end_to_end_test.dart test\rules\sample_packages_import_test.dart"`
预期：PASS（示例包在新契约下整包导入，且新语义可被真实数据驱动）。

**验收：** 上一步「运行」里的目标测试命令 → PASS；再跑「任务门禁」三条命令 → 全绿（`dart.exe analyze lib test` 0 问题、`flutter.bat test` 全绿、`npm run check` / `npm run test:scripts` / `npm run lint:design` 全绿）。

- [ ] **步骤 4：Commit**

```bash
git add samples/homebrew-astral-knight/entries.json apps/client_flutter/test/rules/homebrew_class_end_to_end_test.dart
git commit -m "test(rules): 选择系统端到端验收并更新示例包新写法"
```

---

## 任务 12：文档同步（规格 + `docs/README.md`）

**文件：**
- 修改：`docs/specs/2026-09-10-rules-contract-design.md`
- 修改：`docs/README.md`

- [ ] **步骤 1：规格 `docs/specs/2026-09-10-rules-contract-design.md`**

1) **§5.1 表**：
- 删掉 `unsupportedChoiceField` 整行（放行后无产生点）；
- `invalidCountsToward` 的条件改为"`countsToward` 不在 `spellbook` / `known` / `prepared` 且非 `null`"；
- `invalidRequires` 的条件改为"`requires` 元素形状非法、`choice` / `option` 引用不存在、`ability` 不在 `abilities`、`minimum` 非正"；
- `invalidAutoGrant` 的示例消息改为条目类型（如 `optionType "classFeature" 的选项 "星界之势" 缺少 grants，且无法自动推断`），与决策 D5 对齐。
2) **§5.1 末尾的引用块**（"`unsupportedChoiceField` 是…的落点"整段）替换为"计划 2 已落地：这些字段被真正消费；`unsupportedChoiceField` 不再产生"。
3) **§3.10.1 之后加一段状态注记**：`options[].grants` / `repeatable` / `countsToward` / `requires` / `group` / `help` 已实现，实现计划见 `docs/plans/2026-09-12-choice-system-runtime.md`。
4) **§10.8 状态**由"由计划 2 承接"改为"已达成（计划 2）"，并逐条列出对应测试文件。
5) **§10.5 状态**的"唯一未实现的 code 是 `invalidAutoGrant`"改为"已实现（计划 2）"。
6) **§11「本轮延后」**里"选择系统的运行时语义 —— 计划 2 承接"整块删除或改写为"已由计划 2 落地，见 §3.10 与实现计划"；`invalidAutoGrant` 那一条同样处理；只保留"文档收口 —— 计划 3 承接"。
7) **§3.10.2 字段表**补一行说明本计划的三个口径（D1 / D2 / D4）：`countsToward` 的池上限来源、`requires` 的 `ability` 用入参基础属性、`ability` 加值取 `data.value`。

- [ ] **步骤 2：`docs/README.md`**

1) **§7.7 已知限制表**的"选择系统（计划 2）"行改为：
   > `repeatable` / `countsToward` / `requires` / `group` / `help` 与内联选项 `grants` **已实现**；`requires` 的 `ability` 门槛按**入参基础属性**判定（由其它选择授予的属性加值不计入门槛）；`spellbook` 池无独立数值列，只受选择自身 `maximum` 约束。
2) **§7.7 行为变化清单**追加第 13 条：
   > 13. 选择系统运行时语义落地：内联选项与字符串简写选中即生效（自动授予）；`repeatable` 允许同一选项选多次；`countsToward` 计入共享额度池；`requires` 不满足时选择不可用并说明原因；技能选择改由 `rules.progression[].choices` 的 `optionType: "skill"` 承担并写入 `build.choices`（背景技能仍由背景预设承担）。
3) **§9.2.3** 的 `choices` 段重写为完整字段表（`id`/`label`/`optionType`/`minimum`/`maximum`/`options`/`optionEntryIds`/`optionTags`/`maximumOptionLevel`/`recommendedEntryIds`/`repeatable`/`countsToward`/`requires`/`group`/`help`/`builderStep`），并写明自动授予表（含 `data.value` 口径）与 `invalidAutoGrant`；删掉"声明了但还无法消费的字段一律拒收"整段。
4) **§9.2.5 error 清单**：删 `unsupportedChoiceField`，`invalidCountsToward` / `invalidRequires` 描述改为取值/引用校验，补 `invalidAutoGrant`。
5) **§2 / §16**：如果列出了"未完成：选择系统（计划 2）"（第 1206 行附近），改为已完成并指向 §9.2.3。

- [ ] **步骤 3：验收（文档门禁）**

运行：
```
npm run lint:design
npm run test:scripts
```
预期：全绿（文档改动不影响代码门禁；这两条按下面的总验收再跑一次全量）。

**验收：** 上一步「运行」里的目标测试命令 → PASS；再跑「任务门禁」三条命令 → 全绿（`dart.exe analyze lib test` 0 问题、`flutter.bat test` 全绿、`npm run check` / `npm run test:scripts` / `npm run lint:design` 全绿）。

- [ ] **步骤 4：Commit**

```bash
git add docs/specs/2026-09-10-rules-contract-design.md docs/README.md
git commit -m "docs: 同步选择系统运行时语义的契约与行为变化"
```

---

## 验收标准（可执行的门禁清单）

按顺序执行，全部通过才算计划完成：

- [ ] **主题测试**
  ```
  cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test\rules\rule_choice_definition_test.dart test\rules\rule_choice_semantics_test.dart test\rules\rule_choice_quota_test.dart test\rules\import_rule_diagnostics_test.dart test\rules\homebrew_class_end_to_end_test.dart test\rule_choice_section_test.dart test\character_rules_engine_test.dart test\rules_driven_character_builder_test.dart test\character_builder_choices_test.dart"
  ```
  → 全绿。
- [ ] **静态分析**
  ```
  cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib test"
  ```
  → `No issues found!`
- [ ] **客户端全量**：`cmd.exe /c "cd /d ...\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test"` → 全绿，**测试数量只增不减**（以计划开始前的最近一次全量为基线）。
- [ ] **阶段门禁**：`npm run check`（含 `flutter analyze` + 服务端/客户端全量测试）→ 全绿。
- [ ] **脚本门禁**：`npm run test:scripts` → 全绿（未改 `scripts/`，作回归）。
- [ ] **设计门禁**：`npm run lint:design` → 全绿（未新增 token）。
- [ ] **规格 §10.8 逐条对应**（每条都有测试，不允许"实现了但没断言"）：
  - [ ] 字符串简写自动授予且选中生效（`rule_choice_semantics_test` + `homebrew_class_end_to_end_test`）。
  - [ ] 内联选项的 `ability` / `hitPoints` 经 ledger 改变派生（`character_rules_engine_test` + `rules_driven_character_builder_test`）。
  - [ ] `optionType: "spell"` + `countsToward` 受 `prepared` 约束（`character_builder_choices_test`）。
  - [ ] `repeatable` 行为正确（引擎 + UI + e2e）。
  - [ ] `requires` 隐藏语义正确（引擎 + UI + e2e）。
  - [ ] `group` / `help` 呈现（`rule_choice_section_test` + e2e）。
  - [ ] 装备 A/B 写入 `inventory`（`equipment_bundle_items_test` + e2e）。
  - [ ] 技能选择只由 `optionType: "skill"` 的选择承担（`rules_driven_character_builder_test`）。
- [ ] **无第二套实现**：
  ```
  grep -rn "usesDedicatedOptionUi" apps/client_flutter/lib/
  #   → 只应出现在「是否由专门渲染器承担」的判断处（定义 + 三个渲染入口）；
  #     character_upgrade_planner.dart 不得再出现（任务 6b 已移除免检）
  grep -rn "unsupportedChoiceField" apps/client_flutter/ docs/specs docs/README.md
  #   → 应为空（本计划文档自己会提到这个已退役的 code，故不把 docs/plans 纳入）
  grep -rn "optionType == 'skill'" apps/client_flutter/lib/
  #   → 只应出现在 StructuredClassRules / RuleChoiceDefinition
  ```
- [ ] **示例包**：`samples/homebrew-astral-knight` 在真实导入器下整包通过（`sample_packages_import_test`）。
- [ ] **文档一致**：规格 §3.10 / §5.1 / §10.5 / §10.8 / §11 与 `docs/README.md` §7.7 / §9.2.3 / §9.2.5 均已更新，且与实际实现一致（不再出现"导入即拒收"表述）。
- [ ] **手工冒烟**（推荐）：用 `samples/homebrew-astral-knight` 导入 → 标准创建到 2 级 → 确认祈祷选择可重复选两次、分组与帮助文案可见、装备 A/B 出现在库存、法术上限受 `prepared` 约束。

---

## 风险与已知限制

| 风险 / 限制 | 说明 | 缓解 |
|---|---|---|
| **`abilities` 进 `CharacterBuild` 是数据形状变化** | `data['build']` 新增 `abilities` 键；旧存档没有它。 | 缺省空 map → 能力型 `requires` 判为不满足（可见 pending），项目器一次回填；无 Drift 迁移；任务 4 有专测。 |
| **`requires` 门槛只读基础属性** | 由另一个选择授予的 `ability` 加值不满足前置（如 4 级 ASI 不开启 2 级祈唤）。 | 决策 D2 的显式取舍；写入 §7.7 已知限制；若用户要求"结算后门槛"，改动集中在 `RuleChoiceSemantics.requiresSatisfied` 的入参（引擎不结构改动）。 |
| **`spellbook` 无额度上限** | `classRules` 没有法术书容量列，§3.10.2 的法师例子（1 级法术书 6 个、`prepared` 4）与"共用 prepared"矛盾，只能取无上限。 | 决策 D1；写入 §9.2.3；若将来要精确建模，需在 `classRules.spellcasting` 增加列（属契约扩展，不在本计划）。 |
| **池占用"先声明先占"** | 两个选择共享池时，声明在前的先占满额度，后者进 pending。 | 决策 D8；顺序确定且可复现，pending 带 `poolExceeded` 原因；不按数值大小重排。 |
| **内联 grants 不出现在"自动获得"预览** | `_RuleGrantPreview` 由条目驱动（`ruleGrantPreviewRows`），内联选项 grants 只在选择卡片里可见。 | 选择卡片显示选项 label + 其 grants 摘要；`data['resolvedGrants']` 里可查；不新增第二套预览实现。 |
| **技能选择迁移到 `build.choices` 改变旧存档的 `pendingChoices`** | 老角色若曾用技能选择器（写入 `skills` 而非 `build.choices`），升级预览会出现 1 级技能选择未完成的 pending。 | 升级预览只把"本级新增"的 pending 当门禁（任务 6b）；已派出生的 `skills` 值不回退、不重复授予（自动授予只对 `build.choices` 里的值生效，不会覆盖既有 `skills` 布尔）。 |
| **`repeatable` 的技能/仅布尔结果选择** | 同一技能选两次时 `skills` 仍是 `true` 一次；次数只体现在 `build.choices` 与 grants 计数。 | 契约如此（技能熟练不可叠加）；`data['choices']` 保留次数，供后续特性引用。 |
| **`useDedicatedOptionUi` 语义变更** | 从"值写在别处"变为"有专门渲染器"，影响三处界面与升级规划器的免检逻辑。 | 任务 6b 一次改完并更新 `rules_upgrade_dedicated_choice_test`；`grep` 门禁确认无遗留旧语义。 |
| **UI 交互密度增加** | 分组 + 帮助 + 重复计数 + 前置提示都堆在选择卡片里。 | 只用既有 `Card.outlined` / `Chip` / `bodySmall` / `onSurfaceVariant`；不新增 token；`npm run lint:design` 兜底。 |
| **`builderStep` 白名单与渲染位置不同步** | `abilities` / `details` 原本没有渲染位置；契约允许作者写这两个值，导入期也放行。 | 任务 6b 补齐步骤 3 与 7 的 `...ruleChoiceWidgets`，并加"每个 `allowedBuilderSteps` 都有渲染位置"的结构守卫测试；否则会出现"看不见却要求选"的阻塞。 |
| **规格 §5.1 的 `invalidAutoGrant` 示例与 §3.10.2 表冲突** | 示例写 `optionType "value"`，表格说 `value` 只记录选择。 | 决策 D5：按表格实现（只对条目类型报错），任务 12 改写示例消息；已在「待用户确认」记录。 |

---

## 后续计划（本计划之外）

| 计划 | 内容 |
|---|---|
| 计划 3 | 文档收口：`docs/README.md` §9.2 的**完整**自制职业示例（含选择与法术选择）与"示例可被合成包复用"（规格 §10.7）；`README.md` 教程"导入并使用自定义职业包"；`AGENTS.md` 必读顺序补 §9.2。 |
| S3 | `patch` / `replace` / `priority` / 覆盖冲突 UI / `fieldSources` 的来源显示与关闭覆盖回退。 |
| S4 | 作者 GUI（可视化规则表单、基于已有条目创建覆盖、`.dndpack` 导出）。 |
| 提取器 P0 尾巴 | `scripts/extract_phb_2024_v2.py` 目前**不产出** `optionType: "spell"` 的选择（规格 §3.10.3-3 / §6.5 要求按规则书表格生成），本计划只保证客户端侧能消费这类选择；提取器补齐属脚本侧后续工作。 |

---

## 决策（2026-09-12，项目负责人已定，覆盖上节 D1–D9）

以本节为准；上节对应段落保留作背景。D7 是**必修缺陷**，不是可选项。

| # | 决策 |
|---|---|
| **D1** | 采纳计划：`invalidAutoGrant` **只对条目类型的字符串元素**报错（值类型没有可授予的条目）。规格 §5.1 的示例改为条目类型（任务 12 同步），避免"示例与实现不符"。 |
| **D2** | 采纳计划：`ability` 加值的数值取 `options[].data['value']`，缺省 `1`。规格 §3.10.2 补一句"加值写在选项的 `data.value`"，让载体有明文。 |
| **D3** | 采纳计划：`countsToward` 的池是**具名额度**，额度来源只有两处——同一步/其它选择声明的上限，或该职业自身的列（`prepared` / `known` 池取 `preparedLimit`）。**池没有声明上限 = 不限**（绝不臆造数字）。法师法术书例子按"不限"实现，规格 §3.10.2 的示例同步说明。 |
| **D4** | 采纳计划：`requires` 的能力门槛用 **`build.abilities`（基础属性）**，不用结算后属性——否则前置会依赖"同一批选择的应用顺序"，不可解释。规格补一句。 |
| **D5** | 采纳计划：`requires.option` 匹配**选中值**（内联选项 id 或条目 id 都算），实现按"该选择的选中值集合包含该 option"判定。 |
| **D6** | **扩契约**：给 `options[]` 增加 `requires`（`RuleChoiceOption.requires`），因为规格 §3.10.2 明说 `requires` 既能隐藏"该选择"也能隐藏"该选项"，而现有字段集没有载体。这是**加法**，规格 §3.10.2 补一行说明。 |
| **D7** | **必修**：`builderStep: "abilities"`(步骤 3) 与 `"details"`(步骤 7) 当前没有 `ruleChoiceWidgets`，示例包的 `asi-or-feat` 在创建向导里根本不显示；摘掉"专门 UI 免检"后会变成"看不见却阻塞创建"。任务 6b 必须修掉，并加结构守卫测试（每个允许的 `builderStep` 都必须真的渲染选择区）。 |
| **D8** | **降范围**：`optionType: "spell"` 的**运行时支持**照计划实现（法术池、`alwaysPreparedEntryIds`）；但**改提取器让它产出 `optionType:"spell"` 选择**不在本轮——PHB 包的法术选择现在由 `classRules.spellcasting` 正确承担，改提取器是另一大块且不影响正确性。规格 §11 明确记为延后（并说明"运行时已支持、只是 PHB 提取器未产出"）。 |
| **D9** | 采纳计划：`manualOverrides.spells.preparedEntryIds` 仍是**去重集合**（语义是"常备"），重复选取的**次数**只保留在有序的 `build.choices` 里。规格补一句说明两者分工。 |
| **D10** | **不在本轮**：背景技能仍由 `_presetSkillsForBackground` 的中文名预设提供（不走背景条目的 `rules`）。列入 §11 延后项，注明"背景条目驱动技能授予"属后续工作。 |
