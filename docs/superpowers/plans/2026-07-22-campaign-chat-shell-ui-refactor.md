# 战役聊天壳层 UI 重构实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在不修改服务端协议的前提下，修复战役聊天输入栏和窄屏布局，建立清晰的群聊消息时间线，并收敛聊天相关冗余组件。

**架构：** `CampaignChatPage` 保留生命周期、控制器协调和动作路由；头像、消息分组、时间线、Composer 和工具面板拆成专注组件。当前用户判断与 capability 由页面注入，展示组件不读取全局 DM/Player 偏好。

**技术栈：** Flutter、Material 3、ChangeNotifier、flutter_test、现有 CampaignController/CampaignActorController。

---

## 文件结构

**创建：**

- `apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_chat_composer.dart`：单行输入区、身份入口、说/做模式和发送按钮。
- `apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_chat_timeline.dart`：消息滚动、分组、时间分隔和左右对齐。
- `apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_message_grouping.dart`：无 UI 的消息连续性与时间分隔规则。
- `apps/client_flutter/test/campaign_chat_composer_test.dart`：Composer 响应式、语义和草稿行为。
- `apps/client_flutter/test/campaign_chat_timeline_test.dart`：消息分组、方向和目标尺寸测试。

**修改：**

- `apps/client_flutter/lib/src/features/campaigns/presentation/widgets/campaign_avatar.dart`：唯一头像与生命环实现。
- `apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_chat_bubble.dart`：接收方向与身份显示参数，渲染紧凑事件卡。
- `apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_chat_tool_sheet.dart`：保留现有宫格，调整标题、分组和身份摘要。
- `apps/client_flutter/lib/src/features/campaigns/presentation/campaign_chat_page.dart`：组装新组件，精简顶栏，删除内联搜索和输入 UI。
- `apps/client_flutter/test/campaign_chat_actor_test.dart`：页面级权限、导航、角色卡和发送回归。
- `apps/client_flutter/test/campaign_avatar_test.dart`：统一头像的生命状态和无障碍测试。
- `docs/roadmap/current-execution-status.md`：记录本轮完成范围与验证结果。

**删除：**

- `apps/client_flutter/lib/src/features/campaigns/presentation/chat/chat_avatar.dart`：由统一 `CampaignAvatar` 取代。

## 任务 1：统一头像与生命环

**文件：**

- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/widgets/campaign_avatar.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/campaign_chat_page.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_chat_bubble.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_chat_tool_sheet.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_identity_sheet.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_member_tile.dart`
- 修改：`apps/client_flutter/test/campaign_chat_actor_test.dart`
- 测试：`apps/client_flutter/test/campaign_avatar_test.dart`
- 删除：`apps/client_flutter/lib/src/features/campaigns/presentation/chat/chat_avatar.dart`

- [x] **步骤 1：编写失败的统一头像测试**

测试覆盖字符串状态映射、32px 视觉尺寸、48px 外层点击区域、未知 HP 灰色语义、倒地标记和 Semantics：

```dart
testWidgets('campaign avatar exposes health semantics inside a 48px target', (
  tester,
) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Center(
        child: CampaignAvatar(
          initials: 'A',
          size: 32,
          tapTargetSize: 48,
          health: CampaignAvatarHealth.injured,
        ),
      ),
    ),
  );

  expect(find.bySemanticsLabel('A，受伤'), findsOneWidget);
  expect(tester.getSize(find.byKey(const Key('campaign-avatar-target'))),
      const Size.square(48));
});
```

- [x] **步骤 2：运行测试并确认失败**

运行：

```powershell
cd apps/client_flutter
flutter test test/campaign_avatar_test.dart
```

预期：FAIL，`tapTargetSize` 和健康 Semantics 尚不存在。

- [x] **步骤 3：实现统一头像 API**

为 `CampaignAvatar` 增加 `tapTargetSize`、健康语义和服务端字符串适配：

```dart
static CampaignAvatarHealth healthFromState(String? state) => switch (state) {
  'healthy' => CampaignAvatarHealth.healthy,
  'injured' => CampaignAvatarHealth.injured,
  'critical' => CampaignAvatarHealth.critical,
  'down' => CampaignAvatarHealth.down,
  _ => CampaignAvatarHealth.unknown,
};

