# 规则契约与规则档案（S1+S2）设计规格

- 状态：待用户审查（审查通过后进入实现计划）
- 范围：子项目 S1（规则核心数据化）+ S2（契约扩展与导入校验）
- 验收场景：A（2024 补充包）、B（全新自制职业）、D（覆盖与勘误，仅打地基）
- 明确不做：C（自定义技能/属性、自定义 AC 公式、自定义休息语义）、S3（patch/replace 声明与冲突 UI）、S4（作者 GUI 与 `.dndpack` 导出）

> 本文是实现规格。面向使用者的契约说明在实现完成后写入 `docs/README.md` §9.1；
> 本文不替代 `docs/README.md` 作为项目唯一事实来源的地位。

---

## 1. 背景与现状（实测）

### 1.1 真实内容源已经在按一套契约书写

`private-imports/phb-2024-v2-bundle.json`（formatVersion 2，id `phb-2024`，1106 条）：

| 已声明 | 位置 |
|---|---|
| `hitDie: "d12"`（字符串）、`savingThrows: "力量与体质"`（中文散文）、`skills: "选择2项：…"`（中文散文） | `structured`（12 个 class 条目全有） |
| `spellcastingAbility` + `spellcasting{ mode, ability, listTags, progression[20 行] }`，行内 `maximumSpellLevel / maximumCantrips / maximumLeveledSpells` | `structured`（8 个施法职业） |
| 660 个 `spellSlot:<n>` resource grant（7 个有环位职业）；20 个 `classResource:pactMagicSlots` grant（邪术师，带 `data.spellLevel` 与 `data.recovery`） | `rules.progression[].grants` |
| 464 个 `feature` grant、12 个 `choice` | `rules` |

真实包**没有**声明：职业豁免数值表、准备法术上限标志、战士/野蛮人的任何职业资源。

### 1.2 代码是它的补丁，因此存在 7 个具体缺口

| # | 缺口 | 现状证据 | 后果 |
|---|---|---|---|
| G1 | 职业识别靠中文子串匹配 | `Dnd5eRules._hitDie` / `_classSavingThrows` / `classResources` / `spellSlotMaximums` / `usesPactMagic` 都在 `classSummary.contains('战士')` | `星界游侠` 会被当成游侠推导出半施法者表；第三方职业名字稍像核心职业即被错误推导 |
| G2 | 4 个 grant kind 是空转 | `hitPoints` / `ability` / `conditionResistance` / `note` 只有图标渲染（`character_editor_page.dart:2617-2622`） | 包写进去完全无效，"导入成功但功能不存在" |
| G3 | `replaces` 关系从不生效 | 枚举在 `ContentRelation.allowedTypes`，全仓库无消费方 | 无法房规/勘误 |
| G4 | `structured` 规则字段零校验 | 导入器只校验 entry 必填字段与 grant 引用存在性 | 写错不报错，静默降级为错误角色卡；`_validSkills` 还**静默丢弃**未知技能 |
| G5 | 准备法术上限依赖一个真实包没有的开关 | `StructuredClassRules.preparedSpellLimit` 要求 `structured.preparedSpellcasting == true` | 真实包角色**根本没有**准备法术上限，尽管包里已有 `maximumLeveledSpells` |
| G6 | 邪术师契约魔法双重表示 | 包里是 `classResource:pactMagicSlots` grant，代码里又有 `pactSlotMaximums` 硬编码表 | 同一事实两处维护，短休恢复语义两套 |
| G7 | 作者侧无 GUI、无导出 | `LocalHomebrewContentService` 无 UI 调用者（仅测试）；资料包页只有导入/删除 | 属于 S4，本次不做 |

### 1.3 本次目标

把这套事实契约**正式化、补全、可校验、可覆盖**，并把代码里的补丁表搬进随包发布的规则档案：

1. 删除全部中文子串职业匹配，改为「条目声明 → 档案按 slug 补齐 → 未声明就不猜」。
2. 让一个完全自制的职业条目仅靠 `structured.classRules` 的 6 个字段即可产出正确的 HP / 豁免 / 技能选择 / 法术位 / 职业资源 / 准备法术上限。
3. 导入时对规则字段做精确路径校验（error 阻断、warning 提示），消除静默降级。
4. 处置 4 个空转 kind；消除邪术师双重表示。
5. 为 S3 铺好地基：字段级合并 + **来源可追溯**，使"被哪个包覆盖"可显示、可回退。

---

## 2. 术语

| 术语 | 含义 |
|---|---|
| **规则档案（rule profile）** | 一份只含规则数值、不含任何规则书正文的配置。内置档案随客户端发布；外部包可通过条目声明参与合并 |
| **职业规则块（class rules fragment）** | 描述一个职业规则数值的对象。内置档案的 `classes.<slug>` 与条目 `structured.classRules` 是**同一形状** |
| **原型（progression archetype）** | 具名的进阶模板（`full-caster` / `half-caster` / `third-caster` / `pact` / `none`），用于简写 |
| **解析链（resolution chain）** | 从"角色所选职业条目"到"该职业规则数值"的确定过程，见 §3.6 |
| **来源（provenance）** | 每个解析出的字段记录它来自内置档案 / 哪个包条目，供显示与后续回退 |

