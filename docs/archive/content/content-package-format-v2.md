# 本地资料包格式 v2：D&D 2024 规则声明

v2 在 v1 的安全内容块和稳定 ID 基础上，为条目增加可执行但非脚本化的 `rules` 字段。项目不附带规则正文；本格式只规定用户导入资料如何参与角色创建、升级、角色卡和跑团动作。

## Manifest

`formatVersion` 必须为 `2`，`system` 必须为 `dnd5e-2024`。客户端继续读取 v1 资料包；早期 v1 职业条目中的 `structured.features` 会通过兼容迁移转成等级规则，其余可执行规则应使用 v2 声明。

## rules

```json
{
  "rules": {
    "grants": [],
    "choices": [],
    "progression": [
      {
        "level": 1,
        "grants": [],
        "choices": []
      }
    ]
  }
}
```

- `grants`：选择该条目后立即获得的规则项。
- `choices`：选择该条目后立即需要完成的选项。
- `progression`：角色达到对应等级后激活的授予和选择，等级只能为 1–20。

兼容迁移会识别 `structured.features` 中形如 `N级：特性名 ...` 的字符串，拆成独立 `classFeature` 条目并生成 `progression` 中的 `feature` grant。该迁移只用于已有私有包；新资料包应直接声明独立条目和规则。

## Grant

```json
{
  "id": "second-wind-resource",
  "kind": "resource",
  "label": "回气",
  "entryId": "my-pack:class-feature/second-wind",
  "value": 2,
  "data": { "reset": "longRest" }
}
```

`id` 在来源条目内稳定；`label` 用于角色卡解释；`entryId` 必须指向同一包的条目。允许的 `kind`：

```
feature, proficiency, spell, equipment, resource, action,
conditionResistance, speed, armorClass, hitPoints, ability, note
```

可选字段：

- `target`：受影响的规则目标，例如 `skill:perception`、`armor:all`、`ability:str`。
- `value`：简单数值；加值由规则引擎按种类解释。
- `formula`：受限骰子或数值表达式，只作为数据保存；当前版本不执行任意函数。
- `data`：规则种类的附加参数，未知字段保留但不执行。

## Choice

```json
{
  "id": "starting-spells",
  "label": "选择起始法术",
  "optionType": "spell",
  "minimum": 3,
  "maximum": 3,
  "optionTags": ["spell-list:example-mage"],
  "maximumOptionLevel": 1,
  "recommendedEntryIds": [
    "my-pack:spell/example-cantrip",
    "my-pack:spell/example-ward",
    "my-pack:spell/example-utility"
  ],
  "builderStep": "spells"
}
```

角色中的选择键固定为 `{sourceEntryId}#{choiceId}`。所有过滤条件同时生效：

- `optionType`：候选条目的 `type` 必须相同。
- `optionEntryIds`：可选的稳定 ID 白名单；为空时不限制 ID。
- `optionTags`：候选条目必须包含列出的全部标签。职业法表建议使用 `spell-list:<slug>`。
- `maximumOptionLevel`：候选条目的 `structured.level` 不得高于该值，适用于法术环阶等整数等级。
- `recommendedEntryIds`：创建或升级时自动预选；必须同时满足上述过滤条件，且数量不会超过 `maximum`。
- `builderStep`：把选择放到指定引导页。允许值为 `class`、`origin`、`abilities`、`proficiencies`、`equipment`、`spells`、`details`；省略时跟随来源条目。

角色引擎会再次校验已经保存的选择。被篡改、已失效或不再满足过滤条件的 ID 不会产生授予，并会作为待处理选择显示。选择的条目可拥有自己的 `rules`，引擎会递归应用并以稳定 ID 防止循环。

## relations

条目之间使用稳定 ID 关系建立 Wiki 跳转和规则归属。关系目标必须存在于同一资料包中，导入时会一次性校验：

```json
{
  "id": "my-pack:subclass/champion",
  "type": "subclass",
  "slug": "champion",
  "name": "勇士",
  "body": [],
  "revision": 1,
  "relations": [
    {
      "type": "subclassOf",
      "targetId": "my-pack:class/fighter"
    }
  ]
}
```

允许的关系类型：

```
subclassOf, featureOf, spellOf, requires, replaces, related
```

- `subclassOf`：子职业指向所属职业。职业的 `optionType: "subclass"` 选择只会列出指向当前职业的子职业。
- `featureOf`：职业特性或子职业特性指向其来源职业/子职业，用于等级视图、反向链接和来源解释。
- `spellOf`：法术指向法表或施法来源；当前主要用于 Wiki 关系，角色资格仍由 choice 的标签和等级条件控制。
- `requires`：声明条目依赖。
- `replaces`：声明条目替代另一条目。
- `related`：普通阅读关联；反向链接由客户端索引计算。

子职业通常由职业等级进度产生选择，再递归应用子职业自身的规则：

