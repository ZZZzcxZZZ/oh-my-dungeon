# 本地资料包格式 v1

本文件定义 D&D Table Tool 本地资料库的 v1 资料包格式。资料库默认为空，项目不内置任何 SRD/PHB/官方规则正文；用户通过本地导入 JSON 或 `.dndpack` 包添加自己的资料。格式是来源中立的：导入器只校验结构、链接和资产安全，不关心条目来源于官方、社区还是用户自创。

## 1. 概述

资料包有两种文件形式：

- **单文件 JSON**：扩展名 `.json`，根对象同时包含 manifest 字段和 `entries` 数组。适合小型或纯文本资料。
- **`.dndpack` 归档**：ZIP 压缩包，扩展名 `.dndpack`，根目录必须包含 `manifest.json` 和 `entries.json`，可选 `assets/` 目录存放图片等二进制资源。适合带图片或大体积资料。

两种形式的 manifest 和 entries 字段完全一致，区别只在于资产存放方式：单文件 JSON 不携带二进制资产，`.dndpack` 通过 `assets/` 相对路径引用。

## 2. Manifest 字段

`manifest.json`（或单文件 JSON 的根对象除 `entries` 外的部分）必须包含以下字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `formatVersion` | 整数 | 必须为 `1`。其他值表示未来格式，v1 读取器拒绝。 |
| `id` | 字符串 | 包的稳定标识符，建议使用反向域名或 `slug`，例如 `com.example.srd`。同一 `id` 的导入视为升级。 |
| `name` | 字符串 | 人类可读包名。 |
| `version` | 字符串 | 语义化版本号，例如 `1.0.0`。 |
| `locale` | 字符串 | 主要语言标签，例如 `zh-CN`、`en-US`。 |
| `system` | 字符串 | 规则系统标识，例如 `dnd5e-2024`。 |
| `entryCount` | 整数 | `entries` 数组的长度。导入器会校验该值与实际数组长度一致。 |

## 3. 条目字段

`entries` 数组中每个对象必须包含以下字段，其余字段可选：

| 字段 | 必填 | 类型 | 说明 |
| --- | --- | --- | --- |
| `id` | 是 | 字符串 | 条目稳定 ID，必须以 `{packageId}:` 开头，例如 `com.example.srd:class/fighter`。跨升级保持不变，收藏和笔记按此 ID 关联。 |
| `type` | 是 | 字符串 | v1 类型枚举之一，见下。 |
| `slug` | 是 | 字符串 | 包内唯一的小写标识，例如 `fighter`。与 `id` 的最后一段对应。 |
| `name` | 是 | 字符串 | 条目显示名。 |
| `body` | 是 | 数组 | 内容块数组，见第 4 节。允许为空数组。 |
| `revision` | 是 | 整数 | 条目内容修订号，递增。 |
| `aliases` | 否 | 字符串数组 | 别名列表，参与全文检索。 |
| `summary` | 否 | 字符串 | 一句话摘要，参与检索和列表显示。 |
| `structured` | 否 | 对象 | 结构化字段，例如法术的 `level`、`school`，职业的 `hitDie`。扩展原则见第 5 节。 |
| `tags` | 否 | 字符串数组 | 自由标签，参与检索和筛选。 |
| `source` | 否 | 对象 | 来源信息，建议包含 `label` 字段，例如 `{ "label": "本地资料" }`。 |

### v1 类型枚举

`type` 必须是以下 13 个值之一：

```
class, subclass, classFeature, species, background, feat,
spell, equipment, item, condition, rule, monster, custom
```

未知类型在导入阶段被拒绝。

## 4. 内容块类型

`body` 是内容块数组。v1 读取器只接受以下 10 种安全块类型，未知块类型以 `FormatException` 拒绝（携带 JSON 路径）。**`html` 块被显式拒绝**，任何原始 HTML 都不会进入资料库。

| 块类型 | 必填字段 | 说明 |
| --- | --- | --- |
| `heading` | `level`（整数 1–6）、`text` | 标题。 |
| `paragraph` | `text` | 段落正文，纯文本。 |
| `list` | `items`（字符串数组）、`ordered`（布尔，可选） | 列表。 |
| `table` | `headers`（字符串数组）、`rows`（二维字符串数组） | 表格。 |
| `quote` | `text`、`cite`（字符串，可选） | 引用块。 |
| `callout` | `text`、`variant`（字符串，可选，如 `info`/`warning`） | 高亮提示。 |
| `image` | `path`（`assets/` 相对路径）、`alt`（字符串，可选） | 图片，仅 `.dndpack` 支持；单文件 JSON 中引用资产会被拒绝。 |
| `statBlock` | `fields`（对象数组，每项含 `label` 和 `value`） | 属性统计块，例如法术环阶、学派。 |
| `entryLink` | `targetId`（条目 ID）、`text` | 包内条目链接，`targetId` 必须在同一包内可解析，见第 7 节。 |
| `diceExpression` | `notation`（骰子表达式字符串）、`label`（字符串，可选） | 可掷骰表达式。 |