---

## 3. 契约

### 3.1 内置档案文件

路径：`apps/client_flutter/assets/rules/dnd5e-2024.rules.json`

```jsonc
{
  "rulebookVersion": 1,          // 档案格式版本（整数，必须为 1）
  "system": "dnd5e-2024",
  "abilities": ["str", "dex", "con", "int", "wis", "cha"],
  "skills": [
    { "name": "杂技", "ability": "dex" },
    // …共 18 项，与 Dnd5eRules.skills 一致
  ],
  "progressions": {
    "none":         { "slots": [] },
    "full-caster":  { "slots": [[2],[3],[4,2],"…20 行"],
                      "prepared": [4,5,6,"…20 个数"],
                      "cantrips": [3,3,3,"…"],
                      "maximumSpellLevel": [1,1,2,"…"] },
    "half-caster":  { "minimumLevel": 1, "slots": [[2],[2],[3],"…"],
                      "prepared": [2,3,4,"…"], "cantrips": [0,"…"],
                      "maximumSpellLevel": [1,1,1,"…"] },
    // third-caster 省略 prepared / cantrips：2024 奥法骑士与诡术师的已知/准备
    // 上限不在职业表里，不臆造数值（见 §11）
    "third-caster": { "minimumLevel": 3, "slots": [[],[],[2],"…"] },
    "pact":         { "minimumLevel": 1, "slots": [[1],[2],[2],"…"],
                      "slotLevel": [1,1,2,2,3,"…20 个数"],
                      "prepared": [2,3,4,"…"], "cantrips": [2,2,2,"…"] }
  },
  "classes": {
    "barbarian": {
      "hitDie": 12,
      "savingThrowAbilities": ["str", "con"],
      "skillChoice": { "count": 2, "options": ["驯兽","运动","威吓","自然","察觉","求生"] },
      "spellcasting": { "mode": "none" },
      "resources": [
        { "id": "rage", "name": "狂暴",
          "maximum": { "byLevel": [2,2,3,3,3,4,4,4,4,4,4,5,5,5,5,5,6,6,6,6] },
          "recovery": "shortRestOne" }
      ]
    }
    // …共 12 个核心职业
  }
}
```

**内容边界（合规）**：档案只允许存放数值与枚举，**不得**包含规则书正文、法术描述、怪物数据或任何散文段落。

**两份参照清单**：`abilities` 与 `skills` 是**校验参照表**（场景 C 已排除扩展），以**内置档案**为唯一权威；包若自带同名清单，解析器忽略它并给出 warning（§5.2 `ignoredGlobalList`）。因此第三方的豁免键、技能名、`formula ability:<key>` 都必须落在内置清单内。

**档案键即职业对齐键**：`classes` 的键是 12 个核心职业的规范英文 slug（`barbarian`、`bard`…）。条目要继承内置数值，其 `slug` 必须等于其中之一；用中文名或其它 slug 的自制职业不会命中内置数值（这是刻意的：不猜）。

**行为等价要求**：内置档案的数值必须与改造前的代码表**逐项相等**（含战士/野蛮人资源次数与恢复语义），即本次改造对"只装内置档案"的使用者是行为保持的。

### 3.2 职业规则块（两个载体同一形状）

**载体 A**：内置档案的 `classes.<slug>`（见 §3.1）。
**载体 B**：任意 `type: "class"` 条目的 `structured.classRules`。

```jsonc
"structured": {
  "classRules": {
    "hitDie": 10,
    "savingThrowAbilities": ["wis", "cha"],
    "skillChoice": { "count": 2, "options": ["洞悉","医药","说服","宗教"] },
    "spellcasting": {
      "mode": "prepared",
      "ability": "cha",
      "listTags": ["spell-list:astral"],
      "archetype": "half-caster",
      "progression": [ { "level": 5, "maximumSpellLevel": 2,
                         "maximumCantrips": 0, "maximumLeveledSpells": 6 } ],
      "slotOverrides": { "5": { "1": 4, "2": 2 } }
    },
    "resources": [
      { "id": "astral-surge", "name": "星界涌动",
        "maximum": { "formula": "level" }, "recovery": "shortRestOne" },
      { "id": "astral-ward", "name": "星界守护", "startsAtLevel": 3,
        "maximum": { "byLevel": [0,0,1,1,2,2,2,3,3,3,4,4,4,5,5,5,6,6,6,7] },
        "recovery": "longRest" }
    ]
  }
}
```

字段全集与语义（**只描述"职业级静态事实"**；随等级解锁的效果统一由 `rules.progression[].grants` 承担，见 §3.5）：

