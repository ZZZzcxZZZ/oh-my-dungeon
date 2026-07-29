# 私人工作区与战役体验收敛设计

**日期：** 2026-07-29
**版本：** 0.1
**状态：** 已确认
**范围：** Flutter 客户端、NestJS 服务端、Drift/IndexedDB、PostgreSQL、角色与资料 Markdown
**不包含：** 战斗系统、AI Agent 运行时、官方服务器运营系统、通用 TRPG 规则引擎

## 1. 目标

本轮解决账号数据串用、战役玩家身份和角色绑定不完整、会话不同步、资料与角色模型
混乱、相同交互重复实现等问题。改造必须保持离线优先和现有自由编辑能力，不重写
整个应用。

最终状态：

- 未登录用户使用独立的本机工作区；
- 每个服务器账号拥有独立私人工作区，断网时继续使用；
- 服务器有稳定实例身份和公开名称，客户端可添加私人备注；
- 本地角色发布为战役 Character 后可自动同步并显式绑定；
- 玩家、条目创建者和战役管理者的权限由服务端统一校验；
- 战役消息、会话、档案、角色、成员和未读状态自动刷新；
- 角色与资料使用稳定结构化模型，Markdown 是自动更新的可读镜像和交换格式；
- 触及的页面遵循同一套 Material 3 组件与信息层级。

## 2. 数据域与事实源

### 2.1 全局引导域

客户端保留一个不含私人角色和资料正文的 `bootstrap.db`：

```text
ServerProfile
KnownAccount
ActiveWorkspace
ApplicationPreference
MigrationMarker
```

它负责在未登录时选择服务器和工作区。不得在其中存储角色卡、导入资料正文、战役
消息或 Vault payload。

### 2.2 私人工作区域

原生平台目录：

```text
app-data/
├─ bootstrap.db
├─ local/
│  ├─ workspace.db
│  ├─ imports/
│  ├─ assets/
│  └─ exports/
└─ accounts/
   └─ {serverInstanceId}/
      └─ {userId}/
         ├─ workspace.db
         ├─ imports/
         ├─ assets/
         └─ exports/
```

Web 使用相同逻辑边界：

```text
dnd_bootstrap
dnd_workspace_local
dnd_workspace_{serverInstanceId}_{userId}
```

Web 的 `imports` 和 `assets` 使用 IndexedDB/OPFS 适配器，不假装拥有任意系统目录
访问权。

### 2.3 工作区切换

`WorkspaceStorageManager` 是打开和关闭私人工作区的唯一入口：

```dart
sealed class WorkspaceIdentity {
  const WorkspaceIdentity();
}

final class LocalWorkspaceIdentity extends WorkspaceIdentity {}

final class AccountWorkspaceIdentity extends WorkspaceIdentity {
  const AccountWorkspaceIdentity({
    required this.serverInstanceId,
    required this.userId,
  });

  final String serverInstanceId;
  final String userId;
}
```

切换顺序固定为：

1. 停止当前 Vault 和战役同步；
2. 解除依赖当前数据库的 Controller/Repository；
3. 关闭当前 `workspace.db`；
4. 打开目标工作区；
5. 重建工作区作用域依赖；
6. 从本地事实源恢复 UI；
7. 有网络时启动目标账号同步。

明确退出登录后切回 `local`。已登录时断网不切换目录，也不清空账号工作区。

### 2.4 旧数据迁移

现有单一 `app.db` 迁移到 `local/workspace.db`。首次进入账号工作区时，如检测到未
归属角色或私人资料，展示一次性迁移：

- 移动到当前账号；
- 复制到当前账号；
- 继续保留在本机。

迁移不得自动归属。原生平台通过临时目录、数据库事务和原子替换完成；Web 通过
新数据库写入完成后再写迁移标记。失败时保留原数据。

## 3. 服务器实例身份

服务端公开元数据增加稳定 `instanceId`：

```json
{
  "instanceId": "f394 ...",
  "name": "银剑公共跑团站",
  "version": "0.1.0",
  "apiVersion": "1"
}
```

`instanceId` 在首次部署时生成并保存到 `ServerSetting`，重启和更换域名后保持不变。
不得使用域名、用户名或服务器显示名作为工作区目录键。

客户端 `ServerProfile` 拆分：