String get healthLabel => switch (health) {
  CampaignAvatarHealth.healthy => '健康',
  CampaignAvatarHealth.injured => '受伤',
  CampaignAvatarHealth.critical => '濒危',
  CampaignAvatarHealth.down => '倒地',
  CampaignAvatarHealth.unknown => '生命值未知',
};
```

外层 `SizedBox.square(tapTargetSize)` 居中承载 `SizedBox.square(size)`；生命环颜色使用 `ColorScheme.primary/tertiary/error/outline`。

- [x] **步骤 4：替换聊天气泡和工具面板引用**

将 `CampaignChatPage`、`CampaignChatBubble` 和工具面板中的 `ChatAvatar` 替换为：

```dart
CampaignAvatar(
  initials: displayName,
  imageUrl: message.avatarUrl,
  health: CampaignAvatar.healthFromState(message.publicHealthState),
  onTap: onAvatarTap,
)
```

删除 `chat_avatar.dart` 及测试中的旧 import。

- [x] **步骤 5：运行头像和聊天定向测试**

运行：

```powershell
flutter test test/campaign_avatar_test.dart test/campaign_chat_actor_test.dart
```

预期：全部 PASS。

- [x] **步骤 6：提交**

```powershell
git add apps/client_flutter/lib/src/features/campaigns/presentation/widgets/campaign_avatar.dart apps/client_flutter/lib/src/features/campaigns/presentation/campaign_chat_page.dart apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_chat_bubble.dart apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_chat_tool_sheet.dart apps/client_flutter/lib/src/features/campaigns/presentation/chat/chat_avatar.dart apps/client_flutter/test/campaign_avatar_test.dart apps/client_flutter/test/campaign_chat_actor_test.dart
git commit -m "refactor(v0.1): unify campaign health avatars"
```

## 任务 2：建立消息分组规则

**文件：**

- 创建：`apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_message_grouping.dart`
- 测试：`apps/client_flutter/test/campaign_chat_timeline_test.dart`

- [x] **步骤 1：编写失败的纯规则测试**

```dart
test('groups adjacent ordinary messages from the same speaker', () {
  final first = message(id: '1', actorId: 'actor-1', at: '2026-07-22T10:00:00Z');
  final second = message(id: '2', actorId: 'actor-1', at: '2026-07-22T10:03:00Z');

  final presentation = CampaignMessagePresentation.resolve(
    previous: first,
    current: second,
    currentUserId: 'user-1',
  );

  expect(presentation.showIdentity, isFalse);
  expect(presentation.showTimeDivider, isFalse);
  expect(presentation.isOwn, isTrue);
});

test('does not group events or messages separated by ten minutes', () {
  // checkRequest/system/roll and a >= 10 minute gap always start a new group.
});
```

- [x] **步骤 2：运行测试并确认失败**

运行：

```powershell
flutter test test/campaign_chat_timeline_test.dart
```

预期：FAIL，`CampaignMessagePresentation` 尚不存在。

- [x] **步骤 3：实现不可变展示模型**

```dart
class CampaignMessagePresentation {
  const CampaignMessagePresentation({
    required this.isOwn,
    required this.showIdentity,
    required this.showTimeDivider,
  });

  final bool isOwn;
  final bool showIdentity;
  final bool showTimeDivider;