| 字段 | 类型 | 必填 | 语义 |
|---|---|---|---|
| `hitDie` | int 或 `"dN"` 字符串 | 否* | 生命骰面数，必须 ∈ 4..20。缺省时 HP 只按体质调整值计，见 §3.6 第 3 步 |
| `savingThrowAbilities` | string[]（属性键） | 否* | 豁免熟练，元素必须 ∈ `abilities` |
| `skillChoice` | `{count:int, options:string[] 或 "any"}` | 否 | `count` ∈ 0..options.length（`"any"` 时上界为技能总数）；`options` 元素必须 ∈ `skills` |
| `spellcasting` | object | 否 | 见 §3.3 |
| `resources` | object[] | 否 | 见 §3.4 |

\* 标 `否` 是契约层面的可缺省；但缺 `hitDie` 会导致 HP 无法计算，导入时给 **warning**（§5.2）。

**HP 加值与属性加值不作为 `classRules` 字段**：它们天然是"按等级生效的效果"，统一用 `rules.progression[].grants` 的 `kind: "hitPoints"` / `kind: "ability"` 表达（§3.5），避免同一件事有两种写法。

### 3.3 `spellcasting` 对象

| 字段 | 类型 | 语义 |
|---|---|---|
| `mode` | `"prepared" \| "known" \| "pact" \| "none"` | 施法模型；`none` 表示非施法者 |
| `ability` | 属性键 | 施法属性，必须 ∈ `abilities` |
| `listTags` | string[] | 法术列表过滤标签，透传给 `SpellSelectionPolicy` |
| `archetype` | 原型名 | 简写：从档案 `progressions` 取表 |
| `progression` | object[] | 显式逐级表，行字段 `level`(1..20)、`maximumSpellLevel`(0..9)、`maximumCantrips`(int≥0)、`maximumLeveledSpells`(int≥0)。**逐级优先于 `archetype`**（逐字段） |
| `slotOverrides` | `{ "<charLevel>": { "<slotLevel>": count } }` | 稀疏覆盖法术位；键 1..20 / 1..9，值 int≥0。**按角色等级整级替换**（不与原型逐环合并） |

法术位只有两个来源：`slotOverrides`（显式，最高优先）与 `archetype`（其次）。没有第三个来源。

逐级解析（角色等级 L）：

```
slots         = slotOverrides[L] ?? expand(archetype).slots[L] ?? {}
prepared      = progression(L).maximumLeveledSpells ?? expand(archetype).prepared[L]   // 可能为 null
cantrips      = progression(L).maximumCantrips      ?? expand(archetype).cantrips[L]
maxSpellLevel = progression(L).maximumSpellLevel    ?? expand(archetype).maximumSpellLevel[L]
```

`prepared` 为 `null` 表示**该职业未声明准备/已知上限**：编辑器不施加数量限制，导入时给 warning（§5.2 `missingPreparedColumn`），角色页显示"未声明"。

`pact` 原型的 `slots` 是**单一环阶**：结果形如 `{ "<slotLevel>": count }`（如 5 级邪术师 → `{"3": 2}`），与现有 `spellSlotMaximums` 的返回形状一致；`slotLevel` 数组提供每级环阶。

`mode == "none"` 且未声明 `archetype`/`progression`/`slotOverrides` 时，法术位为空、准备上限为 null。

### 3.4 `resources` 与 `maximum`

```jsonc
{ "id": "string（非空，职业内唯一）",
  "name": "string（非空）",
  "maximum": <MaxSpec>,
  "recovery": "shortRest" | "shortRestOne" | "longRest" | "none",
  "startsAtLevel": 2 }        // 可选，默认 1：该职业等级之前该资源不存在
```

`startsAtLevel` 与 `byLevel` 的关系必须明确：**低于 `startsAtLevel` 的等级一律视为不存在该资源**（`byLevel` 对应项被忽略，即使写了非 0）；`startsAtLevel` 及以上的等级取 `byLevel` 对应项。内置档案里"战士 2 级才有动作如潮"就用 `startsAtLevel: 2` 表达，而不是写一串 0。

`byLevel` 允许出现 0（表示该级上限为 0），但与 `startsAtLevel` 二选一即可，推荐 `startsAtLevel`。

`<MaxSpec>` 只有 5 种写法（**封闭词汇表**，互斥）：

| 写法 | 例 | 语义 |
|---|---|---|
| 固定值 | `{"value": 1}` | 与等级无关 |
| 等级 | `{"formula": "level"}` | 等于职业等级 |
| 属性调整值 | `{"formula": "ability:cha", "minimum": 1}` | 调整值，可带 `minimum` 下限 |
| 系数 × 等级 | `{"formula": "5*level"}` | 系数为非负整数 |
| 逐级表 | `{"byLevel": [20 个数]}` | 必须正好 20 个非负整数 |

`minimum` 可选，对所有写法生效：最终取 `max(结算结果, minimum)`（如诗人激励"魅力调整值，最低 1"）。

