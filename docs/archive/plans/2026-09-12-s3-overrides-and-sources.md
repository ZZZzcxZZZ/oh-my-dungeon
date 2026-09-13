# S3「覆盖 / 勘误声明与来源可追溯」实现计划

> **历史执行记录（2026-09-13 归档）。** 本计划的 13 个任务与后续修复批次已全部执行完毕，见文末「事后注记」。
> 其中的代码片段、行号与当时的 HEAD 都是快照，**可能已经过时**；
> 当前契约以
> [`docs/specs/2026-09-10-rules-contract-design.md`](../../specs/2026-09-10-rules-contract-design.md)
> 与 [`docs/README.md`](../../README.md) 为准，本文件只用于追溯决策与执行顺序。


> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 把「条目声明 ∪ 内置档案」的**字段级合并**升级为**列级合并**（`spellcasting` 按列、`resources` 按 `id` 再按列），把**来源可追溯**升级到列级并真正被角色页与导入报告消费，并在此基础上落地 S3 的三件事：`classRules.mode: "patch" | "replace"` 声明、可配置 `priority`（含 Drift `schemaVersion` 13→14 迁移）、跨包覆盖冲突的提示与选择、"关闭覆盖回退内置"。

**架构：** 合并仍然只有**一个**纯函数入口 `RuleProfileResolver.resolveClassRules`，但它从"条目 vs 档案两级"推广成"**按 tier 排序的多个声明**"：内置档案 = tier 0，包声明 = `100 + package.priority`（不写 `priority` 的包 tier 恒为 100，**行为与今天完全一致**）。列级"是否声明过这一列"的判据只有一处（`ClassRuleSet.declares` / `ClassSpellcasting.declares` / `ClassResourceRule.declares`，解析时填充 `fields`）；列级取值只有一处（`_pickColumn`）；来源写入只有一处（`_writeSource` + `RuleFieldPath`）；优先级排序只有一处（`RuleOverrideOrder.ordered`）。跨包声明由 `RuleOverrideIndex` 从"已启用包的 class 条目 + 包优先级"构建，按**对齐键（条目 id 末段）**分组——一个包可以给"已指向别的包条目"的角色打勘误。冲突（**同 tier 多来源抢同一列**）在合并时被记录成 `RuleOverrideConflict`，持久化到角色数据后在角色页提示并由用户选择。

**技术栈：** Flutter 3.41 / Dart 3.11、`flutter_test`、Drift（本次 `schemaVersion` 13 → 14，`ALTER TABLE ADD COLUMN`）、Material 3 + `DESIGN.md` token（`Card.outlined` / `colorScheme.onSurfaceVariant` / `tertiary`，无新 token）、`npm run check` 门禁。

**规格：** `docs/specs/2026-09-10-rules-contract-design.md`（§3.6、§3.7、§3.8、§3.12、§5.1、§5.2、§7、§11）。本计划只覆盖 S3；选择系统运行时语义（计划 2）与作者 GUI（S4）不在范围内。

**先决条件：** 工作区干净、`git log -1` 为 `2aa655a` 或其后（当前 HEAD：`2aa655a ci: 新增 scripts job 并刷新 §16 实测基线`）；已跑过一次全量 `flutter test` 全绿（基线 **1237 通过 / 6 跳过**，见 `docs/README.md` §16）。

---

## 命令速查（Windows + WSL，全计划统一）

```bash
# 单个测试文件（不要用 --plain-name 过滤中文用例名，直接跑文件）
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test/rules/xxx_test.dart"

# 一组测试目录
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test/rules"

# 静态分析（唯一允许的分析入口；不要跑全仓 dart format）
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib test"

# 阶段门禁（仓库根，逐个跑；npm run check 已含服务端 lint + 客户端 analyze + 服务端/客户端全量测试）
npm run check
npm run test:scripts
npm run lint:design
```

> **每个任务结束时工作树必须全绿**：该任务自己的测试 + `test/rules` 全目录 + 全量 `flutter test` 通过、`dart.exe analyze lib test` 0 问题。
> **不允许**"改了签名让下一任务再修调用方"——本计划所有签名变化都带默认值，既有调用点必须**原样编译通过**。
> 不要跑全仓 `dart format`；不要用 `--plain-name` 过滤中文用例名。

---

## 背景

规格 §3.6 明确记着本轮欠下的一条硬约束：

> 来源的粒度是**顶层字段级**（`spellcasting` 是整字段，不细分到 `spellcasting.slots`）：字段级合并本身就是整 `spellcasting` 替换，因此列级来源在本契约下无法产生。S3 若要"只覆盖 `prepared`、保留档案 `slots`"，必须先把合并粒度改到列级——这是一条**已知限制**，S3 之前必须决策。

§3.7 同时说明来源目前**只写不读**：`ResolvedClassRules.fieldSources` 在数据层被记录，角色页与导入报告尚未消费（`docs/README.md` §7.7「来源可追溯」段逐字一致）。

§3.8 说明当前**故意没有** `priority`：只有两级（内置档案 < 角色所用条目声明），因为一个角色只引用它自己的那一个职业条目，包与包之间不会冲突。

§11 把 S3 定义成四件事：`mode: "patch" | "replace"` 声明、可配置 `priority`（含 Drift 迁移）、覆盖冲突 UI、关闭覆盖回退内置。

本轮因此要**先做列级合并**（否则 S3 的四件事都没有立足点），再把 S3 四件事落在同一个解析链上。

---

## 范围（做什么）

1. **列级合并**：`spellcasting` 内部按列（`mode` / `ability` / `listTags` / `archetype` / `slots` / `slotLevel` / `prepared` / `cantrips` / `maximumSpellLevel`）；`resources` 按 `id` 合、同 id 再按列（`name` / `maximum` / `recovery` / `startsAtLevel`）；`hitDie` / `savingThrowAbilities` 维持整值合并。核心验收：**条目只覆盖 `spellcasting.prepared` 时，`slots` / `mode` / `ability` 仍来自内置档案**。
2. **来源升级到列级并被消费**：`RuleFieldSource` 能表达 `spellcasting.prepared ← <条目 X>`；角色页显示"该数值来自内置档案 / 来自哪个包"（Material 3 + `DESIGN.md` token）；导入报告与导入预览也能看到。这是 §3.7 本轮欠下的实现。
3. **`classRules.mode: "patch" | "replace"`**：语义、与列级合并的关系、`replace` 时未声明列一律"未声明"（不回退更低 tier）。
4. **`priority`**：包级可配置、落 `local_content_packages.priority`、`schemaVersion` 13→14 迁移；两级模型推广为 `tier = 0（内置）/ 100 + priority（包）`；**不写 `priority` 的包 tier 恒为 100，行为不变**。
5. **覆盖冲突 UI**：同 tier 多来源抢同一列时，角色页提示并可选择保留哪个来源（写入角色数据）。
6. **关闭覆盖回退内置**：角色页能看到"当前值来自覆盖"，并能显式关掉该覆盖（回退内置档案）。
7. **规格与 `docs/README.md` 同步**：§3.6 的"已知限制"改掉、§3.7 的"本轮不消费"改掉、§3.8 的无 `priority` 说明推广、§11 的 S3 行标为已实现、§5 补新增诊断 code。

## 不做什么

- 不实现选择系统运行时语义（`repeatable` / `countsToward` / `requires` / `group` / `help` / 内联 `grants`）——计划 2。
- 不做作者 GUI、`.dndpack` 导出、"基于已有条目创建覆盖"的表单——S4。
- 不做 `replaces` relation 的消费方（本计划用**对齐键**关联勘误声明；`replaces` 是否成为第二种关联方式见「待用户确认」第 4 条）。
- 不做**列内逐级**（per-level）合并：`Table<T>` 列一旦被较高 tier 声明，整列由它负责；该列未声明的等级按 §3.12 是"未声明"（`prepared` / `cantrips` 不回退，`slots` / `slotLevel` / `maximumSpellLevel` 仍按 §3.3 回退到 `archetype`）。
- 不引入 `priority` 的条目级粒度、不做全局条目扫描的性能优化（索引是内存 Map，包数量级很小）。
- 不改 `DESIGN.md`（复用既有 token 与 `Card.outlined` / `Switch` / `AlertDialog`；预计无新 token）。

## 已定决策：合并粒度改到列级，及其理由

**决策（已与用户确认）：列级合并。**

理由：本轮把场景 D（覆盖 / 勘误）划进了范围，而"整 `spellcasting` 替换"表达不出"勘误只改 `prepared` 列、保留档案 `slots`"这类需求；规格 §3.6 也明说这是 S3 之前必须做的决策。列级合并同时让 §3.7 的来源粒度有了可落地的形状（`spellcasting.prepared`），否则 S3 的"关掉某一条覆盖"无从表述。

**列级合并矩阵（本计划唯一权威口径，实现必须与此逐项一致）：**

| 字段 / 列 | 合并粒度 | 来源字段路径 | 说明 |
|---|---|---|---|
| `hitDie` | 整值 | `hitDie` | 本来就是单值 |
| `savingThrowAbilities` | 整值（集合整体） | `savingThrowAbilities` | 本来就是单值语义（不是"逐属性合并"） |
| `spellcasting.mode` | 列 | `spellcasting.mode` | 缺省即"未声明"（合并后才落默认 `none`） |
| `spellcasting.ability` | 列 | `spellcasting.ability` | 显式 `null` 是"清空该列"，与"未声明"不同 |
| `spellcasting.listTags` | 列（整个数组） | `spellcasting.listTags` | 数组不做逐元素合并 |
| `spellcasting.archetype` | 列 | `spellcasting.archetype` | 显式 `null` 可清空档案的原型 |
| `spellcasting.slots` | 列（整表） | `spellcasting.slots` | 该列未声明的等级仍按 §3.3 回退 `archetype` |
| `spellcasting.slotLevel` | 列（整表） | `spellcasting.slotLevel` | 仅 pact 有意义 |
| `spellcasting.prepared` | 列（整表） | `spellcasting.prepared` | 无原型回退（§3.1） |
| `spellcasting.cantrips` | 列（整表） | `spellcasting.cantrips` | 无原型回退 |
| `spellcasting.maximumSpellLevel` | 列（整表） | `spellcasting.maximumSpellLevel` | 该列未声明等级回退 `archetype` |
| `resources[].name` | 列 | `resources.<id>.name` | 允许补丁资源省略（由低 tier 同 id 补齐） |
| `resources[].maximum` | 列 | `resources.<id>.maximum` | 同上 |
| `resources[].recovery` | 列 | `resources.<id>.recovery` | 常量形态与 `{"table": …}` 形态**共用一条来源路径** |
| `resources[].startsAtLevel` | 列 | `resources.<id>.startsAtLevel` | 同上 |
| `resources[].description` | 不参与数值合并 | **不记来源** | 取"最高 tier 声明的非空值"；它没有规则语义 |
| `resources[].id` | 合键 | — | 不是可覆盖的列 |

**"已声明"的判据只有一处**：`apps/client_flutter/lib/src/features/rules/domain/class_rule_set.dart` 里的 `ClassRuleSet.declares(String)`（已存在）、`ClassSpellcasting.declares(String)`（任务 1 新增）、`ClassResourceRule.declares(String)`（任务 1 新增）。三者都由 `parse` 在遇到键时填充 `fields`，**不靠"值是否为 null"判断**——否则显式 `null`（"清空该列"）与"未声明"无法区分。

---

## 文件结构

**新增**

| 文件 | 职责 |
|---|---|
| `apps/client_flutter/lib/src/features/rules/domain/rule_field_path.dart` | 列级来源字段路径的**唯一**定义：常量、`spellcasting(column)` / `resource(id, column)` 构造、列白名单、中文展示名 `labelFor(path)` |
| `apps/client_flutter/lib/src/features/rules/domain/rule_override_declaration.dart` | `RuleOverrideDeclaration`：一条参与合并的职业规则声明（`originId` / `packageId` / `priority` / `entryId` / `rules`）+ `tier` |
| `apps/client_flutter/lib/src/features/rules/domain/rule_override_priority.dart` | `RuleOverrideOrder.ordered(...)`：优先级排序的**唯一**实现（tier 降序 → `replace` 先于 `patch` → 角色自己的条目优先 → `originId` 升序） |
| `apps/client_flutter/lib/src/features/rules/domain/rule_override_conflict.dart` | `RuleOverrideConflict`：`{field, tier, originIds, effectiveOriginId}` + `toJson` / `fromJson` |
| `apps/client_flutter/lib/src/features/characters/domain/rule_override_index.dart` | `RuleOverrideIndex`：从"已启用包的 class 条目 + 包优先级"构建按对齐键分组的声明索引；`declarationsFor(slug, {excludeEntryId})` |
| `apps/client_flutter/lib/src/features/characters/domain/character_rule_overrides.dart` | `CharacterRuleOverrides`：角色数据 `data.ruleOverrides` 的**唯一**读取/写入实现（`disabledOriginIds` / `pinned`） |
| `apps/client_flutter/lib/src/features/characters/presentation/widgets/rule_source_list.dart` | 来源展示组件：`RuleSourceChip`（单个字段的来源徽标）、`RuleSourceSection`（字段 → 来源清单 + "关闭覆盖 / 使用内置档案"开关）、`RuleOverrideConflictBanner`（冲突提示入口） |
| `apps/client_flutter/test/rules/class_rule_declared_columns_test.dart` | 列级"已声明"判据单测（任务 1） |
| `apps/client_flutter/test/rules/spellcasting_column_merge_test.dart` | `spellcasting` 列级合并单测（任务 2） |
| `apps/client_flutter/test/rules/resource_column_merge_test.dart` | `resources` 按 id 列级合并 + 补丁资源单测（任务 3） |
| `apps/client_flutter/test/rules/rule_field_sources_test.dart` | 来源列级化、序列化、确定性排序单测（任务 4） |
| `apps/client_flutter/test/rules/class_merge_mode_test.dart` | `patch` / `replace` 语义与校验单测（任务 5） |
| `apps/client_flutter/test/rules/rule_override_priority_test.dart` | 声明排序 + 索引单测（任务 7） |
| `apps/client_flutter/test/rules/rule_override_conflict_test.dart` | 多声明合并 + 冲突记录单测（任务 8） |
| `apps/client_flutter/test/package_priority_migration_test.dart` | Drift v13 → v14 迁移与向后兼容单测（任务 6；`test/` 根目录，与 `app_database_test.dart` / `bundled_content_installer_test.dart` 同级） |
| `apps/client_flutter/test/rules/package_json_test_support.dart` | 从 `import_rule_diagnostics_test.dart` 抽出的 `packageJson` / `classEntry` 包构造辅助（任务 11 起被两个测试文件共用，避免跨测试文件 import） |
| `apps/client_flutter/test/character_rule_sources_ui_test.dart` | 角色页来源显示 + 冲突对话框 + 关闭覆盖 widget 测试（任务 9、10） |
| `apps/client_flutter/test/content_import_rule_sources_test.dart` | 导入报告 / 导入预览显示来源测试（任务 11） |

**修改**

| 文件 | 变化 |
|---|---|
| `apps/client_flutter/lib/src/features/rules/domain/class_rule_set.dart` | `ClassSpellcasting.fields` / `ClassResourceRule.fields` + `declares`；`ClassResourceRule.name` / `maximum` 变可空（补丁资源）；`ClassMergeMode` + `kClassRuleFields` 增加 `mode`；`invalidMergeMode` / `incompleteResourcePatch` 诊断 |
| `apps/client_flutter/lib/src/features/rules/domain/rule_profile_resolver.dart` | `_mergeField` → 列级 `_pickColumn` + `_mergeSpellcasting` / `_mergeResources`；`mode: replace` 截断；多声明合并 + 冲突记录；`RuleFieldPath` 写来源；`resolveBuiltin` 校验档案资源完整性；`validateEntryClassRules` 校验补丁资源完整性 |
| `apps/client_flutter/lib/src/features/rules/domain/rule_profile.dart` | `RuleFieldSource.toJson` / `fromJson`；`RuleFieldSourceMap`（确定性排序的唯一实现）；`ResolvedClassRules.sourceOf` / `conflicts` / `activeOriginIds`；`resourcesAt` 兼容可空 `name` / `maximum` |
| `apps/client_flutter/lib/src/features/characters/domain/dnd5e_rules.dart` | `resolveClassRules` 新增可选 `overrides` / `entryPriority` / `disabledOriginIds` / `pinnedOrigins` 并透传（全部带默认值，既有调用点不变） |
| `apps/client_flutter/lib/src/features/characters/domain/rules_driven_character_builder.dart` | 构造 `RuleOverrideIndex`；输出 `classRuleSources` / `classRuleConflicts`；`classResources` 兼容可空 `name` |
| `apps/client_flutter/lib/src/features/characters/domain/character_rule_projector.dart` | 同上 + 从角色读 `CharacterRuleOverrides`（`disabledOriginIds` / `pinned`）并透传；`mergedData` 键清单加 `classRuleSources` / `classRuleConflicts` |
| `apps/client_flutter/lib/src/features/characters/presentation/characters_tab_page.dart` | 打开详情页时把 `packagePriorities`（来自 `ContentRepository`）与 `contentEntries` 一起传下去，供索引与重新派生使用 |
| `apps/client_flutter/lib/src/features/characters/presentation/character_detail_page.dart` | 新增 `packagePriorities` / `onReapplyRules` 参数（带默认值）；把 `packagePriorities` 传给法术 / 资源 / 资料面板 |
| `apps/client_flutter/lib/src/features/characters/presentation/character_detail_spells_panel.dart` | 法术位 / 准备上限区显示来源徽标 + 冲突横幅；回退解析时带 `overrides` / `disabledOriginIds` / `pinnedOrigins` |
| `apps/client_flutter/lib/src/features/characters/presentation/character_detail_resources_panel.dart` | 每条资源显示来源徽标 + 冲突横幅 |
| `apps/client_flutter/lib/src/features/characters/presentation/character_detail_features_panel.dart` | `_ProfilePanel`（该文件 350 行起）加「规则来源」区（`RuleSourceSection`） |
| `apps/client_flutter/lib/src/features/content/data/import/content_package_importer.dart` | 校验 `$.priority`（`invalidPriority`）与 `classRules.mode`（`invalidMergeMode`）；补丁资源完整性（`incompleteResourcePatch`）；把来源写进报告 |
| `apps/client_flutter/lib/src/features/content/domain/content_import_report.dart` | 新增 `priority`（默认 0）与 `classRuleSources`（默认空 Map） |
| `apps/client_flutter/lib/src/features/content/presentation/content_import_preview_dialog.dart` | 每个 class 条目行下方显示来源摘要 |
| `apps/client_flutter/lib/src/features/content/domain/content_package_manifest.dart` | 新增 `priority`（默认 0）+ `fromJson` / `toJson` / `copyWith` |
| `apps/client_flutter/lib/src/features/content/data/local/content_tables.dart` | `LocalContentPackages.priority`（`integer().withDefault(const Constant(0))`） |
| `apps/client_flutter/lib/src/core/database/app_database.dart` | `schemaVersion => 14`；`if (from >= 2 && from < 14)` 增加 `priority` 列 |
| `apps/client_flutter/lib/src/features/content/data/local/content_repository.dart` | 两处 `LocalContentPackagesCompanion.insert` 写入 `priority`；`_mapPackage` 读回 `priority`；新增 `Future<Map<String, int>> packagePriorities()` |
| `apps/client_flutter/test/rules/rule_profile_test_support.dart` | 新增合成档案 fixture `overrideArchive()`（wizard + barbarian 的最小数值档案，任务 2 / 3 / 5 / 8 共用；沿用该文件"规则档案测试共享辅助"的既有职责） |
| `apps/client_flutter/test/app_database_test.dart` | 断言 `schemaVersion == 14` |
| `apps/client_flutter/test/rules/rule_profile_resolver_test.dart` | 适配列级来源键（`fieldSources` 的键从 `spellcasting` 变 `spellcasting.<列>`） |
| `apps/client_flutter/test/rules/import_rule_diagnostics_test.dart` | 新增 `invalidMergeMode` / `invalidPriority` / `incompleteResourcePatch` 用例 |
| `apps/client_flutter/test/rules/homebrew_class_end_to_end_test.dart` | 新增"条目只覆盖 `prepared`"的核心验收与 `replace` 变体 |
| `docs/specs/2026-09-10-rules-contract-design.md` | §3.6 / §3.7 / §3.8 / §5.1 / §5.2 / §11 同步（任务 12） |
| `docs/README.md` | §5.1（`schemaVersion = 14`）、§7.7（来源可追溯段改写成已消费 + 已知限制删除列级限制）、§9.2.1 / §9.2.2 / §9.2.5（S3 契约与新增 code）（任务 12） |

**不修改**：Drift 表的**其它**任何列与服务端代码、`DESIGN.md`（无新 token 预期）、`scripts/extract_phb_2024_v2.py`（提取器不写 `priority`，缺省 0 合法）、`apps/client_flutter/assets/rules/dnd5e-2024.rules.json`（内置档案不写 `mode`，tier 0 行为不变）。

---

## 唯一实现清单（审查时逐条核对）

| 概念 | 唯一实现点 | 禁止出现的第二处 |
|---|---|---|
| 列级"已声明" | `ClassRuleSet.declares` / `ClassSpellcasting.declares` / `ClassResourceRule.declares`（`class_rule_set.dart`，`parse` 填充 `fields`） | 任何 `value != null` 形式的"是否声明"判断 |
| 列级取值 | `RuleProfileResolver._pickColumn`（`rule_profile_resolver.dart`） | `_mergeField` 的第二份列级化实现 |
| 来源字段路径与展示名 | `rule_field_path.dart`（`RuleFieldPath`） | UI 里手拼 `'spellcasting.prepared'` 字符串或自己写中文标签 |
| 来源写入 | `RuleProfileResolver._writeSource`（唯一出口，内部走 `RuleFieldPath`） | 任何别处 `RuleFieldSource(...)` 构造生产数据 |
| 来源序列化 / 排序 | `RuleFieldSourceMap.toData` / `fromData`（`rule_profile.dart`） | 角色数据里另写一份 `{originId, tier}` 解析 |
| 优先级排序 | `RuleOverrideOrder.ordered`（`rule_override_priority.dart`） | 解析器里再写一次 `sort` |
| 跨包声明索引 | `RuleOverrideIndex.fromEntries`（`characters/domain/rule_override_index.dart`） | 各调用点自己遍历条目找同 slug |
| 冲突记录 | `RuleProfileResolver._pickColumn`（同 tier 多来源时登记） | UI 自己比较来源判断冲突 |
| 关闭覆盖 / 固定来源的读写 | `CharacterRuleOverrides.fromCharacter` / `toData` | 页面直接读写 `dataMap['ruleOverrides']` |
| 重新派生 | `CharacterRuleProjector.project`（既有，`characters_tab_page` 已经调用） | 页面自己拼派生逻辑 |
| `packageId`（条目 id 前缀） | `RuleOverrideDeclaration.packageIdOf`（`rules/domain`，避免解析器反向依赖 `characters/domain`） | 各处 `entryId.split(':').first` |

