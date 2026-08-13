# 角色文档、规则快照与权限规范

**版本：** 0.1  
**范围：** D&D 2024 角色、NPC 与怪物；不包含战斗自动化

## 1. 核心原则

角色创建或升级完成后，**角色文档是该角色的事实来源**。资料库只负责检索和授予
模板，不是角色卡运行时依赖。删除、禁用或替换资料包后，已经获得的职业特性、法术、
动作和物品仍必须可查看、编辑、导出和参与战役。

数据流固定为：

```text
资料库条目 -> 创建/升级/手动添加 -> 角色规则快照 -> 本地角色文档
                                              -> 战役角色快照
```

不得在打开角色卡时根据当前资料库临时拼出已获得内容。资料库更新也不得静默改变现有
角色；用户必须通过明确的升级、重新应用模板或迁移操作接受变化。

## 2. 存储层级

### 2.1 规范内存模型

Flutter 使用 `CharacterSheet` 作为规范运行模型。复杂字段保存在结构化 `data` 中，至少
包括：

- `build`：职业、子职业、种族、背景和选择结果；
- `runtime`：临时生命、激励、死亡豁免、状态和资源消耗；
- `contentRefs`：按 `features/spells/items` 分类的稳定来源 ID；
- `ruleSnapshots`：角色已经获得的完整规则副本；
- `actions`：可直接执行或自定义的角色动作；
- `monster`：怪物特性、动作、反应、传奇动作、施法、感官和语言；
- `profile`：外貌、性格、背景故事和其他人物资料；
- `manualOverrides`：用户添加、隐藏或覆盖的规则内容；
- `extensions`：带命名空间的未知扩展数据。

### 2.2 规则快照

`ruleSnapshots` 以稳定条目 ID 为键。快照必须包含当时授予角色所需的完整可读内容：

```json
{
  "ruleSnapshots": {
    "private-phb:spell/shield": {
      "snapshotVersion": 1,
      "id": "private-phb:spell/shield",
      "type": "spell",
      "name": "护盾术",
      "summary": "...",
      "body": [],
      "structured": {"level": 1, "school": "防护"},
      "rules": {},
      "source": {"label": "..."},
      "revision": 1
    }
  }
}
```

角色卡渲染时先读取角色快照；当前资料库中的同 ID 条目只能用于补充旧角色或由用户明确
选择更新。自定义内容没有资料库 ID 时也必须生成角色内稳定 ID。

### 2.3 Drift、Markdown 与战役副本

- Drift `Characters` 保存规范 JSON，是客户端查询和修改的事务边界。
- Markdown 是完整、可读、可编辑的交换表示，不直接充当数据库事务文件。
- 每次角色保存后生成对应 Markdown 镜像；导入时解析为 `CharacterSheet`，验证后再写入
  Drift。
- 发布到战役时上传完整角色文档，形成独立 `CampaignCharacter.sheetJson`。
- 本地副本与战役副本通过 backlink、revision 和变更事件自动同步；不得靠资料库重建。

## 3. Markdown 格式

文件使用 `format: dnd-table-character/v2`。frontmatter 保存可快速检查的核心字段，并用
`snapshot` 保存完整规范 JSON 的 Base64URL 表示；正文保持人类可阅读、可编辑。

```markdown
---
format: dnd-table-character/v2
kind: player
name: '阿莉娅'
system: dnd5e-2024
level: 5
snapshot: '<base64url canonical json>'
---

# 阿莉娅

## 基础信息

- 职业：战士 5
- 种族：人类

## 规则特性

### 动作如潮

这里是角色获得该特性时保存的完整说明。

## 法术

### 护盾术

这里是角色获得该法术时保存的完整说明。

## 角色动作

### 长剑

- 检定：`1d20+7`
- 伤害：`1d8+4`

## 装备

## 角色资料

## 笔记
```

怪物与 NPC 使用同一格式，`kind: monster`，并增加 `描述`、`特性`、`动作`、`附赠动作`、
`反应`、`传奇动作`、`施法` 和 `怪物资料`。每个动作必须是独立三级标题，禁止把多个
动作压成一个段落。未知 frontmatter 和 `extensions` 字段必须往返保留。

## 4. 权限矩阵

| 场景 | 查看完整卡 | 掷骰 | 编辑 |
|---|---:|---:|---:|
| 本地角色所有者 | 是 | 是 | 是 |
| 战役角色所有者 | 是 | 是 | 是 |
| 同战役其他玩家 | 是（受可见性限制） | 是 | 否 |
| 战役 DM/owner | 是 | 是 | 是，包含玩家角色与 NPC |
| 非战役成员 | 否 | 否 | 否 |

客户端只根据服务端 `CampaignCapabilities` 和角色 `ownerUserId` 决定权限，不得根据本地
“DM 模式”猜测。只读角色卡必须隐藏所有写入口，包括 HP、资源、状态、装备、动作、法术、
特性和人物资料编辑。服务端仍必须再次鉴权，不能信任客户端隐藏控件。

## 5. 修改接口

UI、同步器和未来 Agent 必须调用相同业务接口，不得直接改数据库或任意 JSON：

- `character.get` / `character.get_summary`
- `character.update_profile`
- `character.adjust_hp`
- `character.add_condition` / `character.remove_condition`
- `character.restore_resource`
- `character.add_item` / `character.remove_item` / `character.transfer_item`
- `character.add_action` / `character.update_action` / `character.remove_action`
- `character.add_spell` / `character.remove_spell`
- `character.add_feature` / `character.remove_feature`
- `character.import_markdown` / `character.export_markdown`
- `campaign.character.publish` / `campaign.character.update`

每个写操作必须校验权限、结构、`expectedRevision` 和幂等 `requestId`，并产生结构化事件。

## 6. 兼容与迁移

- 旧角色只有名称型快照时，可在本机仍安装对应资料包的情况下执行一次显式补全；补全后
  写回角色文档。
- 无法补全时保留原始名称和自定义文本，不显示“角色内容不存在”，也不得删除引用。
- schema 升级必须是版本化迁移；不得在 UI build 阶段改写持久数据。
- 资料包条目 ID 改名需要提供 alias/migration 映射，但不能自动替换角色自定义内容。

## 7. 验收要求

- 新建、升级、手动添加后，断开资料库仍可完整打开角色卡。
- Markdown 导出内容可读，重新导入后规则快照、动作、怪物分组和扩展字段不丢失。
- 玩家无法编辑其他玩家和 NPC；DM 可以编辑战役内所有角色；角色所有者可以编辑自己。
- 不同账号相同本地角色 ID 可以发布到同一战役，不发生冲突。
- 聊天、战役中心和角色列表打开同一角色时使用同一权限判定与同一完整角色卡组件。
