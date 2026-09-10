# 星界骑士（示范自制职业包）

这是一份**完整的第三方职业包**，用来检验规则契约的"自定义程度"与"方便程度"。
它只使用新契约的形状（`structured.classRules` + `rules.progression` 的选择系统），
不含任何规则书正文，全部内容为原创示例。

## 它演示了什么

| 契约能力 | 在包里的位置 |
|---|---|
| 自定义生命骰 / 豁免 | `class.structured.classRules`（`hitDie: 10`、`savingThrowAbilities: [int, wis]`） |
| 自定义施法模型与逐级法术位 | `classRules.spellcasting`：`archetype: half-caster` **+ 稀疏覆盖** `slots`/`prepared`/`maximumSpellLevel`（5 级起比圣武士更宽，演示覆盖生效） |
| 逐级资源 + 恢复语义 | `classRules.resources`：星界涌动（`formula: level`、短休恢复 1 次）、星界守护（稀疏表、长休、3 级起） |
| 逐级特性 | `rules.progression[].grants`（`kind: feature` 指向特性条目） |
| 同一效果在多个等级重复 | `{"levels": [4, 8, 12, 16], "grants": [...]}` —— 只写一份 |
| 技能选择 | `optionType: "skill"` 的 choice，`options: ["奥秘", ...]` 字符串自动补熟练（唯一写法，没有 `skillChoice` 简写） |
| HP / AC / 速度加值 | 6 级 `kind: hitPoints`（每级 +1）、10 级 `kind: armorClass`（+1）、7 级 `kind: speed`（+10） |
| 属性加值 | 4/8/12/16 级 `kind: ability` |
| 值选项（内联 grants，不建条目） | 1 级战斗风格里的 `options`「星界之势」 |
| 装备 A / B 方案 | 1 级 `optionType: equipmentBundle` + 两个 `equipmentBundle` 条目 |
| 法术选择 | 1 级 `optionType: spell` + `countsToward: prepared`；子职 3 级 `countsToward: null`（誓约法术不占上限） |
| 子职选择与子职进阶 | 3 级 `optionType: subclass`；`oath-of-the-astral` 自带 3/7/15/20 级进阶 |
| 可重复选取 | 2 级「星界祈唤」`repeatable: true`，上限 2 |
| 前置依赖 | 2 级祈唤 `requires: [{ability: "int", minimum: 13}]` |
| 分组与帮助文案 | `group` / `help` |

共 26 个条目：1 职业 / 1 子职 / 19 职业特性（含 3 祈唤）/ 3 专长 / 2 装备方案，9 个选择定义。

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

契约尚未实现（见 `docs/plans/2026-09-10-rules-contract-core.md`）。
用**当前**代码（commit `f228384`）载入本包，建一个 5 级星界骑士会得到：

```
HP=38（按默认 d8 算；声明的 d10 应为 44）
AC=12  speed=30（10 级才有的 +1 AC 与 7 级 +10 尺未生效）
豁免=全部 false（声明的 智力/感知 未被读取）
法术位=null   职业资源=null   准备上限=null   施法属性=null
待处理选择=5（rules.choices 是旧机制，能部分工作；requires/repeatable/countsToward 被静默忽略）
```

即"**导入成功，但职业规则几乎全部不生效**"。实现计划中的任务 8 会用本包做端到端验收：
同样输入应产出 HP=44、豁免 智力/感知、5 级法术位 4/3、准备上限 7、星界涌动 5 次、星界守护 1 次。
