# 规则契约与规则档案（S1+S2）设计规格

- 状态：待用户审查（审查通过后进入实现计划）
- 范围：子项目 S1（规则核心数据化）+ S2（契约扩展与导入校验）
- 验收场景：A（2024 补充包）、B（全新自制职业）、D（覆盖与勘误，仅打地基）
- 明确不做：C（自定义技能/属性、自定义 AC 公式、自定义休息语义）、S3（patch/replace 声明与冲突 UI）、S4（作者 GUI 与 `.dndpack` 导出）

> 本文是实现规格。面向使用者的契约说明在实现完成后写入 `docs/README.md` §9.1；
> 本文不替代 `docs/README.md` 作为项目唯一事实来源的地位。

## 0. 用户补充的关键需求（2026-09-10，优先级最高）

**需求一（选择系统）**：

> "我希望自己写职业时有很大的自定义空间。比如几级获得几个法术位，获得什么资源，
> 获得什么特性，做出什么选择这些都可以自定义。**尤其是做选择这一部分非常关键。
> 比如法术的选择。**"

**需求二（不背兼容包袱 + 双高要求）**：

> "兼容层不用管，到时候重新转换或者重新提取就好了。**自定义程度和方便程度都必须高**。"

这两条一起改变了设计基线：

1. **不保留兼容层**。旧契约形状（中文散文 `savingThrows`/`skills`、`preparedSpellcasting` 开关、
   `spellSlot:`/`classResource:` 逐级 grant）**不再解析**；`scripts/extract_phb_2024_v2.py`
   与私有包一起**按新契约重写/重提取**。因此契约可以按"最好写、最强表达"来设计，
   不必迁就历史形状。
2. **"自定义程度"与"方便程度"是并列的硬指标**，但不是靠"多给几种写法"实现的。
   契约的第一原则是：**一个概念只有一种写法**（one concept, one shape）。
   方便程度由这四件事保证：字段少、默认值合理、错误信息可操作、GUI 兜底（S4）。
   因此本契约**没有**别名、没有"简写与规范两种写法"、没有"兼容写法"。
3. 唯一保留的迁移是**用户数据**：老角色卡一次性回填 `data.classIdentity`（内容可以重提取，
   玩家的角色卡不能重来）。除此之外不做任何旧格式读取。

`§3.10` 是选择系统的完整契约（已按需求一并入本轮范围，不再有 S2.5 尾巴）。

---

## 1. 背景与现状（实测）

### 1.1 真实内容源的实测形状（**将被重提取替换**）

`private-imports/phb-2024-v2-bundle.json`（formatVersion 2，id `phb-2024`，1106 条）：

| 已声明 | 位置 |
|---|---|
| `hitDie: "d12"`（字符串）、`savingThrows: "力量与体质"`（中文散文）、`skills: "选择2项：…"`（中文散文） | `structured`（12 个 class 条目全有） |
| `spellcastingAbility` + `spellcasting{ mode, ability, listTags, progression[20 行] }`，行内 `maximumSpellLevel / maximumCantrips / maximumLeveledSpells` | `structured`（8 个施法职业） |
| 660 个 `spellSlot:<n>` resource grant（7 个有环位职业）；20 个 `classResource:pactMagicSlots` grant（邪术师，带 `data.spellLevel` 与 `data.recovery`） | `rules.progression[].grants` |
| 464 个 `feature` grant、12 个 `choice` | `rules` |

真实包**没有**声明：职业豁免数值表、准备法术上限标志、战士/野蛮人的任何职业资源。

按 §0 需求二，**这份形状不构成契约**：它是旧提取器的产物，将被 P0 的重写版替换。
保留本节实测的意义是——它精确告诉我们"旧提取器丢了什么、写得多难用"（散文、双重表示、
660 个逐级 grant），从而定出新契约必须补上的能力。

### 1.2 代码是它的补丁，因此存在 8 个具体缺口

| # | 缺口 | 现状证据 | 后果 |
|---|---|---|---|
| G1 | 职业识别靠中文子串匹配 | `Dnd5eRules._hitDie` / `_classSavingThrows` / `classResources` / `spellSlotMaximums` / `usesPactMagic` 都在 `classSummary.contains('战士')` | `星界游侠` 会被当成游侠推导出半施法者表；第三方职业名字稍像核心职业即被错误推导 |
| G2 | 4 个 grant kind 是空转 | `hitPoints` / `ability` / `conditionResistance` / `note` 只有图标渲染（`character_editor_page.dart:2617-2622`） | 包写进去完全无效，"导入成功但功能不存在" |
| G3 | `replaces` 关系从不生效 | 枚举在 `ContentRelation.allowedTypes`，全仓库无消费方 | 无法房规/勘误 |
| G4 | `structured` 规则字段零校验 | 导入器只校验 entry 必填字段与 grant 引用存在性 | 写错不报错，静默降级为错误角色卡；`_validSkills` 还**静默丢弃**未知技能 |
| G5 | 准备法术上限依赖一个真实包没有的开关 | `StructuredClassRules.preparedSpellLimit` 要求 `structured.preparedSpellcasting == true` | 真实包角色**根本没有**准备法术上限，尽管包里已有 `maximumLeveledSpells` |
| G6 | 邪术师契约魔法双重表示 | 包里是 `classResource:pactMagicSlots` grant，代码里又有 `pactSlotMaximums` 硬编码表 | 同一事实两处维护，短休恢复语义两套 |
| G7 | 作者侧无 GUI、无导出 | `LocalHomebrewContentService` 无 UI 调用者（仅测试）；资料包页只有导入/删除 | 属于 S4，本次只保证契约与引擎支持全部能力 |
| G8 | 提取器产出的是"难写的形状" | `scripts/extract_phb_2024_v2.py` 输出中文散文豁免/技能、逐级 `spellSlot:` grant（660 个）、契约外字段 | 作者无法照抄；新契约必须让提取器与第三方作者用同一种简洁写法（P0 重写） |

### 1.3 本次目标

**重新定义一套干净、好写、表达力强的规则契约**，把代码里的补丁表搬进随包发布的规则档案，
并让提取器与第三方作者使用同一种写法：

1. 删除全部中文子串职业匹配，改为「条目声明 → 档案按 slug 补齐 → 未声明就不猜」。
2. 让一个完全自制的职业条目仅靠 `structured.classRules` 的 5–6 个字段即可产出正确的
   HP / 豁免 / 技能选择 / 法术位 / 职业资源 / 准备法术上限。
3. **选择系统收敛为唯一模型**（§3.10）：值选项、法术选择、技能选择、装备选择、可重复、
   前置依赖全部可声明且真正生效——这是用户点名的重点。
4. 导入时对规则字段做精确路径校验（error 阻断、warning 提示），消除静默降级。
5. 处置 4 个空转 kind；消除邪术师双重表示；旧契约形状不读取（§3.9）。
6. 为 S3 铺好地基：字段级合并 + **来源可追溯**，使"被哪个包覆盖"可显示、可回退。

---

## 2. 术语

