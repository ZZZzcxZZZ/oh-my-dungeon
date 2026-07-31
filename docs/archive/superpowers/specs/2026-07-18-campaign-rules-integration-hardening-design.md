# 战役与规则联动加固设计

## 目标

本轮不新增独立子系统，而是收敛已经存在的战役、角色和资料库能力：

- 服务端保存的发言身份是聊天消息身份的唯一权威来源。
- `CampaignCharacter.sheet` 是战役内头像、生命值和完整角色卡的唯一状态源。
- 本地资料库必须无损保存 `ContentEntry` 的 `rules`、`relations` 和 `structured`。
- 角色创建器只消费资料规则，不按职业显示名硬编码规则。
- 所有资料详情使用同一个浮动 Wiki 阅读器。

## P0：正确性

### 旁白

DM 选择旁白后，服务端按 membership 的 `speakerMode=narrator` 创建消息，忽略客户端用户名作为显示身份。消息快照保存 `displayName=旁白 / DM`、`speakerMode=narrator`、空 Character ID。客户端用独立的居中旁白样式渲染，不伪装成普通角色气泡。

### 生命值

精确生命值优先从最新 `CampaignCharacter.sheet.currentHp/maxHp` 计算；只有拿不到 sheet 时才回退到服务端公开分级。Character 更新成功写入本地缓存后，输入栏、身份面板、战役中心和完整角色卡通过同一个 controller 通知刷新。

头像生命环占用外层空间，头像内容向内缩进，二者不重叠。未知 HP 显示中性色完整环，不显示虚假数值。

### 资料关系

Drift 的 `local_content_entries` 增加 `relations_json`，数据库版本升至 7。安装、读取、备份和迁移必须保留关系。真实验收路径为：资料包导入 -> Drift 写入 -> Repository 读出 -> `RuleChoiceResolver` 解析，而不是只测试导入前对象。

## P0：统一入口

`openCampaignCharacterSheet` 负责把任意 Character sheet 投影为 `CharacterSheet`，打开主页同款 `CharacterDetailPage`，并按 viewer capability 注入保存回调。最小 NPC 通过默认值补齐模型，仍使用同一页面。聊天消息头像、输入栏头像、身份列表、成员列表和角色目录全部调用该入口。

DM 的检定工具直接读取目标 Character 的能力与熟练快照，完成 d20 掷骰并发送 roll 系统消息；不再先创建需要玩家响应的请求。资料入口使用可搜索底部面板，详情和内部链接都在同一浮动阅读器内切换。

## P1：战役中心

概览按以下层级排列：

1. 紧凑战役标题、简介、规则系统与当前身份。
2. 成员、角色和最近活动三项统计。
3. 邀请码主操作，DM 可创建、复制和分享。
4. 成员及绑定角色列表。
5. DM 快捷工具。
6. 低频设置与危险操作。

使用 Material 3 的 surface、ListTile、FilledButton、Chip 和响应式 Wrap，不嵌套卡片，不堆叠重复分割线。

## P1：角色创建

属性步骤支持标准数组、27 点购点和 4d6 去最低值。购点规则为 8-15，花费 0/1/2/3/4/5/7/9；界面实时显示剩余点数并阻止负预算。随机生成保存六个结果，玩家仍可重新分配。

职业、背景、物种变化后重新计算 active choices 和 grants。每一步显示：自动获得、必须选择、尚缺资料。熟练、装备、法术和子职业都使用 `RuleChoiceDefinition.builderStep` 分流。没有可选项时显示诊断原因，而不是统一显示“资料库中缺少”。

## P1：资料筛选

`ContentQuery` 增加通用 facets。第一批 UI：

- 法术环位：0-9。
- 法术学派。
- 可用职业。

筛选读取 `structured.level/school/classes`，不解析正文。数据量在本地资料包规模内时允许仓储层先取候选集再执行纯 Dart facet 过滤；接口保持可替换，以便后续增加索引表。

## 验收

- 12 个职业经真实 Drift 安装后均能解析全部相关子职业；魔契师 20 级不再报空选项。
- 旁白消息不显示用户身份，且样式与说/做/OOC 不同。
- 编辑 Character HP 后，输入栏和战役中心生命环立即变化。
- 所有 Character 入口打开同一完整角色卡；玩家只编辑自己，DM 可编辑全部。
- DM 检定一步完成并写入 roll 消息。
- 角色创建的三种属性方式均有单元/Widget 测试。
- 法术可按环位、学派和职业组合筛选。