```text
instanceId
serverName       服务端公开名称
localAlias       当前设备上的私人备注，可空
baseUrl
apiBaseUrl
websocketUrl
lastKnownVersion
lastConnectedAt
```

列表主标题优先使用 `localAlias`，副标题显示 `serverName`。没有备注时主标题使用
`serverName`。重新发现服务器时更新公开字段但保留 `localAlias`。

`/.well-known/dnd-tool-server` 必须读取持久化 `ServerSetting.serverName`，不能与
管理接口各自维护一套名称。环境变量只用于首次默认值。

## 4. 角色事实源与 Markdown 镜像

### 4.1 结构化事实源

角色继续以版本化 `CharacterDocument` 存入 `workspace.db`。核心分区固定：

```text
identity
build
abilities
combat
resources
conditions
inventory
features
spells
story
rules
extensions
```

HP、状态、资源、物品实例等不得存成不可解析文本。自定义内容进入明确的 manual
override 或 namespaced extension，不与规则授予混写。

### 4.2 Markdown 自动镜像

每个角色保存成功后自动生成：

```text
characters/{characterId}/character.md
characters/{characterId}/assets/
```

生成发生在结构化事务提交之后：

1. 更新 `CharacterDocument` 和 revision；
2. 提交数据库事务；
3. 生成确定性 Markdown；
4. 写入临时文件；
5. 原子替换 `character.md`；
6. 失败时记录 `markdownDirty` 并后台重试。

一次修改指保存动作或业务命令提交，不是每次键盘输入。HP、状态、资源、物品操作
提交后立即生成；长文本编辑在保存或失焦提交后生成。

Markdown front matter：

```yaml
---
format: dnd-table-character/v2
id: character-01
kind: player
system: dnd5e-2024
revision: 42
contentHash: sha256:...
generatedAt: 2026-07-29T12:00:00Z
---
```

正文必须可供人类直接阅读，使用表格、列表和稳定章节。Markdown 不是数据库唯一
事实源，而是自动维护的可携带事实快照。

检测到外部修改时必须展示差异，用户选择覆盖导入、合并或忽略。不得同时静默接受
数据库和文件修改。

私人笔记为空时，角色卡和生成的 Markdown 都不显示“备注”“私人笔记”占位段落。
创建角色、怪物模板投影和 Markdown 导入不得自动写入解释性备注。只有用户实际输入
内容时才保存和渲染私人笔记。

## 5. 资料包与怪物模型

### 5.1 私人资料落盘

用户导入的原始包保存在当前工作区：

```text
imports/{contentHash}/source.dndpack
imports/{contentHash}/manifest.json
imports/{contentHash}/import-state.json
```

解析后的条目和搜索索引写入 `workspace.db`。较大资源保存到 `assets/`，数据库保存
路径、哈希和媒体类型。内嵌测试资料属于应用只读基础层，不复制到每个工作区。

### 5.2 统一内容条目

`ContentEntry` 保留：

```text
id, type, slug, name, aliases, summary
body, structured, rules, relations, tags
source, revision
```

`body` 只承载阅读正文；角色创建和规则计算只读取 `structured/rules/relations`，
不得解析正文猜测规则。

### 5.3 怪物分类与动作

怪物只使用稳定大类：

```yaml
classification:
  creatureType: undead
  subtypes: [spellcaster, swarm]
  tags: [亡灵法师]
```

“亡灵法师”“亡灵集群”不得成为资料库顶级类别。

动作结构分开保存：

```yaml
actions:
  normal: []
  bonus: []
  reactions: []
  legendary: []
  lair: []
```

每个动作包含稳定 ID、名称、说明以及可选的攻击、伤害、豁免和资源字段。怪物模板
创建角色时将描述写入角色描述，将动作投影到正确动作栏；怪物分类、体型、阵营、
挑战等级、感官和语言进入角色卡末尾的“怪物资料”。

角色 Markdown v2 与怪物模板使用同一 `CharacterDocument` 映射，导入后的怪物可以
像普通角色一样打开、编辑、发布和同步。

## 6. 战役权限

### 6.1 成员身份

- 战役创建者原子成为 owner；
- 邀请码加入者由服务端强制成为 player；
- join 请求不得接收客户端 role；
- 客户端 DM/Player 视图模式不影响服务端 membership；
- 只有 owner 或明确的 manager/dm membership 拥有管理能力。

### 6.2 角色发布与绑定

