# 0.1 战役可展开会话卡片设计

## 目标

主页战役栏中每个战役只出现一次，并可展开查看该战役内用户有权访问的会话。主聊天室固定置顶，同时支持成员私聊和临时小群，为后续战斗频道、DM 密语和场景频道保留统一扩展点。

## 当前边界

当前 `CampaignChatMessage` 只有 `campaignId`，服务端列表、发送接口和 WebSocket 都把整个战役视为唯一聊天室。客户端可以做展开动画，但在没有会话实体和权限隔离前，不能安全实现私聊或小群。

本设计引入“战役包含会话”的一层关系，不恢复已废弃的 Session 作为聊天前置条件。跑团场次仍不是聊天容器。

## 数据模型

### CampaignConversation

- `id`
- `campaignId`
- `kind`: `main | direct | group`
- `title`: 主聊使用战役名；私聊由成员名派生；小群由创建者命名
- `mainKey`: 仅 main 写入固定值 `main`，用于保证每个战役只有一个主聊
- `directKey`: 仅 direct 写入排序成员组合的稳定哈希，用于复用同一私聊
- `createdBy`
- `createdAt`
- `updatedAt`
- `archivedAt`

每个战役必须且只能有一个 `kind=main` 的会话。主会话在创建战役时同事务创建，不可退出、归档或删除。

### CampaignConversationMember

- `conversationId`
- `userId`
- `lastReadAt`
- `joinedAt`

主会话不复制全部成员记录，访问权直接来自 CampaignMember；direct/group 使用成员表限定访问。direct 必须恰好包含两名不同的活动战役成员，并对相同成员组合复用已有未归档会话。

### CampaignChatMessage

新增非空 `conversationId`，同时保留 `campaignId` 便于策略校验和索引。现有消息迁移到所属战役的 main conversation。

## 权限

- 主聊：所有活动 CampaignMember 可读写。
- 私聊：仅两名会话成员可读写。
- 小群：仅会话成员可读写；创建者可改名和管理成员。
- Campaign owner 可归档小群和处理滥用，但不会因 owner 身份自动读取未加入的私聊内容。
- 所有会话成员必须同时是活动 CampaignMember；退出战役立即失去会话访问。
- 客户端隐藏入口只是体验层，服务端 policy 必须对列表、历史、发送、已读和 Socket join 全部校验。

## API 与实时通信

- `GET /api/campaigns/:campaignId/conversations`：返回当前用户可见的会话摘要。
- `POST /api/campaigns/:campaignId/conversations/direct`：创建或返回现有私聊。
- `POST /api/campaigns/:campaignId/conversations/groups`：创建小群。
- `PATCH /api/campaigns/:campaignId/conversations/:conversationId`：改名或归档，按 policy 限制。
- 历史和发送接口增加 `conversationId` 路径段。
- Socket 在认证后加入 `campaign:{campaignId}:conversation:{conversationId}`，不再向整个 campaign 广播私聊消息。
- 会话摘要包含 `lastMessage`、`unreadCount`、成员预览和 `updatedAt`。

## 客户端列表

折叠状态显示：战役头像、战役名、当前身份、主聊最后消息、主聊未读数和展开按钮。点击卡片主体直接进入主聊天室；点击展开按钮只展开，不触发导航。

展开状态按以下顺序显示：

1. 置顶的“主聊天室”，使用图钉图标。
2. 私聊，按最后活动时间排序。
3. 小群，按最后活动时间排序。
4. “发起私聊”和“创建小群”图标操作。

会话行显示头像/组合头像、名称、最后消息、时间和未读 badge。卡片只允许一个展开层级，不在卡片内再嵌套卡片。展开状态按用户本机保存，但不跨设备同步。

## 聊天页复用

`CampaignChatPage` 增加 `conversation` 参数，顶栏显示会话标题；战役中心仍属于 campaign，不复制到每个会话。角色身份、说/做模式、骰点和角色卡入口继续复用。私聊/小群不改变 Actor 权限，也不允许绕过战役 membership。

系统事件默认只发布到主聊天室。将来需要战斗频道时新增 conversation kind，而不是再造第二套消息系统。

## 非目标

- 不实现跨战役私信、好友系统、语音通话或文件传输协议。
- 不把线索板、地点和战役档案复制成聊天会话。
- 不允许客户端用本地过滤冒充私聊安全。
- 不恢复 SessionGateway 或旧 rooms 原型。

## 验收

1. 每个战役列表项只出现一次，主聊可直接进入，展开后可进入私聊和小群。
2. 旧战役所有历史消息迁移到唯一主会话且数量不变。
3. 无权限用户无法通过 REST 或 Socket 读取/发送其他会话消息。
4. 主聊、私聊和小群分别计算最后消息与未读数。
5. 360、390、600、900、1280px 展开卡片无溢出或嵌套滚动。