## 5. 结构化字段扩展原则

`structured` 是开放对象，但读取器只识别已知类型的已知字段，未知字段保留但不影响渲染。新增结构化字段时：

- 不要改变已存在字段的含义或类型。
- 复杂嵌套应通过新键扩展，而不是重命名旧键。
- 渲染器对未知 `structured` 字段保持静默，不抛出异常。

## 6. 稳定 ID 与升级保留

- 条目 `id` 在包升级（同 `id` 重新导入）过程中保持不变。
- 收藏（`ContentFavorites`）和笔记（`ContentNotes`）以条目 `id` 为主键关联，升级后自动保留。
- 删除条目（升级版本中不再存在该 `id`）会同时清理其收藏和笔记。
- 包自身的 `id` 是升级键：导入同 `id` 包会原子替换旧版本。

## 7. 链接解析

`entryLink` 的 `targetId` 必须在导入预览阶段解析成功：

- `targetId` 必须属于当前包的 `entries` 之一。
- 不允许跨包链接；跨包引用应通过 `source` 或 `tags` 表达关联，而不是 `entryLink`。
- 解析失败时导入器返回 `valid: false`，错误路径形如 `$.entries[0].body[0].targetId`，且不写入任何数据。

## 8. 资产（仅 `.dndpack`）

`.dndpack` 归档的 `assets/` 目录存放图片等二进制资源。`image` 块的 `path` 必须是 `assets/` 开头的相对路径。

### MIME 与文件签名

每个资产的声明 MIME 必须与文件头签名一致；不一致时拒绝导入。

### 大小与数量限制

| 限制项 | 上限 |
| --- | --- |
| 压缩后归档大小 | 50 MB |
| 解压后总大小 | 200 MB |
| 文件数量 | 5000 |
| 单文件大小 | 20 MB |

### 路径安全（zip-slip 防护）

导入器拒绝以下路径，违反时整体拒绝且旧包不变：

- 绝对路径（如 `/etc/passwd`、`C:\...`）。
- 包含 `..` 的相对路径。
- 符号链接条目。
- 规范化后重复的路径（防止同名覆盖）。

## 9. 升级原子性

`replacePackage` 在单一数据库事务内执行：

1. 删除同 `id` 旧包及其条目、资产、链接。
2. 写入新 manifest、条目、资产和链接。
3. 重建全文检索索引。
4. 提交事务。

任一步骤失败则整体回滚，已存在的旧包保持不变。预览（`previewJson` / `previewDndPack`）不写入任何数据，只返回校验报告；只有 `importReport` 接收 `valid == true` 的报告后才执行事务。

## 10. 示例空包

最小合法 v1 包（0 条目）：

```json
{
  "formatVersion": 1,
  "id": "com.example.empty",
  "name": "空示例包",
  "version": "1.0.0",
  "locale": "zh-CN",
  "system": "dnd5e-2024",
  "entryCount": 0,
  "entries": []
}
```

带一个条目和包内链接的示例：

```json
{
  "formatVersion": 1,
  "id": "com.example.srd",
  "name": "示例资料",
  "version": "1.0.0",
  "locale": "zh-CN",
  "system": "dnd5e-2024",
  "entryCount": 2,
  "entries": [
    {
      "id": "com.example.srd:class/fighter",
      "type": "class",
      "slug": "fighter",
      "name": "战士",
      "aliases": ["Fighter"],
      "summary": "武器大师",
      "body": [
        { "type": "heading", "level": 2, "text": "职业特性" },
        { "type": "entryLink", "targetId": "com.example.srd:feature/action-surge", "text": "动作如潮" }
      ],
      "structured": { "hitDie": "d10" },
      "tags": ["class"],
      "source": { "label": "本地资料" },
      "revision": 1
    },
    {
      "id": "com.example.srd:feature/action-surge",
      "type": "classFeature",
      "slug": "action-surge",
      "name": "动作如潮",
      "body": [
        { "type": "paragraph", "text": "在你回合内获得一个额外动作。" }
      ],
      "revision": 1
    }
  ]
}
```

## 11. 兼容策略

- `formatVersion` 未来升级时，新版本必须在本文件记录迁移说明。
- v1 读取器遇到 `formatVersion != 1` 时直接拒绝，不尝试降级解析。
- v1 读取器遇到未知内容块类型时，以 `FormatException` 拒绝整个包，不进行部分写入。
- 已导入的 v1 包在客户端升级后保持可读；读取器向后兼容已存在的 v1 数据。