个人角色和战役 Character 是两个事实源，通过发布快照和 backlink 同步：

```text
Local Character
   -> publish
CampaignCharacter
   -> bind
CampaignMember.boundCharacterId
```

玩家只能发布自己的 `player` 角色到自己作为 player 加入的战役，只能绑定自己拥有
的 active player Character。每个战役最多绑定一个角色。

加入后未绑定角色的玩家可以浏览、发送 OOC 和选择角色；角色说话、动作、检定和
角色业务命令保持禁用，并显示单一绑定入口。发布成功后可立即绑定。

DM 无需绑定角色。DM 可用旁白发言，并切换到战役中的常驻 NPC、怪物、同伴或代管
角色。

DM 代掷和快捷操作以 `CampaignCharacter` 为目标，不以用户账号或成员行作为目标。
目标选择器显示角色头像、角色名、拥有者和简要状态；同一玩家拥有多个可管理角色时
必须分别列出。结构化骰点事件保存 `targetCharacterId`。

### 6.3 角色页

Player 模式：

- 只显示当前私人工作区的角色；
- 显示未发布或已发布战役；
- “发布到战役”先选择目标战役；
- 发布后可立即绑定或更换绑定。

DM 模式：

- 按战役折叠分组；
- 每组复用战役中心角色分组组件；
- 分类展示玩家角色、NPC、怪物、同伴和归档角色；
- 未发布的 DM 本地角色单独分组，发布时选择目标战役。

## 7. 战役档案权限与阅读

所有战役成员都可以创建 document、location、clue 等档案。权限：

| 操作 | 创建者 | 其他玩家 | 战役管理者 |
| --- | --- | --- | --- |
| 查看 | 是 | 是 | 是 |
| 创建 | 是 | 是 | 是 |
| 编辑自己的 | 是 | 否 | 是 |
| 编辑他人的 | 否 | 否 | 是 |
| 归档自己的 | 是 | 否 | 是 |
| 归档他人的 | 否 | 否 | 是 |

服务端保存 `createdBy/updatedBy` 并执行策略，客户端只根据能力显示入口。

档案正文使用与资料库相同的 `ContentBlockView` 和浮动阅读器。详情不得使用局促的
临时文本卡片，也不得引入第二套正文渲染。

编辑字段顺序固定为类型、标题、标签、摘要、正文、关联条目。标签紧跟标题；关联
条目通过名称、类型和标签检索，不铺设不可搜索的完整长列表。

## 8. 自动刷新与同步

### 8.1 CampaignRefreshCoordinator

所有战役控制器共享一个轻量协调器，按实体失效：

```text
message
conversation
member
character
archive
content
readCursor
```

流程：

1. REST 写入成功后立即更新或失效对应本地状态；
2. Socket 收到消息或 change 通知；
3. 按 `campaignId + entityType` 在短时间窗口内防抖；
4. 从最后 cursor 拉取缺失数据；
5. 写入本地缓存；
6. Controller 通过同一流通知 UI。

重连、应用恢复前台和账号工作区恢复时补拉 cursor。前台每 45 秒进行一次低频兜底，
后台不轮询。

### 8.2 未读

进入会话时本地乐观更新阅读游标并立即清除红点，然后提交服务端。失败时恢复未读
并显示非阻断错误。其他设备更新阅读游标后通过 change 通知同步。

### 8.3 Vault

Vault 只运行于当前账号工作区。Outbox、revision、device cursor 和冲突均不得跨
工作区。退出或切换账号必须停止旧同步任务。

## 9. 私聊与小群

所有战役成员都可以：

- 与同战役成员发起私聊；
- 选择至少两名其他成员创建小群。

参与者必须属于同一战役，服务端忽略或拒绝非成员 ID。创建者可修改和归档自己创建
的小群，战役管理者可管理全部会话。

私聊展示名称由“对方成员显示名 + 对方绑定角色”投影，不能依赖空 title。会话列表
响应创建、重命名、归档和新消息通知。

## 10. 战役列表信息架构

折叠态：

```text
[战役图标] 战役名称                    [未读]
           主聊天室最近发言             [展开]
```

展开态在同一 Card 内使用无边框列表：

```text
主聊天室
群聊
  小群 A
  小群 B
私聊
  玩家甲
  玩家乙
[发起私聊] [创建小群]
```