| 术语 | 含义 |
|---|---|
| **规则档案（rule profile）** | 一份只含规则数值、不含任何规则书正文的配置。内置档案随客户端发布；外部包可通过条目声明参与合并 |
| **职业规则块（class rules fragment）** | 描述一个职业规则数值的对象。内置档案的 `classes.<slug>` 与条目 `structured.classRules` 是**同一形状** |
| **简写层 / 规范层** | 简写层是 `classRules` 与字符串选项（好写）；规范层是 choices / grants / tables（唯一被运行时消费的形状）。解析期把简写规范化为规范层 |
| **表（`Table<T>`）** | 统一的"随等级变化"表示：完整 20 项数组或稀疏 `{"等级": 值}` |
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
    // none 没有法术位，是唯一不写 minimumLevel 的原型（其余原型一律显式写出默认值 1）
    "none":         { "slots": [] },
    // 原型只承载"跨职业共享"的进阶量：slots / slotLevel / maximumSpellLevel
    "full-caster":  { "minimumLevel": 1, "slots": [[2],[3],[4,2],"…20 行"],
                      "maximumSpellLevel": [1,1,2,"…"] },
    "half-caster":  { "minimumLevel": 1, "slots": [[2],[2],[3],"…"],
                      "maximumSpellLevel": [1,1,1,"…"] },
    // third-caster：prepared / cantrips 省略（2024 职业表未给出这两列，不臆造，见 §11）；
    // maximumSpellLevel 由官方法术位表推导（3–6 级 1 环、7–12 级 2 环、13–18 级 3 环、19–20 级 4 环）
    "third-caster": { "minimumLevel": 3, "slots": [[],[],[2],"…"],
                      "maximumSpellLevel": [0,0,1,1,1,1,2,2,2,2,2,2,3,3,3,3,3,3,4,4] },
    "pact":         { "minimumLevel": 1, "slots": [[1],[2],[2],"…"],
                      "slotLevel": [1,1,2,2,3,"…20 个数"],
                      "maximumSpellLevel": [1,1,2,"…"] }
  },
  "classes": {
    "barbarian": {
      "hitDie": 12,
      "savingThrowAbilities": ["str", "con"],
      "spellcasting": { "mode": "none" },
      "resources": [
        { "id": "rage", "name": "狂暴", "startsAtLevel": 1,
          "maximum": { "table": {"1":2, "3":3, "6":4, "12":5, "17":6} },
          "recovery": "shortRestOne" }
      ]
    },
    "fighter": {
      "hitDie": 10,
      "savingThrowAbilities": ["str", "con"],
      "spellcasting": { "mode": "none" },
      "resources": [
        { "id": "second_wind", "name": "第二气息", "startsAtLevel": 1,
          "maximum": { "table": {"1":2, "4":3, "10":4} }, "recovery": "shortRestOne" },
        { "id": "action_surge", "name": "动作如潮", "startsAtLevel": 2,
          "maximum": { "table": {"2":1, "17":2} }, "recovery": "shortRest" }
      ]
    }
    // …共 12 个核心职业
  }
}
```

**内容边界（合规）**：档案只允许存放数值与枚举，**不得**包含规则书正文、法术描述、怪物数据或任何散文段落。

**两份参照清单必须显式声明**：`abilities` 与 `skills` 缺失、为空或类型错误时，`resolveBuiltin` 报 `invalidTable`
并使 `profile == null`（启动即 fail-fast）；**不得**伪造占位值（例如把技能属性写成空字符串）来兜底。

**两份参照清单**：`abilities` 与 `skills` 是**校验参照表**（场景 C 已排除扩展），以**内置档案**为唯一权威；包若自带同名清单，解析器忽略它并给出 warning（§5.2 `ignoredGlobalList`）。因此第三方的豁免键、技能名、`formula ability:<key>` 都必须落在内置清单内。

**档案键即职业对齐键**：`classes` 的键是 12 个核心职业的规范英文 slug（`barbarian`、`bard`…）。条目要继承内置数值，其 `slug` 必须等于其中之一；用中文名或其它 slug 的自制职业不会命中内置数值（这是刻意的：不猜）。

**数值权威**：档案数值来自 SRD 5.2 / PHB 2024 官方表，由 §6.1 的资产测试逐项核算。原代码中的职业表在本次改造中被删除，其数值整体搬入本档案。

**档案覆盖 12 个职业的完整资源池**（2024 官方恢复语义）：

| 职业 | 资源 | 上限 | 恢复 | 起始等级 |
|---|---|---|---|---|
| 野蛮人 | 狂暴 | `{"table":{"1":2,"3":3,"6":4,"12":5,"17":6}}` | `shortRestOne` | 1 |
| 战士 | 第二气息 / 动作如潮 | `{"table":{"1":2,"4":3,"10":4}}` / `{"table":{"2":1,"17":2}}` | `shortRestOne` / `shortRest` | 1 / 2 |
| 吟游诗人 | 诗人激励 | `{"formula":"ability:cha","minimum":1}` | `{"table":{"1":"longRest","5":"shortRest"}}` | 1 |
| 牧师 | 引导神力 | `{"table":{"2":2,"6":3,"18":4}}` | `shortRestOne` | 2 |
| 德鲁伊 | 野性形态 | `{"table":{"2":2,"6":3,"17":4}}` | `shortRestOne` | 2 |
| 武僧 | 专注点 | `{"formula":"level"}` | `shortRest` | 2 |
| 圣武士 | 引导神力 / 圣疗（治疗池） | `{"table":{"3":2,"11":3}}` / `{"formula":"5*level"}` | `shortRestOne` / `longRest` | 3 / 1 |
| 游侠 | 宿敌 | `{"table":{"1":2,"5":3,"9":4,"13":5,"17":6}}` | `longRest` | 1 |
| 术士 | 术法点 / 先天术法 | `{"formula":"level"}` / 常量 `2` | `longRest` / `longRest` | 2 / 2 |
| 邪术师 | 魔法诡计 | 常量 `1` | `longRest` | 2 |

（武僧/术士的上限等于职业等级；牧师引导神力、圣武士引导神力、德鲁伊野性形态都是**短休只恢复 1 次**；
诗人激励是**魅力调整值（最低 1）且长休恢复，5 级起改为短休也能全恢复**——以上均按 SRD 5.2 原文核对。）

**原型的键必须落在白名单内**：`{slots, slotLevel, maximumSpellLevel, minimumLevel}`；出现其它键（典型是
把 `prepared`/`cantrips` 塞回原型）→ `unknownField`（error）。这条与"原型只管三件事"配套，让该约束
在解析期就生效，而不是只靠测试拦。

**原型的 `slots` 是"模板压缩编码"**：写成"每级一个计数数组" `[[2],[3],[4,2],…]`（第 n 项是第 n 级，
数组内第 k 个数字表示 k 环法术位的数量，省略 0）。这是**只在内置档案里使用的模板编码**，
第三方作者永远不写它（他们只写 `archetype: <名>`）。
**唯一的展开点**是 `RuleProfileResolver` 解析原型时：把该编码展开成运行期统一的 `{环阶: 数量}` 形状
（`pact` 的每级只有计数，环阶由同级 `slotLevel` 提供）。除这一处外，契约里 `slots` 只有一种形状：
`{环阶: 数量}`。压缩编码形状不合法（非数组、长度 >20、含非非负整数、`pact` 缺 `slotLevel`）→ `invalidTable`。

**原型只管三件事**：`slots`、`slotLevel`（仅 `pact`）、`maximumSpellLevel`。
**`prepared`（准备/已知法术数）与 `cantrips`（戏法数）永远是职业自己的字段**——2024 官方表里这两列逐职业不同
（法师 20 级 25、术士 1 级 2、德鲁伊戏法 2、术士戏法 4…），只有法术位与最高环阶是原型共用的。
把逐职业的表塞进原型会让法师从 25 掉到 22，属于会静默改数值的错误，因此契约层面禁止。

**表类型 `Table<T>`**（本契约的统一约定，用于所有"随等级变化"的字段）：

```jsonc
[20 个值]                       // 完整表
{"1": 值, "5": 值, "17": 值}    // 稀疏表：只写变化的等级，键 1..20
```

解析规则：取值时取"**不超过当前等级的最大已声明档位**"的值（即档位下取整）；**低于最早声明等级时返回"未声明"**
（`null`，不借用更高档位的值，见 §3.12）。**原型内部**（`progressions`）使用完整 20 项数组，
因为它是模板而不是覆盖，因此不会触发"低于最早声明"这一分支。

**档案自身的书写风格**：内置档案里**默认值一律显式写出**（`"startsAtLevel": 1`、`"minimumLevel": 1`、
`"recovery": "longRest"`），让读者不查契约就知道真实取值，也避免"是漏写还是取默认"的歧义。
契约层面仍允许外部包省略默认值（省略即取默认），这只是内置档案的书写约定。

**不变量**：`pact` 原型的 `slotLevel` 与 `maximumSpellLevel` 必须逐级相等（契约魔法的最高环阶就是其法术位环阶）；
`full-caster` / `half-caster` / `third-caster` 的 `maximumSpellLevel[L]` 必须等于 `slots[L]` 的环阶个数。

**行为等价要求**：改造后"只装内置档案"的角色数值必须与改造前逐项相等（含战士/野蛮人资源次数与恢复语义），由 §6.1 + §6.2 保证。

### 3.2 职业规则块（两个载体同一形状）

**载体 A**：内置档案的 `classes.<slug>`（见 §3.1）。
**载体 B**：任意 `type: "class"` 条目的 `structured.classRules`。

```jsonc
"structured": {
  "classRules": {
    "hitDie": 10,
    "savingThrowAbilities": ["wis", "cha"],
    "spellcasting": {
      "mode": "prepared",
      "ability": "cha",
      "listTags": ["spell-list:astral"],
      "archetype": "half-caster",
      "slots": { "5": { "1": 4, "2": 2 } },
      "prepared": { "5": 6 }
    },
    "resources": [
      { "id": "astral-surge", "name": "星界涌动",
        "maximum": { "formula": "level" }, "recovery": "shortRestOne" },
      { "id": "astral-ward", "name": "星界守护", "startsAtLevel": 3,
        "maximum": { "table": {"3":1, "5":2, "8":3, "11":4, "15":5, "18":6} },
        "recovery": "longRest" }
    ]
  }
}
```

字段全集与语义（**只描述"职业级静态事实"**；随等级解锁的效果统一由 `rules.progression[].grants` 承担，见 §3.5）：

| 字段 | 类型 | 必填 | 语义 |
|---|---|---|---|
| `hitDie` | int | 否* | 生命骰面数，**只写整数**（规则书的 `d10` 写 `10`），且必须是标准骰面之一：**4 / 6 / 8 / 10 / 12**。`d7`、`d9`、`d20` 等一律拒绝。缺省时 HP 只按体质调整值计，见 §3.6 第 3 步 |
| `savingThrowAbilities` | string[]（属性键） | 否* | 豁免熟练，元素必须 ∈ `abilities` |
| `spellcasting` | object | 否 | 见 §3.3 |
| `resources` | object[] | 否 | 见 §3.4。**内置档案里 `startsAtLevel` 一律显式写出**（见下方书写约定） |

\* 标 `否` 是契约层面的可缺省；但缺 `hitDie` 会导致 HP 无法计算，导入时给 **warning**（§5.2）。

**`classRules` 只有这 4 个字段，全部是"数值事实"。** 技能选择、法术选择、特性、熟练、
装备方案一律属于**选择与效果**，只有一种写法：`rules.progression[].grants` / `.choices`（§3.5、§3.10）。
档案（tier 0）因此只提供数值，选择与特性永远由内容条目声明——这也让"档案只含数值"的合规边界更硬。

**HP 加值与属性加值不作为 `classRules` 字段**：它们天然是"按等级生效的效果"，统一用 `rules.progression[].grants` 的 `kind: "hitPoints"` / `kind: "ability"` 表达（§3.5），避免同一件事有两种写法。

### 3.3 `spellcasting` 对象

| 字段 | 类型 | 语义 |
|---|---|---|
| `mode` | `"prepared" \| "known" \| "pact" \| "none"` | 施法模型；`none` 表示非施法者。默认 `none` |
| `ability` | 属性键 | 施法属性，必须 ∈ `abilities`；`mode != "none"` 时必填 |
| `listTags` | string[] | 法术列表过滤标签，透传给法术选择 |
| `archetype` | 原型名 | 简写：从档案 `progressions` 取整套表 |
| `slots` | `Table<{环阶: 数量}>` | 法术位表（稀疏即可，如 `{"5": {"1":4,"2":2}}`）。**优先于 `archetype`，按角色等级整级替换** |
| `slotLevel` | `Table<int>` | 仅 `pact` 有意义：每级契约法术位的环阶 |
| `prepared` | `Table<int>` | 每级"已准备/已知"法术数量上限。**职业独有**，原型不提供 |
| `cantrips` | `Table<int>` | 每级戏法数量上限。**职业独有**，原型不提供 |
| `maximumSpellLevel` | `Table<int>` | 每级可学/可准备的最高环阶（0..9）。原型提供，职业可覆盖 |

全部为可缺省字段；缺省即"未声明"（不猜测）。

解析（角色等级 L）：

```
slots         = slots[L] ?? expand(archetype).slots[L] ?? {}          // pact 结果形如 {"3": 2}
              // expand() 由 RuleProfileResolver 完成（模板压缩编码 → {环阶:数量}），见 §3.1