`formula` 的封闭语法（正则级）：`level` | `ability:<abilities 中的键>` | `<非负整数>*level` | `<非负整数>`。**不实现通用表达式求值**。

原型对象的 `minimumLevel`：该原型在**低于此等级**时无法术位（`third-caster` = 3、`pact` = 1、`full-caster` / `half-caster` = 1、`none` 无意义）。低于该等级时法术位为空。

### 3.5 合法 grant kind（本次收紧）

`RuleGrantKind` 收敛为 **10 项**：`feature`、`proficiency`、`spell`、`equipment`、`resource`、`action`、`speed`、`armorClass`、`hitPoints`、`ability`。

| 处置 | kind | 说明 |
|---|---|---|
| **实现** | `hitPoints` | 累加进 HP 上限；`value`（固定）或 `formula`（同一封闭语法，按职业等级结算）二选一 |
| **实现** | `ability` | 属性加值，**在派生之前**施加（影响 HP/AC/豁免/技能/法术 DC）；`target` 为属性键，`value` 为加值 |
| **移除** | `conditionResistance` | 无消费方、真实包未使用。移除后误用会在导入时报错，而不是静默无效；抗性/免疫结算记入 §11 待办 |
| **移除** | `note` | 同上；角色卡备注由 `notes` 字段承担 |

`rules.progression[].grants` 的现有语义不变；`kind: "resource"` 继续等价于"往类级资源表按等级写入"（兼容写法，导入时给 warning，§5.2）。`hitPoints` / `ability` 的 `formula` 与 `resource.maximum` 共用同一封闭语法与同一求值器。

### 3.6 解析链（字段级）

输入：角色所选职业的 `ContentEntry`（来自 `build.selections['class']`，或老角色 `data.classIdentity`）。

1. **条目自身声明**：该条目 `structured.classRules`（规范化后的字段）。
2. **档案补齐**：对仍缺失的字段，按该条目的 `slug`（规范化：`trim().toLowerCase()`），其次按 `aliases` 逐项精确匹配，在内置档案与已装规则档案中查找，字段级合并。
3. **未声明即不猜**：仍缺失的字段视为"未声明"：
   - `hitDie` 缺失 → HP 仅按体质调整值计（最低 1），并在角色页与导入报告给出该职业的"未声明"提示；
   - `savingThrowAbilities` 缺失 → 无豁免熟练；
   - `spellcasting` 缺失或 `mode: "none"` → 无法术位、无准备上限、无施法属性；
   - `resources` 缺失 → 无职业资源；
   - 绝不回退到"名字相近的职业"。

老角色（无 `classIdentity`、仅有 `classSummary` 散文）的兼容：`CharacterRuleProjector` 用**精确匹配**（条目 `name` / `slug` / `aliases` 全等，非子串）补写一次 `data.classIdentity`；匹配不到则视为未声明并提示。

### 3.7 来源可追溯

`RuleProfile` 为每个职业的每个字段记录来源：

```dart
class RuleFieldSource {
  final String field;      // 'hitDie' | 'resources' | 'spellcasting.slots' …
  final String originId;   // 'builtin:dnd5e-2024' | 'phb-2024' | 'local-homebrew'
  final int tier;          // 0 内置 / 100 已装包 / 1000 本地自制
}
```

本次只在角色页与导入报告的诊断信息中显示来源；S3 用它实现"被哪个包覆盖 / 关掉覆盖回退"。

### 3.8 优先级（本次范围）

**三档固定优先级，不引入可配置 `priority` 字段**（避免本轮 Drift 迁移；可配置优先级与冲突 UI 属 S3）：

| 档 | 来源 | tier | 平级冲突 |
|---|---|---|---|
| 低 | 内置档案 | 0 | — |
| 中 | 已装内容包（含私有 PHB） | 100 | `LocalContentPackages.installedAt` 较晚者胜（同 slug 字段级） |
| 高 | `local-homebrew` 包（本地自制） | 1000 | — |

### 3.9 兼容与迁移映射