---

## 任务 1：列级"已声明"判据 + 来源字段路径

**文件：**
- 创建：`apps/client_flutter/lib/src/features/rules/domain/rule_field_path.dart`
- 修改：`apps/client_flutter/lib/src/features/rules/domain/class_rule_set.dart`
- 测试：`apps/client_flutter/test/rules/class_rule_declared_columns_test.dart`

- [ ] **步骤 1：写失败测试**

```dart
// test/rules/class_rule_declared_columns_test.dart
import 'package:dnd_table_client/src/features/rules/domain/class_rule_set.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_diagnostic.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_field_path.dart';
import 'package:flutter_test/flutter_test.dart';

const _path = r'$.structured.classRules';

void main() {
  group('列级声明集合', () {
    test('spellcasting 只记录真正出现过的键', () {
      final diagnostics = <RuleDiagnostic>[];
      final rules = ClassRuleSet.parse({
        'spellcasting': {
          'prepared': {'5': 9},
        },
      }, path: _path, diagnostics: diagnostics);

      expect(
        diagnostics.where((d) => d.severity == RuleSeverity.error),
        isEmpty,
      );
      final spellcasting = rules.spellcasting!;
      expect(spellcasting.declares('prepared'), isTrue);
      for (final absent in [
        'mode',
        'ability',
        'listTags',
        'archetype',
        'slots',
        'slotLevel',
        'cantrips',
        'maximumSpellLevel',
      ]) {
        expect(spellcasting.declares(absent), isFalse, reason: absent);
      }
      // 缺省值仍然照契约生效，但**不算声明**。
      expect(spellcasting.mode, 'none');
      expect(spellcasting.listTags, isEmpty);
    });

    test('显式 null 的 archetype 记为已声明（可用来清空档案的列）', () {
      final diagnostics = <RuleDiagnostic>[];
      final rules = ClassRuleSet.parse({
        'spellcasting': {'mode': 'prepared', 'ability': 'cha', 'archetype': null},
      }, path: _path, diagnostics: diagnostics);

      expect(rules.spellcasting!.declares('archetype'), isTrue);
      expect(rules.spellcasting!.archetype, isNull);
      expect(rules.spellcasting!.declares('mode'), isTrue);
    });

    test('资源只记录真正出现过的键；缺省值不算声明', () {
      final diagnostics = <RuleDiagnostic>[];
      final rules = ClassRuleSet.parse({
        'resources': [
          {'id': 'rage', 'name': '狂暴', 'maximum': 2},
        ],
      }, path: _path, diagnostics: diagnostics);

      expect(diagnostics.where((d) => d.severity == RuleSeverity.error), isEmpty);
      final rage = rules.resources.single;
      expect(rage.declares('name'), isTrue);
      expect(rage.declares('maximum'), isTrue);
      expect(rage.declares('recovery'), isFalse);
      expect(rage.declares('startsAtLevel'), isFalse);
      expect(rage.recovery, isNull, reason: '缺省不合成常量');
      expect(rage.recoveryAt(1), 'longRest', reason: '运行期默认值不变');
      expect(rage.startsAtLevel, 1, reason: '缺省值不变');
    });
  });

  group('来源字段路径', () {
    test('构造与列白名单', () {
      expect(RuleFieldPath.spellcasting('prepared'), 'spellcasting.prepared');
      expect(
        RuleFieldPath.resource('rage', 'maximum'),
        'resources.rage.maximum',
      );
      expect(RuleFieldPath.spellcastingColumns, {
        'mode',
        'ability',
        'listTags',
        'archetype',
        'slots',
        'slotLevel',
        'prepared',
        'cantrips',
        'maximumSpellLevel',
      });
      expect(RuleFieldPath.resourceColumns, {
        'name',
        'maximum',
        'recovery',
        'startsAtLevel',
      });
    });

    test('每个路径都有中文展示名（UI 不得自己拼）', () {
      expect(RuleFieldPath.labelFor('hitDie'), '生命骰');
      expect(RuleFieldPath.labelFor('savingThrowAbilities'), '豁免熟练');
      expect(RuleFieldPath.labelFor('spellcasting.prepared'), '准备法术上限');
      expect(RuleFieldPath.labelFor('resources.rage.maximum'), '狂暴 · 次数上限');
      expect(RuleFieldPath.labelFor('resources.rage.recovery'), '狂暴 · 恢复');
      expect(
        RuleFieldPath.labelFor('resources.rage.startsAtLevel'),
        '狂暴 · 起始等级',
      );
    });
  });
}
```

- [ ] **步骤 2：跑测试确认失败**

```bash
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test/rules/class_rule_declared_columns_test.dart"
```

预期：编译失败（`declares` / `RuleFieldPath` 不存在）。

- [ ] **步骤 3：实现 `RuleFieldPath`**

```dart
// apps/client_flutter/lib/src/features/rules/domain/rule_field_path.dart
//
// 列级来源的**唯一**字段路径定义（契约 §3.7）。解析器写来源、UI 读来源、
// 角色数据持久化来源都走这里；任何地方都不得手拼 'spellcasting.prepared'。
abstract final class RuleFieldPath {
  static const hitDie = 'hitDie';
  static const savingThrowAbilities = 'savingThrowAbilities';

  static const spellcastingPrefix = 'spellcasting.';
  static const resourcePrefix = 'resources.';

  /// `spellcasting` 的列白名单（顺序与契约 §3.3 的字段表一致）。
  static const spellcastingColumns = <String>{
    'mode',
    'ability',
    'listTags',
    'archetype',
    'slots',
    'slotLevel',
    'prepared',
    'cantrips',
    'maximumSpellLevel',
  };

  /// 资源参与列级合并、且记录来源的列（`id` 是合键，`description` 无数值语义）。
  static const resourceColumns = <String>{
    'name',
    'maximum',
    'recovery',
    'startsAtLevel',
  };

  static String spellcasting(String column) => '$spellcastingPrefix$column';

  static String resource(String id, String column) => '$resourcePrefix$id.$column';

  /// `resources.<id>.<列>` 拆解；不是资源路径时返回 null。
  static ({String id, String column})? parseResource(String path) {
    if (!path.startsWith(resourcePrefix)) return null;
    final rest = path.substring(resourcePrefix.length);
    final split = rest.lastIndexOf('.');
    if (split <= 0) return null;
    return (id: rest.substring(0, split), column: rest.substring(split + 1));
  }

  /// 展示名（中文）的**唯一**实现。未知路径原样返回，便于暴露漏登记。
  static String labelFor(String path, {String? resourceName}) {
    return switch (path) {
      hitDie => '生命骰',
      savingThrowAbilities => '豁免熟练',
      'spellcasting.mode' => '法术选择模型',
      'spellcasting.ability' => '施法属性',
      'spellcasting.listTags' => '法术列表',
      'spellcasting.archetype' => '法术位进阶',
      'spellcasting.slots' => '法术位',
      'spellcasting.slotLevel' => '契约法术位环阶',
      'spellcasting.prepared' => '准备法术上限',
      'spellcasting.cantrips' => '戏法上限',
      'spellcasting.maximumSpellLevel' => '最高法术环阶',
      _ => _resourceLabel(path, resourceName) ?? path,
    };
  }

  static String? _resourceLabel(String path, String? resourceName) {
    final parsed = parseResource(path);
    if (parsed == null) return null;
    final subject = resourceName ?? parsed.id;
    return switch (parsed.column) {
      'name' => '$subject · 名称',
      'maximum' => '$subject · 次数上限',
      'recovery' => '$subject · 恢复',
      'startsAtLevel' => '$subject · 起始等级',
      _ => null,
    };
  }
}
```

- [ ] **步骤 4：给 `ClassSpellcasting` / `ClassResourceRule` 加列级声明集合**

在 `class_rule_set.dart` 中：

```dart
class ClassSpellcasting {
  const ClassSpellcasting({
    required this.mode,
    this.ability,
    this.listTags = const [],
    this.archetype,
    this.slots,
    this.slotLevel,
    this.prepared,
    this.cantrips,
    this.maximumSpellLevel,
    this.fields = const {},
  });

  // …既有字段不变…

  /// 声明过哪些列（**列级合并的唯一判据**，契约 §3.6）。
  /// 由 [ClassRuleSet.parse] 在"键存在"时填充；缺省值不算声明，
  /// 显式 `null` 算声明（`archetype: null` = 清空该列）。
  final Set<String> fields;

  bool declares(String column) => fields.contains(column);
}
```

`ClassResourceRule` 同样加 `final Set<String> fields;` + `bool declares(String column) => fields.contains(column);`。

`_parseSpellcasting` 里，在 `fields.add('spellcasting')`（顶层）之后收集子列：

```dart
  // 列级声明：只记"键存在"，不记"值非 null"（显式 null 是"清空该列"）。
  final declaredColumns = <String>{
    for (final key in kSpellcastingFields)
      if (value.containsKey(key)) key,
  };
  // …构造返回值时传 fields: declaredColumns
```

`_parseResource` 里同样：

```dart
  final declaredColumns = <String>{
    for (final key in kResourceFields)
      if (raw.containsKey(key)) key,
  };
  // …构造 ClassResourceRule 时传 fields: declaredColumns
```

- [ ] **步骤 5：跑测试确认通过**

```bash
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test/rules"
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib test"
```

预期：新增测试全绿；`test/rules` 全绿（这一步是纯增量，不应有既有用例变化）；analyze 0 问题。

- [ ] **步骤 6：Commit**

```bash
git add apps/client_flutter/lib/src/features/rules/domain/rule_field_path.dart \
        apps/client_flutter/lib/src/features/rules/domain/class_rule_set.dart \
        apps/client_flutter/test/rules/class_rule_declared_columns_test.dart
git commit -m "feat(rules): 记录 spellcasting 与资源的列级声明集合

为 S3 的列级合并提供唯一判据：ClassRuleSet.parse 在遇到键时填充 fields，
declares() 只看"键是否存在"而不是"值是否为 null"，因为显式 null 表示
清空该列（与未声明语义不同）。

同时新增 RuleFieldPath：列级来源字段路径与中文展示名的唯一定义。"
```

---

## 任务 2：`spellcasting` 列级合并（核心验收）

**文件：**
- 修改：`apps/client_flutter/lib/src/features/rules/domain/rule_profile_resolver.dart`
- 测试：`apps/client_flutter/test/rules/spellcasting_column_merge_test.dart`（新建）
- 测试：`apps/client_flutter/test/rules/rule_profile_resolver_test.dart`（适配来源键）

- [ ] **步骤 1：把合成档案 fixture 放进共享辅助**

`test/rules/rule_profile_test_support.dart` 追加（任务 2 / 3 / 5 / 8 共用**同一份**最小档案；不要在多个测试文件里各抄一份）：

```dart
/// S3 列级合并测试共用的最小内置档案（只含数值，字段形状与真实档案一致）。
///
/// wizard：施法职业（full-caster / int / 稀疏 slots，`prepared` / `cantrips` 为短数组）
/// barbarian：非施法职业 + 一条可列级覆盖的资源
Map<String, Object?> overrideArchive() => {
  'rulebookVersion': 1,
  'system': 'dnd5e-2024',
  'abilities': ['str', 'dex', 'con', 'int', 'wis', 'cha'],
  'skills': [
    {'name': '奥秘', 'ability': 'int'},
    {'name': '运动', 'ability': 'str'},
  ],
  'progressions': {
    'none': {'slots': <Object?>[]},
    'full-caster': {
      'minimumLevel': 1,
      'slots': [
        {'1': 2},
        {'1': 3},
        {'1': 4, '2': 2},
        {'1': 4, '2': 3},
        {'1': 4, '2': 3, '3': 2},
      ],
      'maximumSpellLevel': [1, 1, 2, 2, 3],
    },
  },
  'classes': {
    'wizard': {
      'hitDie': 6,
      'savingThrowAbilities': ['int', 'wis'],
      'spellcasting': {
        'mode': 'prepared',
        'ability': 'int',
        'archetype': 'full-caster',
        'slots': {'5': {'1': 4, '2': 3, '3': 2}},
        'prepared': [4, 5, 6, 7, 9],
        'cantrips': [3, 3, 3, 4, 4],
        'maximumSpellLevel': [1, 1, 2, 2, 3],
      },
      'resources': <Object?>[],
    },
    'barbarian': {
      'hitDie': 12,
      'savingThrowAbilities': ['str', 'con'],
      'spellcasting': {'mode': 'none'},
      'resources': [
        {
          'id': 'rage',
          'name': '狂暴',
          'startsAtLevel': 1,
          'recovery': 'shortRestOne',
          'maximum': {
            'table': {'1': 2, '3': 3, '6': 4},
          },
        },
      ],
    },
  },
};
```

- [ ] **步骤 2：写失败测试（核心验收先写）**

```dart
// test/rules/spellcasting_column_merge_test.dart
import 'package:dnd_table_client/src/features/rules/domain/class_rule_set.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_diagnostic.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_field_path.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rule_profile_test_support.dart';

const _path = r'$.structured.classRules';
const _entryId = 'errata:class/wizard';

ClassRuleSet entry(Map<String, Object?> classRules) {
  final diagnostics = <RuleDiagnostic>[];
  final rules = ClassRuleSet.parse(
    classRules,
    path: _path,
    diagnostics: diagnostics,
  );
  expect(
    diagnostics.where((d) => d.severity == RuleSeverity.error),
    isEmpty,
    reason: '$diagnostics',
  );
  return rules;
}

void main() {
  late RuleProfile profile;
  setUp(() {
    profile = RuleProfileResolver.resolveBuiltin(overrideArchive()).profile!;
  });

  test('核心验收：条目只覆盖 prepared，档案的 slots / mode / ability 仍然生效', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: entry({
        'spellcasting': {'prepared': {'5': 9}},
      }),
      entryId: _entryId,
    );

    expect(merged.preparedLimit(5), 9, reason: '条目覆盖的列生效');
    expect(
      merged.preparedLimit(1),
      isNull,
      reason: '列级：该列由条目负责，1 级未声明 → 不借用档案（§3.12）',
    );
    expect(
      merged.spellSlots(5),
      {'1': 4, '2': 3, '3': 2},
      reason: 'slots 仍来自档案',
    );
    expect(merged.spellcastingMode, 'prepared', reason: 'mode 仍来自档案');
    expect(merged.spellcastingAbility, 'int', reason: 'ability 仍来自档案');
    expect(merged.cantripLimit(1), 3, reason: 'cantrips 仍来自档案');
    expect(merged.maxSpellLevel(3), 2, reason: 'maximumSpellLevel 仍来自档案');

    expect(
      merged.sourceOf(RuleFieldPath.spellcasting('prepared'))!.originId,
      _entryId,
    );
    expect(
      merged.sourceOf(RuleFieldPath.spellcasting('slots'))!.originId,
      kBuiltinOriginId,
    );
    expect(
      merged.sourceOf(RuleFieldPath.spellcasting('mode'))!.originId,
      kBuiltinOriginId,
    );
    expect(
      merged.sourceOf(RuleFieldPath.hitDie)!.originId,
      kBuiltinOriginId,
    );
  });

  test('条目声明 mode: none 时短路整个施法（slots 为空、能力为 null）', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: entry({
        'spellcasting': {'mode': 'none'},
      }),
      entryId: _entryId,
    );
    expect(merged.spellcastingMode, 'none');
    expect(merged.spellcastingAbility, isNull);
    expect(merged.spellSlots(5), isEmpty);
    expect(merged.preparedLimit(5), isNull);
    expect(
      merged.sourceOf(RuleFieldPath.spellcasting('mode'))!.originId,
      _entryId,
    );
    expect(
      merged.sourceOf(RuleFieldPath.spellcasting('slots'))!.originId,
      kBuiltinOriginId,
      reason: 'slots 列仍然来自档案——只是被 mode: none 短路',
    );
  });

  test('条目写全 9 列时全部来源都是条目', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'astral-knight',
      entryRules: entry({
        'spellcasting': {
          'mode': 'known',
          'ability': 'cha',
          'listTags': ['spell-list:astral'],
          'slots': {'5': {'1': 4, '2': 2}},
          'prepared': {'5': 6},
          'cantrips': {'5': 3},
          'maximumSpellLevel': {'5': 3},
        },
      }),
      entryId: _entryId,
    );
    for (final column in RuleFieldPath.spellcastingColumns) {
      final source = merged.sourceOf(RuleFieldPath.spellcasting(column));
      if (column == 'archetype' || column == 'slotLevel') {
        expect(source, isNull, reason: '$column 未声明 → 无来源');
        continue;
      }
      expect(source!.originId, _entryId, reason: column);
      expect(source.tier, kEntryTier, reason: column);
    }
    expect(merged.archetype, isNull, reason: '未声明 archetype，档案也没有 astral-knight');
  });

  test('显式 null 的 archetype 清空档案的列', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: entry({
        'spellcasting': {'archetype': null},
      }),
      entryId: _entryId,
    );
    expect(merged.archetype, isNull);
    expect(
      merged.sourceOf(RuleFieldPath.spellcasting('archetype'))!.originId,
      _entryId,
      reason: '显式 null 是"清空该列"，来源仍是条目',
    );
    // prepared / cantrips 是职业自己的列，与 archetype 无关，仍来自档案。
    expect(merged.preparedLimit(1), 4);
  });

  test('双方都没声明 spellcasting 时不产生 spellcasting 来源', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'astral-knight',
      entryRules: entry({'hitDie': 10}),
      entryId: _entryId,
    );
    expect(merged.spellcasting, isNull);
    expect(
      merged.fieldSources.keys.where((k) => k.startsWith('spellcasting.')),
      isEmpty,
    );
  });
}
```

同时改 `rule_profile_resolver_test.dart` 里"字段级合并"那条用例的注释与断言：`fieldSources.keys` 仍是 `{'hitDie','savingThrowAbilities'}`（双方都没声明 `spellcasting` / `resources`），**断言不变**，只把注释里的"字段级"改成"顶层字段 + 列级"并补一条 `spellcasting` 列级断言（可复用核心验收里的最小档案）。

- [ ] **步骤 3：跑测试确认失败**

```bash
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test/rules/spellcasting_column_merge_test.dart"
```

预期：`核心验收` 用例 FAIL（当前实现整块替换：条目只声明 `prepared` 时 `slots` / `mode` / `ability` 全丢，`spellSlots(5)` 为 `{}`，`spellcastingMode == 'none'`）。

- [ ] **步骤 4：实现列级合并**

在 `rule_profile_resolver.dart` 中把 `_mergeField<ClassSpellcasting>` 换成 `_mergeSpellcasting`，并抽出后续任务复用的两个私有件：

```dart
/// 一条参与合并的声明（本任务只有"条目"与"档案"两级）。
///
/// **这是脚手架**：任务 7 步骤 5 会把它整体换成
/// `RuleOverrideDeclaration`（`.package` / `.builtin` 两个命名构造）并删除本类。
/// 任务 8 起合并链上只允许存在 `RuleOverrideDeclaration` 一种声明类型。
class _OrderedDeclaration {
  const _OrderedDeclaration({
    required this.originId,
    required this.tier,
    required this.rules,
  });

  final String originId;
  final int tier;
  final ClassRuleSet rules;
}

/// 列级合并的**唯一**取值点。
///
/// [declarations] 必须已按优先级**从高到低**排好（排序的唯一实现在
/// `RuleOverrideOrder.effective`，本函数不排序）。
/// [declares] / [read] 都由调用点在**每个字段上写一次**：`declares` 判"这一列
/// 是否被该声明声明过"（列级判据的唯一入口），`read` 取该列的值。
/// 取"第一个声明过该列"的声明即生效值（**同 tier 的冲突登记在任务 8 加回**）；
/// 全都未声明 → 返回 `(value: null, originId: null)`。
_ColumnPick<T> _pickColumn<T>({
  required String field,
  required List<_OrderedDeclaration> declarations,
  required bool Function(ClassRuleSet rules) declares,
  required T? Function(ClassRuleSet rules) read,
  required Map<String, RuleFieldSource> sources,
}) {
  for (final declaration in declarations) {
    if (!declares(declaration.rules)) continue;
    _writeSource(sources, field, declaration.originId, declaration.tier);
    return _ColumnPick(
      value: read(declaration.rules),
      originId: declaration.originId,
    );
  }
  return const _ColumnPick(value: null, originId: null);
}

class _ColumnPick<T> {
  const _ColumnPick({required this.value, required this.originId});

  final T? value;
  final String? originId;
}

/// 来源写入的**唯一**出口（契约 §3.7）。字段路径必须来自 [RuleFieldPath]。
void _writeSource(
  Map<String, RuleFieldSource> sources,
  String field,
  String originId,
  int tier,
) {
  sources[field] = RuleFieldSource(field: field, originId: originId, tier: tier);
}

/// 条目 ∪ 档案的 `spellcasting` 列级合并（契约 §3.6）。
///
/// - 双方都没有 `spellcasting` → null（不产生来源）；
/// - 逐列取"高优先级且声明过该列"的一侧；
/// - 合并结果的 `fields` 是**声明列的并集**，供下游判断"该列是否未声明"；
/// - `mode` 的默认值 `none` 在**合并之后**落，缺省不算声明（否则条目只写
///   `prepared` 时会把档案的 `mode: prepared` 误压成 `none`）。
ClassSpellcasting? _mergeSpellcasting({
  required _OrderedDeclaration? entry,
  required _OrderedDeclaration? archive,
  required Map<String, RuleFieldSource> sources,
}) {
  final entryRules = entry?.rules.spellcasting;
  final archiveRules = archive?.rules.spellcasting;
  if (entryRules == null && archiveRules == null) return null;
  final declarations = <_OrderedDeclaration>[
    if (entry != null && entryRules != null) entry,
    if (archive != null && archiveRules != null) archive,
  ];
  // 供 declares/read 统一按"声明的字段集合"取值（不按值是否为 null）。
  ClassSpellcasting? spellcastingOf(ClassRuleSet rules) => rules.spellcasting;
  T? column<T>(String name, T? Function(ClassSpellcasting) read) => _pickColumn<T>(
    field: RuleFieldPath.spellcasting(name),
    declarations: declarations,
    declares: (rules) => spellcastingOf(rules)?.declares(name) ?? false,
    read: (rules) => read(spellcastingOf(rules)!),
    sources: sources,
  ).value;

  final fields = <String>{
    for (final declaration in declarations)
      ...?spellcastingOf(declaration.rules)?.fields,
  };
  return ClassSpellcasting(
    mode: column<String>('mode', (c) => c.mode) ?? 'none',
    ability: column<String>('ability', (c) => c.ability),
    listTags: column<List<String>>('listTags', (c) => c.listTags) ?? const [],
    archetype: column<String>('archetype', (c) => c.archetype),
    slots: column<SlotTable>('slots', (c) => c.slots),
    slotLevel: column<IntTable>('slotLevel', (c) => c.slotLevel),
    prepared: column<IntTable>('prepared', (c) => c.prepared),
    cantrips: column<IntTable>('cantrips', (c) => c.cantrips),
    maximumSpellLevel: column<IntTable>(
      'maximumSpellLevel',
      (c) => c.maximumSpellLevel,
    ),
    fields: fields,
  );
}
```