slotLevel     = slotLevel[L] ?? expand(archetype).slotLevel[L]
maxSpellLevel = maximumSpellLevel[L] ?? expand(archetype).maximumSpellLevel[L]
prepared      = prepared[L]                                        // 只看职业自身，无原型回退
cantrips      = cantrips[L]                                        // 同上
```

`prepared` 为 `null` 表示**该职业未声明准备/已知上限**：编辑器不施加数量限制，导入时给 warning（§5.2 `missingPreparedColumn`），角色页显示"未声明"。

原型对象的 `minimumLevel`：该原型在低于此等级时无法术位（`third-caster` = 3，其余 = 1）。低于该等级时法术位为空。

`pact` 原型的 `slots` 是**单一环阶**：结果形如 `{ "<slotLevel>": count }`（如 5 级邪术师 → `{"3": 2}`），与现有 `spellSlotMaximums` 的返回形状一致。

### 3.4 `resources` 与 `maximum`

```jsonc
{ "id": "string（非空，职业内唯一）",
  "name": "string（非空）",
  "maximum": <MaxSpec>,
  "recovery": "shortRest" | "shortRestOne" | "longRest" | "none",   // 默认 longRest
  // 恢复语义也可以随等级变化（2024 吟游诗人 5 级"激发灵感"把长休改成短休）：
  // "recovery": {"table": {"1": "longRest", "5": "shortRest"}}
  "startsAtLevel": 2,     // 可选，默认 1：该职业等级之前该资源不存在
  "description": "可选，一句话说明（不得放规则书正文）" }
```

`recovery` 与其它"随等级变化"的量使用**同一套"常量或表"写法**（`Table<string>`；高于最后声明等级沿用、
低于最早声明等级回退原型/默认值）。这也是契约里表达"某个数值随等级改变"的唯一手段。

`startsAtLevel` 与表的取值关系必须明确：**低于 `startsAtLevel` 的等级一律视为不存在该资源**（表中对应项被忽略，即使写了非 0）；`startsAtLevel` 及以上按表取值。内置档案里"战士 2 级才有动作如潮"用 `startsAtLevel: 2` 表达，而不是写一串 0。

`<MaxSpec>` 是"整数或对象"的二选一（对象内 `formula` / `table` 互斥，`minimum` 可选且只对对象形态有意义）：

| 写法 | 例 | 语义 |
|---|---|---|
| 整数 | `"maximum": 3` | 与等级无关 |
| 封闭公式 | `{"formula": "ability:cha", "minimum": 1}` | 见下方语法 |
| 等级表 | `{"table": {"1":2, "3":3}}` 或 `{"table": [20 个数]}` | `Table<int>`，稀疏即可 |

`minimum` 对公式与等级表都生效：最终取 `max(结算结果, minimum)`。

`formula` 的封闭语法（正则级）：`level` | `ability:<abilities 中的键>` | `<非负整数>*level` | `<非负整数>`。**不实现通用表达式求值**。

### 3.5 合法 grant kind（本次收紧）

`RuleGrantKind` 收敛为 **9 项**：`feature`、`proficiency`、`spell`、`equipment`、`action`、`speed`、`armorClass`、`hitPoints`、`ability`。

| 处置 | kind | 说明 |
|---|---|---|
| **实现** | `hitPoints` | 累加进 HP 上限；`value`（固定）或 `formula`（同一封闭语法，按职业等级结算）二选一 |
| **实现** | `ability` | 属性加值，**在派生之前**施加（影响 HP/AC/豁免/技能/法术 DC）；`target` 为属性键，`value` 为加值 |
| **移除** | `resource` | 资源是**职业级静态事实**，改由 `classRules.resources`（§3.4）统一声明；旧包里的 `resource` grant 按未知 kind 报错 |
| **移除** | `conditionResistance` | 无消费方、真实包未使用。移除后误用会在导入时报错，而不是静默无效；抗性/免疫结算记入 §11 待办 |
| **移除** | `note` | 同上；角色卡备注由 `notes` 字段承担 |

`rules.progression[]` 的每一步**只用一个 `levels` 数组**声明生效等级（不再有单个 `level` 字段）：

```jsonc
{"levels": [1], "grants": [ … ]}              // 单级
{"levels": [4, 8, 12, 16], "grants": [ … ]}   // 同一批效果在多个等级重复生效
```

这样"属性提升在 4/8/12/16 级各来一次"只写一份，不需要第二套语法。
`hitPoints` / `ability` 的 `formula` 与 `resource.maximum` 共用同一封闭语法与同一求值器。

### 3.6 解析链（字段级）

输入：角色所选职业的 `ContentEntry`（来自 `build.selections['class']`，或老角色 `data.classIdentity`）。

1. **条目自身声明**：该条目 `structured.classRules`（规范化后的字段）。
2. **档案补齐**：对仍缺失的字段，按该条目的 `slug`（规范化：`trim().toLowerCase()`），其次按 `aliases` 逐项精确匹配，在**内置档案**中查找，字段级合并。
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
  final String field;      // 'hitDie' | 'savingThrowAbilities' | 'spellcasting' | 'resources'（**整字段粒度**）
  final String originId;   // 'builtin:dnd5e-2024' | '<entryId>'
  final int tier;          // 0 内置档案 / 100 条目声明
}
```