| legacy 写法 | 现状 | 处理 |
|---|---|---|
| `structured.hitDie: "d12"` | 已支持 | 继续支持；规范化为 int |
| `structured.savingThrows: "力量与体质"`（中文散文） | 按属性标签包含关系解析 | 继续解析，导入时 **warning**"建议改用 `savingThrowAbilities`" |
| `structured.skills: "选择2项：…"`（中文散文） | 正则解析，未知技能静默丢弃 | 继续解析，**未知技能改为 warning 并列出被丢弃项** |
| `structured.spellcastingAbility: "cha"` | 独立字段 | 等价于 `classRules.spellcasting.ability`；两者都存在时以 `classRules` 为准 |
| `structured.preparedSpellcasting: true` | `preparedSpellLimit` 的开关 | **废弃**：准备上限改为由 `spellcasting.mode ∈ {prepared, known}` 推导（修 G5） |
| `structured.spellcasting.progression[].maximumLeveledSpells` | 已支持 | 正式成为准备上限来源 |
| `structured.startingEquipmentChoice.maximum` | 已支持 | 不变 |
| `rules.progression[].grants` 的 `spellSlot:<n>`（`kind: "resource"`） | 已支持，进 `spellSlots` | 不变；等价于 `spellcasting.slotOverrides` |
| `rules.progression[].grants` 的 `classResource:<id>` 带 `data.spellLevel` | 进 `classResources`，而法术位另由硬编码表给出（G6 双重表示） | **改为**：翻译为该职业 `spellcasting.slotOverrides`（数量取 `value`，环阶取 `data.spellLevel`），**不再**出现在 `classResources` 中 |
| `rules.progression[].grants` 的 `classResource:<id>` 不带 `data.spellLevel` | 进 `classResources` | 不变 |
| grant `formula` 字段 | 只存储 | 对 `hitPoints` / `ability` / `resource.maximum` 生效（封闭语法）；其他 kind 仍只存储 |

---

## 4. 组件设计

### 4.1 新增

| 组件 | 文件 | 职责 |
|---|---|---|
| `RuleProfile` | `features/rules/domain/rule_profile.dart` | 不可变；`abilities`、`skills`、`progressions`、`classes(slug→ClassRuleSet)`、`fieldSources`；纯查询（`hitDie(slug)`、`savingThrows(slug)`、`skillChoice(slug)`、`spellSlots(slug, level)`、`pactSlotLevel(slug, level)`、`preparedLimit(slug, level)`、`classResources(slug, level)`、`spellcastingAbility(slug)`、`isPact(slug)`）与 `merge` |
| `ClassRuleSet` / `ClassSpellcasting` / `ClassResourceRule` / `MaxSpec` | 同上 | 值对象，含 `fromJson`/校验钩子 |
| `RuleProfileResolver` | `features/rules/domain/rule_profile_resolver.dart` | 纯函数：内置档案 JSON + 条目集合 + tier 表 → `RuleProfile` + `RuleDiagnostics` |
| `RuleDiagnostic` | 同上 | `{path, severity, code, message}`；导入器把它翻译成 `ContentValidationError`（error）或导入警告（warning） |
| `RuleProfileStore` | `features/rules/data/rule_profile_store.dart` | 读资产（`AssetBundle` 可注入）+ 内容仓库条目 → 调 Resolver → `Dnd5eRules.configure(profile)`；负责缓存与内容变更后重建 |

### 4.2 改造

| 位置 | 变化 |
|---|---|
| `Dnd5eRules` | 保留纯运算（`abilityModifier`、`proficiencyBonus`、`saveBonus`、`skillBonus`、`baseArmorClass`、`initiativeBonus`、`attackBonus`、`damageFormula`、`averageHitPointsForHitDie`、`applyHitPointDelta`、`classResourcesAfterRest`、`spellSlotsAfterRest`）；**删除全部职业表与中文匹配**，改为读 `Dnd5eRules.profile`；新增 `configure(profile)` / `profile` 访问器（一次性装配，之后不可变） |
| `structured_class_rules.dart` | 退化为适配器：`structured.classRules` + legacy 字段 → `ClassRuleSet`；`savingThrowAbilities` / `skillChoice` / `startingEquipmentChoice` 保留签名，`preparedSpellLimit` 改由 `spellcasting.mode` 推导 |
| `rules_driven_character_builder.dart` | 职业规则统一从条目声明 + profile 合并读取；新增输出 `data.classIdentity = {entryId, slug, name}`；`hitPoints` / `ability` grant 参与派生（属性加值先于 HP/AC/豁免/技能/DC 计算） |
| `character.dart` | `classResources` getter 改按 `classIdentity.slug` 查 profile（保留 `dataMap['classResources']` 优先） |
| `character_rule_projector.dart` | 为老角色按"精确匹配"补写 `classIdentity`；补写缺失的 `classResources` |
| `quick_build.dart` | 用 `classEntryId` 定位；无 id 时按精确名称匹配一次并固化 `classIdentity` |
| `character_detail_page.dart` | `_slotMaximums()` 兜底改走 profile；未声明字段的提示 |
| `character_editor_page.dart` | 等级摘要与法术选择改走 profile |
| `content_package_importer.dart` | 接入 `RuleProfileResolver` 的 `RuleDiagnostics`；新增 §5 的 error/warning |
| `content_import_report.dart` | `ContentImportReport` 新增 `warnings` 列表 |
| `content_import_preview_dialog.dart` | 次级样式展示 warnings，不阻断确认 |
| `assets/rules/dnd5e-2024.rules.json` | 新增（**仅数值**，随公开构建发布） |
| `pubspec.yaml` | 必须新增一行 `- assets/rules/dnd5e-2024.rules.json`（现有 assets 是逐条声明，不是目录整体声明）；该文件是被 git 跟踪的普通资产，`scripts/build_private_client.ps1` 只改动 `bundled_content.json`，不冲突 |