  static CampaignMessagePresentation resolve({
    CampaignChatMessage? previous,
    required CampaignChatMessage current,
    required String? currentUserId,
  }) {
    final gap = previous == null
        ? null
        : DateTime.parse(current.createdAt)
            .difference(DateTime.parse(previous.createdAt));
    final ordinary = current.kind == 'say' || current.kind == 'action';
    final sameSpeaker = previous != null &&
        previous.senderId == current.senderId &&
        previous.campaignActorId == current.campaignActorId &&
        previous.speakerMode == current.speakerMode;
    final separated = gap == null || gap.inMinutes >= 10 || gap.isNegative;
    return CampaignMessagePresentation(
      isOwn: currentUserId != null && current.senderId == currentUserId,
      showIdentity: !(ordinary && sameSpeaker && !separated),
      showTimeDivider: previous == null || separated,
    );
  }
}
```

- [x] **步骤 4：运行规则测试并确认通过**

运行：`flutter test test/campaign_chat_timeline_test.dart`

预期：PASS。

- [x] **步骤 5：提交**

```powershell
git add apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_message_grouping.dart apps/client_flutter/test/campaign_chat_timeline_test.dart
git commit -m "feat(v0.1): define campaign message grouping rules"
```

## 任务 3：提取响应式消息时间线（已完成）

**文件：**

- 创建：`apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_chat_timeline.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_chat_bubble.dart`
- 修改：`apps/client_flutter/test/campaign_chat_timeline_test.dart`

- [x] **步骤 1：补充失败的 Widget 测试**

覆盖自己的消息靠右、他人靠左、连续消息隐藏重复身份、事件卡限制宽度和三种视口无异常：

```dart
testWidgets('aligns own messages right and keeps event cards compact', (tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(testTimeline(currentUserId: 'user-1'));

  expect(
    tester.widget<Align>(find.byKey(const Key('message-own-1'))).alignment,
    Alignment.centerRight,
  );
  expect(
    tester.getSize(find.byKey(const Key('check-request-message'))).width,
    lessThanOrEqualTo(640),
  );
  expect(tester.takeException(), isNull);
});
```

- [x] **步骤 2：运行测试并确认失败**

运行：`flutter test test/campaign_chat_timeline_test.dart`

预期：FAIL，时间线组件和方向参数尚不存在。

- [x] **步骤 3：实现 `CampaignChatTimeline`**

组件接收：

```dart
const CampaignChatTimeline({
  required this.messages,
  required this.currentUserId,
  required this.scrollController,
  required this.onAvatarTap,
  required this.canRespondToCheck,
  required this.hasRespondedToCheck,
  required this.onRespondToCheck,
  super.key,
});
```

在一次 `ListView.builder` 中调用 `CampaignMessagePresentation.resolve`，为消息设置最大阅读宽度，并将时间分隔、方向和身份可见性传给气泡。

- [x] **步骤 4：调整气泡结构**

`CampaignChatBubble` 新增：

```dart
final bool isOwn;
final bool showIdentity;
```

普通消息使用 `Row(mainAxisAlignment: isOwn ? end : start)`；自己的消息将头像放在右侧。事件卡使用 `ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640))`，旁白和系统事件保持居中。

- [x] **步骤 5：运行时间线测试**

运行：`flutter test test/campaign_chat_timeline_test.dart`

预期：全部 PASS。

- [x] **步骤 6：提交**

```powershell
git add apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_chat_timeline.dart apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_chat_bubble.dart apps/client_flutter/test/campaign_chat_timeline_test.dart
git commit -m "feat(v0.1): add responsive campaign message timeline"
```

## 任务 4：提取并修复 Composer（已完成）

**文件：**

- 创建：`apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_chat_composer.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/chat/chat_mode_picker.dart`
- 测试：`apps/client_flutter/test/campaign_chat_composer_test.dart`

- [x] **步骤 1：编写失败的 Composer 测试**

测试 360x800 和 390x844 下无溢出、头像目标为 48px、说/做有语义、键盘 inset 下仍显示输入框，并验证失败发送不清空控制器：

```dart
testWidgets('keeps the composer usable at 360px with keyboard insets', (
  tester,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 800);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final text = TextEditingController(text: '保留草稿');
  addTearDown(text.dispose);
  await tester.pumpWidget(composerHarness(
    controller: text,
    viewInsets: const EdgeInsets.only(bottom: 300),
    onSend: (_) async => false,
  ));

  await tester.tap(find.byKey(const Key('campaign-chat-send')));
  await tester.pumpAndSettle();
  expect(text.text, '保留草稿');
  expect(tester.takeException(), isNull);
});
```

- [x] **步骤 2：运行测试并确认失败**

运行：`flutter test test/campaign_chat_composer_test.dart`

预期：FAIL，Composer 组件尚不存在。

- [x] **步骤 3：实现单行 Composer**

接口：

```dart
class CampaignChatComposer extends StatelessWidget {
  const CampaignChatComposer({
    required this.identity,
    required this.mode,
    required this.controller,
    required this.sending,
    required this.onIdentityTap,
    required this.onModeChanged,
    required this.onSend,
    this.draftIdentityName,
    super.key,
  });
}
```

使用 `Material(color: colorScheme.surfaceContainer)` 包住一个 `SafeArea(top: false)`。头像外层直接使用统一 `CampaignAvatar(size: 32, tapTargetSize: 48)`，不再嵌套 `IconButton`。模式选择器固定 64px，输入框 `Expanded`，发送目标 48px。

- [x] **步骤 4：实现发送结果与草稿规则**

`onSend` 返回 `Future<bool>`；组件不自行清空文本。页面成功时清空，失败时保留，并由页面显示 SnackBar。临时身份横幅保持在 Composer 上方，但关闭目标为 48px。

- [x] **步骤 5：运行 Composer 测试**

运行：`flutter test test/campaign_chat_composer_test.dart`

预期：全部 PASS。

- [x] **步骤 6：提交**

```powershell
git add apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_chat_composer.dart apps/client_flutter/lib/src/features/campaigns/presentation/chat/chat_mode_picker.dart apps/client_flutter/test/campaign_chat_composer_test.dart
git commit -m "feat(v0.1): rebuild campaign chat composer"
```

## 任务 5：精简顶栏并组装页面（已完成）

**文件：**

- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/campaign_chat_page.dart`
- 修改：`apps/client_flutter/test/campaign_chat_actor_test.dart`