来源的粒度是**顶层字段级**（`spellcasting` 是整字段，不细分到 `spellcasting.slots`）：字段级合并本身就是
整 `spellcasting` 替换，因此列级来源在本契约下无法产生。S3 若要"只覆盖 prepared、保留档案 slots"，
必须先把合并粒度改到列级——这是一条**已知限制**，S3 之前必须决策。

本次只在角色页与导入报告的诊断信息中显示来源（"该数值来自内置档案"还是"来自本职业条目"）；
S3 用它实现"被哪个包覆盖 / 关掉覆盖回退"。

### 3.8 优先级（本次范围）

**只有两级：内置档案 < 角色所用条目的声明。** 理由：一个角色只引用它自己那一个职业条目
（`classIdentity.entryId`），所以包与包之间在**本阶段**不会对同一角色产生冲突——
只有"条目没声明、档案有"这一种补齐关系，以及"条目声明了、档案也有"这一种覆盖关系。

因此本轮**不引入** `priority` 字段、不做全局条目扫描、也没有 Drift 迁移。
S3 的 patch/replace 才需要跨包优先级与冲突 UI（届时一条 errata 才能作用于**已指向别的包条目**的角色）。

### 3.9 无兼容层：旧契约不读取，提取器同步重写

按用户决定（§0 需求二），**不实现任何旧契约的读取路径**。以下形状在导入时按"未知字段 / 未知取值"处理：

**只有一个包格式版本**：`formatVersion: 3`。导入器接受且仅接受 3；
遇到 `1` / `2` 直接整包拒绝，并给出可操作提示"这是旧格式，请用新版工具重新生成/重提取"。
（`1` 的"只读兼容"分支一并删除——不留第二套格式。）

| 不再支持 | 替代写法 |
|---|---|
| `structured.savingThrows`（中文散文） | `classRules.savingThrowAbilities` |
| `structured.skills`（中文散文，含"任选3项"） | `rules.progression[].choices` 里 `optionType: "skill"` 的选择 |
| `structured.preparedSpellcasting` 开关 | `classRules.spellcasting.mode` + `prepared` 表 |
| `structured.spellcasting.progression[]` 四列行数组 | `archetype` + `slots` / `prepared` / `cantrips` / `maximumSpellLevel` 表 |
| `rules.progression[].grants` 的 `spellSlot:<n>` | `classRules.spellcasting.slots` |
| `rules.progression[].grants` 的 `classResource:<id>`（含 `data.spellLevel`） | `classRules.resources`（配 `startsAtLevel` + `table`），这类资源**不再**与法术位双重表示 |
| grant `formula` 只存储不求值 | `hitPoints` / `ability` / `resource.maximum` 求值（封闭语法）；其他 kind 不接受 `formula` |

配套动作：

1. `scripts/extract_phb_2024_v2.py` **按新契约重写输出**：`formatVersion: 3`、
   `classRules`（生命骰/豁免/施法数值表/资源）、技能与法术**选择**写成 `rules.progression[].choices`
   （`levels` 数组），不再产出散文与逐级 grant；`scripts/test_phb_2024_v2_tools.py` 同步。
   这一步是 P0，必须与契约定稿一起落地。
2. 私有包**重新提取**后导入；重提取产物需通过 §6.1 官方表核算与 §6.2 的"无旧形状残留"断言。
3. `CharacterRulesEngine` 不再需要"逐级 resource grant → 资源表"的运行时翻译逻辑，代码量随之减少。

---

### 3.10 选择系统（choices）：唯一模型

> 本节对应用户补充的关键需求（§0 需求一）。**全部能力并入本轮范围**（不再有 S2.5 尾巴）。

#### 3.10.1 现状：四套并行的选择机制

| 机制 | 代码位置 | 能表达什么 | 真实包实际用了什么 |
|---|---|---|---|
| **A. `rules.choices`** | `RuleChoiceDefinition` + `RuleChoiceResolver` + `CharacterRulesEngine._resolveChoices` | 从**条目**里选：`optionType`（条目类型）+ `optionTags`（全含）+ `optionEntryIds`（白名单）+ `maximumOptionLevel`（0–9）+ `minimum`/`maximum` + `recommendedEntryIds`；选中的条目进入规则队列，带出它自己的 grants/choices | 仅 12 个"3 级选子职"（min=max=1） |
| **B. 法术选择** | `SpellSelectionPolicy` + `structured.spellcasting.progression[].maximumCantrips / maximumLeveledSpells / maximumSpellLevel` + `listTags` | 按等级给戏法数与有环法术数上限，限定列表标签与最高环阶 | 8 个施法职业全部靠它 |
| **C. 技能选择** | `StructuredClassRules.skillChoice`（解析 `structured.skillChoice`，或中文散文） | `count` + `options` 列表 | 12 个职业靠中文散文正则解析（**本轮改为** `optionType: "skill"` 的选择，见 §3.10.2） |
| **D. 装备选择** | `StructuredClassRules.startingEquipmentChoice` | 只有 `maximum`（自由挑选数量），**没有选项列表** | 真实包用散文 `startingEquipment`，未用该字段 |

#### 3.10.2 目标：一个模型，两种选项载体

A–D 全部收敛到**同一套声明**，写在 `rules.choices` / `rules.progression[].choices`（作用域键沿用
`{sourceEntryId}#{choiceId}`，步骤沿用 `builderStep`）。**选项有两种载体**：

- **条目选项**：`optionEntryIds`（白名单）/ `optionTags`（全含）/ `optionType`（条目类型）/
  `maximumOptionLevel`；选中后该条目进入规则队列，带出它自己的 grants 与 choices。
- **内联选项**：`options` 里的对象，**自带 `grants`**，不建条目也能选、并且选中即生效。

```jsonc
// 1) 技能选择（内联选项 + 自动授予）
{ "id": "class-skills", "label": "选择两项技能熟练",
  "optionType": "skill", "minimum": 2, "maximum": 2,
  "options": ["洞悉", "医药", "说服", "宗教"],       // 字符串简写 → 自动授予对应熟练
  "builderStep": "proficiencies" }

// 2) 内联选项 + 属性提升（同样只写 options）
{ "id": "asi-or-feat", "label": "属性提升或专长",
  "optionType": "feat", "minimum": 1, "maximum": 1,
  "optionTags": ["origin"],
  "options": [
    { "id": "asi", "label": "属性提升 +1/+1", "grants": [
        { "id": "asi-str", "kind": "ability", "target": "str", "value": 1 } ] } ] }

// 3) 法术选择（纳入同一模型）
{ "id": "spellbook", "label": "法术书",
  "optionType": "spell", "minimum": 6, "maximum": 6,
  "optionTags": ["spell-list:wizard"], "maximumOptionLevel": 1,
  "countsToward": "spellbook" }

// 4) 可重复 + 前置依赖
{ "id": "invocations", "label": "祈唤",
  "optionType": "classFeature", "optionTags": ["eldritch-invocation"],
  "minimum": 1, "maximum": 3, "repeatable": true,
  "requires": [ { "ability": "cha", "minimum": 13 } ] }

// 5) 装备 A/B 方案
{ "id": "starting-equipment", "label": "初始装备",
  "optionType": "equipmentBundle", "minimum": 1, "maximum": 1 }
```

字段全集：