`resolveClassRules` 里改成：

```dart
static ResolvedClassRules resolveClassRules({
  required RuleProfile profile,
  required String slug,
  required ClassRuleSet? entryRules,
  String? entryId,
}) {
  final fromArchive = profile.classRules(slug);
  final entryOrigin = entryId ?? '<entry>';
  final sources = <String, RuleFieldSource>{};
  final entry = entryRules == null
      ? null
      : _OrderedDeclaration(originId: entryOrigin, tier: kEntryTier, rules: entryRules);
  final archive = fromArchive == null
      ? null
      : _OrderedDeclaration(originId: kBuiltinOriginId, tier: kBuiltinTier, rules: fromArchive);
  final ordered = <_OrderedDeclaration>[
    if (entry != null) entry,
    if (archive != null) archive,
  ];

  final spellcasting = _mergeSpellcasting(
    entry: entry,
    archive: archive,
    sources: sources,
  );
  return ResolvedClassRules(
    hitDie: _pickColumn<int>(
      field: RuleFieldPath.hitDie,
      declarations: ordered,
      declares: (rules) => rules.declares('hitDie'),
      read: (rules) => rules.hitDie,
      sources: sources,
    ).value,
    savingThrowAbilities: _pickColumn<Set<String>>(
      field: RuleFieldPath.savingThrowAbilities,
      declarations: ordered,
      declares: (rules) => rules.declares('savingThrowAbilities'),
      read: (rules) => rules.savingThrowAbilities,
      sources: sources,
    ).value ?? const {},
    spellcasting: spellcasting,
    // resources 在任务 3 换成按 id 的列级合并；本任务保持整块替换以免混两次行为变化。
    resources: ...（保持 _pickColumn<List<ClassResourceRule>> 的整块语义）,
    archetype: profile.progression(spellcasting?.archetype),
    fieldSources: sources,
    entryRules: entryRules,
    archiveRules: fromArchive,
  );
}
```

> **本任务刻意不动 `resources`**：`prepared` 的核心验收只需要 `spellcasting` 列级化。`resources` 的按 id 合并是任务 3，这样每个任务的失败测试集合最小、审查边界清晰。

- [ ] **步骤 5：跑测试确认通过**

```bash
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test/rules"
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib test"
```

预期：新增 5 条全绿；`test/rules` 全绿（`字段级合并` 那条用例的 `fieldSources.keys` 断言仍成立）；analyze 0 问题。

- [ ] **步骤 6：跑全量客户端测试（列级合并会波及消费方）**

```bash
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test"
```

预期：1237 通过 / 6 跳过（数量只增不减）。若有失败，**修调用方或明确记录行为变化**，不得靠放宽断言。

- [ ] **步骤 7：Commit**

```bash
git add apps/client_flutter/lib/src/features/rules/domain/rule_profile_resolver.dart \
        apps/client_flutter/test/rules/spellcasting_column_merge_test.dart \
        apps/client_flutter/test/rules/rule_profile_resolver_test.dart
git commit -m "feat(rules): spellcasting 改为列级合并

条目只声明 spellcasting.prepared 时，mode / ability / slots / cantrips /
maximumSpellLevel 仍按列回退内置档案；来源记录到列级（spellcasting.prepared）。
显式 null 是"清空该列"，与未声明区分。"
```

---

## 任务 3：`resources` 按 `id` 列级合并 + 补丁资源

**文件：**
- 修改：`apps/client_flutter/lib/src/features/rules/domain/class_rule_set.dart`
- 修改：`apps/client_flutter/lib/src/features/rules/domain/rule_profile_resolver.dart`
- 修改：`apps/client_flutter/lib/src/features/rules/domain/rule_profile.dart`
- 测试：`apps/client_flutter/test/rules/resource_column_merge_test.dart`（新建）
- 测试：`apps/client_flutter/test/rules/import_rule_diagnostics_test.dart`

- [ ] **步骤 1：写失败测试**

```dart
// test/rules/resource_column_merge_test.dart
import 'package:dnd_table_client/src/features/rules/domain/class_rule_set.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_diagnostic.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_field_path.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rule_profile_test_support.dart';

const _path = r'$.structured.classRules';
const _entryId = 'errata:class/barbarian';

void main() {
  late RuleProfile profile;
  setUp(() {
    // 与任务 2 共用同一份合成档案（含 barbarian 的 rage）。
    profile = RuleProfileResolver.resolveBuiltin(overrideArchive()).profile!;
  });

  ClassRuleSet entry(List<Object?> resources) {
    final diagnostics = <RuleDiagnostic>[];
    final rules = ClassRuleSet.parse({'resources': resources}, path: _path, diagnostics: diagnostics);
    expect(diagnostics.where((d) => d.severity == RuleSeverity.error), isEmpty, reason: '$diagnostics');
    return rules;
  }

  test('核心验收：同 id 只覆盖 recovery，name / maximum / startsAtLevel 仍来自档案', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'barbarian',
      entryRules: entry([
        {'id': 'rage', 'recovery': 'longRest'},
      ]),
      entryId: _entryId,
    );

    expect(merged.resources, hasLength(1));
    final rage = merged.resources.single;
    expect(rage.recoveryAt(1), 'longRest', reason: '条目覆盖的列');
    expect(rage.name, '狂暴', reason: 'name 来自档案');
    expect(
      rage.maximum!.resolve(level: 3, abilities: const {}),
      3,
      reason: 'maximum 来自档案',
    );
    expect(rage.startsAtLevel, 1, reason: 'startsAtLevel 来自档案');

    expect(
      merged.sourceOf(RuleFieldPath.resource('rage', 'recovery'))!.originId,
      _entryId,
    );
    expect(
      merged.sourceOf(RuleFieldPath.resource('rage', 'maximum'))!.originId,
      kBuiltinOriginId,
    );
    expect(
      merged.sourceOf(RuleFieldPath.resource('rage', 'name'))!.originId,
      kBuiltinOriginId,
    );
  });

  test('同 id 覆盖 maximum，档案的 recovery / startsAtLevel 保留', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'barbarian',
      entryRules: entry([
        {
          'id': 'rage',
          'maximum': 5,
        },
      ]),
      entryId: _entryId,
    );
    final rage = merged.resources.single;
    expect(rage.maximum!.resolve(level: 12, abilities: const {}), 5);
    expect(rage.recoveryAt(1), 'shortRestOne', reason: 'recovery 来自档案');
    expect(rage.name, '狂暴');
  });

  test('条目新增档案没有的资源必须自带 name 与 maximum', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'barbarian',
      entryRules: entry([
        {'id': 'storm-aura', 'name': '风暴灵光', 'maximum': {'formula': 'level'}},
      ]),
      entryId: _entryId,
    );
    expect(merged.resources, hasLength(2));
    final aura = merged.resources.singleWhere((r) => r.id == 'storm-aura');
    expect(aura.name, '风暴灵光');
    expect(
      merged.sourceOf(RuleFieldPath.resource('storm-aura', 'maximum'))!.originId,
      _entryId,
      reason: '档案里没有这个 id，两列都只能来自条目',
    );
    expect(
      merged.sourceOf(RuleFieldPath.resource('storm-aura', 'name'))!.originId,
      _entryId,
    );
  });

  test('补丁资源缺 name / maximum 且档案无同 id → 合并后 maximum 为空，运行期跳过', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'barbarian',
      entryRules: entry([
        {'id': 'storm-aura', 'recovery': 'longRest'},
      ]),
      entryId: _entryId,
    );
    // 运行期不产出"上限 0"的假资源（导入期已由 incompleteResourcePatch 拦住，
    // 这里的直连解析只是兜底路径）。
    expect(
      merged.resourcesAt(1, const {}).map((r) => r.id),
      isNot(contains('storm-aura')),
    );
  });

  test('resourcesAt 跳过合并后仍无 maximum 的资源，不产出假资源', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'barbarian',
      entryRules: entry([
        {'id': 'rage'},
      ]),
      entryId: _entryId,
    );
    // 档案补齐了 maximum，因此正常产出。
    expect(
      merged.resourcesAt(1, const {}).single.maximum,
      2,
    );
  });
}
```

导入期错误用例（追加到 `import_rule_diagnostics_test.dart` 的 classRules group）：

```dart
    test('补丁资源缺 name / maximum 且档案没有同 id → incompleteResourcePatch', () async {
      final report = await importer.previewJson(
        packageJson(
          entry: classEntry(
            slug: 'fighter', // 命中内置 slug，必须显式 classRules
            structured: {
              'classRules': {
                'resources': [
                  {'id': 'unknown-resource', 'recovery': 'shortRest'},
                ],
              },
            },
          ),
          id: 'patch-pack',
        ),
      );
      expect(report.valid, isFalse);
      final error = report.errors.singleWhere(
        (e) => e.path == r'$.entries[0].structured.classRules.resources[0].id',
      );
      expect(error.message, contains('incompleteResourcePatch'));
      expect(error.message, contains('unknown-resource'));
    });
```

- [ ] **步骤 2：跑测试确认失败**

```bash
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test/rules/resource_column_merge_test.dart"
```

预期：`ClassRuleSet.parse` 对 `{'id': 'rage', 'recovery': 'longRest'}` 报 `invalidMaxSpec`（缺 name），且 `ClassResourceRule.name` / `maximum` 尚不可空 → 编译失败。

- [ ] **步骤 3：`ClassResourceRule` 支持补丁形状**

```dart
class ClassResourceRule {
  const ClassResourceRule({
    required this.id,
    this.name,             // 补丁声明可省略，由低 tier 同 id 资源补齐
    required this.maximum, // 同上；改为 MaxSpec?（可空）
    this.recovery,
    this.recoveryTable,
    this.startsAtLevel = 1,
    this.description,
    this.fields = const {},
  });

  final String id;
  final String? name;
  final MaxSpec? maximum;
  // …其它字段不变…

  /// 声明过哪些列（列级合并的唯一判据）。
  final Set<String> fields;
  bool declares(String column) => fields.contains(column);

  /// 资源表声明到的最高等级；没有表（补丁 / 只有 formula）时不贡献等级。
  int? get declaredMaxLevel => maximum?.table?.maxLevel;
  int? get declaredMinLevel => maximum?.table?.minLevel;
}
```

`_parseResource` 的改动（**只放宽"缺省"，不放宽"类型错误"**）：

```dart
  // `id` 永远是必填；`name` / `maximum` 是列，补丁声明可以省略（由低 tier 补齐）。
  // 类型错误仍然报错，绝不静默。
  final id = '${raw['id'] ?? ''}'.trim();
  if (id.isEmpty) {
    _addError(diagnostics, itemPath, 'invalidMaxSpec', '资源缺少 id');
    return null;
  }
  if (!seen.add(id)) {
    _addError(diagnostics, '$itemPath.id', 'duplicateResourceId', '资源 id "$id" 重复');
    return null;
  }
  final rawName = raw['name'];
  String? name;
  if (raw['name'] != null) {
    if (rawName is! String || rawName.trim().isEmpty) {
      _addError(diagnostics, '$itemPath.name', 'invalidMaxSpec', 'name 必须是非空字符串');
      return null;
    }
    name = rawName.trim();
  }
  MaxSpec? maximum;
  if (raw.containsKey('maximum')) {
    maximum = MaxSpec.tryParse(raw['maximum']);
    if (maximum == null) {
      _addError(
        diagnostics,
        '$itemPath.maximum',
        'invalidMaxSpec',
        'maximum 必须且只能使用 value / formula / table 之一',
      );
      return null;
    }
  }
  // recovery / startsAtLevel / 公式属性键的既有校验一律保留（缺省不校验类型以外的语义）。
```

- [ ] **步骤 4：档案侧 fail-fast + 条目侧完整性校验**

`resolveBuiltin` 的 `_parseClasses` 之后补一条校验（档案是发布资产，缺 `name`/`maximum` 必须整包失败）：

```dart
  /// 档案资源必须自带 `name` 与 `maximum`（§3.4）：内置档案不是补丁，没有"低 tier
  /// 可补齐"这回事。报错码沿用 `invalidMaxSpec`，path 精确到列。
  static void _validateArchiveResources(
    Map<String, ClassRuleSet> classes,
    List<RuleDiagnostic> diagnostics,
  ) {
    classes.forEach((slug, rules) {
      for (var index = 0; index < rules.resources.length; index++) {
        final resource = rules.resources[index];
        final path = '\$.classes.$slug.resources[$index]';
        if (resource.name == null) {
          _invalidTable(diagnostics, '$path.name', '档案资源必须声明 name');
        }
        if (resource.maximum == null) {
          _invalidTable(diagnostics, '$path.maximum', '档案资源必须声明 maximum');
        }
      }
    });
  }
```

`validateEntryClassRules` 补"合并后完整性"（**这是补丁语义的唯一合法性判据**）：

```dart
    // 补丁资源：条目资源的 id 必须在档案里有同 id 资源，或自带 name + maximum。
    // 否则运行期拿不到可展示的名称或上限（静默产出"未声明资源"），必须阻断。
    final archiveById = <String, ClassResourceRule>{
      for (final resource in archiveRules?.resources ?? const <ClassResourceRule>[])
        resource.id: resource,
    };
    for (var index = 0; index < entryRules.resources.length; index++) {
      final resource = entryRules.resources[index];
      final base = archiveById[resource.id];
      final name = resource.name ?? base?.name;
      final maximum = resource.maximum ?? base?.maximum;
      if (name != null && maximum != null) continue;
      diagnostics.add(
        RuleDiagnostic(
          path: '$path.resources[$index].id',
          severity: RuleSeverity.error,
          code: 'incompleteResourcePatch',
          message:
              '资源 "${resource.id}" 是补丁声明（缺 ${[
                if (name == null) 'name',
                if (maximum == null) 'maximum',
              ].join(' / ')}），但内置档案没有同 id 资源可补齐',
        ),
      );
    }
```

`validateEntryClassRules` 的签名因此需要多一个可选参数（**带默认值**，既有调用点不变）：

```dart
  static void validateEntryClassRules({
    required RuleProfile profile,
    required ClassRuleSet? entryRules,
    required String path,
    required List<RuleDiagnostic> diagnostics,
    bool hasSpellChoiceIntent = false,
    ClassSpellcasting? archiveSpellcasting,
    ClassRuleSet? archiveRules, // 新增，可空
  })
```

并在 `content_package_importer.dart:1236` 的调用处补 `archiveRules: archiveRules,`（该函数里已经有 `archiveRules` 局部变量）。

- [ ] **步骤 5：实现 `_mergeResources`（按 id + 列级）**

```dart
  /// 条目 ∪ 档案的 `resources` 合并（契约 §3.4、§3.6）：**按 id 合**，同 id 再按列。
  ///
  /// - id 的出现顺序按"优先级从高到低"稳定排列（高 tier 新增的资源排在前面）；
  /// - 每条资源的每个列取"高优先级且声明过该列"的一侧；
  /// - 合并后 `name` / `maximum` 仍可能为 null：导入期已用
  ///   `incompleteResourcePatch` 拦住条目补丁，档案侧由 `_validateArchiveResources`
  ///   fail-fast。运行期 [ResolvedClassRules.resourcesAt] 对 null 采取"跳过"，
  ///   避免产出没有上限的假资源。
  static List<ClassResourceRule> _mergeResources({
    required List<RuleOverrideDeclaration> chain,
    required Map<String, RuleFieldSource> sources,
    required List<RuleOverrideConflict> conflicts,
  }) {
    final ids = <String>[];
    for (final declaration in chain) {
      for (final resource in declaration.rules.resources) {
        if (!ids.contains(resource.id)) ids.add(resource.id);
      }
    }
    ClassResourceRule? ruleOf(ClassRuleSet rules, String id) =>
        rules.resources.where((r) => r.id == id).firstOrNull;

    final merged = <ClassResourceRule>[];
    for (final id in ids) {
      T? column<T>(String name, T? Function(ClassResourceRule) read) =>
          _pickColumn<T>(
            field: RuleFieldPath.resource(id, name),
            declarations: chain,
            declares: (rules) => ruleOf(rules, id)?.declares(name) ?? false,
            read: (rules) => read(ruleOf(rules, id)!),
            sources: sources,
            conflicts: conflicts,
          ).value;

      // 常量形态与表形态是**同一条来源路径**（§3.4 的双表示歧义）：两者必须
      // 整体取同一侧，不能"常量取条目、表取档案"。这里当成一条记录类型的列。
      final recovery = _pickColumn<({String? constant, StringTable? table})>(
        field: RuleFieldPath.resource(id, 'recovery'),
        declarations: chain,
        declares: (rules) => ruleOf(rules, id)?.declares('recovery') ?? false,
        read: (rules) {
          final rule = ruleOf(rules, id)!;
          return (constant: rule.recovery, table: rule.recoveryTable);
        },
        sources: sources,
        conflicts: conflicts,
      ).value;

      merged.add(
        ClassResourceRule(
          id: id,
          name: column<String>('name', (r) => r.name),
          maximum: column<MaxSpec>('maximum', (r) => r.maximum),
          recovery: recovery?.constant,
          recoveryTable: recovery?.table,
          startsAtLevel:
              column<int>('startsAtLevel', (r) => r.startsAtLevel) ?? 1,
          // `description` 没有数值语义：取最高 tier 声明的非空值，**不记来源**。
          description: [
            for (final declaration in chain)
              if (ruleOf(declaration.rules, id)?.description
                  case final String description)
                description,
          ].firstOrNull,
          fields: <String>{
            for (final declaration in chain)
              ...?ruleOf(declaration.rules, id)?.fields,
          },
        ),
      );
    }
    return merged;
  }
```

**调用点**：`resolveClassRules` 里把任务 2 保留的
`resources: _pickColumn<List<ClassResourceRule>>(...)` 整块替换换成
`resources: _mergeResources(chain: ordered, sources: sources)`（本任务还没有
`conflicts` 参数；任务 8 再加）。**不允许**保留整块 `_pickColumn` 那条旧路径。

- [ ] **步骤 6：`resourcesAt` 兼容可空字段**

`rule_profile.dart`：

```dart
  List<ResolvedResource> resourcesAt(int level, Map<String, int> abilities) {
    final result = <ResolvedResource>[];
    for (final rule in resources) {
      if (level < rule.startsAtLevel) continue;
      // 补丁资源：导入期已保证合并后 name / maximum 非空（`incompleteResourcePatch`）；
      // 未导入的手工数据仍可能为空，此时按 §3.12 **跳过**，绝不产出"上限 0"的假资源。
      final maximum = rule.maximum;
      if (maximum == null) {
        assert(false, '资源 ${rule.id} 合并后仍无 maximum：应由导入期拦住');
        continue;
      }
      final value = maximum.resolve(level: level, abilities: abilities);
      if (value == null) continue;
      result.add(
        ResolvedResource(
          id: rule.id,
          name: rule.name ?? rule.id,
          maximum: value,
          recovery: rule.recoveryAt(level),
        ),
      );
    }
    return result;
  }
```

- [ ] **步骤 7：跑测试确认通过**

```bash
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test/rules"
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib test"
```

（第二条命令按「命令速查」的写法执行。）

预期：新增用例全绿；`import_rule_diagnostics_test.dart` 的 `incompleteResourcePatch` 用例转绿；`test/rules` 全绿。

- [ ] **步骤 8：跑全量客户端测试**

```bash
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test"
```

- [ ] **步骤 9：Commit**

```bash
git add apps/client_flutter/lib/src/features/rules/domain/class_rule_set.dart \
        apps/client_flutter/lib/src/features/rules/domain/rule_profile_resolver.dart \
        apps/client_flutter/lib/src/features/rules/domain/rule_profile.dart \
        apps/client_flutter/test/rules/resource_column_merge_test.dart \
        apps/client_flutter/test/rules/import_rule_diagnostics_test.dart
git commit -m "feat(rules): resources 按 id 列级合并，支持补丁资源

同 id 视为同一资源，可单列覆盖 name / maximum / recovery / startsAtLevel；
补丁资源可省略 name 与 maximum，由内置档案同 id 补齐，缺基础声明时导入报
incompleteResourcePatch（path 精确到资源 id）。"
```

---

## 任务 4：来源列级化（序列化 + 确定性排序 + `sourceOf`）

**文件：**
- 修改：`apps/client_flutter/lib/src/features/rules/domain/rule_profile.dart`
- 测试：`apps/client_flutter/test/rules/rule_field_sources_test.dart`（新建）

- [ ] **步骤 1：写失败测试**

```dart
// test/rules/rule_field_sources_test.dart
import 'package:dnd_table_client/src/features/rules/domain/rule_field_path.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuleFieldSource 序列化', () {
    test('往返不丢字段，未知 origin 原样保留', () {
      const source = RuleFieldSource(
        field: 'spellcasting.prepared',
        originId: 'errata-pack:class/wizard',
        tier: 140,
      );
      final json = source.toJson();
      expect(json, {
        'field': 'spellcasting.prepared',
        'originId': 'errata-pack:class/wizard',
        'tier': 140,
      });
      final restored = RuleFieldSource.fromJson(json);
      expect(restored.field, source.field);
      expect(restored.originId, source.originId);
      expect(restored.tier, source.tier);
    });

    test('坏数据返回 null（不抛异常、不静默造值）', () {
      expect(RuleFieldSource.fromJson({'field': '', 'originId': 'a'}), isNull);
      expect(
        RuleFieldSource.fromJson({
          'field': 'hitDie',
          'originId': '',
          'tier': 0,
        }),
        isNull,
      );
      expect(
        RuleFieldSource.fromJson({'field': 'hitDie', 'originId': 'a', 'tier': '0'}),
        isNull,
      );
    });
  });

  group('RuleFieldSourceMap', () {
    test('toData 按字段路径升序（持久化稳定，UI 不抖动）', () {
      final data = RuleFieldSourceMap.toData({
        RuleFieldPath.spellcasting('slots'): const RuleFieldSource(
          field: 'spellcasting.slots',
          originId: 'builtin:dnd5e-2024',
          tier: 0,
        ),
        RuleFieldPath.hitDie: const RuleFieldSource(
          field: 'hitDie',
          originId: 'builtin:dnd5e-2024',
          tier: 0,
        ),
        RuleFieldPath.spellcasting('prepared'): const RuleFieldSource(
          field: 'spellcasting.prepared',
          originId: 'x:class/wizard',
          tier: 100,
        ),
      });
      expect(data.keys.toList(), [
        'hitDie',
        'spellcasting.prepared',
        'spellcasting.slots',
      ]);
    });

    test('fromData 跳过坏条目而不是整块丢掉', () {
      final sources = RuleFieldSourceMap.fromData({
        'hitDie': {'field': 'hitDie', 'originId': 'builtin:dnd5e-2024', 'tier': 0},
        'broken': {'field': '', 'originId': ''},
      });
      expect(sources.keys, {'hitDie'});
    });
  });

  group('ResolvedClassRules.sourceOf', () {
    test('未声明该列时返回 null；资源列按完整路径查', () {
      const rules = ResolvedClassRules(
        fieldSources: {
          'resources.rage.maximum': RuleFieldSource(
            field: 'resources.rage.maximum',
            originId: 'builtin:dnd5e-2024',
            tier: 0,
          ),
        },
      );
      expect(rules.sourceOf('resources.rage.maximum')!.tier, 0);
      expect(rules.sourceOf('resources.rage.recovery'), isNull);
    });
  });
}
```