```json
{
  "id": "my-pack:class/fighter",
  "type": "class",
  "slug": "fighter",
  "name": "战士",
  "body": [],
  "revision": 1,
  "rules": {
    "progression": [
      {
        "level": 3,
        "choices": [
          {
            "id": "fighter-subclass",
            "label": "选择战士子职业",
            "optionType": "subclass",
            "minimum": 1,
            "maximum": 1,
            "builderStep": "class"
          }
        ]
      }
    ]
  }
}
```

选择子职业后，它的 `grants`、`choices` 和 `progression` 会递归进入角色创建、升级和角色卡。

## 职业基础规则字段

职业条目的展示摘要放在 `structured`，可执行选择与等级授予继续放在 `rules`。新资料包应使用稳定、与语言无关的规范字段：

```json
{
  "structured": {
    "primaryAbility": "力量或敏捷",
    "hitDie": "d10",
    "savingThrowAbilities": ["str", "con"],
    "skillChoice": {
      "count": 2,
      "options": ["杂技", "驯兽", "运动", "历史", "洞悉", "威吓", "说服", "察觉", "求生"]
    },
    "weaponProficiency": "简易武器与军用武器",
    "armorProficiency": "轻甲、中甲、重甲与盾牌",
    "startingEquipment": "用于阅读的简短方案摘要"
  }
}
```

- `savingThrowAbilities` 只允许六项能力稳定键：`str / dex / con / int / wis / cha`。角色构建器会把它们写入豁免熟练。
- `skillChoice.count` 是职业技能选择数量；`options` 使用客户端稳定技能名。创建引导只展示候选项，背景已授予技能不会重复计数。
- `startingEquipment` 仅用于创建步骤的阅读摘要。可执行装备必须使用下文的 `equipmentBundle` choice 和 `equipment` grant，客户端不会从自然语言正文猜测物品。
- `primaryAbility / hitDie / weaponProficiency / armorProficiency` 用于创建摘要和派生计算；需要影响数值或库存时仍应声明对应 grant。

当前客户端兼容旧私有包的 `savingThrows` 与 `skills` 中文字符串，并归一化常见译名；该兼容层不应作为新包格式。私有包验收会检查每个职业能否解析出两个豁免、正数技能选择数量和非空候选。

## 法术检索分面

法术条目应提供 `structured.level`（0-9 整数）、`structured.school`（字符串）与 `structured.classes`（字符串数组）。资料库按环位、学派、职业执行 AND 查询；同一字段选择多个值时执行 OR 查询。筛选只读取结构化字段，不解析正文。
## 法术能力与法术位

施法职业在 `structured.spellcastingAbility` 中声明 `str`、`dex`、`con`、`int`、`wis` 或 `cha`。法术位使用 `resource` grant 和 `spellSlot:<环阶>` target 声明：

```json
{
  "structured": { "spellcastingAbility": "int" },
  "rules": {
    "progression": [
      {
        "level": 1,
        "grants": [
          {
            "id": "level-1-slots",
            "kind": "resource",
            "label": "一环法术位",
            "target": "spellSlot:1",
            "value": 2
          }
        ]
      }
    ]
  }
}
```

角色卡优先读取这些派生值计算法术位、施法加值与豁免 DC。没有 v2 声明的旧资料才使用客户端兼容回退。

## 起始装备方案

装备方案使用 `equipmentBundle` 条目。职业或背景 choice 选择方案，方案再递归授予真实装备条目：

```json
{
  "id": "my-pack:equipment-bundle/scholar",
  "type": "equipmentBundle",
  "slug": "scholar",
  "name": "学者装备方案",
  "body": [],
  "revision": 1,
  "rules": {
    "grants": [
      {
        "id": "book",
        "kind": "equipment",
        "label": "书籍",
        "entryId": "my-pack:equipment/book"
      }
    ]
  }
}
```

对应 choice 的 `optionType` 使用 `equipmentBundle`，`builderStep` 使用 `equipment`。方案本身不会进入库存，最终授予的 `equipment` 或 `item` 条目会进入角色库存和引用账本。

## Character 模板与 Character Markdown

怪物资料使用 `type: "monster"`，可执行预填数据只放在
`structured.characterTemplate`。正文 `body` 用于资料库阅读，不作为角色数值来源：