**不改 `content_schema_registry.dart`**：`ContentFieldSchema.kind` 目前只有 text/integer/decimal/boolean/stringList，无法描述嵌套对象。`classRules` 的校验完全由 `RuleProfileResolver` 负责（导入期），而 `normalizeStructured` 对未知键本就原样透传、`validateForCreation` 本就忽略未知键，因此不需要也不应该为它伪造一个字段类型。给自制内容做嵌套表单编辑属于 S4。

### 4.3 数据流

```
启动：RuleProfileStore.initialize()
   ├─ AssetBundle 读 assets/rules/dnd5e-2024.rules.json   → tier 0
   ├─ ContentRepository 取所有 class 条目（含 legacy 字段与 grants → 规范化） → tier 100/1000
   ├─ RuleProfileResolver.resolve(...) → RuleProfile + diagnostics
   └─ Dnd5eRules.configure(profile)     // 失败则 fail-fast 并给出明确错误

建角色/升级：条目 classRules × profile 字段级合并 → ClassRuleSet → 派生 HP/AC/豁免/技能/法术位/资源
导入包：previewJson → 解析条目 → RuleProfileResolver.resolveForPackage(entries) → diagnostics → error/warning
```

### 4.4 失败处理

- 内置档案缺失或非法：启动即抛 `StateError`（消息含资产路径与首个错误路径），并由 CI 测试兜底。
- 条目规则字段非法：导入阻断（error，§5.1），不写入本地库。
- 运行期查到未声明字段：不抛异常，返回"未声明"（空/`null`）并在 UI 提示。

---

## 5. 校验规则

### 5.1 Error（阻断整包，`path` 精确到字段）

| code | 条件 | 示例消息 |
|---|---|---|
| `unknownField` | `classRules` 内出现未定义字段 | `未知字段 classRules.hitDices，是否想写 hitDie？` |
| `invalidHitDie` | `hitDie` 非 `d4..d20` / int 不在 4..20 | `生命骰必须是 d4–d20 或 4–20 的整数` |
| `unknownAbility` | 豁免/施法属性/`formula ability:x`/`kind: "ability"` 的 `target` 不在 `abilities` | `未知属性键 "力量"，可用：str, dex, con, int, wis, cha` |
| `unknownSkill` | `skillChoice.options` 元素不在 `skills` | `未知技能 "特技"（可用别名：杂技）` |
| `invalidSkillCount` | `count` 不在 0..上界 | `skillChoice.count 必须为 0..6` |
| `invalidSpellcastingMode` | `mode` 不在枚举 | `spellcasting.mode 必须是 prepared / known / pact / none` |
| `unknownArchetype` | `archetype` 不在 `progressions` | `未知原型 "three-quarter-caster"` |
| `invalidProgressionRow` | `level` 不在 1..20 / `maximumSpellLevel` 不在 0..9 / 计数为负 | `progression[2].level 必须为 1..20` |
| `invalidSlotOverride` | 键不在 1..20 / 1..9，值非 int≥0 | `slotOverrides["21"] 的键必须为 1..20` |
| `invalidMaxSpec` | 五种写法全缺、同时出现多种、`byLevel` 长度≠20、含负值、`formula` 不在封闭语法 | `maximum 必须且只能使用 value / formula / byLevel 之一` |
| `duplicateResourceId` | 同职业内 `resources[].id` 重复 | `资源 id "rage" 重复` |
| `invalidRecovery` | `recovery` 不在枚举 | `recovery 必须是 shortRest / shortRestOne / longRest / none` |
| `unknownGrantKind` | `kind` 不在 10 项枚举（含被移除的 `conditionResistance` / `note`） | `未知 grant kind "note"，该字段已移除` |

### 5.2 Warning（可导入，导入预览中列出）

| code | 条件 |
|---|---|
| `legacySavingThrows` | 使用中文散文 `structured.savingThrows` 而非 `savingThrowAbilities` |
| `legacySkills` | 使用中文散文 `structured.skills` 而非 `skillChoice` |
| `legacyPreparedFlag` | 使用 `preparedSpellcasting`（已废弃，改用 `spellcasting.mode`） |
| `legacyResourceGrants` | 用逐级 `resource` / `spellSlot:` grant 而非类级资源表 / `slotOverrides` |
| `droppedSkillOption` | 中文散文技能里出现无法识别的技能名（列出被丢弃项） |
| `missingCoreField` | 职业条目缺 `hitDie`（或施法职业缺 `spellcasting`），角色卡对应数值将缺省 |
| `missingPreparedColumn` | 施法职业未声明 `progression[].maximumLeveledSpells` 且原型无 `prepared`（编辑器不限制数量） |
| `ignoredGlobalList` | 包自带了 `abilities` / `skills` 清单（内置档案为唯一权威，该清单被忽略） |
| `unresolvedClassRule` | 条目没有任何可用规则来源（既无 `classRules` 也无档案匹配） |