- [ ] **步骤 2：跑测试确认失败**

```bash
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test/rules/rule_field_sources_test.dart"
```

- [ ] **步骤 3：实现序列化与排序**

`rule_profile.dart`：

```dart
/// 某个字段 / 列最终取自哪里（阶段 S3 起粒度为**列**，字段路径见 [RuleFieldPath]）。
class RuleFieldSource {
  const RuleFieldSource({
    required this.field,
    required this.originId,
    required this.tier,
  });

  /// 列级字段路径，如 `hitDie` / `spellcasting.prepared` / `resources.rage.maximum`。
  /// 取值必须来自 `RuleFieldPath`（唯一实现），不得手拼。
  final String field;
  final String originId; // 'builtin:dnd5e-2024' 或条目 id
  final int tier; // 0 内置档案 / 100 + package.priority 包声明

  Map<String, Object?> toJson() => {
    'field': field,
    'originId': originId,
    'tier': tier,
  };

  /// 坏数据返回 null：来源是"附加信息"，读不回来时按"来源未知"处理，
  /// 绝不猜一个 originId（界面据此显示"来源未知"而不是"来自内置档案"）。
  static RuleFieldSource? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final field = '${raw['field'] ?? ''}'.trim();
    final originId = '${raw['originId'] ?? ''}'.trim();
    final tier = raw['tier'];
    if (field.isEmpty || originId.isEmpty || tier is! int) return null;
    return RuleFieldSource(field: field, originId: originId, tier: tier);
  }

  @override
  String toString() => 'RuleFieldSource($field ← $originId, tier $tier)';
}

/// 来源表的持久化与排序的**唯一**实现（角色数据 `data.classRuleSources`）。
abstract final class RuleFieldSourceMap {
  /// 按字段路径升序输出：同一角色每次派生的 JSON 键序一致，测试与 diff 稳定。
  static Map<String, Object?> toData(Map<String, RuleFieldSource> sources) {
    final keys = sources.keys.toList()..sort();
    return {
      for (final key in keys) key: sources[key]!.toJson(),
    };
  }

  static Map<String, RuleFieldSource> fromData(Object? raw) {
    if (raw is! Map) return const {};
    final result = <String, RuleFieldSource>{};
    for (final entry in raw.entries) {
      final source = RuleFieldSource.fromJson(entry.value);
      if (source != null) result['${entry.key}'] = source;
    }
    return result;
  }
}
```

`ResolvedClassRules` 增加读取口：

```dart
  /// 列级来源（契约 §3.7）。键是 [RuleFieldPath] 的字段路径。
  final Map<String, RuleFieldSource> fieldSources;

  /// 该列最终取自哪里；未声明 / 未记录时返回 null（**不猜**）。
  RuleFieldSource? sourceOf(String field) => fieldSources[field];

  /// 本条解析结果实际用到的来源 id（去重、排序）。UI 用它决定"是否发生了覆盖"：
  /// 只有内置档案 → 没有覆盖；出现非内置 id → 有覆盖。
  List<String> get activeOriginIds {
    final ids = {for (final source in fieldSources.values) source.originId};
    return ids.toList()..sort();
  }
```

- [ ] **步骤 4：跑测试确认通过 + 全量**

```bash
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test/rules"
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test"
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib test"
```

- [ ] **步骤 5：Commit**

```bash
git add apps/client_flutter/lib/src/features/rules/domain/rule_profile.dart \
        apps/client_flutter/test/rules/rule_field_sources_test.dart
git commit -m "feat(rules): 来源表支持列级序列化与确定性排序

RuleFieldSource 增加 toJson/fromJson，新增 RuleFieldSourceMap 作为持久化与
键序的唯一实现（按字段路径升序）；ResolvedClassRules 增加 sourceOf 与
activeOriginIds 两个读取口。"
```

---

## 任务 5：`classRules.mode: "patch" | "replace"`

**文件：**
- 修改：`apps/client_flutter/lib/src/features/rules/domain/class_rule_set.dart`
- 修改：`apps/client_flutter/lib/src/features/rules/domain/rule_profile_resolver.dart`
- 测试：`apps/client_flutter/test/rules/class_merge_mode_test.dart`（新建）
- 测试：`apps/client_flutter/test/rules/import_rule_diagnostics_test.dart`

- [ ] **步骤 1：写失败测试**

```dart
// test/rules/class_merge_mode_test.dart
import 'package:dnd_table_client/src/features/rules/domain/class_rule_set.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_diagnostic.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rule_profile_test_support.dart';

const _path = r'$.structured.classRules';

/// 归档测试用：`classRules.mode` 只接受 patch / replace。
void main() {
  late RuleProfile profile;
  setUp(() => profile = RuleProfileResolver.resolveBuiltin(overrideArchive()).profile!);

  ClassRuleSet entry(
    Map<String, Object?> classRules, {
    List<RuleDiagnostic>? out,
  }) => ClassRuleSet.parse(
    classRules,
    path: _path,
    diagnostics: out ?? <RuleDiagnostic>[],
  );

  test('patch（缺省）：条目未声明的列仍回退档案', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: entry({'hitDie': 6}),
      entryId: 'x:class/wizard',
    );
    expect(merged.hitDie, 6);
    expect(merged.savingThrowAbilities, {'int', 'wis'}, reason: '档案补齐');
    expect(merged.preparedLimit(1), 4, reason: '档案补齐 spellcasting 列');
  });

  test('replace：条目未声明的列一律"未声明"，不回退档案', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: entry({'mode': 'replace', 'hitDie': 6}),
      entryId: 'x:class/wizard',
    );
    expect(merged.hitDie, 6);
    expect(merged.savingThrowAbilities, isEmpty, reason: '未声明 → 空，不借用档案');
    expect(merged.spellcasting, isNull, reason: '未声明 → 无 spellcasting');
    expect(merged.resources, isEmpty);
    expect(merged.spellSlots(5), isEmpty);
    expect(merged.sourceOf('hitDie')!.originId, 'x:class/wizard');
    expect(merged.sourceOf('savingThrowAbilities'), isNull);
  });

  test('replace 仍然回退 archetype 之外的一切（原型来自档案，不被 replace 影响）', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: entry({
        'mode': 'replace',
        'spellcasting': {'mode': 'prepared', 'ability': 'int', 'archetype': 'full-caster'},
      }),
      entryId: 'x:class/wizard',
    );
    // 条目自己声明的 archetype 指向档案原型：原型是"跨职业共享模板"，
    // 不是 classRules 的列，replace 不屏蔽它（§3.1）。
    expect(merged.archetype!.name, 'full-caster');
    expect(merged.spellSlots(2), isNotEmpty);
  });

  test('未知 mode 值 → invalidMergeMode，path 精确', () {
    final diagnostics = <RuleDiagnostic>[];
    entry({'mode': 'merge'}, out: diagnostics);
    final error = diagnostics.singleWhere((d) => d.code == 'invalidMergeMode');
    expect(error.severity, RuleSeverity.error);
    expect(error.path, '$_path.mode');
    expect(error.message, contains('patch'));
    expect(error.message, contains('replace'));
  });

  test('把 spellcasting.mode 写到 classRules.mode 上不静默：报错并提示位置', () {
    final diagnostics = <RuleDiagnostic>[];
    entry({'mode': 'prepared'}, out: diagnostics);
    final error = diagnostics.singleWhere((d) => d.code == 'invalidMergeMode');
    expect(error.message, contains('spellcasting.mode'));
  });
}
```

- [ ] **步骤 2：跑测试确认失败**

```bash
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test/rules/class_merge_mode_test.dart"
```

预期：`mode` 目前是 `unknownField`（error），`invalidMergeMode` 用例找不到该 code → FAIL。

- [ ] **步骤 3：实现 `ClassMergeMode`**

`class_rule_set.dart`：

```dart
/// `classRules.mode`：该规则块相对**更低 tier** 的合并语义（契约 §3.8、S3）。
enum ClassMergeMode {
  /// 只覆盖自己声明过的列，未声明的列继续向下回退（**默认**）。
  patch,

  /// 自己就是该职业的全部真相：更低 tier（含内置档案）不再提供任何列，
  /// 未声明的列一律"未声明"。
  replace;

  static ClassMergeMode? tryParse(Object? raw) => switch (raw) {
    null => ClassMergeMode.patch,
    'patch' => ClassMergeMode.patch,
    'replace' => ClassMergeMode.replace,
    _ => null,
  };
}

const kClassRuleFields = {
  'mode',
  'hitDie',
  'savingThrowAbilities',
  'spellcasting',
  'resources',
};
```

`ClassRuleSet` 增加 `final ClassMergeMode mode;`（默认 `ClassMergeMode.patch`），`parse` 里：

```dart
    final mode = ClassMergeMode.tryParse(raw['mode']);
    if (mode == null) {
      _addError(
        diagnostics,
        '$path.mode',
        'invalidMergeMode',
        'classRules.mode 只接受 patch / replace；若想声明法术选择模型，'
        '请写在 spellcasting.mode（prepared / known / none）',
      );
    }
```

`parse` 的返回值用 `mode: mode ?? ClassMergeMode.patch`（错误已经报出，形状仍可继续解析）。

- [ ] **步骤 4：`replace` 在合并里截断更低 tier**

`rule_profile_resolver.dart`：把 `ordered` 构造成"按 tier 从高到低、遇 `replace` 截断"的列表。**这一步的排序逻辑在任务 7 抽到 `RuleOverrideOrder.ordered`；本任务先在本文件内实现一个私有版本**，任务 7 再把它移出并让两边共用（届时删除私有版本，避免第二处排序）。

```dart
  /// 有序声明（高 → 低），并在遇到第一条 `mode: replace` 时**截断**：
  /// 更低 tier 不再参与任何列的合并（契约 S3）。返回的列表里包含那条 replace。
  static List<_OrderedDeclaration> _orderedDeclarations(
    List<_OrderedDeclaration> declarations,
  ) {
    final sorted = [...declarations]
      ..sort((a, b) {
        final byTier = b.tier.compareTo(a.tier);
        if (byTier != 0) return byTier;
        final byMode = a.rules.mode.index.compareTo(b.rules.mode.index);
        if (byMode != 0) return byMode;
        return a.originId.compareTo(b.originId);
      });
    final result = <_OrderedDeclaration>[];
    for (final declaration in sorted) {
      result.add(declaration);
      if (declaration.rules.mode == ClassMergeMode.replace) break;
    }
    return result;
  }
```

> 注意：`_pickColumn` 里那句"低 tier 只是被覆盖，直接 `break`"要改成**继续遍历**——因为 `replace` 截断已经在有序化时完成，`_pickColumn` 只需"取第一个声明了该列的高优先级声明"，并在**同 tier** 时登记冲突（任务 8）。本任务先把 `_pickColumn` 的循环改成"取第一个声明该列的声明后 `break`"（去掉原草稿里的同 tier 判断），冲突登记在任务 8 加回。

- [ ] **步骤 5：跑测试确认通过 + 全量**

```bash
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test/rules"
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test"
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib test"
```

- [ ] **步骤 6：Commit**

```bash
git add apps/client_flutter/lib/src/features/rules/domain/class_rule_set.dart \
        apps/client_flutter/lib/src/features/rules/domain/rule_profile_resolver.dart \
        apps/client_flutter/test/rules/class_merge_mode_test.dart \
        apps/client_flutter/test/rules/import_rule_diagnostics_test.dart
git commit -m "feat(rules): 支持 classRules.mode 的 patch / replace 声明

patch 为默认（未声明列继续回退）；replace 声明后更低 tier 不再提供任何列，
未声明列一律按未声明处理。非法值在解析期报 invalidMergeMode，并提示
spellcasting.mode 才是法术选择模型的位置。"
```

---

## 任务 6：`priority`（manifest + Drift 13→14 迁移 + 仓库）

**文件：**
- 修改：`apps/client_flutter/lib/src/features/content/domain/content_package_manifest.dart`
- 修改：`apps/client_flutter/lib/src/features/content/domain/content_import_report.dart`
- 修改：`apps/client_flutter/lib/src/features/content/data/import/content_package_importer.dart`
- 修改：`apps/client_flutter/lib/src/features/content/data/local/content_tables.dart`
- 修改：`apps/client_flutter/lib/src/core/database/app_database.dart`
- 修改：`apps/client_flutter/lib/src/features/content/data/local/content_repository.dart`
- 测试：`apps/client_flutter/test/app_database_test.dart`
- 测试：`apps/client_flutter/test/package_priority_migration_test.dart`（新建，`test/` 根目录）
- 测试：`apps/client_flutter/test/rules/import_rule_diagnostics_test.dart`

- [ ] **步骤 1：写失败测试**

```dart
// test/package_priority_migration_test.dart
import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('v13 → v14 给 local_content_packages 增加 priority，既有包取默认 0', () async {
    final sqlite = sqlite3.openInMemory();
    sqlite
      ..execute('''
        CREATE TABLE local_content_packages (
          id TEXT PRIMARY KEY NOT NULL,
          format_version INTEGER NOT NULL,
          name TEXT NOT NULL,
          version TEXT NOT NULL,
          locale TEXT NOT NULL,
          system TEXT NOT NULL,
          entry_count INTEGER NOT NULL,
          content_hash TEXT NOT NULL,
          enabled INTEGER NOT NULL DEFAULT 1,
          installed_at INTEGER NOT NULL
        )
      ''')
      ..execute(
        "INSERT INTO local_content_packages VALUES "
        "('phb-2024-v2', 3, 'PHB 2024', '2.0.0', 'zh-CN', 'dnd5e-2024', 1106, "
        "'hash', 1, 0)",
      )
      ..execute('PRAGMA user_version = 13');

    final database = AppDatabase.forTesting(NativeDatabase.opened(sqlite));
    final rows = await database.select(database.localContentPackages).get();

    // 向后兼容：老存档打开后包还在、enabled 不变、priority 取 0（= tier 100，
    // 与升级前"包声明固定 tier 100"完全一致，数值不变）。
    expect(rows.single.id, 'phb-2024-v2');
    expect(rows.single.enabled, isTrue);
    expect(rows.single.entryCount, 1106);
    expect(rows.single.priority, 0);
    await database.close();
  });

  test('priority 可写入并读回', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await database
        .into(database.localContentPackages)
        .insert(
          LocalContentPackagesCompanion.insert(
            id: 'errata',
            formatVersion: 3,
            name: '勘误',
            version: '1.0.0',
            locale: 'zh-CN',
            system: 'dnd5e-2024',
            entryCount: 1,
            contentHash: 'hash',
            installedAt: DateTime(2026, 9, 12),
            priority: const Value(40),
          ),
        );
    final row = await (database.select(
      database.localContentPackages,
    )..where((t) => t.id.equals('errata'))).getSingle();
    expect(row.priority, 40);
    await database.close();
  });
}
```

导入期用例（追加到 `import_rule_diagnostics_test.dart`）：

```dart
  group('priority', () {
    test('缺省 0，合法整数通过', () async {
      final report = await importer.previewJson(
        packageJson(entry: classEntry(structured: {'classRules': {'hitDie': 8}}), priority: 30),
      );
      expect(report.valid, isTrue, reason: '${report.errors}');
      expect(report.priority, 30);
      final absent = await importer.previewJson(
        packageJson(entry: classEntry(structured: {'classRules': {'hitDie': 8}})),
      );
      expect(absent.priority, 0);
    });

    test('非整数 / 负数 / 越界 → invalidPriority，path 精确到 $.priority', () async {
      for (final bad in <Object?>['30', -1, 1.5, 1001]) {
        final report = await importer.previewJson(
          packageJson(
            entry: classEntry(structured: {'classRules': {'hitDie': 8}}),
            priority: bad,
          ),
        );
        expect(report.valid, isFalse, reason: '$bad');
        final error = report.errors.singleWhere((e) => e.path == r'$.priority');
        expect(error.message, contains('invalidPriority'));
      }
    });
  });
```

（`packageJson` 需要加 `Object? priority` 参数并放进包级 JSON。）

- [ ] **步骤 2：跑测试确认失败**

```bash
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test/package_priority_migration_test.dart"
```

- [ ] **步骤 3：Drift 表、版本与迁移**

`content_tables.dart`：

```dart
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  /// 规则声明的优先级（S3）：0..1000，缺省 0。
  /// 生效 tier = kEntryTier(100) + priority；缺省 0 ⇒ 与引入 priority 之前的
  /// "包声明固定 tier 100"完全一致（行为不变）。
  IntColumn get priority => integer().withDefault(const Constant(0))();
  DateTimeColumn get installedAt => dateTime()();
```

`app_database.dart`：

```dart
  @override
  int get schemaVersion => 14;
```

并在 migration 末尾追加：

```dart
      if (from >= 2 && from < 14) {
        // Schema v14: local_content_packages.priority（S3 规则覆盖优先级）。
        // 默认 0，老包升级后 tier 仍是 100，任何角色数值都不变。
        // `from >= 2` 是必需的：from < 2 时上面的 createTable 已经按**当前**
        // schema 建表（含 priority），再加一次会重复列。
        await m.addColumn(localContentPackages, localContentPackages.priority);
      }
```

`app_database_test.dart`：`expect(database.schemaVersion, 13)` → `14`。

- [ ] **步骤 4：manifest / report / importer / repository 串起 priority**

`content_package_manifest.dart`：

```dart
  const ContentPackageManifest({
    required this.formatVersion,
    // …既有…
    this.priority = 0,
    this.contentHash = '',
  });

  /// 规则覆盖优先级（0..1000）。缺省 0 = 与引入前行为一致。
  final int priority;

  // fromJson：priority 缺失 → 0；类型不对 → 抛 FormatException（导入器另有精确 path 校验）
  // toJson：priority 始终写出（0 也写，保证 manifest 往返自洽）
  // copyWith：增加 `int? priority`
```

`content_import_report.dart`：

```dart
  /// 规则覆盖优先级（0..1000）。缺省 0，既有构造点不受影响。
  final int priority;
  /// class 条目的列级来源摘要（键 = 条目 id）。缺省空 Map。
  final Map<String, List<RuleFieldSource>> classRuleSources;
```

（构造器里都给默认值：`this.priority = 0`、`this.classRuleSources = const {}`。）

`content_package_importer.dart`：
- `previewJson` 里紧挨 `formatVersion` 校验之后加：

```dart
    // 规则覆盖优先级（S3）：整数 0..1000，缺省 0。非整数不静默取默认值——
    // 那会让"写了 '30' 的包"以为自己的勘误生效了，实际排在内置之后。
    final rawPriority = json['priority'];
    var priority = 0;
    if (rawPriority != null) {
      if (rawPriority is! int || rawPriority < 0 || rawPriority > 1000) {
        errors.add(
          const ContentValidationError(
            path: r'$.priority',
            message: 'priority 必须是 0..1000 的整数，缺省为 0（invalidPriority）',
          ),
        );
      } else {
        priority = rawPriority;
      }
    }
```
- `_buildReport` 增加 `required int priority` 并透传到 `ContentImportReport`；`previewJson` / `previewDndPack` 两个调用点都传。
- `importReport` 构造 manifest 时传 `priority: report.priority`。

`content_repository.dart`：
- `LocalContentPackagesCompanion.insert(...)` 两处（约 279-294 与 389 附近）加 `priority: Value(manifest.priority),`
- `_mapPackage`（约 886 行）加 `priority: row.priority,`
- 新增：

```dart
  /// 每个已安装包的规则覆盖优先级（S3）。键 = packageId。
  /// 只读投影，供 `RuleOverrideIndex` 构建使用；UI 不直接查库。
  Future<Map<String, int>> packagePriorities() async {
    final rows = await db.select(db.localContentPackages).get();
    return {for (final row in rows) row.id: row.priority};
  }
```

（`MemoryContentRepository`（测试替身）也要实现该方法：返回 `const {}`。）

- [ ] **步骤 5：跑测试确认通过**

```bash
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test/package_priority_migration_test.dart test/app_database_test.dart test/rules/import_rule_diagnostics_test.dart"
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test"
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib test"
```

预期：新迁移测试全绿；`app_database_test.dart` 的 13→14 断言通过；全量通过。

- [ ] **步骤 6：Commit**

```bash
git add apps/client_flutter/lib/src/features/content/domain/content_package_manifest.dart \
        apps/client_flutter/lib/src/features/content/domain/content_import_report.dart \
        apps/client_flutter/lib/src/features/content/data/import/content_package_importer.dart \
        apps/client_flutter/lib/src/features/content/data/local/content_tables.dart \
        apps/client_flutter/lib/src/features/content/data/local/content_repository.dart \
        apps/client_flutter/lib/src/core/database/app_database.dart \
        apps/client_flutter/test/app_database_test.dart \
        apps/client_flutter/test/package_priority_migration_test.dart \
        apps/client_flutter/test/rules/import_rule_diagnostics_test.dart
git commit -m "feat(content): 包级 priority 与 Drift schemaVersion 14 迁移

manifest 增加 priority（0..1000，缺省 0），非整数/越界在导入期报
invalidPriority（path 精确到 $.priority）；local_content_packages 增加
priority 列，从 v13 迁移时默认 0 —— 老包 tier 仍为 100，角色数值不变。"
```

---

## 任务 7：声明 / 排序 / 索引值对象（纯新增）

**文件：**
- 创建：`apps/client_flutter/lib/src/features/rules/domain/rule_override_declaration.dart`
- 创建：`apps/client_flutter/lib/src/features/rules/domain/rule_override_priority.dart`
- 创建：`apps/client_flutter/lib/src/features/characters/domain/rule_override_index.dart`
- 测试：`apps/client_flutter/test/rules/rule_override_priority_test.dart`（新建）

- [ ] **步骤 1：写失败测试**