| 字段 | 类型 | 语义 |
|---|---|---|
| `id` / `label` | string | 必填；选择键 = `{sourceEntryId}#{id}` |
| `optionType` | string | **条目类型**（`subclass`/`feat`/`spell`/`item`/`classFeature`/`equipmentBundle`/`custom`…）或**值类型**（`value`/`skill`/`ability`/`language`/`damageType`/`weaponMastery`） |
| `minimum` / `maximum` | int | 默认 `1` / 等于 `minimum`；`maximum` 为可选数量上限 |
| `options` | array | **内联选项**（唯一写法，没有别名）。元素可以是字符串 `"察觉"`（等价于 `{id:"察觉", label:"察觉"}`）或对象 `{id, label, description?, data?, grants?}`；字符串元素会按 `optionType` 自动补 `grants`（见下） |
| `optionEntryIds` / `optionTags` | string[] | 条目选项的白名单 / 标签过滤（跨字段 AND、同字段 OR，沿用现有语义） |
| `maximumOptionLevel` | int? | 条目选项的等级上限（0–9） |
| `recommendedEntryIds` | string[] | 推荐项，UI 预选 |
| `repeatable` | bool，默认 `false` | 同一 option id 可被选多次（上限仍由 `maximum` 约束） |
| `countsToward` | string? 或 `null` | 法术选择计入哪个数量池（`spellbook`/`known`/`prepared`）；`null` = 不占上限 |
| `requires` | object[] | 前置依赖：`{choice, option}` 或 `{ability, minimum}`；不满足时**隐藏**该选择或选项 |
| `group` / `help` | string? | 分组标题与帮助文案（呈现用，无规则语义） |
| `builderStep` | string | 归属创建向导步骤（沿用 `allowedBuilderSteps`） |

**自动授予**：当 `optionType` 是值类型时，字符串元素会自动生成 grants（写成对象可覆盖）：

| `optionType` | 自动 grants |
|---|---|
| `skill` | `{kind: "proficiency", target: "skill:<名>"}` |
| `ability` | `{kind: "ability", target: "<属性键>", value: <choice.value ?? 1>}` |
| `language` | `{kind: "note", ...}` 不适用 → 记录到角色卡的"语言"列表（`data.languages`），不做数值派生 |
| `damageType` / `weaponMastery` / `value` | 只记录选择（`data.choices`），供内容显示与后续特性引用 |

写成完整对象时，作者可覆盖自动 grants（显式 `grants` 优先），也可给选项加 `description` / `data`。

#### 3.10.3 设计要点

1. **内联选项复用 `RuleGrantDefinition`**（含本轮实现的 `hitPoints` / `ability`），因此"选属性 +1""选技能熟练""选 HP +2"天然生效，不需要为每种值类型写新代码。
2. **值类型与条目类型**：值类型只允许内联 `options`；条目类型允许 `options` 与 `optionEntryIds`/`optionTags` 共存，UI 合并展示并分组。
3. **法术选择只有一种写法**：显式 `optionType: "spell"` 的选择（`maximum` 给数量、`maximumOptionLevel` 给环阶上限、`optionTags` 给法术列表、`countsToward` 给计入哪个池）。
   `classRules.spellcasting` 只声明**数值表**（法术位、准备数、戏法数、最高环阶），不派生选择——
   声明与选择分离，各自只有一种形态。提取器按规则书的表格生成这些选择（P0）。
4. **可重复选取**：`CharacterBuild.choices` 已是 `Map<String, List<String>>`，引擎天然支持重复；需要改的是编辑器状态（`Set` → 有序 `List`）与校验（`repeatable: false` 时同一 id 只允许出现一次）。
5. **前置依赖**：`requires` 不满足时隐藏；隐藏项若已被选择则进入 pending 并在 UI 提示。导入期静态校验引用存在性（`choice` 必须存在于同一条目或祖先条目，`ability` 必须合法）。
6. **装备选择**：`optionType: "equipmentBundle"` 让"选择 A 或 B"成为普通选择；选中结果写入 `inventory`，与现有 `equipmentBundle` 类型、`startingEquipmentChoice` 简写打通。
7. **不接受"声明了但用不了"**：任何进入契约的字段都必须有运行时支持；若某能力在实现阶段被砍，导入必须**报 error 拒绝**，不得静默接受。

---

### 3.11 作者试写发现（2026-09-10，用 `samples/homebrew-astral-knight/` 试写一个 26 条的职业包）

试写暴露了 6 处契约缺口与 1 处方便性改进点。**A 类已按本节定稿，B 类需用户拍板。**

**A 类：只是"形状没写清"，直接补进契约（无需决策）**

| # | 缺口 | 补法 |
|---|---|---|
| A1 | 内联特性/内联选项的**描述文字**没有字段 | 约定 `data.description`（字符串），界面在特性/选项行下方以小字展示；`RuleGrantDefinition.data` 保持自由字典 |
| A2 | **装备方案 A/B 的条目结构未定义** | `equipmentBundle` 条目的 `structured.items` = `[{name, quantity}]`，`structured.currency` = `{cp,sp,ep,gp,pp}`；选中后按此写入 `inventory` 与 `currency`，并忽略 `structured.itemTemplate` |
| A3 | **`countsToward: null`（不占上限）与现有"已准备"存储的关系未定义** | `countsToward` 只决定**是否计入数量上限**；无论取值如何，选中的法术都写入 `manualOverrides.spells.preparedEntryIds`（`null` 时额外记 `alwaysPreparedEntryIds`，仅用于展示"始终准备"标记） |
| A4 | **`requires` 的 `choice` 引用作用域未定义** | 可引用"同一 `sourceEntryId`"，或沿 `relations` 的 `featureOf` / `subclassOf` 链向上找到的祖先条目；导入期按该链校验引用存在性 |

**B 类：用户已拍板——"包格式最后统一到只有一个；一定要干净稳定强大"**

| # | 结论 |
|---|---|
| B1 | **单一格式版本**：只接受 `formatVersion: 3`；`1` / `2` 整包拒绝并提示重新生成；删除 `1` 的只读兼容分支（§3.9） |
| B2 | **静默继承改为 error**：`type: "class"` 的条目其 `slug` 命中 12 个内置 slug 时，**必须显式声明 `classRules`**（视为有意的房规覆盖）；未声明则报 `builtinSlugRequiresExplicitRules`，杜绝"误写 slug 就悄悄拿到别的职业数值" |
| B3 | **不做第二个写法**：`rules.progression[]` 统一用 `levels` 数组（`level` 字段删除），既能写一个也能写多个，不存在"两种声明方式" |

**同时清除的其余"多写法"**（本次一并收敛，见 §3.2–§3.4、§3.10）：

| 清掉的写法 | 保留的唯一写法 |
|---|---|
| `inlineOptions`（`options` 的别名） | `options` |
| `classRules.skillChoice` 简写 | 显式 `optionType: "skill"` 的 choice |
| 由 `spellcasting` 计数派生法术选择 | 显式 `optionType: "spell"` 的 choice |
| `hitDie: "d10"` 字符串 | `hitDie: 10` |
| `{"value": 3}` | 整数 `3` |
| `progression[].level` | `progression[].levels` |

---

### 3.12 部分声明是一等功能（人性化）

自制职业**不需要写完 1–20 级**。作者只声明他设计过的部分，其余由"继承"语义与界面提示兜住。

**规则**

1. **`rules.progression[]` 可以只声明部分等级**：不要求覆盖 1..20，也不要求必须含 1 级。
   未声明的等级不产生任何 grants/choices（自然继承，不需要写空壳步骤）。
2. **所有 `Table<T>` 允许短数组**：`prepared: [3, 4, 5]` 等价于只声明 1–3 级。
   取值语义统一为：
   - **高于最后声明等级 → 沿用最后声明值**（"后面按这个继续"）；
   - **低于最早声明等级 → 未声明**（返回 `null`/空，**不会**借用更高等级的值，
     然后按 §3.3 的优先级回退到 `archetype`，仍无则视为未声明）。
   稀疏表 `{"5": …}` 同样遵守这两条（所以只写 5 级**不会**让 1–4 级获得 5 级的数值）。