### 5.3 诊断的路由

`RuleDiagnostic.severity == error` → `ContentValidationError`（现有整包阻断语义与 UI 不变）；
`severity == warning` → 导入报告新增 `warnings` 列表，在 `ContentImportPreviewDialog` 中以次级样式展示，不阻断。

---

## 6. 测试策略

### 6.1 资产测试（替代现有的硬编码核算）
- `dnd5e_rules_verification_test.dart`（现有 49 项）改为加载内置档案并对官方表断言数值（生命骰、豁免、法术位 1–20、准备法术 1–20、契约魔法、资源次数与恢复语义）。加载方式：`File('assets/rules/dnd5e-2024.rules.json')`（`flutter test` 的工作目录是包根，无需 `rootBundle` 与 binding），失败时测试报出资产路径。
- 新增档案 schema 自检：`rulebookVersion == 1`、6 项属性与全部技能、12 个核心 slug 全部存在、每个职业字段可解析、每张 `slots` 表长度 20、每个 `byLevel` 长度 20、无未知原型引用。

### 6.2 兼容金标（私有包存在时运行，否则 skip）
- 载入 `private-imports/phb-2024-v2-bundle.json`，对 12 职业断言解析结果与**改造前**逐个数值相等：`hitDie`、豁免集合、每级法术位、每级准备上限、职业资源（战士/野蛮人来自档案）、邪术师契约位。
- 断言邪术师**不再**出现 `classResources['pact-magic-slots']` 双重表示（行为变化，需在文档标注）。
- 与现有私有路径测试一致：缺少私有包时跳过，不使 CI 变红。

### 6.3 端到端自制职业（核心验收）
构造一个合成包（条目 id/slug/name 均不含任何核心职业名）：
- `classRules` 声明 `hitDie: 10`、豁免、`skillChoice`、`spellcasting{ mode: prepared, ability: cha, archetype: half-caster }`、两个资源（一个 `formula: "level"`、一个 `byLevel` + `startsAtLevel: 3`）；另在 `rules.progression` 里用 `kind: "hitPoints"`（`formula: "level"`）与 `kind: "ability"`（`target: "cha"`, `value: 1`）声明两个按等级生效的效果。
- 流程：导入 → 断言无 error → 建角色（第 1、5、20 级）→ 断言 HP（含 `hitPoints` grant）、属性（含 `ability` grant 及其对 DC/技能的连带影响）、豁免、技能选择上限、法术位、资源次数与恢复语义、准备上限、施法 DC；→ 升级 +1 级后断言增量。
- 变体：只声明 `hitDie` + 豁免 + `skillChoice` 的最小职业（断言其余数值为"未声明"而非猜测）；只声明 `archetype: pact` 的契约施法者（断言 `{"<环阶>": n}` 形状与短休恢复）；用 `slotOverrides` 写满 20 级的自定义施法者。

### 6.4 校验与解析链
- §5.1 每条 error、§5.2 每条 warning 各一个最小反例包，断言 `path` 与消息。
- 解析链：条目声明优先于档案；`slotOverrides` 整级替换；`progression` 逐级优先于 `archetype`；slug 冲突按 tier 与 `installedAt`；未声明字段返回空且产出提示而非猜测。
- 回归：`RuleProfileStore` 加载失败时 fail-fast。

### 6.5 生成侧
- 更新 `scripts/extract_phb_2024_v2.py` 输出 `savingThrowAbilities` / `skillChoice` 结构化字段（消除 `legacySavingThrows` / `legacySkills` warning）。
- `scripts/test_phb_2024_v2_tools.py` 同步断言；`npm run test:scripts` 保持全绿。

### 6.6 门禁
`npm run check`（服务端 lint + 客户端 analyze + 服务端/客户端测试）、`npm run test:scripts`、`npm run lint:design` 全绿；客户端测试数量只增不减。

---

## 7. 迁移与兼容

- **现有私有包无需修改**即可继续工作（legacy 映射 + warning）；更新生成脚本后 warning 消失。
- **老角色**：首次打开时由 `CharacterRuleProjector` 精确匹配补写 `classIdentity`；匹配不到则提示"该职业未声明规则"，数值按未声明处理。
- **行为变化清单**（必须写入 `docs/README.md` §7.7 与 CHANGELOG 式提交说明）：
  1. 邪术师契约位不再作为 `classResources` 条目出现（改由法术位承担）。
  2. 准备法术上限不再要求 `preparedSpellcasting: true`（真实包角色从此有上限）。
  3. 未知技能名不再静默丢弃，改为 warning。
  4. `conditionResistance` / `note` grant 会被拒绝（导入报错）。
  5. 职业数值改为可被本地自制包覆盖（tier 1000）。

---

## 8. 文档更新清单