```dart
// test/rules/rule_override_priority_test.dart
import 'package:dnd_table_client/src/features/characters/domain/rule_override_index.dart';
import 'package:dnd_table_client/src/features/content/domain/content_block.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/rules/domain/class_rule_set.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_diagnostic.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_override_declaration.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_override_priority.dart';
import 'package:flutter_test/flutter_test.dart';

const _path = r'$.structured.classRules';

ClassRuleSet rulesOf(Map<String, Object?> raw) => ClassRuleSet.parse(
  raw,
  path: _path,
  diagnostics: <RuleDiagnostic>[],
);

RuleOverrideDeclaration declaration({
  required String originId,
  int priority = 0,
  Map<String, Object?> rules = const {'hitDie': 8},
  String? entryId,
  bool replace = false,
}) => RuleOverrideDeclaration.package(
  originId: originId,
  packageId: originId.split(':').first,
  priority: priority,
  entryId: entryId ?? originId,
  rules: rulesOf({if (replace) 'mode': 'replace', ...rules}),
);

void main() {
  group('RuleOverrideOrder.ordered', () {
    test('tier 降序：priority 高的包排在前面', () {
      final ordered = RuleOverrideOrder.ordered([
        declaration(originId: 'low:class/wizard', priority: 0),
        declaration(originId: 'high:class/wizard', priority: 50),
      ]);
      expect(ordered.map((d) => d.originId), [
        'high:class/wizard',
        'low:class/wizard',
      ]);
      expect(ordered.first.tier, kEntryTier + 50);
      expect(ordered.last.tier, kEntryTier);
    });

    test('同 tier：replace 排在 patch 之前', () {
      final ordered = RuleOverrideOrder.ordered([
        declaration(originId: 'a:class/wizard'),
        declaration(originId: 'b:class/wizard', replace: true),
      ]);
      expect(ordered.first.originId, 'b:class/wizard');
    });

    test('同 tier 同 mode：角色自己的条目排在别的包之前', () {
      final ordered = RuleOverrideOrder.ordered([
        declaration(originId: 'other:class/wizard'),
        declaration(originId: 'mine:class/wizard'),
      ], characterEntryId: 'mine:class/wizard');
      expect(ordered.first.originId, 'mine:class/wizard');
    });

    test('其余同 tier 按 originId 升序（结果可复现，不依赖 Map 迭代序）', () {
      final ordered = RuleOverrideOrder.ordered([
        declaration(originId: 'zeta:class/wizard'),
        declaration(originId: 'alpha:class/wizard'),
      ]);
      expect(ordered.map((d) => d.originId), [
        'alpha:class/wizard',
        'zeta:class/wizard',
      ]);
    });

    test('默认 priority 0 的声明 tier 就是 100（行为不变）', () {
      expect(declaration(originId: 'x:class/wizard').tier, kEntryTier);
    });
  });

  group('RuleOverrideIndex', () {
    ContentEntry classEntry(String id, String name) => ContentEntry(
      id: id,
      type: 'class',
      slug: name.toLowerCase(),
      name: name,
      body: const <ContentBlock>[],
      revision: 1,
      structured: const {'classRules': {'hitDie': 8}},
    );

    test('按对齐键（条目 id 末段）分组，排除角色自己那条', () {
      final index = RuleOverrideIndex.fromEntries([
        classEntry('base:class/wizard', 'Wizard'),
        classEntry('errata:class/wizard', 'Wizard Errata'),
        classEntry('other:class/fighter', 'Fighter'),
      ], const {'errata': 40});

      final wizard = index.declarationsFor(
        'wizard',
        excludeEntryId: 'base:class/wizard',
      );
      expect(wizard, hasLength(1));
      expect(wizard.single.originId, 'errata:class/wizard');
      expect(wizard.single.tier, kEntryTier + 40);
      expect(index.declarationsFor('fighter'), hasLength(1));
      expect(index.declarationsFor('barbarian'), isEmpty);
    });

    test('非 class 条目与未声明 classRules 的条目不参与', () {
      final index = RuleOverrideIndex.fromEntries([
        ContentEntry(
          id: 'p:spell/fireball',
          type: 'spell',
          slug: 'fireball',
          name: 'F',
          body: const <ContentBlock>[],
          revision: 1,
        ),
        ContentEntry(
          id: 'p:class/naked',
          type: 'class',
          slug: 'naked',
          name: 'N',
          body: const <ContentBlock>[],
          revision: 1,
        ),
      ], const {});
      expect(index.declarationsFor('naked'), isEmpty);
    });

    test('packageIdOf 取 id 前缀（缺失时返回空串）', () {
      expect(
        RuleOverrideDeclaration.packageIdOf('phb-2024:class/wizard'),
        'phb-2024',
      );
      expect(RuleOverrideDeclaration.packageIdOf('wizard'), '');
    });
  });
}
```

- [ ] **步骤 2：跑测试确认失败**

```bash
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test/rules/rule_override_priority_test.dart"
```

- [ ] **步骤 3：实现三个值对象**

```dart
// rule_override_declaration.dart
import 'class_rule_set.dart';
import 'rule_profile.dart';

/// 一条参与职业规则合并的声明（契约 S3）。
///
/// **这是合并链上唯一的声明类型**（解析器不再有第二套 `_OrderedDeclaration`）：
/// - [RuleOverrideDeclaration.package]：角色自己的职业条目与别的包的补丁 / 勘误条目，
///   `tier == kEntryTier + priority`（缺省 priority 0 ⇒ tier 恒为 100，行为不变）；
/// - [RuleOverrideDeclaration.builtin]：内置档案，`tier == kBuiltinTier`（0）。
class RuleOverrideDeclaration {
  const RuleOverrideDeclaration._({
    required this.originId,
    required this.packageId,
    required this.priority,
    required this.tier,
    required this.rules,
    this.entryId,
  });

  /// 包声明。
  factory RuleOverrideDeclaration.package({
    required String originId,
    required String packageId,
    required ClassRuleSet rules,
    int priority = 0,
    String? entryId,
  }) => RuleOverrideDeclaration._(
    originId: originId,
    packageId: packageId,
    priority: priority,
    tier: kEntryTier + priority,
    rules: rules,
    entryId: entryId,
  );

  /// 内置档案（tier 0 的基准）。`priority` 固定为 [kBuiltinTier] -
  /// [kEntryTier]（负数）只是为了字段可读，**排序只看 [tier]**。
  factory RuleOverrideDeclaration.builtin(ClassRuleSet rules) =>
      RuleOverrideDeclaration._(
        originId: kBuiltinOriginId,
        packageId: '',
        priority: kBuiltinTier - kEntryTier,
        tier: kBuiltinTier,
        rules: rules,
        entryId: null,
      );

  /// 条目 id（如 `errata:class/wizard`）或 [kBuiltinOriginId]。
  final String originId;

  /// 条目所属包 id（[RuleOverrideDeclaration.packageIdOf]），用于"关闭整个包的覆盖"；
  /// 内置档案为空串。
  final String packageId;

  /// 包声明的 priority（0..1000）。内置档案为负数，不参与展示。
  final int priority;

  /// 生效 tier。**唯一排序键**：包声明 = [kEntryTier] + priority；内置 = [kBuiltinTier]。
  final int tier;

  /// `structured.classRules` 解析结果（含 `mode`）。
  final ClassRuleSet rules;

  /// 便于排序时判断"这是角色自己那条"。
  final String? entryId;

  /// 条目 id 前缀里的包 id（`<packageId>:<type>/<slug>` → `<packageId>`）；
  /// 没有 `:` 时返回空串。**唯一实现**：索引、解析器、UI 都调这里，
  /// 不各自 `split(':')`。
  static String packageIdOf(String entryId) {
    final index = entryId.indexOf(':');
    return index <= 0 ? '' : entryId.substring(0, index);
  }
}
```

```dart
// rule_override_priority.dart
import 'class_rule_set.dart';
import 'rule_override_declaration.dart';

/// 优先级排序的**唯一**实现（契约 S3）。
///
/// 顺序（从高到低）：
/// 1. `tier` 降序（内置档案 tier 0 永远最后）；
/// 2. 同 tier：`replace` 先于 `patch`（更强的语义先落，避免"胜负取决于 id 字母序"）；
/// 3. 同 tier 同 mode：[characterEntryId] 命中的那条优先（角色自己的职业条目）；
/// 4. 其余同 tier：`originId` 升序 —— 结果可复现，不依赖 Map 迭代序。
abstract final class RuleOverrideOrder {
  static List<RuleOverrideDeclaration> ordered(
    Iterable<RuleOverrideDeclaration> declarations, {
    String? characterEntryId,
  }) {
    final sorted = [...declarations]
      ..sort((a, b) {
        final byTier = b.tier.compareTo(a.tier);
        if (byTier != 0) return byTier;
        final byMode = a.rules.mode.index.compareTo(b.rules.mode.index);
        if (byMode != 0) return byMode;
        if (characterEntryId != null) {
          final aOwn = a.entryId == characterEntryId ? 0 : 1;
          final bOwn = b.entryId == characterEntryId ? 0 : 1;
          if (aOwn != bOwn) return aOwn - bOwn;
        }
        return a.originId.compareTo(b.originId);
      });
    return List<RuleOverrideDeclaration>.unmodifiable(sorted);
  }

  /// `replace` 截断：在 [ordered] 的结果上，第一条 `mode: replace` 之后的声明
  /// 全部丢弃（更低 tier 不再提供任何列）。
  static List<RuleOverrideDeclaration> effective(
    Iterable<RuleOverrideDeclaration> declarations, {
    String? characterEntryId,
  }) {
    final result = <RuleOverrideDeclaration>[];
    for (final declaration in ordered(
      declarations,
      characterEntryId: characterEntryId,
    )) {
      result.add(declaration);
      if (declaration.rules.mode == ClassMergeMode.replace) break;
    }
    return List<RuleOverrideDeclaration>.unmodifiable(result);
  }
}
```

```dart
// characters/domain/rule_override_index.dart
import '../../content/domain/content_entry.dart';
import '../../rules/domain/class_rule_set.dart';
import '../../rules/domain/rule_diagnostic.dart';
import '../../rules/domain/rule_override_declaration.dart';
import '../../rules/domain/rule_override_priority.dart';

/// 跨包职业规则声明的索引（契约 S3）。
///
/// 按**对齐键**（条目 id 末段，与 `Dnd5eRules.resolveClassSlug` 同一口径）分组，
/// 让"一条只改 spellcasting.prepared 的勘误"能作用于**已指向别的包条目**的角色。
///
/// 只含"有 `structured.classRules` 的 `type: class` 条目"；未声明规则块的条目
/// 不参与（导入期已用 `builtinSlugRequiresExplicitRules` / `unresolvedClassRule`
/// 处理过它们）。
class RuleOverrideIndex {
  const RuleOverrideIndex(this._bySlug);

  static const empty = RuleOverrideIndex(<String, List<RuleOverrideDeclaration>>{});

  final Map<String, List<RuleOverrideDeclaration>> _bySlug;

  /// 唯一构建点。[packagePriorities] 键 = packageId，缺省 0。
  static RuleOverrideIndex fromEntries(
    Iterable<ContentEntry> entries,
    Map<String, int> packagePriorities,
  ) {
    final bySlug = <String, List<RuleOverrideDeclaration>>{};
    for (final entry in entries) {
      if (entry.type != 'class') continue;
      final raw = entry.structured['classRules'];
      if (raw is! Map) continue;
      final slug = _alignmentKeyOf(entry.id);
      if (slug.isEmpty) continue;
      final rules = ClassRuleSet.parse(
        Map<String, Object?>.from(raw),
        path: r'$.structured.classRules',
        diagnostics: <RuleDiagnostic>[],
        abilities: kDefaultAbilities,
      );
      final packageId = RuleOverrideDeclaration.packageIdOf(entry.id);
      (bySlug[slug] ??= <RuleOverrideDeclaration>[]).add(
        RuleOverrideDeclaration(
          originId: entry.id,
          packageId: packageId,
          priority: packagePriorities[packageId] ?? 0,
          rules: rules,
          entryId: entry.id,
        ),
      );
    }
    return RuleOverrideIndex(bySlug);
  }

  /// 该对齐键上的**其它**包声明（已按优先级从高到低排好、已做 `replace` 截断）。
  List<RuleOverrideDeclaration> declarationsFor(
    String slug, {
    String? excludeEntryId,
  }) {
    final all = _bySlug[slug.trim().toLowerCase()] ?? const [];
    return RuleOverrideOrder.effective(
      all.where((d) => d.originId != excludeEntryId),
      characterEntryId: excludeEntryId,
    );
  }

  /// 对齐键 = 条目 id 末段（与运行期继承内置数值的键**同源**）。
  static String _alignmentKeyOf(String entryId) {
    final segments = entryId.split('/');
    return segments.isEmpty ? '' : segments.last.trim().toLowerCase();
  }
}
```

> **注意**：`fromEntries` 里调用 `ClassRuleSet.parse` 会丢弃诊断（`diagnostics: []`）。这是刻意的——运行期索引不重复导入期的校验（导入期已经把坏声明挡在库外），且索引构建必须无副作用。**但 parse 必须能容忍坏数据**：因此实现时对 `parse` 抛异常的情况加 `try/catch` 跳过该条目（`parse` 现在不抛，只是防御）。

- [ ] **步骤 4：跑测试确认通过**

```bash
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test/rules/rule_override_priority_test.dart"
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib test"
```

- [ ] **步骤 5：把脚手架的排序与声明类型收敛到唯一实现**

两步都是**等价替换**，`test/rules` 必须保持全绿：

1. 删除 `rule_profile_resolver.dart` 里的私有 `_orderedDeclarations`（任务 5 引入），
   改成调用 `RuleOverrideOrder.effective(...)`；
2. 删除私有类 `_OrderedDeclaration`（任务 2 引入），全部换成
   `RuleOverrideDeclaration`：条目 / 包声明用 `.package`，内置档案用 `.builtin`，
   `_pickColumn` / `_mergeSpellcasting` / `_mergeResources` 的参数类型随之改成
   `List<RuleOverrideDeclaration>`。

验收：`grep -rn "_OrderedDeclaration\|_orderedDeclarations" apps/client_flutter/lib` 无输出。

- [ ] **步骤 6：Commit**

```bash
git add apps/client_flutter/lib/src/features/rules/domain/rule_override_declaration.dart \
        apps/client_flutter/lib/src/features/rules/domain/rule_override_priority.dart \
        apps/client_flutter/lib/src/features/characters/domain/rule_override_index.dart \
        apps/client_flutter/lib/src/features/rules/domain/rule_profile_resolver.dart \
        apps/client_flutter/test/rules/rule_override_priority_test.dart
git commit -m "feat(rules): 增加跨包规则声明、优先级排序与索引

tier = 0（内置）/ 100 + priority（包）；同 tier 按 replace 优先、角色自己的
条目优先、originId 升序，结果可复现。RuleOverrideIndex 按条目 id 末段分组，
让勘误声明能作用于已指向别的包条目的角色。同时把任务 2/3 引入的
_OrderedDeclaration 脚手架与私有排序收敛到 RuleOverrideDeclaration +
RuleOverrideOrder 这一套唯一实现。"
```

---

## 任务 8：多声明合并 + 冲突记录 + 派生接线

**文件：**
- 创建：`apps/client_flutter/lib/src/features/rules/domain/rule_override_conflict.dart`
- 修改：`apps/client_flutter/lib/src/features/rules/domain/rule_profile_resolver.dart`
- 修改：`apps/client_flutter/lib/src/features/rules/domain/rule_profile.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/domain/dnd5e_rules.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/domain/rules_driven_character_builder.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/domain/character_rule_projector.dart`
- 测试：`apps/client_flutter/test/rules/rule_override_conflict_test.dart`（新建）

- [ ] **步骤 1：写失败测试**

```dart
// test/rules/rule_override_conflict_test.dart
import 'package:dnd_table_client/src/features/rules/domain/class_rule_set.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_diagnostic.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_override_declaration.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rule_profile_test_support.dart';

const _path = r'$.structured.classRules';

ClassRuleSet rulesOf(Map<String, Object?> raw) => ClassRuleSet.parse(
  raw,
  path: _path,
  diagnostics: <RuleDiagnostic>[],
);

RuleOverrideDeclaration declaration(
  String originId,
  Map<String, Object?> raw, {
  int priority = 0,
}) => RuleOverrideDeclaration.package(
  originId: originId,
  packageId: originId.split(':').first,
  priority: priority,
  entryId: originId,
  rules: rulesOf(raw),
);

void main() {
  late RuleProfile profile;
  setUp(() => profile = RuleProfileResolver.resolveBuiltin(overrideArchive()).profile!);

  test('高 priority 的勘误覆盖角色自己条目声明的列', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: rulesOf({'hitDie': 6, 'spellcasting': {'prepared': {'5': 7}}}),
      entryId: 'base:class/wizard',
      declarations: [
        declaration('errata:class/wizard', {
          'spellcasting': {'prepared': {'5': 9}},
        }, priority: 40),
      ],
    );
    expect(merged.preparedLimit(5), 9);
    expect(merged.sourceOf('spellcasting.prepared')!.originId, 'errata:class/wizard');
    expect(merged.sourceOf('spellcasting.prepared')!.tier, kEntryTier + 40);
    expect(merged.sourceOf('hitDie')!.originId, 'base:class/wizard');
  });

  test('低 priority 的勘误不生效，但来源里看得见谁赢', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: rulesOf({'spellcasting': {'prepared': {'5': 7}}}),
      entryId: 'base:class/wizard',
      declarations: [
        declaration('errata:class/wizard', {
          'spellcasting': {'prepared': {'5': 9}},
        }, priority: 0),
      ],
    );
    // 同 tier（都是 100）；角色自己的条目优先，因此 7 生效。
    expect(merged.preparedLimit(5), 7);
    expect(merged.sourceOf('spellcasting.prepared')!.originId, 'base:class/wizard');
  });

  test('同 tier 两个外部包抢同一列 → 记一条 RuleOverrideConflict，取排序首位', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: rulesOf({'hitDie': 6}),
      entryId: 'base:class/wizard',
      declarations: [
        declaration('alpha:class/wizard', {
          'spellcasting': {'prepared': {'5': 9}},
        }, priority: 10),
        declaration('zeta:class/wizard', {
          'spellcasting': {'prepared': {'5': 11}},
        }, priority: 10),
      ],
    );
    expect(merged.preparedLimit(5), 9, reason: 'alpha 在 originId 升序里先');
    expect(merged.conflicts, hasLength(1));
    final conflict = merged.conflicts.single;
    expect(conflict.field, 'spellcasting.prepared');
    expect(conflict.tier, kEntryTier + 10);
    expect(conflict.originIds, ['alpha:class/wizard', 'zeta:class/wizard']);
    expect(conflict.effectiveOriginId, 'alpha:class/wizard');
  });

  test('声明不同列的两个包同一 tier 不算冲突（互补）', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: rulesOf({'hitDie': 6}),
      entryId: 'base:class/wizard',
      declarations: [
        declaration('alpha:class/wizard', {
          'spellcasting': {'prepared': {'5': 9}},
        }, priority: 10),
        declaration('beta:class/wizard', {
          'spellcasting': {'cantrips': {'5': 5}},
        }, priority: 10),
      ],
    );
    expect(merged.preparedLimit(5), 9);
    expect(merged.cantripLimit(5), 5);
    expect(merged.conflicts, isEmpty);
  });

  test('高 tier 覆盖低 tier 不算冲突（只是覆盖）', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: rulesOf({'hitDie': 6}),
      entryId: 'base:class/wizard',
      declarations: [
        declaration('errata:class/wizard', {
          'spellcasting': {'prepared': {'5': 9}},
        }, priority: 40),
        declaration('other:class/wizard', {
          'spellcasting': {'prepared': {'5': 11}},
        }, priority: 10),
      ],
    );
    expect(merged.preparedLimit(5), 9);
    expect(merged.conflicts, isEmpty);
  });

  test('priority 不同的两个包都参与合并：各自声明的列都生效', () {
    final merged = RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: 'wizard',
      entryRules: null,
      entryId: null,
      declarations: [
        declaration('alpha:class/wizard', {
          'spellcasting': {'prepared': {'5': 9}},
        }, priority: 40),
        declaration('zeta:class/wizard', {
          'spellcasting': {'cantrips': {'5': 5}},
        }, priority: 10),
      ],
      characterEntryId: 'base:class/wizard',
    );
    expect(merged.preparedLimit(5), 9);
    expect(merged.cantripLimit(5), 5, reason: '低 priority 声明的是另一列，仍然生效');
    expect(merged.spellSlots(5), {'1': 4, '2': 3, '3': 2}, reason: '档案补齐');
  });
}
```

- [ ] **步骤 2：跑测试确认失败**

```bash
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test/rules/rule_override_conflict_test.dart"
```

- [ ] **步骤 3：`RuleOverrideConflict`**

```dart
// rule_override_conflict.dart
/// 同一 tier 的多个来源抢同一列时的记录（契约 S3）。
///
/// 生效值取 [RuleOverrideOrder] 排序首位（可复现），但**必须让用户看见**并能
/// 显式改选（`CharacterRuleOverrides.pinned`）。
class RuleOverrideConflict {
  const RuleOverrideConflict({
    required this.field,
    required this.tier,
    required this.originIds,
    required this.effectiveOriginId,
  });

  final String field; // RuleFieldPath 的列级路径
  final int tier;
  final List<String> originIds; // 按 RuleOverrideOrder 排序（≥2）
  final String effectiveOriginId;

  Map<String, Object?> toJson() => {
    'field': field,
    'tier': tier,
    'originIds': originIds,
    'effectiveOriginId': effectiveOriginId,
  };

  static RuleOverrideConflict? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final field = '${raw['field'] ?? ''}'.trim();
    final tier = raw['tier'];
    final effective = '${raw['effectiveOriginId'] ?? ''}'.trim();
    final rawOrigins = raw['originIds'];
    if (field.isEmpty || tier is! int || effective.isEmpty || rawOrigins is! List) {
      return null;
    }
    final origins = [for (final o in rawOrigins) '$o'];
    if (origins.length < 2) return null;
    return RuleOverrideConflict(
      field: field,
      tier: tier,
      originIds: origins,
      effectiveOriginId: effective,
    );
  }
}

/// 冲突表的持久化（角色数据 `data.classRuleConflicts`）的**唯一**实现。
abstract final class RuleOverrideConflicts {
  static List<Object?> toData(Iterable<RuleOverrideConflict> conflicts) =>
      [for (final conflict in conflicts) conflict.toJson()];

  static List<RuleOverrideConflict> fromData(Object? raw) => [
    if (raw is List)
      for (final item in raw)
        if (RuleOverrideConflict.fromJson(item) case final conflict) conflict,
  ];
}
```

- [ ] **步骤 4：解析器改成"条目 + N 条声明"合并**

`resolveClassRules` 的新签名（**全部可选参数带默认值**，既有 15 处调用点原样编译）。
声明链上**只有 `RuleOverrideDeclaration` 一种类型**（任务 7 已把它做成"包声明 / 内置"两种
命名构造），排序**只调一次** `RuleOverrideOrder.effective`：