3. **声明范围是一等公民**：每个职业解析出 `declaredLevels`（从 `progression` 的
   `levels` 与各 `Table` 的声明范围合并），并写进角色数据
   `data.classIdentity.declaredLevels = {min: 1, max: 12}`。
4. **部分声明既不报错也不警告**：导入期只在"完全没有 `hitDie`"等真正缺数值的情况下给 warning；
   "只写到 12 级"是合法状态，由界面如实呈现（见下）。

**必须体现在所有相关界面上**（同一个 `declaredLevels` 数据源，不许各界面自己算）：

| 界面 | 呈现要求 |
|---|---|
| 导入预览（`ContentImportPreviewDialog`） | 条目行显示"职业声明：1–12 级"；这是信息，不写成错误色 |
| 资料库条目详情（`content_character_rules_view.dart`） | 规则视图顶部显示声明范围；未声明等级不显示空行 |
| 角色创建向导（`character_editor_page.dart`） | 等级滑杆在"已声明区间"用主题色、"未声明区间"用 `outlineVariant` 并加刻度提示；滑到未声明等级时，步骤面板顶部出现一条信息条："该职业未声明 N 级以上内容，你仍可继续（数值按未声明处理）"；选择面板不显示未声明等级的选择 |
| 角色升级页（`character_upgrade_planner` + 升级页） | 目标等级超出声明范围时，`CharacterUpgradePlan` 带 `beyondDeclaredLevel` 标记，页面在"确认升级"上方显示同一信息条；升级结果里未声明字段为空而不是报错 |
| 角色卡详情（`character_detail_page.dart`） | 法术位/资源/准备上限区在超出声明范围时显示"该职业未声明该等级的内容"；已有数值继续按继承语义显示 |
| 自制内容编辑（S4 的 GUI） | 等级步骤列表默认只到已声明等级，"添加等级"按钮可继续补；不强制补满 20 级 |

**同一个原则的另一面**：任何"未声明"都必须**可见**，不能表现为空白或静默为 0。
数值型未声明一律显示为"未声明"，而不是 0 或空字符串。**这包括 `MaxSpec.resolve`**：
它返回 `int?`，未声明（表的最早声明等级高于当前等级）时返回 `null`；
调用方（资源的逐级解析）把 `null` 当作"该等级没有这个资源"而**跳过**，
而不是产出"上限 0 次"的假资源。表里**显式写 0** 仍表示"存在但上限为 0"，两者语义不同。

---

## 4. 组件设计

### 4.1 新增

| 组件 | 文件 | 职责 |
|---|---|---|
| `RuleProfile` | `features/rules/domain/rule_profile.dart` | 不可变；`abilities`、`skills`、`progressions`、`classes(slug→ClassRuleSet)`、`fieldSources`；纯查询（`hitDie(slug)`、`savingThrows(slug)`、`spellSlots(slug, level)`、`pactSlotLevel(slug, level)`、`preparedLimit(slug, level)`、`classResources(slug, level)`、`spellcastingAbility(slug)`、`isPact(slug)`）与 `merge` |
| `ClassRuleSet` / `ClassSpellcasting` / `ClassResourceRule` / `MaxSpec` | 同上 | 值对象，含 `fromJson`/校验钩子 |
| `RuleProfileResolver` | `features/rules/domain/rule_profile_resolver.dart` | 纯函数：内置档案 JSON + 条目集合 + tier 表 → `RuleProfile` + `RuleDiagnostics` |
| `RuleDiagnostic` | 同上 | `{path, severity, code, message}`；导入器把它翻译成 `ContentValidationError`（error）或导入警告（warning） |
| `RuleProfileStore` | `features/rules/data/rule_profile_store.dart` | **只读内置档案资产**（`AssetBundle` 可注入）→ 调 Resolver → `Dnd5eRules.configure(profile)`。**不依赖内容仓库**：包里的职业声明在用到该条目时（建角色/升级/编辑/项目器）与档案做字段级合并 |

### 4.2 改造

| 位置 | 变化 |
|---|---|
| `Dnd5eRules` | 保留纯运算（`abilityModifier`、`proficiencyBonus`、`saveBonus`、`skillBonus`、`baseArmorClass`、`initiativeBonus`、`attackBonus`、`damageFormula`、`averageHitPointsForHitDie`、`applyHitPointDelta`、`classResourcesAfterRest`、`spellSlotsAfterRest`）；**删除全部职业表与中文匹配**，改为读 `Dnd5eRules.profile`；新增 `configure(profile)` / `profile` 访问器（一次性装配，之后不可变） |
| `structured_class_rules.dart` | 退化为适配器：`structured.classRules` → `ClassRuleSet`（**只认新契约的 4 个数值字段**）；保留 `savingThrowAbilities` / `hitDie` 查询，删除 `skillChoice`（改由 `rules.choices` 承担） |
| `character_rule_definition.dart` | `RuleChoiceDefinition` 扩展 `options`/`repeatable`/`countsToward`/`requires`/`group`/`help`；`RuleProgressionDefinition.level` 改为 `levels` 数组；`RuleGrantKind` 收敛为 9 项 |
| `rule_choice_resolver.dart` | 选项解析支持值类型与内联选项合并；`requires` 过滤；简写自动授予生成 |
| `character_rules_engine.dart` | 选中内联选项时合并其 `grants`；`repeatable` 的去重规则；选择结果的存储（`Map<String, List<String>>` 支持重复） |
| `character_editor_page.dart`（选择面板） | 选择状态 `Set` → 有序 `List`；值类型与条目选项分组展示；`group`/`help`；`requires` 隐藏；选择计数校验走统一模型 |
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
启动：main() → await RuleProfileStore.initialize()
   ├─ AssetBundle 读 assets/rules/dnd5e-2024.rules.json（只含数值，约 12 个职业）
   ├─ RuleProfileResolver.resolveBuiltin(json) → RuleProfile + diagnostics
   └─ Dnd5eRules.configure(profile)     // 失败则 fail-fast 并给出明确错误

建角色/升级/编辑/项目器（有条目在手，无全局扫描）：
   entry.structured.classRules ∪ entry.rules.choices
        ↓ 字段级合并（条目优先）  ↑ 内置档案按 slug/aliases
   ClassRuleSet + 规范选择 → 派生 HP/AC/豁免/技能/法术位/资源/准备上限
        ↓ 结果写入 character.data（classIdentity / classResources / spellSlots / …）