| 文件 | 更新 |
|---|---|
| `docs/README.md` §9.1 | 重写为现行契约：档案格式、`classRules` 字段全集、5 种 `maximum`、解析链与优先级、error/warning 全清单、完整自制职业示例、legacy 迁移表 |
| `docs/README.md` §7.7 | 删除"代码内置职业表"表述；记录来源可追溯语义、行为变化清单、抗性/备注仍未实现 |
| `docs/README.md` §2 / §16 | 快速事实与验收基线更新（测试数量、档案路径） |
| `docs/README.md` §13.6 | 合规清单新增一项：内置规则档案只含数值，不含规则书正文 |
| `README.md` | 使用教程新增"导入并使用自定义职业包"一节 |
| `DESIGN.md` | 若新增"未声明字段"提示 UI，需按设计契约使用既有组件（无新 token 预期） |
| `AGENTS.md` | 必读顺序中补充：涉及规则/内容契约时必须读 `docs/README.md` §9.1 |

---

## 9. 风险与缓解

| 风险 | 缓解 |
|---|---|
| 搬迁数值出错（最严重） | §6.2 私有包金标逐个数值对照；§6.1 官方表核算指向资产 |
| 全局可变 profile | 只允许启动时 `configure` 一次，之后只读；测试提供显式重置钩子；`configure` 在已装配后再次调用抛错 |
| 资产加载失败致应用不可用 | fail-fast + 明确错误；CI 资产测试保证不会发布坏档案 |
| `structured.classRules` 与 legacy 字段并存导致歧义 | §3.9 明确优先级（`classRules` 优先）并给 warning |
| 解析链让"未声明"变成用户可见的空值 | 只在角色页提示、不阻断；导入时 warning 提前暴露 |
| 老角色 `classSummary` 无法精确匹配（如"战士（奥法骑士）"） | 项目器可拆分子职名与母职业名做精确匹配；仍失败则提示，不做子串猜测 |
| 移除两个 grant kind 破坏未知第三方包 | 真实包未使用；导入期报错信息明确指向替代方案（`notes` 字段） |

---

## 10. 验收标准

1. 客户端**代码**中**不存在**任何以职业名（中文或英文）为键的规则表或 `contains` 职业匹配（`grep` 可验证；内置档案里的 `classes.<slug>` 键属于数据，不计入）。
2. 内置档案通过 §6.1 的官方表核算与 schema 自检。
3. §6.2 私有包金标全部数值与改造前相等；邪术师双重表示消失。
4. §6.3 合成自制职业包端到端通过（含升级）。
5. §5.1 / §5.2 每条诊断都有对应测试，`path` 精确。
6. `npm run check`、`npm run test:scripts`、`npm run lint:design` 全绿。
7. `docs/README.md` §9.1 含完整自制职业示例，且示例可被测试中的合成包复用（文档与实现不脱节）。

---

## 11. 明确不在本次范围

- **S3**：`mode: "patch" | "replace"` 声明、可配置 `priority` 字段（含 Drift 迁移）、覆盖冲突 UI、关闭覆盖回退内置。
- **S4**：作者 GUI（规则表单）、基于已有条目创建覆盖、`.dndpack` 导出。
- **C 场景**：自定义技能/属性清单、自定义 AC 公式（护甲敏捷上限、无甲防御）、自定义休息与恢复语义。
- **仍不建模的规则能力**（继续留在 §7.7 已知限制）：其他职业资源池（引导神力/野性形态/专注点/术法点/诗人激励/宿敌/圣疗/魔法诡计/先天术法）、伤害抗性与免疫结算、**奥法骑士/诡术师的准备或已知法术上限与戏法上限**（2024 职业表未给出，不臆造）、命中骰池、力竭等级惩罚、专注校验、专精、多职业、XP、负重。

---

## 12. 建议实现阶段（供实现计划参考）

| 阶段 | 内容 | 完成标志 |
|---|---|---|
| P1 | 内置档案 + `RuleProfile` / `ClassRuleSet` / `MaxSpec` + `RuleProfileResolver` + 资产测试与解析链测试 | 档案通过官方表核算；解析链测试全绿；`Dnd5eRules` 尚未接入 |
| P2 | `Dnd5eRules` 改为读 profile（删除职业表与中文匹配）+ `RuleProfileStore` 启动装配 + 消费者改造 + 私有包金标 | `npm run check` 全绿且客户端测试数量不减；金标数值全等 |
| P3 | 导入校验与 warnings（含 `ContentImportReport.warnings` + 预览 UI）+ `classIdentity` 与老角色回填 | §5 每条诊断都有测试；老角色提示正确 |
| P4 | grant kind 收紧：实现 `hitPoints`/`ability`、移除 `conditionResistance`/`note`、修邪术师双重表示 | 行为变化清单逐条有测试 |
| P5 | 生成脚本升级 + 文档（§9.1 重写、§7.7、§2/§16、README、AGENTS.md） | 文档示例与合成包一致；warning 消失 |

P1→P2 之间必须有一次全量回归（这是数值搬迁的安全网，不可跳过）。