```dart
  static ResolvedClassRules resolveClassRules({
    required RuleProfile profile,
    required String slug,
    required ClassRuleSet? entryRules,
    String? entryId,
    List<RuleOverrideDeclaration> declarations = const [],
    int entryPriority = 0,
    String? characterEntryId,
    Set<String> disabledOriginIds = const {},
    Map<String, String> pinnedOrigins = const {},
  }) {
    final fromArchive = profile.classRules(slug);
    final sources = <String, RuleFieldSource>{};
    final conflicts = <RuleOverrideConflict>[];

    // 1) 组装"包声明"这一层（内置档案不在其中——它由 RuleOverrideOrder 之后追加）。
    final packages = <RuleOverrideDeclaration>[
      if (entryRules != null)
        RuleOverrideDeclaration.package(
          originId: entryId ?? '<entry>',
          packageId: entryId == null
              ? ''
              : RuleOverrideDeclaration.packageIdOf(entryId),
          priority: entryPriority,
          rules: entryRules,
          entryId: entryId,
        ),
      for (final declaration in declarations)
        // 关闭覆盖：按条目 id 或包 id 命中都算（UI 关的是条目，但"关掉整个包"
        // 也是合法表达）。角色自己的条目不受这个开关影响（它不是"覆盖"）。
        if (!disabledOriginIds.contains(declaration.originId) &&
            !disabledOriginIds.contains(declaration.packageId) &&
            declaration.originId != entryId)
          declaration,
    ];

    // 2) 排序 + `replace` 截断（唯一排序点）。**不要**在这里按 pin 重排整条链：
    //    pin 只影响被 pin 的那一列（见任务 8 审查项 0.1 的修正）。被 `disabled`
    //    关掉、但被 pin 选中的来源作为"仅这些列"的候选单独保留（pin 豁免
    //    disabled），不参与 `replace` 截断。
    final ranked = RuleOverrideOrder.ordered(packages, characterEntryId: entryId);
    final ordered = RuleOverrideOrder.truncate(<RuleOverrideDeclaration>[
      ...ranked,
      if (fromArchive != null) RuleOverrideDeclaration.builtin(fromArchive),
    ]);
    // pin 的按列优先在 `_pickColumn` / `_pickTableColumn` /
    // `_mergeResourceMaximum` 内完成（`_PinContext`），解析器不重排链。

    final spellcasting = _mergeSpellcasting(
      chain: ordered,
      sources: sources,
      conflicts: conflicts,
    );
    final entryRulesResolved = entryRules;
    return ResolvedClassRules(
      hitDie: _pickColumn<int>(
        field: RuleFieldPath.hitDie,
        declarations: ordered,
        declares: (rules) => rules.declares('hitDie'),
        read: (rules) => rules.hitDie,
        sources: sources,
        conflicts: conflicts,
      ).value,
      savingThrowAbilities: _pickColumn<Set<String>>(
        field: RuleFieldPath.savingThrowAbilities,
        declarations: ordered,
        declares: (rules) => rules.declares('savingThrowAbilities'),
        read: (rules) => rules.savingThrowAbilities,
        sources: sources,
        conflicts: conflicts,
      ).value ??
          const {},
      spellcasting: spellcasting,
      resources: _mergeResources(
        chain: effectiveChain,
        sources: sources,
        conflicts: conflicts,
      ),
      archetype: profile.progression(spellcasting?.archetype),
      fieldSources: sources,
      conflicts: _dedupeConflicts(conflicts),
      entryRules: entryRulesResolved,
      archiveRules: fromArchive,
    );
  }

  /// 用户 pin 的来源**只在被 pin 的那一列的候选里置顶**（唯一实现）。
  ///
  /// ⚠️ **本段是批次 B 的原始草稿，已作废**：把"在任意 pinned 列上被选中的
  /// 来源"整体提前是**错的**——`_pickColumn` 取的是"声明了该列"的第一个声明，
  /// 但同一来源往往同时声明了别的列（`hitDie` / `savingThrowAbilities` /
  /// `spellcasting.*`），整条提前会让那些列也一起抢到最高位，`effectiveOriginId`
  /// 与冲突随之静默改变。**只 pin 一列就改动别的列，属静默改值**。
  ///
  /// 正确实现（已落地）：`pinnedOrigins`（列路径 → originId）传进
  /// `_pickColumn` / `_pickTableColumn` / `_mergeResourceMaximum`，在**声明了该列**
  /// 的候选里把被 pin 的来源置顶；被 `disabled` 剔除的来源若被 pin 选中，只作为
  /// **这些列**的候选保留（"pin 豁免 disabled"）。pin 命中的列不再登记冲突
  /// （用户已做出选择）。解析器不重排整条链。
  static List<RuleOverrideDeclaration> pinnedFirst(
    List<RuleOverrideDeclaration> declaring,
    String? pinnedOriginId,
  ) {
    if (pinnedOriginId == null) return declaring;
    final index = declaring.indexWhere(
      (declaration) => declaration.originId == pinnedOriginId,
    );
    if (index <= 0) return declaring;
    return List<RuleOverrideDeclaration>.unmodifiable([
      declaring[index],
      ...declaring.sublist(0, index),
      ...declaring.sublist(index + 1),
    ]);
  }

  /// 冲突去重 + 按字段路径升序（同一列在 hitDie / spellcasting / resources 的
  /// 三次 `_pickColumn` 调用里只会命中一次，去重是防御）。
  static List<RuleOverrideConflict> _dedupeConflicts(
    List<RuleOverrideConflict> conflicts,
  ) {
    final byField = <String, RuleOverrideConflict>{};
    for (final conflict in conflicts) {
      byField.putIfAbsent(conflict.field, () => conflict);
    }
    final fields = byField.keys.toList()..sort();
    return List<RuleOverrideConflict>.unmodifiable([
      for (final field in fields) byField[field]!,
    ]);
  }
```

> **`_mergeSpellcasting` / `_mergeResources` 的签名随之改为接收整条 `chain` + `conflicts`**
> （而不是任务 2 / 3 里的 `entry` + `archive` 两个具名参数）。这是同一任务的机械改造：
> 函数体里直接用 `chain`，把冲突收集器透传给 `_pickColumn`，`declares` / `read` 闭包不变。
> 任务 7 步骤 5 已经把 `_OrderedDeclaration` 收敛成 `RuleOverrideDeclaration`，
> 本任务不再引入第二种声明类型。
>
> **已落地时修正（任务 8 审查项 0.3 / 0.4-8）**：
> - 冲突判定不再是"同 tier 同列即登记"，而是 **同 tier + 同列 + 声明区间有交集 +
>   该交集上取值不同**（标量列按整值比较）；同值、只改不同等级都不登记。
> - `originIds` 恒按 `originId` 升序（`RuleOverrideOrder.orderedOriginIds`）。
> - `_dedupeConflicts` **不留在解析器里**：排序 / 去重的唯一实现是
>   `RuleOverrideOrder.orderedConflicts`（任务 13 门禁要求
>   `rule_profile_resolver.dart` 内没有 sort 调用）。

`_pickColumn` 增加冲突登记（同 tier 的多来源声明同列）：

```dart
_ColumnPick<T> _pickColumn<T>({
  required String field,
  required List<RuleOverrideDeclaration> declarations,
  required bool Function(ClassRuleSet rules) declares,
  required T? Function(ClassRuleSet rules) read,
  required Map<String, RuleFieldSource> sources,
  required List<RuleOverrideConflict> conflicts,
}) {
  String? winnerOrigin;
  int? winnerTier;
  T? winnerValue;
  final sameTierOrigins = <String>[];
  for (final declaration in declarations) {
    if (!declares(declaration.rules)) continue;
    if (winnerOrigin == null) {
      winnerOrigin = declaration.originId;
      winnerTier = declaration.tier;
      winnerValue = read(declaration.rules);
      sameTierOrigins.add(declaration.originId);
      continue;
    }
    if (declaration.tier == winnerTier) {
      // 同 tier 抢同一列：登记冲突，但**不让结果不确定**——排序已保证首位胜出。
      sameTierOrigins.add(declaration.originId);
    }
  }
  if (winnerOrigin != null) {
    if (sameTierOrigins.length > 1) {
      conflicts.add(
        RuleOverrideConflict(
          field: field,
          tier: winnerTier!,
          originIds: List<String>.unmodifiable(sameTierOrigins),
          effectiveOriginId: winnerOrigin,
        ),
      );
    }
    _writeSource(sources, field, winnerOrigin, winnerTier!);
  }
  return _ColumnPick(value: winnerValue, originId: winnerOrigin);
}
```

`ResolvedClassRules` 增加：

```dart
  /// 同 tier 多来源抢同一列的记录（去重后按字段路径升序）。
  final List<RuleOverrideConflict> conflicts;
```

`dnd5e_rules.dart` 的透传（**唯一** facade，所有消费方经它）：

```dart
  static ResolvedClassRules resolveClassRules({
    required String? entryId,
    required String classSummary,
    Map<String, Object?> structured = const <String, Object?>{},
    List<RuleDiagnostic>? diagnostics,
    RuleOverrideIndex? overrides,
    Set<String> disabledOriginIds = const <String>{},
    Map<String, String> pinnedOrigins = const <String, String>{},
    int entryPriority = 0,
  }) {
    final slug = _slugFor(entryId: entryId, classSummary: classSummary);
    // …entryRules 解析不变…
    return RuleProfileResolver.resolveClassRules(
      profile: profile,
      slug: slug,
      entryRules: entryRules,
      entryId: entryId,
      declarations: overrides?.declarationsFor(slug, excludeEntryId: entryId) ?? const [],
      entryPriority: entryPriority,
      characterEntryId: entryId,
      disabledOriginIds: disabledOriginIds,
      pinnedOrigins: pinnedOrigins,
    );
  }
```

- [ ] **步骤 5：Builder / Projector 接线并持久化**

`RulesDrivenCharacterBuilder`：

```dart
  RulesDrivenCharacterBuilder({
    required this.entries,
    Map<String, int> packagePriorities = const <String, int>{},
  }) : _overrides = RuleOverrideIndex.fromEntries(
         entries.values,
         packagePriorities,
       ),
       _packagePriorities = packagePriorities,
       _engine = CharacterRulesEngine(entries: entries);
```

`build()` 里解析职业规则时：

```dart
    final classRules = Dnd5eRules.resolveClassRules(
      entryId: classEntry?.id,
      classSummary: classEntry?.name ?? '',
      structured: classEntry?.structured ?? const <String, Object?>{},
      overrides: _overrides,
      entryPriority:
          _packagePriorities[
            RuleOverrideDeclaration.packageIdOf(classEntry?.id ?? '')
          ] ??
          0,
    );
```

并在返回的 `data` 里追加：

```dart
        'classRuleSources': RuleFieldSourceMap.toData(classRules.fieldSources),
        'classRuleConflicts': RuleOverrideConflicts.toData(classRules.conflicts),
```

`CharacterRuleProjector`：

```dart
  const CharacterRuleProjector({
    required this.entries,
    this.packagePriorities = const <String, int>{},
  });
```

`project()` 里：

```dart
    final overrides = CharacterRuleOverrides.fromCharacter(character);
    final builder = RulesDrivenCharacterBuilder(
      entries: entries,
      packagePriorities: packagePriorities,
    );
    // builder 是建档路径（没有 overrides），再派生必须自己再解析一次并带上 overrides：
    final classRules = Dnd5eRules.resolveClassRules(
      entryId: classId,
      classSummary: character.classSummary,
      structured: classEntry?.structured ?? const {},
      overrides: RuleOverrideIndex.fromEntries(entries.values, packagePriorities),
      disabledOriginIds: overrides.disabledOriginIds,
      pinnedOrigins: overrides.pinned,
    );
```

> **实现要点（避免双份派生）**：`builder.build()` 已经解析过一次职业规则。为了让"再派生带 overrides"只有一处实现，给 `RulesDrivenCharacterBuilder.build` 增加可选参数 `Set<String> disabledOriginIds = const {}` / `Map<String,String> pinnedOrigins = const {}`，由 projector 传进去；**不要**在 projector 里另解析一次。这样"读 overrides → 传参 → 一次解析"的路径唯一。

`mergedData` 的键清单（约 47-59 行）追加 `'classRuleSources'`、`'classRuleConflicts'`，让再派生刷新它们。

- [ ] **步骤 6：跑测试确认通过 + 全量**

```bash
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test/rules"
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test"
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib test"
```

预期：冲突用例全绿；全量通过；`classRuleSources` / `classRuleConflicts` 出现在派生数据里（`homebrew_class_end_to_end_test.dart` 可补一条断言）。

- [ ] **步骤 7：Commit**

```bash
git add apps/client_flutter/lib/src/features/rules/domain/rule_override_conflict.dart \
        apps/client_flutter/lib/src/features/rules/domain/rule_profile_resolver.dart \
        apps/client_flutter/lib/src/features/rules/domain/rule_profile.dart \
        apps/client_flutter/lib/src/features/characters/domain/dnd5e_rules.dart \
        apps/client_flutter/lib/src/features/characters/domain/rules_driven_character_builder.dart \
        apps/client_flutter/lib/src/features/characters/domain/character_rule_projector.dart \
        apps/client_flutter/test/rules/rule_override_conflict_test.dart
git commit -m "feat(rules): 多声明列级合并与覆盖冲突记录

resolveClassRules 接受按优先级排好的跨包声明；同 tier 多来源抢同一列时记录
RuleOverrideConflict（生效值取排序首位，结果可复现）。派生结果把
classRuleSources / classRuleConflicts 写进角色数据。"
```

---

## 任务 9：角色页消费来源与冲突

**文件：**
- 创建：`apps/client_flutter/lib/src/features/characters/presentation/widgets/rule_source_list.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_detail_spells_panel.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_detail_resources_panel.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_detail_page.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/characters_tab_page.dart`
- 测试：`apps/client_flutter/test/character_rule_sources_ui_test.dart`（新建）

- [ ] **步骤 1：写失败测试**

```dart
// test/character_rule_sources_ui_test.dart
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_detail_page.dart';
import 'package:dnd_table_client/src/features/characters/presentation/widgets/rule_source_list.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_field_path.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_override_conflict.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('来源徽标把内置档案与包声明分开显示', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RuleSourceChip(
            field: RuleFieldPath.spellcasting('prepared'),
            source: RuleFieldSource(
              field: 'spellcasting.prepared',
              originId: 'errata-pack:class/wizard',
              tier: 140,
            ),
            originLabels: {'errata-pack:class/wizard': '勘误包'},
          ),
        ),
      ),
    );
    expect(find.textContaining('准备法术上限'), findsOneWidget);
    expect(find.textContaining('勘误包'), findsOneWidget);
    expect(find.byIcon(Icons.extension_outlined), findsOneWidget);
  });

  testWidgets('内置档案来源不显示"覆盖"图标', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RuleSourceChip(
            field: RuleFieldPath.hitDie,
            source: RuleFieldSource(
              field: 'hitDie',
              originId: 'builtin:dnd5e-2024',
              tier: 0,
            ),
            originLabels: {'builtin:dnd5e-2024': '内置档案'},
          ),
        ),
      ),
    );
    expect(find.textContaining('内置档案'), findsOneWidget);
    expect(find.byIcon(Icons.rule_outlined), findsOneWidget);
  });

  testWidgets('冲突横幅列出竞争来源并可打开选择对话框', (tester) async {
    const conflict = RuleOverrideConflict(
      field: 'spellcasting.prepared',
      tier: 110,
      originIds: ['alpha:class/wizard', 'zeta:class/wizard'],
      effectiveOriginId: 'alpha:class/wizard',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RuleOverrideConflictBanner(
            conflicts: const [conflict],
            originLabels: const {
              'alpha:class/wizard': 'A 包',
              'zeta:class/wizard': 'Z 包',
            },
            onResolve: (conflicts) async {},
          ),
        ),
      ),
    );
    expect(find.textContaining('1 处'), findsOneWidget);
    await tester.tap(find.textContaining('处理'));
    await tester.pumpAndSettle();
    expect(find.text('覆盖冲突'), findsOneWidget);
    expect(find.text('A 包'), findsWidgets);
    expect(find.text('Z 包'), findsWidgets);
  });
}
```

- [ ] **步骤 2：跑测试确认失败**

```bash
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test/character_rule_sources_ui_test.dart"
```

- [ ] **步骤 3：实现 `rule_source_list.dart`**

```dart
// 角色页的"规则来源"组件（契约 §3.7）。
//
// 设计契约：只用 colorScheme 角色；覆盖用 `tertiary`（信息级，不是 error），
// 内置档案用 `onSurfaceVariant` 次级文字；图标控件带 Tooltip；圆角走 Card.outlined
// 的 8dp；不新增 DESIGN token。
import 'package:flutter/material.dart';

import '../../../rules/domain/rule_field_path.dart';
import '../../../rules/domain/rule_override_conflict.dart';
import '../../../rules/domain/rule_profile.dart';

/// 单个字段 / 列的来源徽标。
class RuleSourceChip extends StatelessWidget {
  const RuleSourceChip({
    required this.field,
    required this.source,
    required this.originLabels,
    this.onDisableOverride,
    super.key,
  });

  final String field;
  final RuleFieldSource? source;
  final Map<String, String> originLabels;
  final Future<void> Function()? onDisableOverride;

  bool get _isOverride => (source?.tier ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = source == null
        ? '来源未知'
        : originLabels[source!.originId] ?? source!.originId;
    final color = _isOverride
        ? theme.colorScheme.tertiary
        : theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: _isOverride ? '该列被内容包覆盖' : '该列来自内置规则档案',
          child: Icon(
            _isOverride ? Icons.extension_outlined : Icons.rule_outlined,
            size: 16,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '${RuleFieldPath.labelFor(field)}：$label',
            style: theme.textTheme.bodySmall?.copyWith(color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (_isOverride && onDisableOverride != null)
          TextButton(
            onPressed: onDisableOverride,
            child: const Text('使用内置档案'),
          ),
      ],
    );
  }
}

/// 冲突提示条：同 tier 多来源抢同一列。
class RuleOverrideConflictBanner extends StatelessWidget {
  const RuleOverrideConflictBanner({
    required this.conflicts,
    required this.originLabels,
    required this.onResolve,
    super.key,
  });

  final List<RuleOverrideConflict> conflicts;
  final Map<String, String> originLabels;
  final Future<void> Function(List<RuleOverrideConflict> conflicts) onResolve;

  @override
  Widget build(BuildContext context) {
    if (conflicts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.call_split, color: theme.colorScheme.tertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${conflicts.length} 处规则覆盖冲突：多个内容包以相同优先级声明了同一列',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: () => _openResolveDialog(context),
              child: const Text('处理'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openResolveDialog(BuildContext context) async {
    final result = await showDialog<List<RuleOverrideConflict>>(
      context: context,
      builder: (context) => RuleOverrideConflictDialog(
        conflicts: conflicts,
        originLabels: originLabels,
      ),
    );
    if (result != null) await onResolve(result);
  }
}
```

`RuleOverrideConflictDialog`（同文件）：`AlertDialog`，**标题固定为 `覆盖冲突`**（测试
`find.text('覆盖冲突')` 依赖它），正文每个冲突一段：先用
`RuleFieldPath.labelFor(conflict.field)` 显示列名，再用一个
`RadioListTile<String>` 列表列出 `conflict.originIds`（标签经 `originLabels` 翻译，
默认选中 `effectiveOriginId`）；确认后返回"用户选择后的冲突列表"
（每一项的 `effectiveOriginId` 已替换成用户选择）。尺寸取 `dialog_sizes.dart`
的 `narrow`（440）；不新增任何颜色 / 圆角 token。

- [ ] **步骤 4：把来源接进角色页**

`CharacterDetailPage` 新增参数（**全部带默认值**，既有 widget 测试构造点不变）：

```dart
    this.packagePriorities = const <String, int>{},
    this.onReapplyRules,
    this.packageNames = const <String, String>{},
```

```dart
  /// 包 id → priority（来自 `ContentRepository.packagePriorities()`）。
  final Map<String, int> packagePriorities;
  /// 包 id → 展示名；同时用于把来源 id 翻译成人类可读标签。
  final Map<String, String> packageNames;
  /// 重新派生规则快照（关闭覆盖 / 解决冲突后调用）。
  ///
  /// 新增独立 typedef（与 `onUpgrade` 同形状但语义不同，不复用名字）：
  /// `typedef CharacterRulesReapplyCallback = Future<CharacterSheet?> Function(CharacterSheet character);`
  ///
  /// **实现时修正**：回调必须**接收当前角色**（刚被写过 `data.ruleOverrides` 的
  /// 那一份）。若按原稿的无参 `Future<CharacterSheet?> Function()` 并捕获打开页面
  /// 时的旧角色，`CharacterRuleProjector` 读到的仍是**旧** `ruleOverrides`——用户的
  /// "关闭覆盖 / 选择来源"会在再派生时被静默还原。下方 `_openDetailPage` 片段里的
  /// `() => _reapplyRules(projectedCharacter, …)` 因此读作
  /// `(updated) => _reapplyRules(updated, …)`。
  final CharacterRulesReapplyCallback? onReapplyRules;
```

`build()` 里组装 `originLabels` 的**唯一**实现（放进一个私有方法）：

```dart
  /// 来源 id → 展示名（唯一实现）：内置档案固定文案；条目 id 用"包名 · 条目名"；
  /// 包 id → 包名（`ruleOriginLabel` 在条目 id 查不到时退回包 id）。
  Map<String, String> _originLabels() {
    final labels = <String, String>{kBuiltinOriginId: '内置档案'};
    for (final entry in widget.contentEntries) {
      final packageId = RuleOverrideDeclaration.packageIdOf(entry.id);
      final packageName = widget.packageNames[packageId];
      labels[entry.id] = packageName == null || packageName.isEmpty
          ? entry.name
          : '$packageName · ${entry.name}';
    }
    for (final entry in widget.packageNames.entries) {
      labels.putIfAbsent(entry.key, () => entry.value);
    }
    return labels;
  }
```

`character_detail_spells_panel.dart`：
- `_SpellsPanel` 增加 `originLabels` / `conflicts` / `sources` / `onDisableOverride` 参数；
- 法术位区与准备上限区下方按列渲染 `RuleSourceChip`：`spellcasting.slots`、`spellcasting.prepared`、`spellcasting.mode`、`spellcasting.ability`；
- 区域顶部渲染 `RuleOverrideConflictBanner`；
- 回退解析（`_slotMaximums()` / `_spellcastingAbility()`）传 `overrides` / `disabledOriginIds` / `pinnedOrigins`。

`character_detail_resources_panel.dart`：每条 `_ClassResourceLine` 下加两行 `RuleSourceChip`（`resources.<id>.maximum`、`resources.<id>.recovery`）+ 顶部冲突横幅。