导入包：previewJson → 解析条目 → RuleProfileResolver.validateEntry(...) → diagnostics → error/warning
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
| `unknownField` | `classRules` 顶层、`spellcasting` 对象内、**每个资源对象内**、选择对象内出现未定义字段 | `未知字段 classRules.hitDices，是否想写 hitDie？` |
| `invalidHitDie` | `hitDie` 不是标准骰面 `{4,6,8,10,12}`，或写成 `"d10"` 字符串 | `生命骰只写整数且必须是标准骰面 4/6/8/10/12，例如 d10 写 10` |
| `unknownAbility` | 豁免 / 施法属性 / `formula ability:x` / `kind:"ability"` 的 `target` 不在 `abilities` | `未知属性键 "力量"，可用：str, dex, con, int, wis, cha` |
| `unknownSkill` | `optionType: "skill"` 的选择里的选项不在 `skills` | `未知技能 "特技"（可用别名：杂技）` |
| `invalidSkillCount` | 技能选择的 `minimum`/`maximum` 不在 0..选项数 | `技能选择的数量必须为 0..6` |
| `invalidSpellcastingMode` | `mode` 不在枚举 | `spellcasting.mode 必须是 prepared / known / pact / none` |
| `unknownArchetype` | `archetype` 不在 `progressions` | `未知原型 "three-quarter-caster"` |
| `invalidTable` | `Table<T>` 键不在 1..20、数组长度为 0 或 >20、值类型不符或为负；`resources[].startsAtLevel` 不在 1..20（沿用本 code，不新增） | `prepared["21"] 的键必须为 1..20`（**短数组合法**，见 §3.12） |
| `invalidMaxSpec` | 三种写法全缺或同时出现多种、`minimum` 为负、`formula` 不在封闭语法 | `maximum 必须且只能使用 value / formula / table 之一` |
| `duplicateResourceId` | 同职业内 `resources[].id` 重复 | `资源 id "rage" 重复` |
| `invalidRecovery` | `recovery` 不在枚举 | `recovery 必须是 shortRest / shortRestOne / longRest / none` |
| `unknownGrantKind` | `kind` 不在 9 项枚举（含被移除的 `resource` / `conditionResistance` / `note`） | `未知 grant kind "resource"，职业资源请改用 classRules.resources` |
| `unknownOptionType` | `optionType` 既不是已知条目类型也不是已知值类型 | `未知选项类型 "savingThrow"` |
| `unsupportedFormatVersion` | `formatVersion != 3` | `只支持 formatVersion 3；这是旧格式，请用新版工具重新生成` |
| `builtinSlugRequiresExplicitRules` | `class` 条目 slug 命中内置 12 slug 却未声明 `classRules` | `slug "fighter" 属于内置职业：要覆盖其数值必须显式声明 classRules` |
| `invalidChoiceRange` | `minimum`/`maximum` 为负或 `maximum < minimum` | `maximum 不能小于 minimum` |
| `invalidOptionRef` | 条目选项引用不存在、或未通过 `optionType`/`optionTags`/`maximumOptionLevel` 过滤、或 `recommendedEntryIds` 不合法 | `选项 "x:feat/a" 不满足本选择的类型/标签/等级过滤` |
| `duplicateOptionId` | 同一选择内 inline 选项 id 重复，或 id 与条目选项冲突 | `选项 id "asi" 重复` |
| `invalidValueOption` | 值类型选择里出现条目选项字段（`optionEntryIds`/`optionTags`），或条目类型选择里 `options` 与 `optionEntryIds` 同时为空 | `值类型选择不允许 optionEntryIds` |
| `invalidRequires` | `requires` 引用了不存在的 `choice`/`option`，或 `ability` 非法、`minimum` 非正 | `requires 引用的选择 "spellbook-x" 不存在` |
| `invalidCountsToward` | `countsToward` 不在 `spellbook`/`known`/`prepared`/`null` | `countsToward 必须是 spellbook / known / prepared 或省略` |
| `invalidAutoGrant` | 字符串简写无法为该 `optionType` 推断 grants，且未显式写 `grants` | `optionType "value" 的选项 "x" 缺少 grants，且无法自动推断` |

### 5.2 Warning（可导入，导入预览中列出）

| code | 条件 |
|---|---|
| `missingCoreField` | 职业条目缺 `hitDie`（或施法职业缺 `spellcasting`），角色卡对应数值将缺省 |
| `missingPreparedColumn` | 施法职业未声明 `prepared`（原型**不提供**该列，见 §3.1/§3.3；编辑器不限制数量） |
| `ignoredGlobalList` | 包自带了 `abilities` / `skills` 清单（内置档案为唯一权威，该清单被忽略） |
| `unresolvedClassRule` | 条目没有任何可用规则来源（既无 `classRules` 也无档案匹配） |
| `zeroLevelResource` | 资源的表在 `startsAtLevel` 及以上出现 0（该级上限为 0，UI 不显示） |

> **不存在的 warning**：不得因为"职业只声明到 N 级"或"Table 是短数组"而产出任何 error/warning
> ——这是合法写法（§3.12），只在界面作为信息呈现。

> 不再存在任何"legacy 写法"warning：旧形状一律按未知字段/未知取值报 error（§3.9）。

### 5.3 诊断的路由

`RuleDiagnostic.severity == error` → `ContentValidationError`（现有整包阻断语义与 UI 不变）；
`severity == warning` → 导入报告新增 `warnings` 列表，在 `ContentImportPreviewDialog` 中以次级样式展示，不阻断。

---

## 6. 测试策略

### 6.1 资产测试（替代现有的硬编码核算）
- `dnd5e_rules_verification_test.dart`（现有 49 项）改为加载内置档案并对官方表断言数值（生命骰、豁免、法术位 1–20、准备法术 1–20、契约魔法、资源次数与恢复语义）。加载方式：`File('assets/rules/dnd5e-2024.rules.json')`（`flutter test` 的工作目录是包根，无需 `rootBundle` 与 binding），失败时测试报出资产路径。
- 新增档案 schema 自检：`rulebookVersion == 1`、6 项属性与全部技能、12 个核心 slug 全部存在、每个职业字段可解析、每个 `Table` 合法（数组长度 20 或稀疏键 1..20）、无未知原型引用。

### 6.2 重提取金标（私有包存在时运行，否则 skip）
- 用**重写后的提取器**重新产出 bundle，断言产物：无散文 `savingThrows`/`skills`、无 `preparedSpellcasting`、无 `spellSlot:`/`classResource:` grant、所有职业都有结构化 `classRules`。
- 对 12 职业 × {1,5,11,20} 级断言派生数值与改造前逐项相等：`hitDie`、豁免集合、每级法术位、每级准备上限、职业资源（战士/野蛮人）、邪术师契约位（形状 `{"<环阶>": n}`）。
- 断言邪术师**不再**出现 `classResources['pact-magic-slots']` 双重表示（行为变化，需在文档标注）。
- 与现有私有路径测试一致：缺少私有包时跳过，不使 CI 变红。

### 6.3 端到端自制职业（核心验收）
构造一个合成包（条目 id/slug/name 均不含任何核心职业名）：
- `classRules` 声明 `hitDie: 10`、豁免、`spellcasting{ mode: prepared, ability: cha, archetype: half-caster, slots: {"5": {"1":4,"2":2}} }`；技能选择写在 `rules.progression[].choices`（`optionType: "skill"`）、两个资源（一个 `formula: "level"`、一个 `table` + `startsAtLevel: 3`）；另在 `rules.progression` 里用 `kind: "hitPoints"`（`formula: "level"`）与 `kind: "ability"`（`target: "cha"`, `value: 1`）声明按等级生效的效果。
- 流程：导入 → 断言无 error → 建角色（第 1、5、20 级）→ 断言 HP（含 `hitPoints` grant）、属性（含 `ability` grant 及其对 DC/技能的连带影响）、豁免、技能选择上限、法术位、资源次数与恢复语义、准备上限、施法 DC；→ 升级 +1 级后断言增量。
- 选择系统专项（§3.10）：字符串简写技能选项自动授予熟练；内联 `options` 的 `ability +1` 真的改变派生；`optionType: "spell"` + `countsToward` 的法术选择受 `prepared` 上限约束；`repeatable: true` 允许同一选项选两次而 `repeatable: false` 被拒；`requires` 不满足时选项隐藏；`group`/`help` 出现在编辑器；装备 A/B 方案写入 `inventory`。
- 变体：只声明 `hitDie` + 豁免的最小职业（断言其余数值为"未声明"而非猜测）；只声明 `archetype: pact` 的契约施法者（断言 `{"<环阶>": n}` 形状与短休恢复）；用 `slots` 表写满 20 级的自定义施法者。

### 6.4 校验与解析链
- §5.1 每条 error、§5.2 每条 warning 各一个最小反例包，断言 `path` 与消息。
- 解析链：条目声明优先于档案；`slots`/`prepared`/`cantrips`/`maximumSpellLevel` 各自整表优先于 `archetype`；稀疏 `Table` 按"不超过当前等级的最大已声明档位"取值；条目声明优先于内置档案（字段级）；未声明字段返回空且产出提示而非猜测。
- 回归：`RuleProfileStore` 加载失败时 fail-fast。

### 6.5 生成侧（P0，与契约定稿同步）
- 重写 `scripts/extract_phb_2024_v2.py`：输出 `classRules`（`hitDie` / `savingThrowAbilities` /
  `spellcasting` 表 / `resources`，并把技能与法术**选择**写成 `rules.progression[].choices`），
  不再输出散文与逐级 `spellSlot:`/`classResource:` grant。
- `scripts/test_phb_2024_v2_tools.py` 同步断言"产物只含新契约形状"；`npm run test:scripts` 保持全绿。

### 6.6 门禁
`npm run check`（服务端 lint + 客户端 analyze + 服务端/客户端测试）、`npm run test:scripts`、`npm run lint:design` 全绿；客户端测试数量只增不减。

---

## 7. 迁移（内容重提取 + 用户数据回填）

- **内容**：全部**重新提取**（P0 重写提取器）。旧形状的包在导入时报 error 并提示重新提取，
  **不提供**读取旧格式的回退路径（§0 需求二）。