去掉成员头像堆。主聊天室固定置顶；群聊和私聊分别分区；空分区不显示多余标题。
卡片内不得嵌套 Card。移动端保持单列，宽屏只扩大文字区域，不增加无意义操作栏。

## 11. Material 3 与共享控件

本轮建立并复用以下产品级组件：

- `CampaignAvatar`：头像、生命环、统一触控区域；
- `EntitySummaryRow`：角色、成员、服务器、会话的统一摘要行；
- `SectionHeader`：页面分区标题与可选命令；
- `AdaptiveDetailSurface`：移动端 BottomSheet、宽屏 Dialog；
- `ContentEntryReader`：资料和档案正文；
- `InlineSearchFilterBar`：搜索框、筛选入口和启用计数；
- `CampaignCharacterGroup`：主页 DM 角色页与战役中心共用；
- `EmptyState` 和 `ErrorState`：统一空态和错误态。

头像工具面板顶部使用一个统一信息面：角色摘要占主体，最右端为切换身份图标；点击
摘要进入角色卡。不得把切换按钮放在信息条外部。

旁白长文本减少两侧横线和空白，使用紧凑宽度和可换行正文。资料正文、字段值和标签
必须允许自然换行；只有明确的列表摘要允许省略。

资料库搜索栏使用一个 Material 3 `SearchBar`。筛选图标和启用数量位于尾部，点击
打开响应式筛选面；不把大量 Chip 永久铺在搜索框下方。

全局中文文案使用“激励”，不再显示“灵感”。

## 12. 冗余清理原则

只删除经过引用审计确认无消费者的代码：

1. 使用 `rg` 和静态分析确认入口；
2. 为保留行为增加回归测试；
3. 删除旧接口、适配器或控件；
4. 运行目标测试；
5. 再删除下一组。

禁止通过一次大规模删除同时改变数据模型、权限和 UI。不得恢复 Rooms、Session 或
独立 CheckRequest 产品路径。

## 13. 实施批次

### 批次一：私人工作区与服务器身份

- 拆分 bootstrap 与 workspace 存储；
- 增加 instanceId、serverName、localAlias；
- 完成旧数据库迁移和账号切换生命周期；
- Vault 限定到当前工作区。

### 批次二：成员权限、发布与绑定

- join 固定 player；
- 完成玩家发布、选择战役、绑定和更换；
- 重构 DM 角色页按战役分组；
- 修复档案创建者和管理者权限。

### 批次三：实时一致性与会话

- 引入失效协调器；
- 修复未读、私聊显示、自动同步和小群创建；
- 重做战役折叠卡片。

### 批次四：阅读 UI 与共享组件

- 修复内容换行、档案阅读和旁白长文本；
- 重做搜索筛选栏；
- 调整头像工具信息条；
- 全局替换“激励”并合并重复控件。

### 批次五：角色与怪物模型

- 固定 CharacterDocument 和 Markdown v2；
- 增加自动 Markdown 镜像及外部变更导入；
- 规范怪物类别、描述和动作；
- 修复怪物模板角色卡投影；
- 更新内容包、GUI 扩展和 Agent 接口规范。

### 批次六：清理与验收

- 按引用审计清理遗留接口；
- 运行全量客户端和服务端测试；
- 运行 analyze、lint、构建和数据库迁移验证；
- 构建包含私人测试资料的本地 Web 测试版；
- 在窄屏和宽屏检查战役列表、聊天、角色页、档案和资料库。

## 14. 验收标准

- 同设备切换账号时不会看到另一账号的角色、资料、收藏、战役缓存或同步队列；
- 断网不会把已登录账号切回 local；
- 服务器迁址后可凭 instanceId 继续识别同一服务器；
- 邀请加入无法获得 DM 权限；
- 玩家可发布并绑定自己的角色，DM 无需绑定；
- 玩家可创建和编辑自己的档案，DM 可编辑全部；
- 战役修改、消息、会话和未读状态无需重新进入页面即可更新；
- 私聊显示对象，小群可以创建；
- 战役卡片符合主聊、群聊、私聊的信息层级且无成员头像堆；
- 资料和旁白长文本正常换行；
- 资料搜索与筛选使用一个紧凑入口；
- 怪物大类稳定，动作投影到正确角色卡区域；
- 每次角色保存或业务命令后生成最新 Markdown；
- Markdown 外部修改必须经过差异确认；
- 触及页面不存在无消费者控件、重复详情流或越权入口。