`character_detail_features_panel.dart` 的 `_ProfilePanel`：加一个「规则来源」`Card`，列出全部来源（`sources` 按字段路径升序）与"使用内置档案"按钮，作为集中管理面。

`characters_tab_page._openDetailPage`：

```dart
    final priorities = await repository.packagePriorities();
    final packages = await repository.watchPackages().first;
    final projectedCharacter = CharacterRuleProjector(
      entries: {for (final entry in contentEntries) entry.id: entry},
      packagePriorities: priorities,
    ).project(character);
    // …CharacterDetailPage(
    //   packagePriorities: priorities,
    //   packageNames: {for (final p in packages) p.id: p.name},
    //   onReapplyRules: () => _reapplyRules(projectedCharacter, contentEntries, priorities),
    // )
```

- [ ] **步骤 5：跑测试确认通过 + 全量**

```bash
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test/character_rule_sources_ui_test.dart"
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test"
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib test"
npm run lint:design
```

- [ ] **步骤 6：Commit**

```bash
git add apps/client_flutter/lib/src/features/characters/presentation/widgets/rule_source_list.dart \
        apps/client_flutter/lib/src/features/characters/presentation/character_detail_spells_panel.dart \
        apps/client_flutter/lib/src/features/characters/presentation/character_detail_resources_panel.dart \
        apps/client_flutter/lib/src/features/characters/presentation/character_detail_features_panel.dart \
        apps/client_flutter/lib/src/features/characters/presentation/character_detail_page.dart \
        apps/client_flutter/lib/src/features/characters/presentation/characters_tab_page.dart \
        apps/client_flutter/test/character_rule_sources_ui_test.dart
git commit -m "feat(characters): 角色页显示列级规则来源与覆盖冲突

法术位的每个列、每条资源的每个列都带来源徽标（内置档案 / 覆盖它的包）；
同 tier 抢同一列时用法术位 / 资源区的冲突提示条打开选择对话框。"
```

---

## 任务 10：关闭覆盖回退内置

**文件：**
- 创建：`apps/client_flutter/lib/src/features/characters/domain/character_rule_overrides.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_detail_page.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/characters_tab_page.dart`
- 测试：`apps/client_flutter/test/character_rule_sources_ui_test.dart`（追加 group）

> **API 已按任务 8 审查项 0.4-6 落地**（本任务按实际 API 写调用方）：
> mutator 名是 `disable(originId)` / `enable(originId)` / `pin(field, originId)`
> （不是 `disabled` / `enabled`）；`fromData(Object?)` 是形状归一化的唯一实现
> （`fromJson` 只是兼容入口）；`toData()` **只写非空键**；`fromData` 遇非 String
> 键降级为"没有覆盖"而不是抛。下面片段里的 `disabled(...)` 一律读作 `disable(...)`。

- [ ] **步骤 1：写失败测试**

```dart
// test/character_rule_sources_ui_test.dart（在同一文件追加）
import 'package:dnd_table_client/src/features/characters/domain/character_rule_overrides.dart';

group('CharacterRuleOverrides', () {
  test('缺省为空：没有禁用、没有固定来源', () {
    const overrides = CharacterRuleOverrides.empty;
    expect(overrides.disabledOriginIds, isEmpty);
    expect(overrides.pinned, isEmpty);
  });

  test('往返序列化：只写有内容的键（老角色数据不变）', () {
    const overrides = CharacterRuleOverrides(
      disabledOriginIds: {'errata-pack:class/wizard'},
      pinned: {'spellcasting.prepared': 'alpha:class/wizard'},
    );
    final data = overrides.toData();
    expect(data['disabledOriginIds'], ['errata-pack:class/wizard']);
    expect(data['pinned'], {'spellcasting.prepared': 'alpha:class/wizard'});
    final restored = CharacterRuleOverrides.fromData(data);
    expect(restored.disabledOriginIds, overrides.disabledOriginIds);
    expect(restored.pinned, overrides.pinned);
  });

  test('坏数据按"没有覆盖"处理，不抛异常', () {
    expect(
      CharacterRuleOverrides.fromData({'disabledOriginIds': 'x'}).disabledOriginIds,
      isEmpty,
    );
    expect(
      CharacterRuleOverrides.fromData({'pinned': {'a': 1}}).pinned,
      isEmpty,
    );
  });

  test('toggleOrigin 幂等：连续两次回到原状态', () {
    const overrides = CharacterRuleOverrides.empty;
    final disabled = overrides.disabled('errata-pack:class/wizard');
    expect(disabled.disabledOriginIds, {'errata-pack:class/wizard'});
    expect(
      disabled.disabled('errata-pack:class/wizard').disabledOriginIds,
      isEmpty,
    );
  });
});
```

- [ ] **步骤 2：跑测试确认失败**

```bash
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test/character_rule_sources_ui_test.dart"
```

- [ ] **步骤 3：实现 `CharacterRuleOverrides`**

```dart
// apps/client_flutter/lib/src/features/characters/domain/character_rule_overrides.dart
import 'character.dart';

/// 角色数据 `data.ruleOverrides` 的**唯一**读取 / 写入实现（契约 S3）。
///
/// - [disabledOriginIds]：被用户显式关掉的覆盖来源（条目 id 或包 id）。
///   关掉之后该来源不再参与合并，**回退到内置档案**——数值随之改变。
/// - [pinned]：冲突列上用户显式选定的来源（列路径 → 来源 id）。它高于 priority。
class CharacterRuleOverrides {
  const CharacterRuleOverrides({
    this.disabledOriginIds = const <String>{},
    this.pinned = const <String, String>{},
  });

  static const empty = CharacterRuleOverrides();

  final Set<String> disabledOriginIds;
  final Map<String, String> pinned;

  static CharacterRuleOverrides fromCharacter(CharacterSheet character) =>
      fromData(character.dataMap['ruleOverrides']);

  /// 坏数据一律按"没有覆盖"处理：它只影响"用哪一份数值"，
  /// 读不回来时按默认（条目 ∪ 档案）解析，绝不猜用户的意图。
  static CharacterRuleOverrides fromData(Object? raw) {
    if (raw is! Map) return empty;
    final disabled = raw['disabledOriginIds'];
    final pinned = raw['pinned'];
    return CharacterRuleOverrides(
      disabledOriginIds: {
        if (disabled is List)
          for (final item in disabled)
            if ('$item'.trim().isNotEmpty) '$item'.trim(),
      },
      pinned: {
        if (pinned is Map)
          for (final entry in pinned.entries)
            if ('${entry.key}'.trim().isNotEmpty && entry.value is String)
              '${entry.key}'.trim(): '${entry.value}'.trim(),
      },
    );
  }

  Map<String, Object?> toData() => {
    if (disabledOriginIds.isNotEmpty)
      'disabledOriginIds': (disabledOriginIds.toList()..sort()),
    if (pinned.isNotEmpty)
      'pinned': {
        for (final key in pinned.keys.toList()..sort()) key: pinned[key],
      },
  };

  bool isDisabled(String originId) =>
      disabledOriginIds.contains(originId) || disabledOriginIds.contains(_packageId(originId));

  CharacterRuleOverrides disabled(String originId) => CharacterRuleOverrides(
    disabledOriginIds: {
      if (!isDisabled(originId)) ...disabledOriginIds,
      originId,
    },
    pinned: pinned,
  );

  CharacterRuleOverrides enabled(String originId) => CharacterRuleOverrides(
    disabledOriginIds: {...disabledOriginIds}..removeWhere(
        (value) => value == originId || value == _packageId(originId)),
    pinned: pinned,
  );

  CharacterRuleOverrides pin(String field, String originId) =>
      CharacterRuleOverrides(
        disabledOriginIds: disabledOriginIds,
        pinned: {...pinned, field: originId},
      );

  static String _packageId(String originId) {
    final index = originId.indexOf(':');
    return index <= 0 ? originId : originId.substring(0, index);
  }
}
```

- [ ] **步骤 4：把开关接到角色页并触发重新派生**

`CharacterDetailPage`：`RuleSourceChip.onDisableOverride` 的回调统一走一个私有方法：

```dart
  /// 关闭某条覆盖并**重新派生**（唯一实现）：写 `data.ruleOverrides` →
  /// 通知上层重新派生（`onReapplyRules`，由 characters_tab_page 用
  /// `CharacterRuleProjector` 实现）→ 保存。UI 不自己算规则数值。
  Future<void> _disableOverride(String originId) async {
    final overrides = CharacterRuleOverrides.fromCharacter(_character);
    final data = Map<String, Object?>.from(_character.dataMap)
      ..['ruleOverrides'] = overrides.disabled(originId).toData();
    setState(() => _character = _character.copyWith(data: data));
    final reapplied = await widget.onReapplyRules?.call();
    if (reapplied != null) {
      if (mounted) setState(() => _character = reapplied);
    } else {
      await widget.onSaveCharacter?.call(_character);
    }
  }
```

冲突对话框的结果（`onResolve`）同样收敛到一条路径：`overrides.pin(field, originId)` 写回 `data.ruleOverrides` → `onReapplyRules`。

`characters_tab_page`：实现 `_reapplyRules`：

```dart
  /// 重新派生的**唯一**实现（关闭覆盖 / 解决冲突后调用）。
  /// 复用打开详情页的同一条链路：读条目 → 读包优先级 → `CharacterRuleProjector`。
  Future<CharacterSheet?> _reapplyRules(
    CharacterSheet character,
    List<ContentEntry> contentEntries,
    Map<String, int> packagePriorities,
  ) async {
    final projected = CharacterRuleProjector(
      entries: {for (final entry in contentEntries) entry.id: entry},
      packagePriorities: packagePriorities,
    ).project(character);
    await widget.controller.updateCharacter(projected);
    return projected;
  }
```

- [ ] **步骤 5：跑测试确认通过 + 全量**

```bash
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test/character_rule_sources_ui_test.dart"
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test"
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib test"
```

- [ ] **步骤 6：Commit**

```bash
git add apps/client_flutter/lib/src/features/characters/domain/character_rule_overrides.dart \
        apps/client_flutter/lib/src/features/characters/presentation/character_detail_page.dart \
        apps/client_flutter/lib/src/features/characters/presentation/characters_tab_page.dart \
        apps/client_flutter/test/character_rule_sources_ui_test.dart
git commit -m "feat(characters): 可关闭规则覆盖并回退内置档案

data.ruleOverrides 记录被关掉的来源与冲突列上用户选定的来源；关闭后经
CharacterRuleProjector 重新派生并保存，数值回到内置档案。"
```

---

## 任务 11：导入报告与导入预览显示来源

**文件：**
- 修改：`apps/client_flutter/lib/src/features/content/data/import/content_package_importer.dart`
- 修改：`apps/client_flutter/lib/src/features/content/domain/content_import_report.dart`
- 修改：`apps/client_flutter/lib/src/features/content/presentation/content_import_preview_dialog.dart`
- 测试：`apps/client_flutter/test/content_import_rule_sources_test.dart`（新建）

- [ ] **步骤 1：把包构造辅助抽成共享文件**

`import_rule_diagnostics_test.dart` 顶部的 `packageJson(...)` 与 `classEntry(...)`
是本仓库构造合成包的既有写法。任务 11 的新测试也要用同一份，**不要再抄一份**：
把它们原样移到新文件 `test/rules/package_json_test_support.dart`
（`packageJson` 增加可选参数 `Object? priority`，放进包级 JSON；`classEntry` 增加
可选参数 `Map<String, Object?>? classRules`，塞进 `structured['classRules']`），
然后让 `import_rule_diagnostics_test.dart` 改成
`import 'package_json_test_support.dart';`（**只移动、不改语义**，`test/rules` 必须保持全绿）。

- [ ] **步骤 2：写失败测试**

```dart
// test/content_import_rule_sources_test.dart
import 'package:dnd_table_client/src/features/characters/domain/dnd5e_rules.dart';
import 'package:dnd_table_client/src/features/content/data/import/content_package_importer.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_import_preview_dialog.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rules/package_json_test_support.dart';
import 'rules/rule_profile_test_support.dart';
import 'support/content_test_support.dart';

void main() {
  late MemoryContentRepository repository;
  late ContentPackageImporter importer;

  setUpAll(() async {
    Dnd5eRules.configure(await loadBuiltinProfileForTest());
  });

  setUp(() {
    repository = MemoryContentRepository();
    importer = ContentPackageImporter(repository);
  });

  test('导入报告记录每个 class 条目的列级来源', () async {
    final report = await importer.previewJson(
      packageJson(
        id: 'patch-pack',
        entry: classEntry(
          slug: 'wizard',
          // 条目只覆盖 spellcasting.prepared，其余列来自内置档案
          classRules: {'spellcasting': {'prepared': {'5': 9}}},
        ),
      ),
    );
    expect(report.valid, isTrue, reason: '${report.errors}');

    final sources = report.classRuleSources['patch-pack:class/wizard']!;
    final byField = {for (final source in sources) source.field: source.originId};
    expect(byField['spellcasting.prepared'], 'patch-pack:class/wizard');
    expect(byField['spellcasting.slots'], 'builtin:dnd5e-2024');
    expect(byField['spellcasting.mode'], 'builtin:dnd5e-2024');
    expect(byField['hitDie'], 'builtin:dnd5e-2024');
  });

  testWidgets('导入预览列出条目的来源摘要，不阻断确认', (tester) async {
    final report = await importer.previewJson(
      packageJson(
        id: 'patch-pack',
        entry: classEntry(
          slug: 'wizard',
          classRules: {'spellcasting': {'prepared': {'5': 9}}},
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ContentImportPreviewDialog(report: report, onConfirm: () async {}),
      ),
    );
    expect(find.byKey(const Key('import-preview-sources')), findsOneWidget);
    expect(find.textContaining('内置档案'), findsWidgets);
    expect(find.byKey(const Key('import-preview-sources-confirm')), findsOneWidget);
  });
}
```

- [ ] **步骤 3：跑测试确认失败**

```bash
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test/content_import_rule_sources_test.dart"
```

- [ ] **步骤 4：导入器收集来源**

`_validateStructuredClassRules` 在解析 entryRules 之后多解析一次"完整合并"，把来源收进一个 `Map<String, List<RuleFieldSource>>`（由调用方 `previewJson` 持有）：

```dart
    // 来源摘要（契约 §3.7）：**复用生产解析链**，不另写一份合并。
    // 导入预览阶段的语义是"只看这个包 + 内置档案"，因此不接跨包索引
    // （冲突是运行期概念：导入单个包时看不到别的包）。
    final merged = RuleProfileResolver.resolveClassRules(
      profile: Dnd5eRules.profile,
      slug: slug,
      entryRules: entryRules,
      entryId: entryId.isEmpty ? null : entryId,
      entryPriority: priority,
    );
    classRuleSources[entryId] = [
      for (final field in merged.fieldSources.keys.toList()..sort())
        merged.fieldSources[field]!,
    ];
```

`_validateStructuredClassRules` 因此再加两个参数：`required int priority`、`required Map<String, List<RuleFieldSource>> classRuleSources`。`_buildReport` / `ContentImportReport` 带上 `classRuleSources`。

- [ ] **步骤 5：预览对话框渲染来源摘要**

`content_import_preview_dialog.dart` 在 `classLevels` 循环下追加：

```dart
            if (report.classRuleSources.isNotEmpty) ...[
              const SizedBox(height: 12),
              Column(
                key: const Key('import-preview-sources'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('规则来源', style: theme.textTheme.titleSmall),
                  for (final entry in report.classRuleSources.entries)
                    for (final source in entry.value)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${entry.key} · ${RuleFieldPath.labelFor(source.field)}'
                          ' ← ${source.tier == kBuiltinTier ? '内置档案' : entry.key.split(':').first}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                ],
              ),
            ],
```

> 展示名的唯一实现是 `RuleFieldPath.labelFor`；"来源 id → 展示名"的翻译在导入预览里只用"包 id"（包名在 manifest 里就是 `report.packageName`），因此这里不引第二套 label 表。

- [ ] **步骤 6：跑测试确认通过 + 全量**

```bash
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test/content_import_rule_sources_test.dart"
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test"
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib test"
```

- [ ] **步骤 7：Commit**

```bash
git add apps/client_flutter/lib/src/features/content/data/import/content_package_importer.dart \
        apps/client_flutter/lib/src/features/content/domain/content_import_report.dart \
        apps/client_flutter/lib/src/features/content/presentation/content_import_preview_dialog.dart \
        apps/client_flutter/test/content_import_rule_sources_test.dart
git commit -m "feat(content): 导入报告与预览显示列级规则来源

报告新增 classRuleSources（每个 class 条目的列 → 来源），预览以次级样式列出
"字段 ← 内置档案 / 包 id"，不阻断确认。"
```

---

## 任务 12：文档同步（规格 + `docs/README.md`）

**文件：**
- 修改：`docs/specs/2026-09-10-rules-contract-design.md`
- 修改：`docs/README.md`

- [ ] **步骤 1：改规格 §3.6 的"已知限制"**

把 §3.6 末尾（"本次只在**数据层**记录来源…"一段之前）的整段替换为列级口径，逐条落地：

```
2. **档案补齐**：对仍缺失的**列**，按该条目的**对齐键**查询内置档案……
   **列级合并**（S3 起）：条目声明过哪一列，该列就由条目负责；未声明的列继续
   向下回退（内置档案或其他包的声明）。`spellcasting` 逐列合并，`resources`
   按 `id` 合、同 id 再逐列合并；`hitDie` / `savingThrowAbilities` 维持整值合并。
```

删除 §3.6 的"整 `spellcasting` 替换，因此列级来源在本契约下无法产生……这是一条**已知限制**"整段，替换为"列级合并已落地"的陈述 + `mode: patch | replace` 与 `priority` 的指引段落。

- [ ] **步骤 2：改规格 §3.7 / §3.8**

§3.7：

- `RuleFieldSource.field` 的注释从"**整字段粒度**"改为列级路径，并给出示例 `spellcasting.prepared` / `resources.rage.maximum`；
- 删除"本次只在数据层记录……角色页与导入报告尚未消费"一段，改为"角色页（法术位 / 资源 / 规则来源区）、导入报告与导入预览都消费 `fieldSources`；角色数据持久化 `data.classRuleSources` 与 `data.classRuleConflicts`"。

§3.8 改为推广后的口径：

```
**两级已推广为按 tier 排序的 N 条声明**：
- 内置档案 = tier 0；
- 包声明 = tier 100 + package.priority（manifest 的 `priority`，0..1000，缺省 0）。
  缺省 0 ⇒ tier 恒为 100 —— 不写 priority 的包行为与引入前完全一致。
- 同 tier：`replace` 先于 `patch` → 角色自己的条目 → originId 升序（结果可复现）；
- **同 tier 多来源抢同一列 = 覆盖冲突**：生效值取排序首位，同时在角色页提示，
  用户可显式选定来源（`data.ruleOverrides.pinned`）或关闭某条覆盖
  （`data.ruleOverrides.disabledOriginIds`）。
- `classRules.mode: "replace"` 表示"自己就是该职业的全部真相"：更低 tier（含内置
  档案）不再提供任何列，未声明的列一律"未声明"。
```

- [ ] **步骤 3：改规格 §5.1 / §5.2 的诊断表**

§5.1 追加四行：

| code | 条件 | 示例消息 |
|---|---|---|
| `invalidMergeMode` | `classRules.mode` 不在 `patch` / `replace` | `classRules.mode 只接受 patch / replace；若想声明法术选择模型，请写在 spellcasting.mode` |
| `invalidPriority` | manifest 的 `priority` 不是 0..1000 的整数 | `priority 必须是 0..1000 的整数，缺省为 0` |
| `incompleteResourcePatch` | 条目资源是补丁声明（缺 `name` / `maximum`），且档案没有同 id 资源可补齐 | `资源 "unknown-resource" 是补丁声明（缺 name / maximum），但内置档案没有同 id 资源可补齐` |
| `overrideConflict` | **不是导入 error**：解析期同 tier 多来源抢同一列时由 `ResolvedClassRules.conflicts` 承载（不阻断导入） | `spellcasting.prepared 被 alpha / zeta 以相同优先级声明` |

并在表下补一句：`overrideConflict` 只出现在运行期解析结果与角色页提示里，**不进** `ContentImportReport.errors`（导入单包时看不到别的包，冲突不是该包的错）。

- [ ] **步骤 4：改规格 §11 的 S3 行**

把 `- **S3**：...` 一行从"其余不在本次范围"移到"本轮达成"，标注每个子项落在哪个任务 / 哪个文件。

- [ ] **步骤 5：改 `docs/README.md`**

- §5.1：`schemaVersion = 13` → `14`；
- §7.7「来源可追溯」段整段重写：来源已到**列级**并被角色页 / 导入报告消费；补充 `data.classRuleSources` / `data.classRuleConflicts` / `data.ruleOverrides` 三个键与"关闭覆盖回退内置"的行为；
- §7.7「本轮行为变化」追加 3 条：13. 列级合并（条目只覆盖 `prepared` 不再清空 `slots`）；14. 引入 `priority`（缺省 0 行为不变、Drift 13→14 迁移）；15. `classRules.mode: replace` 的新语义；
- §7.7「已知限制」表：删除"`spellcasting` 整字段替换导致无法只覆盖某列"这类限制（如果表里有），新增一条"列内**逐级**合并不支持（勘误要改某列必须重述整列的表）"；
- §9.2.1：把"没有 `priority` 字段"改为 tier 推广说明 + 冲突与关闭覆盖的行为；
- §9.2.2：`classRules` 从"只有 4 个数值字段"改为"4 个数值字段 + 合并声明 `mode`"，`spellcasting` 表补"按列合并"一列说明；`resources[]` 表补"同 id 按列合并，补丁声明可省略 `name` / `maximum`"；
- §9.2.5：诊断表补 `invalidMergeMode` / `invalidPriority` / `incompleteResourcePatch`（error）与 `overrideConflict`（运行期提示，不阻断）；
- §9.1：manifest 字段表补 `priority`（可选，0..1000，缺省 0）；
- §16：更新实测基线（测试数量、`schemaVersion = 14`）。

- [ ] **步骤 6：验收**

```bash
npm run lint:design
git diff --stat docs/
```

预期：`docs/` 只有上述两个文件变化；`lint:design` 0 error。

- [ ] **步骤 7：Commit**

```bash
git add docs/specs/2026-09-10-rules-contract-design.md docs/README.md
git commit -m "docs(rules): 同步 S3 列级合并、priority 与来源可追溯

规格 §3.6 的「整 spellcasting 替换」已知限制改为列级合并；§3.7 的来源粒度
改为列级并说明已被角色页与导入报告消费；§3.8 的无 priority 说明推广为
tier = 100 + priority；§5 补 invalidMergeMode / invalidPriority /
incompleteResourcePatch / overrideConflict；§11 的 S3 行标为已实现。"
```

---

## 任务 13：收尾门禁与端到端验收