- **用户数据**：唯一保留的迁移是老角色卡的 `data.classIdentity` 一次性回填——
  由 `CharacterRuleProjector` 按条目 `slug`/`name`/`aliases` **精确匹配**（不做子串猜测）写入；
  匹配不到则标记"该职业未声明规则"，数值按未声明处理。理由：内容可以重提取，玩家的角色卡不能重来。
- **行为变化清单**（必须写入 `docs/README.md` §7.7 与提交说明）：
  1. 旧契约形状（散文 `savingThrows`/`skills`、`preparedSpellcasting`、`spellSlot:`/`classResource:` grant）不再被解析，导入报 error。
  2. 邪术师契约位不再作为 `classResources` 条目出现（改由法术位承担，消除双重表示）。
  3. 准备法术上限不再需要独立开关（由 `spellcasting.mode` + `prepared` 表决定）。
  4. 未知技能名不再静默丢弃（现在会在导入期被拒绝并指出位置）。
  5. `conditionResistance` / `note` grant 会被拒绝（导入报错）。
  6. 职业数值改为"条目声明优先于内置档案"，本地自制职业条目可覆盖同 slug 的内置数值。
  7. 自制职业可以只靠 `classRules` 声明规则；未声明字段显示"未声明"而非猜测。
  8. 法术选择与技能选择改为走统一的选择模型与同一套 UI。
  9. **新增 11 个职业的资源池追踪**（诗人激励/引导神力/野性形态/专注点/圣疗/宿敌/术法点/先天术法/魔法诡计等）——这是能力增加，不是回归；老角色首次打开时会由项目器补齐。
  10. 武器攻击不再按名字匹配硬编码的 5 把武器，改为读取物品条目自身的 `structured`（`damage`（如 `"1d8 挥砍"`）/`category`/`finesse`）；未声明伤害的物品不再产出攻击行动，**不猜**。

---

## 8. 文档更新清单

| 文件 | 更新 |
|---|---|
| `docs/README.md` §9.1 | 重写为现行契约：档案格式、`classRules` 字段全集、`Table` 与 3 种 `maximum`、**选择系统全字段**、解析链与优先级、error/warning 全清单、完整自制职业示例（含选择与法术选择）、"旧契约不读取"说明 |
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
| 搬迁数值出错（最严重） | §6.2 重提取金标逐个数值对照（12 职业 × 4 等级）；§6.1 官方表核算指向资产 |
| 全局可变 profile | 只允许启动时 `configure` 一次，之后只读；测试提供显式重置钩子；`configure` 在已装配后再次调用抛错 |
| 资产加载失败致应用不可用 | fail-fast + 明确错误；CI 资产测试保证不会发布坏档案 |
| 不背兼容层导致旧包直接不可用 | 这是用户明确选择的取舍（§0 需求二）：旧包按未知字段报 error，并提示"请用新版提取器重提取"；不提供静默降级 |
| 简写层与规范层语义分歧 | 规范化在解析期一次完成，运行时只认规范层；两者同时存在时规范层优先，并对简写产出的规范项标注来源 |
| 解析链让"未声明"变成用户可见的空值 | 只在角色页提示、不阻断；导入时 warning 提前暴露 |
| 老角色 `classSummary` 无法精确匹配（如"战士（奥法骑士）"） | 项目器可拆分子职名与母职业名做精确匹配；仍失败则提示，不做子串猜测 |
| 移除三个 grant kind 破坏未知第三方包 | 不背兼容层是用户明确取舍；导入期报错信息明确指向替代写法（`classRules.resources`、`notes` 字段） |

---

## 10. 验收标准

1. 客户端**代码**中**不存在**任何以职业名（中文或英文）为键的规则表或 `contains` 职业匹配（`grep` 可验证；内置档案里的 `classes.<slug>` 键属于数据，不计入）。
2. 内置档案通过 §6.1 的官方表核算与 schema 自检。
3. §6.2 重提取金的标数值与改造前相等；产物不含任何旧契约形状；邪术师双重表示消失。
4. §6.3 合成自制职业包端到端通过（含升级与选择系统专项）。
5. §5.1 / §5.2 每条诊断都有对应测试，`path` 精确。
6. `npm run check`、`npm run test:scripts`、`npm run lint:design` 全绿。
7. `docs/README.md` §9.1 含完整自制职业示例（含选择与法术选择），且示例可被测试中的合成包复用（文档与实现不脱节）。
8. **选择系统（§3.10）**：字符串简写自动授予且选中生效；内联选项的 `ability`/`hitPoints` 改变派生结果；`optionType: "spell"` + `countsToward` 受 `prepared` 约束；`repeatable` 行为正确；`requires` 隐藏语义正确；`group`/`help` 呈现；装备 A/B 方案写入 `inventory`；技能选择与法术选择都只由 `optionType: "skill"` / `"spell"` 的选择定义承担（`classRules` 不再派生选择）。

---

## 11. 明确不在本次范围

- **S3**：`mode: "patch" | "replace"` 声明、可配置 `priority` 字段（含 Drift 迁移）、覆盖冲突 UI、关闭覆盖回退内置。
- **S4**：作者 GUI 的**完整形态**（可视化规则表单、基于已有条目创建覆盖、`.dndpack` 导出）。本轮只保证
  契约与引擎支持全部能力、编辑器能渲染并应用选择结果；把它做成"填表即得"的完整体验属于 S4。
- **C 场景**：自定义技能/属性清单、自定义 AC 公式（护甲敏捷上限、无甲防御）、自定义休息与恢复语义。
- **已建模**：12 职业的资源池**计数与恢复语义**（含随等级变化的恢复）、法术位与准备上限、HP/AC/速度/属性加值。
- **仍不建模的规则能力**（继续留在 §7.7 已知限制）：资源池的**具体效果**（引导神力选项、野性形态数据与形态切换、术法点转换法术位、圣疗治疗结算、魔法诡计恢复法术位、诗人激励骰的授予与消耗）——本次只追踪"用了几次/怎么恢复"，不做效果结算；伤害抗性与免疫结算、**奥法骑士/诡术师的准备或已知法术上限与戏法上限**（2024 职业表未给出，不臆造）、命中骰池、力竭等级惩罚、专注校验、专精、多职业、XP、负重、武器精通（Mastery）与 versatile 变化伤害骰。

---

## 12. 建议实现阶段（供实现计划参考）

| 阶段 | 内容 | 完成标志 |
|---|---|---|
| **P0** | **契约定稿 + 提取器重写**：`scripts/extract_phb_2024_v2.py` 输出新契约形状，`test_phb_2024_v2_tools.py` 同步；生成一份重提取样本用于后续金标 | 产物无旧形状；`npm run test:scripts` 全绿 |
| P1 | 内置档案 + `RuleProfile` / `ClassRuleSet` / `Table` / `MaxSpec` / 选择值对象 + `RuleProfileResolver`（含简写规范化）+ 资产测试与解析链测试 | 档案通过官方表核算；解析链与规范化测试全绿；`Dnd5eRules` 尚未接入 |
| P2 | `Dnd5eRules` 改为读 profile（删除职业表与中文匹配）+ `RuleProfileStore` 启动装配 + 消费者改造 + 重提取金标 | `npm run check` 全绿且客户端测试数量不减；金标数值全等 |
| P3 | 导入校验与 warnings（含 `ContentImportReport.warnings` + 预览 UI）+ `classIdentity` 与老角色回填 | §5 每条诊断都有测试；老角色提示正确 |
| P4 | grant kind 收紧：实现 `hitPoints`/`ability`、移除 `resource`/`conditionResistance`/`note`、修邪术师双重表示 | 行为变化清单逐条有测试 |
| **P5** | **选择系统落地**（§3.10）：值类型选项 + 内联 grants + 自动授予、`optionType: "spell"` + `countsToward`、`repeatable`、`requires`、`group`/`help`、装备 A/B、`progression[].levels` 数组 | §10.8 逐条有测试；编辑器可选择且生效 |
| P6 | 文档（§9.1 重写、§7.7、§2/§16、README、AGENTS.md、§13.6） | 文档示例与合成包一致 |

P1→P2 之间必须有一次全量回归（这是数值搬迁的安全网，不可跳过）。
P0 必须在 P1 之前完成：契约形状一旦定稿，提取器与档案必须同步，否则无法产生金标。