- [x] **步骤 1：编写失败的页面结构测试**

```dart
testWidgets('chat app bar only exposes campaign navigation', (tester) async {
  await pumpChatPage(tester);

  expect(find.byKey(const Key('campaign-open-center')), findsOneWidget);
  expect(find.byKey(const Key('campaign-chat-search')), findsNothing);
  expect(find.byKey(const Key('campaign-chat-subtitle')), findsNothing);
});
```

同时断言页面使用 `CampaignChatTimeline` 和 `CampaignChatComposer`，最后一条消息在 390x844 下不被 Composer 遮挡。

- [x] **步骤 2：运行页面测试并确认失败**

运行：

```powershell
flutter test test/campaign_chat_actor_test.dart --plain-name "chat app bar only exposes campaign navigation"
```

预期：FAIL，旧搜索按钮和副标题仍存在。

- [x] **步骤 3：替换页面内联 UI**

- AppBar 只保留战役名称和 `campaign-open-center`。
- `_buildChat` 改为组装 `CampaignChatTimeline` 与 `CampaignChatComposer`。
- `currentUserId` 从 `campaignController.authController.user?.id` 注入时间线。
- `_send` 改为返回 `Future<bool>`，成功后清空输入并滚动到底部。
- 删除 `_buildInputBar`、`_onlineStatusLine`、`_openSearch` 和 `_CampaignChatSearchSheet`。

- [x] **步骤 4：运行页面级聊天测试**

运行：`flutter test test/campaign_chat_actor_test.dart`

预期：全部 PASS。

- [x] **步骤 5：提交**

```powershell
git add apps/client_flutter/lib/src/features/campaigns/presentation/campaign_chat_page.dart apps/client_flutter/test/campaign_chat_actor_test.dart
git commit -m "refactor(v0.1): assemble campaign chat shell components"
```

## 任务 6：轻量整理身份工具面板（已完成）

**文件：**

- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_chat_tool_sheet.dart`
- 修改：`apps/client_flutter/test/campaign_chat_actor_test.dart`

- [x] **步骤 1：编写失败的面板层级测试**

测试当前身份名称成为标题、高频操作排在战役工具之前、玩家隐藏 DM 工具、不可用角色动作不渲染：

```dart
testWidgets('tool sheet keeps the current UI but groups actions by frequency', (
  tester,
) async {
  await openToolSheet(tester, isDm: true);

  expect(find.text('Arannis'), findsWidgets);
  expect(find.byKey(const Key('tool-primary-actions')), findsOneWidget);
  expect(find.byKey(const Key('tool-campaign-actions')), findsOneWidget);
  expect(
    tester.getTopLeft(find.byKey(const Key('tool-primary-actions'))).dy,
    lessThan(tester.getTopLeft(find.byKey(const Key('tool-campaign-actions'))).dy),
  );
});
```

- [x] **步骤 2：运行测试并确认失败**

运行：`flutter test test/campaign_chat_actor_test.dart --plain-name "tool sheet keeps the current UI but groups actions by frequency"`

预期：FAIL，分组 key 尚不存在。

- [x] **步骤 3：调整面板而不重绘**

- 标题使用 `identity.displayName`。
- 身份摘要保留现有 ListTile 和按钮。
- 使用两个有标题的 Wrap：`tool-primary-actions` 与 `tool-campaign-actions`。
- 保留手机三列、宽屏四列和 76px 工具高度。
- DM 能力只由 `isManager` 控制。

- [x] **步骤 4：运行面板与页面测试**

运行：`flutter test test/campaign_chat_actor_test.dart`

预期：全部 PASS。

- [ ] **步骤 5：提交**

```powershell
git add apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_chat_tool_sheet.dart apps/client_flutter/test/campaign_chat_actor_test.dart
git commit -m "refactor(v0.1): clarify campaign chat tool hierarchy"
```

## 任务 7：响应式验收、清理与文档收口

**文件：**

- 修改：`apps/client_flutter/test/campaign_chat_composer_test.dart`
- 修改：`apps/client_flutter/test/campaign_chat_timeline_test.dart`
- 修改：`apps/client_flutter/test/campaign_chat_actor_test.dart`
- 修改：`docs/roadmap/current-execution-status.md`

- [ ] **步骤 1：补齐目标尺寸和长内容回归测试**

参数化执行 360x800、390x844、1280x720，覆盖长角色名、无空格长文本、五种生命状态、横屏工具面板和最后消息可见性：

```dart
for (final size in const [
  Size(360, 800),
  Size(390, 844),
  Size(1280, 720),
]) {
  testWidgets('chat shell has no overflow at ${size.width}x${size.height}',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(longContentChatHarness());
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('campaign-chat-input')), findsOneWidget);
  });
}
```

- [ ] **步骤 2：运行聊天测试集合**

运行：

```powershell
flutter test test/campaign_avatar_test.dart test/campaign_chat_composer_test.dart test/campaign_chat_timeline_test.dart test/campaign_chat_actor_test.dart
```

预期：全部 PASS。

- [ ] **步骤 3：清理聊天页冗余**

运行引用检查：

```powershell
rg -n "ChatAvatar|_CampaignChatSearchSheet|_buildInputBar|_onlineStatusLine" apps/client_flutter/lib apps/client_flutter/test
```

预期：无结果。删除未使用 import、重复 helper 和失效 key，不重构无关页面。

- [ ] **步骤 4：更新执行状态文档**

在 `docs/roadmap/current-execution-status.md` 增加 2026-07-22 聊天壳层收口条目，记录组件边界、响应式尺寸和实际验证结果。

- [ ] **步骤 5：运行完整客户端门禁**

运行：

```powershell
$env:DART_SUPPRESS_ANALYTICS='true'
$env:FLUTTER_SUPPRESS_ANALYTICS='true'
flutter analyze
flutter test
flutter build web --release
```

预期：analyze 无问题；全部测试通过；生成 `build/web`。

- [ ] **步骤 6：运行仓库门禁**

运行：

```powershell
cd ..\..
npm run doctor
git diff --check
```

预期：服务端、客户端、Docker Compose 配置和 diff 检查全部通过。

- [ ] **步骤 7：提交**

```powershell
git add apps/client_flutter/test/campaign_chat_composer_test.dart apps/client_flutter/test/campaign_chat_timeline_test.dart apps/client_flutter/test/campaign_chat_actor_test.dart docs/roadmap/current-execution-status.md
git commit -m "test(v0.1): close campaign chat shell refactor"
```

## 后续计划边界

聊天壳层完成后，按已确认顺序分别建立新规格与计划：

1. 角色卡与角色创建向导重构。
2. 全局 Material 3 视觉规范统一。

这两个主题不作为本计划的附带改动。