**文件：**
- 修改：`apps/client_flutter/test/rules/homebrew_class_end_to_end_test.dart`（追加 S3 场景）
- 创建：`apps/client_flutter/test/rules/s3_override_end_to_end_test.dart`

- [ ] **步骤 1：写端到端合成场景（两个包）**

```dart
// test/rules/s3_override_end_to_end_test.dart
// 场景 D（覆盖 / 勘误）端到端：
//   base 包声明一个自制职业（不命中内置 slug），errata 包只改它的
//   spellcasting.prepared 与 resources[rage].recovery。
// 断言：导入两包 → 建角色 → 数值来自 base + errata（列级）→ 关闭 errata 后
// 数值回到 base → 冲突（同 priority 两个包抢同一列）可被提示并选定。
```

必须覆盖的断言（逐条写成一个 `test`，全部用真实导入器 + 真实解析链，不 mock 合并逻辑）：

1. `base` 包一个自制职业（对齐键 `astral-knight`）、`errata` 包同对齐键条目只声明 `spellcasting.prepared`；
2. 建角色（用 `RulesDrivenCharacterBuilder(entries: ..., packagePriorities: {'errata': 40})`）；
3. 断言 `data.spellSlots` 来自 base、`data.preparedSpellLimit` 来自 errata、`data.classRuleSources` 里 `spellcasting.prepared` 的 `originId == 'errata:class/astral-knight'`、`spellcasting.slots` 的 `originId == 'base:class/astral-knight'`；
4. 断言 `data.classRuleConflicts` 为空；
5. 第二个 `errata-b` 包与 `errata` 同 priority、改同一列 → 断言 `data.classRuleConflicts` 有 1 条、`effectiveOriginId` 是 id 升序首位；
6. 把 `data.ruleOverrides.disabledOriginIds = ['errata']` 后经 `CharacterRuleProjector` 再派生 → 断言 `preparedSpellLimit` 回到 base 的值、`classRuleSources['spellcasting.prepared'].originId == 'base:class/astral-knight'`；
7. `mode: replace` 的勘误条目：断言其余列全部"未声明"（`data.spellSlots` 缺失 / 为空、`preparedSpellLimit` 缺失）。

- [ ] **步骤 2：跑新测试**

```bash
cmd.exe /c "cd /d C:\Users\26047\Desktop\dnd-table-tool\apps\client_flutter && C:\Flutter\flutter\bin\flutter.bat test test/rules/s3_override_end_to_end_test.dart"
```

- [ ] **步骤 3：跑全部门禁**

```bash
npm run check
npm run test:scripts
npm run lint:design
```

预期：`npm run check` 服务端 lint + 客户端 analyze + 服务端 24 套件/355 测试 + 客户端 ≥1237 通过；`npm run test:scripts` 37 通过；`npm run lint:design` 0 error / 0 warning（1 条 token 统计 info）。

- [ ] **步骤 4：唯一实现清单核对（人工 grep）**

```bash
# 来源构造只允许在解析器里出现
grep -rn "RuleFieldSource(" apps/client_flutter/lib
# 排序只允许在 rule_override_priority.dart + 一个调用点
grep -rn "\.sort(" apps/client_flutter/lib/src/features/rules/domain/rule_profile_resolver.dart apps/client_flutter/lib/src/features/characters/domain/rule_override_index.dart
# "是否声明"判断不得靠值判空
grep -rn "declares(" apps/client_flutter/lib/src/features/rules/domain/
# 手拼列路径不允许出现在 UI
grep -rn "'spellcasting\.\|'resources\." apps/client_flutter/lib/src/features/characters/presentation apps/client_flutter/lib/src/features/content/presentation
```

预期：第 1 条只在 `rule_profile_resolver.dart`（写来源）与 `rule_profile.dart`（类型定义 / 反序列化）；第 2 条 `rule_profile_resolver.dart` 无 `.sort(`；第 3 条只有 `class_rule_set.dart` 的定义与解析器调用；第 4 条无输出（一律经 `RuleFieldPath`）。

- [ ] **步骤 5：Commit**

```bash
git add apps/client_flutter/test/rules/s3_override_end_to_end_test.dart \
        apps/client_flutter/test/rules/homebrew_class_end_to_end_test.dart
git commit -m "test(rules): 覆盖 / 勘误场景端到端验收

两个包的同对齐键条目按列合并、priority 生效、同 tier 冲突被记录并可关闭覆盖
回退，replace 清空未声明列——全部经真实导入器与解析链验证。"
```

---

## 验收标准（可执行门禁）

1. **列级合并核心验收**：`test/rules/spellcasting_column_merge_test.dart` 的
   「条目只覆盖 `prepared`，档案的 `slots` / `mode` / `ability` 仍然生效」通过；
   `test/rules/resource_column_merge_test.dart` 的「同 id 只覆盖 `recovery`」通过。
2. **来源可追溯被消费**：角色页（法术位 / 资源 / 规则来源区）与导入预览都出现来源文案；
   `test/character_rule_sources_ui_test.dart` 与 `test/content_import_rule_sources_test.dart` 通过；
   `ResolvedClassRules.fieldSources` 的键是**列级路径**（`spellcasting.prepared` 等）。
3. **`mode: patch | replace`**：`test/rules/class_merge_mode_test.dart` 通过；非法值导入报 `invalidMergeMode`（path `$.entries[i].structured.classRules.mode`）。
4. **`priority`**：manifest `priority` 0..1000（缺省 0）→ tier = 100 + priority；非法值导入报 `invalidPriority`（path `$.priority`）；
   `local_content_packages.priority` 存在，`schemaVersion == 14`，v13 → v14 迁移后 `priority == 0` 且既有包数据不变（`test/package_priority_migration_test.dart`）。
5. **覆盖冲突 UI**：同 tier 抢同一列 → `ResolvedClassRules.conflicts` 非空 → 角色页提示并可选定来源（`data.ruleOverrides.pinned`）。
6. **关闭覆盖回退内置**：角色页可"使用内置档案"；关闭后经 `CharacterRuleProjector` 再派生，数值回到内置档案。
7. **向后兼容**：不写 `priority`、不写 `mode` 的包，解析结果与升级前**逐项相等**（`test/rules/rule_profile_resolver_test.dart` 既有断言不改语义）；
   老存档（无 `ruleOverrides` / `classRuleSources` / `classRuleConflicts`）打开后数值不变。
8. **不静默失败**：`invalidMergeMode` / `invalidPriority` / `incompleteResourcePatch` 都是导入期 error，`path` 精确；坏来源数据读回时降级为"来源未知"而不是猜成内置档案。
9. **唯一实现**：任务 13 步骤 4 的四条 grep 全部符合预期。
10. **全绿门禁**：`npm run check`、`npm run test:scripts`、`npm run lint:design` 全绿；客户端测试数量只增不减（基线 1237 通过 / 6 跳过）。

---

## 风险与已知限制

| 风险 / 限制 | 说明与缓解 |
|---|---|
| 列级合并改变既有包的解析结果 | 只有"条目部分声明 `spellcasting`"的包会变（从"整块替换"变成"逐列回退"）——这正是本轮的目标行为，且方向是**从丢失数值变成补齐数值**。`replace` 声明可恢复旧的"以我为准"语义。任务 2 / 3 必须跑全量客户端测试，任何失败都按"行为变化"逐条记录，不得放宽断言 |
| 条目显式 `resources: []` **不再清空档案资源** | 旧"整块替换"语义下 `resources: []` 会把档案资源全删掉；按 id / 列合并后它只表示"这个条目没有新增资源"，档案同 id 资源继续生效。这是**有意的行为变化**：唯一清空手段是 `classRules.mode: "replace"`（D4）。锁定用例在 `test/rules/resource_column_merge_test.dart`（"条目显式 resources: [] 不清空档案资源"） |
| 混合形态的 `maximum` 曾整条静默消失 | 最高 tier 声明 `{"table": …}`、低 tier 是常量 / 公式时，旧 `_mergeResourceMaximum` 会把低 tier 的 `MaxSpec` 丢掉（`table == null` 直接返回），于是"档案 `maximum: 2` + 勘误 `{"table": {"20": 5}}`"让 1..19 级资源整条消失（违反 §3.12）。批次 A 改为把各 tier 的 `MaxSpec` 用 `withFallback` 分层保留，逐级回退到常量 / 公式并在运行期再算；两条真实数值用例（档案常量 / 档案公式 + 勘误表）锁定 |
| `replace` 的语义容易与 `spellcasting.mode` 混淆 | `invalidMergeMode` 的错误消息明确提示 `spellcasting.mode` 的位置；`kClassRuleFields` 的 `unknownField` 建议逻辑（`_suggestion`）按前 3 个字符匹配，`mode` 不会再触发"是否想写…" |
| 补丁资源放宽了 `name` / `maximum` 必填 | 放宽只发生在**条目**侧；档案侧新增 `_validateArchiveResources` 保持 fail-fast；条目侧由 `incompleteResourcePatch` 在导入期拦住。运行期 `resourcesAt` 对 null 采取"跳过"并带 `assert` |
| 列内**逐级**合并不支持 | 勘误若只改某一级的 `prepared`，必须重述整列的表（§3.12 的"低于最早声明等级 = 未声明"会被放大）。这是刻意的取舍（与 `Table` 的既有语义一致，且避免"三处优先级"），记入 `docs/README.md` §7.7 已知限制 |
| 跨包冲突的判断依赖"同 tier" | 默认 priority 都是 0 ⇒ 任何两个改同一列的包都是同 tier，都会进冲突列表。好处是"默认就能看见冲突"；坏处是包多时提示较多。缓解：冲突只按**列**登记、去重后按字段路径排序，UI 一次列出全部 |
| `priority` 只在包级 | 无法"只让某一条勘误生效"。缓解：拆包是最自然的表达方式（一个勘误一个包），且包级才能落 Drift 列。条目级 priority 见「待用户确认」第 2 条 |
| 全局索引的性能与新鲜度 | `RuleOverrideIndex` 是内存 Map，构建一次 O(条目数)；每次打开详情页重建（条目量级 1e3）。包增删 / 启用切换后**下次打开**生效；不引入全局可变状态 |
| 关闭覆盖后角色数据被改写 | 关闭覆盖会重新派生并保存角色（数值变化是用户点下去的结果）。UI 必须在按钮旁给出"使用内置档案"的动作语义，不做静默改写；`onReapplyRules` 走既有的 `updateCharacter` 保存链路 |
| 老存档 `classResources` 快照优先 | `CharacterSheet.classResources` 优先读 `data.classResources` 快照；因此**升级前建的老角色**不会自动看到新的覆盖结果，直到再派生（打开角色页会经 `CharacterRuleProjector` 重新派生并覆盖快照键）。这是既有行为（契约 §3.12 的"再派生"链路），不是本计划引入的倒退 |
| 任务 2/3 的 `_OrderedDeclaration` 脚手架残留 | 它是完成任务 2 必需的最小形状，但**必须在任务 7 步骤 5 删除**（换成 `RuleOverrideDeclaration` + `RuleOverrideOrder`），否则就是"两套声明类型 + 两处排序"。任务 13 的 grep 会检查解析器里既没有 `_OrderedDeclaration` 也没有 `.sort(` |

---

## 待用户确认的规格含糊 / 互相矛盾之处（**不要擅自决定**）

以下 8 条在规格里没有定义或与实现现状不一致。本计划为每条选了一个**可执行且向后兼容**的默认值，并在正文里标注了假设；实现前需要用户确认，确认结果若与假设不同，只需改对应任务的少量代码（都已被隔离在单一文件）：

1. **`mode: "patch" | "replace"` 的声明位置未定义**。规格 §11 只写"`mode: "patch" | "replace"` 声明"，没说写在哪一层。本计划假设放在 **`structured.classRules.mode`**（`classRules` 块顶层第 5 个字段）。替代方案：包级 manifest 字段（一个包一种语义）、或条目 `structured.classRulesMode`（把块形状拆到两个键）。
2. **`priority` 的作用域未定义**。本计划假设是**包级 manifest 字段**（要求"含 Drift 迁移"意味着它必须落库，而落库的位置只有 `local_content_packages`）。替代方案：条目级 priority（不落包表，也不需要 Drift 迁移，与"含 Drift 迁移"的要求矛盾）。
3. **`priority` 的范围与默认值未定义**。本计划定 **0..1000、缺省 0**，`tier = 100 + priority`。若用户希望"priority 就是 tier"（即内置档案 0、包 priority 直接当 tier、缺省 100），需要改 `RuleOverrideDeclaration.tier` 一处。
4. **"勘误如何关联到已指向别的包条目的角色"未定义**。规格 §1.2-G3 提到 `replaces` relation "从不生效"，但 §11 没把 `replaces` 列进 S3。本计划假设用**对齐键（条目 id 末段）相同**来关联；替代方案：只认 `relations: [{type: "replaces", targetId: ...}]`（更精确，但需要 extra 索引与导入期校验）。
5. **`replace` 对"未声明的列"的语义未定义**。本计划定：`replace` 之后**更低 tier 不再提供任何列**（未声明列一律未声明）。替代方案：`replace` 只对"声明过的字段所在的顶层字段"整体生效（`spellcasting` 整块 replace，`hitDie` 仍可回退）——粒度更细但更难解释。
6. **冲突是导入 error 还是运行期提示未定义**。本计划定：**运行期提示 + UI 选择**（`ResolvedClassRules.conflicts`，不进 `ContentImportReport.errors`），因为导入单个包时看不到别的包，冲突不是该包的错；导入期只校验 `mode` / `priority` / 补丁资源的**形状**。替代方案：导入时扫描在库条目并报 error/ warning。
7. **列级合并下"表列"的取值语义未定义**。本计划沿用 §3.12 的既有语义：被较高 tier 声明的列**整表负责**，该列未声明的等级是"未声明"（`slots` / `slotLevel` / `maximumSpellLevel` 仍按 §3.3 回退 `archetype`）。替代方案：列内逐级回退到更低 tier 的同名表（"勘误只改 20 级的 `prepared`"可写一行，但优先级变成三级、更难解释）。
8. **规格与现状的其它不一致**（任务 12 顺手修正，非决策）：
   - 规格 §3.7 的 `RuleFieldSource.field` 注释写"**整字段粒度**"、§3.6 写"列级来源在本契约下无法产生"、§4.1 写 `fieldSources`"**本轮 UI 未消费**"——三处都必须改（任务 12）；
   - 规格 §3.12 表格里写 `content_character_rules_view.dart`，实际路径是
     `apps/client_flutter/lib/src/features/content/presentation/widgets/content_character_rules_view.dart`（漏了 `widgets/`）；
   - `docs/README.md` §5.1 写"Drift，`schemaVersion = 13`，19 张表"——迁移后是 14（任务 6 改代码/测试，任务 12 改文档）。

---

## 决策（2026-09-12，项目负责人已定，覆盖上节含糊清单）

上节 8 条里，1 / 2 / 3 / 5 / 6 / 8 采用计划给出的默认值；**第 4、7 条改按下面执行**。
实现时以本节为准；上节对应段落保留作背景。

### D1 `mode` 位置：`structured.classRules.mode`
取值 `patch`（缺省）| `replace`；非法值报 error（code `invalidMergeMode`）。
`kClassRuleFields` 增加 `mode`。**不写 `mode` 的包行为不变**（等价于 `patch`）。

### D2 `priority`：包级 manifest 字段
范围 `0..1000`，缺省 `0`；有效 tier = `kEntryTier + priority`（内置档案仍是 `0`）。
落库到 `local_content_packages`（`schemaVersion` 13 → 14，写迁移）。缺省 `0` 保证旧包行为不变。

### D3 勘误的对齐方式：**条目 id 末段**（与内置档案同一套对齐键），**不引入跨包 `replaces` 关系**
- 理由：契约里"对齐键 = 条目 id 末段"已经是唯一身份口径（`builtinSlugRequiresExplicitRules`
  就是靠它）。用同一个键做跨包覆盖，语义一致、零新机制；而跨包 `replaces` 会与
  "导入期校验每个 `relation.targetId` 必须在本包内"直接冲突，需要放宽链接校验 +
  运行期跨包解析，属于额外一大块工作。
- 因此：两个包各自声明 `class/ fighter` 时，它们按 tier/priority 合并到同一个职业上，
  冲突按 D6 处理。**`replaces` relation 的跨包语义明确不在 S3 范围**（在计划与规格里写明）。
- 角色侧：角色只记条目身份（id 末段 + 声明范围），所以在库包集合决定最终数值——
  这正是"关闭覆盖回退内置"能做到的前提（见任务 10）。

### D4 `replace` 的语义：该条目**独占**这个职业的规则块
更低 tier（档案与更低 tier 的条目）**不提供任何列**；未声明的列就是"未声明"，不回退。

### D5 **表列的合并粒度：`patch` 下按"每个等级"回退**（**改自计划默认值，重点**）
- `patch`：对**每一个等级**独立取"声明过该等级的最高 tier"；该等级在所有 tier 都没声明 →
  未声明。列级同样如此（`mode` / `ability` / `archetype` / `slots` / `slotLevel` /
  `prepared` / `cantrips` / `maximumSpellLevel` 各列独立）。
- 为什么改：场景 D（覆盖/勘误）是明确在范围内的需求，而"整个表列由最高 tier 独占"会让
  **"只把法师 20 级准备法术从 25 改成 24"必须重述整列 20 行**——这正好违反用户对
  "自定义程度与方便程度都必须高"的要求。按等级回退让勘误包只写
  `"prepared": {"20": 24}` 一行即可，其余 19 级自动来自档案。
- `replace`：整块独占（D4），作为"我就是要重述"的显式逃生口。
- 与 §3.3「自身表 → 原型表」的关系：先做"条目之间/条目与档案"的逐级合并，
  得到该职业自身各列的表；**之后**才按 §3.3 决定该列未声明时是否回退 `archetype`。
  两级关系不要混在一起，顺序在代码与注释里写死。
- 这条会让"按等级回退"成为唯一实现点：必须有单一函数（例如
  `mergeRuleTable(lower, upper) -> Table`）承担，`slots` / `prepared` / `cantrips` /
  `maximumSpellLevel` / `slotLevel` 全部走它，`resources.maximum.table` 同理。
  **实现落点（批次 A 已落地）**：`rule_values.dart` 的 `firstDeclaredAt` 是"哪一层声明了
  这个等级"的唯一原语；`mergeRuleTableLevels`（施法表列）与 `MaxSpec.resolve` 的
  `withFallback` 层链（`resources.maximum`，额外支持常量 / 公式形态）都只经过它。
- **`recovery` 不逐级合并（已落地，§3.4）**：常量形态与 `{"table": …}` 形态是同一条来源
  路径，整列由"声明过 `recovery` 的最高 tier"负责；该表未声明的等级落默认 `longRest` 或
  沿用最后声明值，**不**回退低 tier 的 `recovery` 表。恢复语义是枚举，逐级拼接两张表会产出
  作者没写过的混合语义；锁定用例在 `test/rules/resource_column_merge_test.dart`。

### D6 冲突：运行期提示 + UI 选择，不进导入 error
导入期只校验形状（`mode` / `priority` / 补丁资源 / 表形状）。两个包在**同一 tier**声明
**同一列同一等级**且取值不同 → 记为 `RuleOverrideConflict`，在角色页提示并由用户选择；
无用户选择时的确定性回退 = 按 `originId` 取**升序首位**（等价于包 id 字典序**最小**者；
角色自身条目在同 tier 同 mode 时优先；写进注释与文档，保证同样输入同样结果）。

冲突判据（实现期收紧）：**更低优先级那条显式写下的等级，被更高优先级在该级的有效值
（显式或沿用）遮住且取值不同**才登记；只改不同等级且互不遮挡（真互补）不登记。
（原稿的"声明区间有交集"看不到"高优先级沿用值压住别人显式写的等级"这种静默失效。）

同一 tier 的 `replace` 截断（D4）丢弃的同 tier `patch`：只在 `replace` **也声明了该列**时
登记冲突（`replace` 未声明的列就是未声明，不是静默数值变化）；pin 到该 `patch` 可**逐列**
把该列拿回来（pin 在截断之后按列生效，被丢弃的声明仍作为该列的候选）。

### D7 文档同步（任务 12）必须一并做掉
规格 §3.6「列级来源无法产生」、§3.7「整字段粒度 / 本轮 UI 未消费」、§3.8「没有 priority」、
§11 的 S3 行、§5 新增 code；`docs/README.md` §5.1（`schemaVersion` 13 → 14）、§7.7、§9.2、§16；
以及 §3.12 里 `content_character_rules_view.dart` 的路径漏了 `widgets/`。


---

## 事后注记（2026-09-13 收口）

**任务 1–13 全部落地**，另有 4 个修复批次（C1 / C2 / C3 / 验证后修复）来自**独立审查**：

| 批次 | commit | 修掉的真缺陷（都是静默数值或静默丢失） |
|---|---|---|
| C1 | `16b3f54` `268173f` `bb296f3` | pin 整链越权（pin 一列会连带提升整条来源）、旧备份恢复因非空列回滚、冲突判定过宽 |
| C2 | `1155180` `a0f43e2` `5f228b7` `c372c00` | **派生快照残留被关闭来源的旧数值**（H，主路径静默错误）、冲突对话框把未改动列静默 pin、`isDisabled` 两套实现语义分叉、`_maximumLevels` 跨形态同值误报冲突、编辑器/向导/短休漏带 priority 或覆盖 |
| C3 | `bab2111` `e02ea09` `f2081d4` | `classResources` getter 把"已派生为空"当"未派生"回退到**不带覆盖**的解析、6 处测试盲区（mutating 实现不红）、战役视图 priority 失效 |
| 验证后 | `8dc5290` | `CampaignAwareContentRepository.packagePriorities()` 键不带 `local:` / `campaign:` 前缀 → 战役装配下 priority 静默归零；`QuickBuildService` 不带 entries/priority/覆盖 → 同 slug 两包时与规则驱动路径分叉；`spellSaveDc` 自解析（与 L 同类） |

**偏离计划的决策**：D6 的"取后者"改为"取升序首位"（与实现一致）；`replace` 未声明的列**不登记**冲突
（D4 语义：未声明就是未声明）；pin 可逐列取回被同 tier `replace` 丢弃的 `patch`；`_withoutPinSolvedConflicts`
（pin 已决定的列不再提示冲突）；`quick_build` 也写入 `classRuleSources`/`classRuleConflicts`。

**收口基线**：`npm run check` EXIT=0（客户端 **1582 通过 / 6 跳过**，服务端 24 套件 / 355）、
`npm run test:scripts` 38 OK、`npm run lint:design` 0 error / 0 warning、
`npm run validate:phb-private` PASS；`origin/main` = `40eb04f`。

**仍未做**：S4 作者 GUI 与 `.dndpack` 导出；PHB 提取器产出 `optionType: "spell"` 选择；
背景条目驱动技能授予；战役视图覆盖 id 的前缀口径统一（见 §7.7 已知限制）。