```json
{
  "id": "my-pack:monster/zombie",
  "type": "monster",
  "slug": "zombie",
  "name": "丧尸",
  "body": [],
  "revision": 1,
  "structured": {
    "challengeRating": "1/4",
    "type": "undead",
    "size": "medium",
    "alignment": "neutral-evil",
    "classification": {
      "creatureType": "undead",
      "subtypes": [],
      "tags": ["亡灵"]
    },
    "characterTemplate": {
      "kind": "monster",
      "templateRef": "my-pack:monster/zombie",
      "size": "medium",
      "creatureType": "undead",
      "alignment": "neutral-evil",
      "armorClass": 8,
      "initiativeBonus": -2,
      "hitPoints": {"maximum": 15, "formula": "2d8+6"},
      "speed": {"walk": 20},
      "abilities": {
        "str": 13, "dex": 6, "con": 16,
        "int": 3, "wis": 6, "cha": 5
      },
      "challengeRating": "1/4",
      "proficiencyBonus": 2,
      "actions": {
        "normal": [
          {
            "id": "slam",
            "name": "猛击",
            "description": "近战武器攻击说明。",
            "attack": {"bonus": 3},
            "damage": {"expression": "1d6+1", "type": "bludgeoning"}
          }
        ],
        "bonus": [],
        "reactions": [],
        "legendary": [],
        "lair": []
      },
      "sections": {
        "特质": "### 不死坚韧\n\n说明。",
        "动作": "### 猛击\n\n近战攻击说明。"
      }
    }
  }
}
```

客户端从模板创建的是普通、可编辑的角色实例。模板只负责初始值；
`templateRef` 和 revision 用于追溯来源，后续模板更新不得覆盖用户编辑。
实例可以进入角色库、完整角色卡、Markdown 导入导出、战役发布和聊天身份。

统一交换格式为 `dnd-table-character/v2`：

```markdown
---
format: dnd-table-character/v2
kind: monster
name: 丧尸
system: dnd5e-2024
templateRef: my-pack:monster/zombie
revision: 1
contentHash: sha256:...
generatedAt: 2026-07-29T12:00:00Z
size: medium
creatureType: undead
alignment: neutral-evil
armorClass: 8
hitPoints:
  current: 15
  maximum: 15
  formula: 2d8+6
speed:
  walk: 20
abilities:
  str: 13
  dex: 6
  con: 16
  int: 3
  wis: 6
  cha: 5
initiativeBonus: -2
challengeRating: 1/4
proficiencyBonus: 2
---

# 丧尸

中型亡灵，中立邪恶

## 特质

### 不死坚韧

说明。

## 动作

### 猛击

近战攻击说明。
```

YAML 是机器状态，Markdown 正文是人类可读描述。导入器接受缺少通用角色表格
的怪物图鉴式文件，也接受完整角色卡导出；未知 `##` 区块必须保留。旧
`dnd-table-character/v1` 只作为兼容输入。

## 物品模板与物品实例

资料条目描述物品本身，角色库存保存具体实例：

```json
{
  "id": "my-pack:item/ring-of-protection",
  "type": "item",
  "structured": {
    "category": "ring",
    "rarity": "rare",
    "attunement": true,
    "itemTemplate": {
      "kind": "item",
      "templateRef": "my-pack:item/ring-of-protection",
      "quantity": 1,
      "equipped": false,
      "attuned": false
    }
  }
}
```

库存实例统一保存：

```json
{
  "id": "instance-stable-id",
  "templateRef": "my-pack:item/ring-of-protection",
  "name": "守护戒指",
  "quantity": 1,
  "equipped": true,
  "attuned": true,
  "instanceData": {}
}
```

`templateRef` 可为空以支持自定义物品。战役服务端兼容读取旧 `itemId`，新写入
会归一化为上述实例字段；UI 和未来 Agent 都不得直接修改库存 JSON。

## 职业示例

```json
{
  "id": "my-pack:class/fighter",
  "type": "class",
  "slug": "fighter",
  "name": "战士",
  "body": [],
  "revision": 1,
  "rules": {
    "progression": [
      {
        "level": 1,
        "grants": [
          {
            "id": "second-wind",
            "kind": "feature",
            "label": "回气",
            "entryId": "my-pack:class-feature/second-wind"
          }
        ],
        "choices": [
          {
            "id": "fighting-style",
            "label": "战斗风格",
            "optionType": "feat",
            "minimum": 1,
            "maximum": 1
          }
        ]
      }
    ]
  }
}
```

## 兼容与升级

- v1 条目继续作为 Wiki、搜索和链接内容读取，其 `rules` 视为空。
- v1 升级到 v2 时保持 package ID、entry ID 和 revision 语义；新增 `rules` 后提高条目 revision。
- v2 导入会验证 grant/choice 类型、等级范围、创建步骤、显式与推荐条目引用，以及推荐项是否满足类型、标签和等级过滤；任一失败则整个包不写入。
- 2014 与混合规则包不受支持，`system != dnd5e-2024` 会在预览阶段拒绝。

## 私有包验收

商业规则正文不得提交、seed、打包或自动加载。私有包放入被忽略的 `private-imports/` 后，可使用工程命令执行双层验收：

```powershell
npm run validate:phb-private
```

该命令先运行 Python schema、链接、关系和规则引用检查，再在 Flutter 测试运行时调用真实 `ContentPackageImporter.previewJson()`。验收只读取本地文件，不会安装资料包、修改 Drift 数据或上传正文。
