# 星界骑士（示范自制职业包）

这是一份**完整的第三方职业包**，用来检验规则契约的"自定义程度"与"方便程度"。
它只使用新契约的形状（`structured.classRules` + `rules.progression` 的选择系统），
不含任何规则书正文，全部内容为原创示例。

## 它演示了什么

| 契约能力 | 在包里的位置 |
|---|---|
| 自定义生命骰 / 豁免 | `class.structured.classRules`（`hitDie: 10`、`savingThrowAbilities: [int, wis]`） |
| 自定义施法模型与逐级法术位 | `classRules.spellcasting`：`archetype: half-caster` 提供 `slots` 与 `maximumSpellLevel`；**`prepared`/`cantrips` 是职业独有字段**（2024 官方表逐职业不同，原型不提供），本职业写成 20 项数组、比圣武士每级 +1；`maximumSpellLevel` 用稀疏表覆盖原型以演示覆盖生效 |
| 逐级资源 + 恢复语义 | `classRules.resources`：星界涌动（`formula: level`、短休恢复 1 次）、星界守护（稀疏表、长休、3 级起） |
| 逐级特性 | `rules.progression[].grants`（`kind: feature` 指向特性条目） |
| 同一效果在多个等级重复 | `{"levels": [4, 8, 12, 16], "grants": [...]}` —— 只写一份 |
| 技能选择 | `optionType: "skill"` 的 choice，`options: ["奥秘", ...]` 字符串自动补熟练（唯一写法，没有 `skillChoice` 简写） |
| HP / AC / 速度加值 | 6 级 `kind: hitPoints`（每级 +1）、10 级 `kind: armorClass`（+1）、7 级 `kind: speed`（+10） |
| 属性加值 | 4/8/12/16 级 `kind: ability` |
| 值选项（内联 `options`，不建条目） | 1 级战斗风格里的 `options`「星界之势」（`id` / `label` / `description`） |
| 装备 A / B 方案 | 1 级 `optionType: equipmentBundle` + 两个 `equipmentBundle` 条目 |
| 法术选择 | 1 级与子职 3 级都是 `optionType: spell` + `optionTags` + `maximumOptionLevel` |
| 子职选择与子职进阶 | 3 级 `optionType: subclass`；`oath-of-the-astral` 自带 3/7/15/20 级进阶 |

共 30 个条目：1 职业 / 1 子职 / 19 职业特性（含 3 祈唤）/ 3 专长 / 2 装备方案 / 4 法术，9 个选择定义。

包格式：**`formatVersion: 3`**（唯一被接受的版本；1/2 会被整包拒绝并提示重新生成）。
`classRules` 只有 4 个字段：`hitDie` / `savingThrowAbilities` / `spellcasting` / `resources`——
技能选择、法术选择、特性都属于"选择与效果"，写在 `rules.progression[].choices` / `.grants` 里。

## 如何打包成 `.dndpack`

```bash
cd samples/homebrew-astral-knight
zip ../astral-knight.dndpack manifest.json entries.json
```

Windows PowerShell：

```powershell
Compress-Archive -Path samples/homebrew-astral-knight/manifest.json,
                        samples/homebrew-astral-knight/entries.json `
                 -DestinationPath astral-knight.zip
```

`manifest.json` 与 `entries.json` 必须位于压缩包**根目录**，可选 `assets/` 放图片。

## 当前状态（重要）

**本包可被当前版本的导入器整包导入**（`report.errors` 为空、`report.valid` 为 true），
并由 `apps/client_flutter/test/rules/sample_packages_import_test.dart`（整包导入）与
`apps/client_flutter/test/rules/homebrew_class_end_to_end_test.dart`（真实建角色 + 数值核对）
守卫——包写坏就会红。

**选择系统的运行时字段已经全部落地并生效**（计划 2，2026-09-12）：`repeatable`（2 级祈唤可重复选取）、
`group` / `help`（选择面板分组标题与说明）、`countsToward`（共享额度池）、`requires`（前置不满足
则不可选）、内联 `options[].grants`（选中即生效）。本包**已在用**这些字段；导入期只做取值/引用校验
（`invalidCountsToward` / `invalidRequires` / `invalidAutoGrant` / `invalidOptionRef` …），
不再"存在即拒收"（契约 §5.1 的 `unsupportedChoiceField` 已退役）。

`docs/README.md` §9.2.7 逐字嵌入了本包的 `manifest.json`、职业条目、一条法术条目与一条特性条目，
并由 `scripts/test_release_packaging.py::test_readme_examples_match_tracked_samples` 做 JSON 深比较
守卫：**改这里就必须同步改文档**（反之亦然）。

其余契约能力（自定义生命骰/豁免、逐级法术位与准备表、逐级资源、逐级特性、
HP/AC/速度/属性加值、技能选择、装备 A/B、子职）同样已经生效。
