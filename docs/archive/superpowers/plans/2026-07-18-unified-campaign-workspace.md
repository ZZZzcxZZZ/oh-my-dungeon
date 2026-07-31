# 统一战役工作区实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将战役重构为权限真实、角色数据统一、可离线使用资料库且私人测试版可可靠内嵌资料的群聊工作区。

**架构：** 服务端成员角色和能力集继续作为权限权威；客户端以 `CampaignCharacterController` 为完整 Character 唯一状态源，并通过一个工作区刷新协调器让聊天上下文与 Character 缓存同步。战役中心重新分为概览、角色、档案、记录，所有角色入口复用同一完整角色卡。私人资料使用单一 UTF-8 构建入口，在 Flutter 启动门槛中完成内容哈希安装和子职业端到端校验。

**技术栈：** Flutter / Material 3 / Drift / flutter_test，NestJS / Prisma / Jest / Supertest，PowerShell，Docker Compose。

---

## 文件结构

### 客户端战役工作区

- 修改 `apps/client_flutter/lib/src/features/campaigns/domain/campaign.dart`：解析扩展后的服务端能力集。
- 修改 `apps/client_flutter/lib/src/features/campaigns/presentation/campaign_chat_page.dart`：使用统一身份、同步协调器和完整角色卡入口。
- 修改 `apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_identity_sheet.dart`：DM 显示所有可控角色，玩家只显示自己的摘要。
- 修改 `apps/client_flutter/lib/src/features/campaigns/presentation/chat/chat_mode_picker.dart`：说/做只显示图标并保留语义标签。
- 创建 `apps/client_flutter/lib/src/features/campaigns/presentation/campaign_workspace_mutation_coordinator.dart`：统一刷新 Character 缓存和工作区上下文。
- 修改 `apps/client_flutter/lib/src/features/campaigns/presentation/campaign_center_page.dart`：概览、角色、档案、记录四域编排。
- 修改 `apps/client_flutter/lib/src/features/campaigns/presentation/center/campaign_overview_panel.dart`：显示成员、邀请码和概览统计。
- 创建 `apps/client_flutter/lib/src/features/campaigns/presentation/center/campaign_characters_panel.dart`：分类显示和管理全部战役角色。
- 删除 `apps/client_flutter/lib/src/features/campaigns/presentation/center/campaign_team_panel.dart`：完成调用迁移后移除混合职责页面。
- 创建 `apps/client_flutter/lib/src/features/campaigns/presentation/characters/campaign_character_sheet_launcher.dart`：统一角色卡权限计算和页面导航。
- 修改 `apps/client_flutter/lib/src/features/campaigns/presentation/characters/campaign_character_sheet_page.dart`：支持可编辑和只读两种状态。
- 修改 `apps/client_flutter/lib/src/features/campaigns/presentation/center/campaign_archive_panel.dart`：显示结构化兼容错误。

### 服务端战役权限和能力

- 修改 `apps/server_nest/src/modules/campaigns/campaigns.types.ts`：扩展 `CampaignCapabilitiesView`。
- 修改 `apps/server_nest/src/modules/campaigns/policies/campaign.policy.ts`：返回邀请、Character 编辑和档案能力。
- 修改 `apps/server_nest/src/modules/server-info/server-metadata.type.ts`：加入 API 版本和功能标识。
- 修改 `apps/server_nest/src/modules/server-info/server-info.service.ts`：发布稳定能力信息。

### 私人测试资料

- 修改 `apps/client_flutter/lib/src/features/content/data/import/bundled_content_installer.dart`：按内容哈希更新并暴露无效包错误。
- 修改 `apps/client_flutter/lib/src/features/server_home/presentation/main_shell.dart`：等待内置资料初始化后开放应用功能。
- 修改 `scripts/build_private_client.ps1`：成为唯一的私人 Web / APK 构建器。
- 修改 `scripts/preview-client.ps1`：默认构建包含私人资料的本地测试 Web。
- 删除 `scripts/build-private-test-apk.ps1`：消除第二套失效构建入口。
- 修改 `apps/client_flutter/test/tooling/private_content_package_validation_test.dart`：验证所有职业的子职业解析结果。

### 测试

- 修改 `apps/client_flutter/test/campaign_chat_character_test.dart`
- 创建 `apps/client_flutter/test/campaign_workspace_mutation_coordinator_test.dart`
- 修改 `apps/client_flutter/test/campaign_center_page_test.dart`
- 创建 `apps/client_flutter/test/campaign_characters_panel_test.dart`
- 修改 `apps/client_flutter/test/campaign_character_pages_test.dart`
- 修改 `apps/client_flutter/test/campaign_archive_panel_test.dart`
- 修改 `apps/client_flutter/test/bundled_content_installer_test.dart`
- 修改 `apps/server_nest/src/modules/campaigns/policies/campaign.policy.spec.ts`
- 修改 `apps/server_nest/test/campaign-characters.e2e-spec.ts`
- 修改 `apps/server_nest/test/server-info.e2e-spec.ts`

---

### 任务 1：稳定当前聊天室重构基线

**文件：**
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/campaign_chat_page.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/campaign_controller.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/campaigns_tab_page.dart`
- 创建：`apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_archive_create_dialog.dart`
- 创建：`apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_chat_tool_sheet.dart`
- 创建：`apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_composer_identity.dart`
- 创建：`apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_identity_sheet.dart`
- 测试：`apps/client_flutter/test/campaign_chat_character_test.dart`

- [ ] **步骤 1：审查现有未提交差异的职责和遗留入口**

运行：

```powershell
git diff --check
rg -n "showModalBottomSheet|CampaignCharacterQuickSheet|speakerMode|boundCharacter" apps/client_flutter/lib/src/features/campaigns/presentation/campaign_chat_page.dart
```

预期：`git diff --check` 无输出；身份面板、工具面板和创建档案对话框只有一个入口。

- [ ] **步骤 2：运行现有聊天室行为测试**

运行：

```powershell
flutter test test/campaign_chat_character_test.dart
```

预期：全部通过；若失败，只修复本批现有重构引起的回归，不加入后续功能。

- [ ] **步骤 3：运行静态分析**

运行：

```powershell
flutter analyze
```

预期：`No issues found!`

- [ ] **步骤 4：提交基线**

```powershell
git add apps/client_flutter/lib/src/features/campaigns/presentation/campaign_chat_page.dart apps/client_flutter/lib/src/features/campaigns/presentation/campaign_controller.dart apps/client_flutter/lib/src/features/campaigns/presentation/campaigns_tab_page.dart apps/client_flutter/lib/src/features/campaigns/presentation/chat apps/client_flutter/test/campaign_chat_character_test.dart
git commit -m "refactor(v0.1): simplify campaign chat composer"
```

### 任务 2：统一 DM 身份和 Character 同步

**文件：**
- 创建：`apps/client_flutter/lib/src/features/campaigns/presentation/campaign_workspace_mutation_coordinator.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/campaign_chat_page.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_identity_sheet.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/chat/chat_mode_picker.dart`
- 测试：`apps/client_flutter/test/campaign_workspace_mutation_coordinator_test.dart`
- 测试：`apps/client_flutter/test/campaign_chat_character_test.dart`

- [ ] **步骤 1：为统一刷新编写失败测试**

测试应构造记录调用次数的 fake controller，并断言一次工作区变更同时刷新 Character 和 workspace：

```dart
test('refreshAfterCharacterMutation refreshes characters before workspace context', () async {
  final calls = <String>[];
  final coordinator = CampaignWorkspaceMutationCoordinator(
    pullCharacters: () async => calls.add('characters'),
    loadWorkspace: (campaignId) async => calls.add('workspace:$campaignId'),
  );

  await coordinator.refreshAfterCharacterMutation('campaign-1');

  expect(calls, ['characters', 'workspace:campaign-1']);
});
```

运行：

```powershell
flutter test test/campaign_workspace_mutation_coordinator_test.dart
```

预期：FAIL，原因是协调器尚不存在。

- [ ] **步骤 2：实现最小协调器**

```dart
class CampaignWorkspaceMutationCoordinator {
  const CampaignWorkspaceMutationCoordinator({
    required this.pullCharacters,
    required this.loadWorkspace,
  });

  final Future<void> Function() pullCharacters;
  final Future<void> Function(String campaignId) loadWorkspace;

  Future<void> refreshAfterCharacterMutation(String campaignId) async {
    await pullCharacters();
    await loadWorkspace(campaignId);
  }
}
```

- [ ] **步骤 3：为 DM 可控角色和玩家身份限制编写失败 widget 测试**

新增断言：

```dart
expect(find.text('DM 旁白'), findsOneWidget);
expect(find.text('无主临时守卫'), findsOneWidget);
expect(find.byKey(const Key('identity-switch-list')), findsOneWidget);
```

玩家用例断言：

```dart
expect(find.text('DM 旁白'), findsNothing);
expect(find.byKey(const Key('identity-switch-list')), findsNothing);
```

运行 `flutter test test/campaign_chat_character_test.dart`，预期 DM 无主角色断言失败。

- [ ] **步骤 4：实现身份筛选和同步接入**

DM 可控角色条件统一为：

```dart
final controllableCharacters = characters.where((character) {
  if (!canManageCampaign || character.status != 'active') return false;
  return character.characterType != 'player';
}).toList(growable: false);
```

临时角色创建、草稿角色创建、转长期和归档成功后调用：

```dart
await mutationCoordinator.refreshAfterCharacterMutation(campaign.id);
```

- [ ] **步骤 5：为图标化说/做控件编写失败测试并实现**

测试：

```dart
expect(find.text('说'), findsNothing);
expect(find.text('做'), findsNothing);
expect(find.bySemanticsLabel('说'), findsOneWidget);
expect(find.bySemanticsLabel('做'), findsOneWidget);
```

实现使用两个 `IconButton` 或图标分段按钮，分别使用 `Icons.chat_bubble_outline` 和 `Icons.directions_run_outlined`，设置 `tooltip` 和 `semanticLabel`。

- [ ] **步骤 6：验证并提交**

```powershell
flutter test test/campaign_workspace_mutation_coordinator_test.dart test/campaign_chat_character_test.dart
flutter analyze
git add apps/client_flutter/lib/src/features/campaigns/presentation/campaign_workspace_mutation_coordinator.dart apps/client_flutter/lib/src/features/campaigns/presentation/campaign_chat_page.dart apps/client_flutter/lib/src/features/campaigns/presentation/chat/campaign_identity_sheet.dart apps/client_flutter/lib/src/features/campaigns/presentation/chat/chat_mode_picker.dart apps/client_flutter/test/campaign_workspace_mutation_coordinator_test.dart apps/client_flutter/test/campaign_chat_character_test.dart
git commit -m "fix(v0.1): unify campaign speaker and character refresh"
```

### 任务 3：重构战役中心概览与角色目录

**文件：**
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/campaign_center_page.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/center/campaign_overview_panel.dart`
- 创建：`apps/client_flutter/lib/src/features/campaigns/presentation/center/campaign_characters_panel.dart`
- 删除：`apps/client_flutter/lib/src/features/campaigns/presentation/center/campaign_team_panel.dart`
- 测试：`apps/client_flutter/test/campaign_center_page_test.dart`
- 创建：`apps/client_flutter/test/campaign_characters_panel_test.dart`

- [ ] **步骤 1：编写导航和概览失败测试**

```dart
expect(find.text('角色'), findsOneWidget);
expect(find.text('队伍'), findsNothing);
await tester.tap(find.text('概览'));
expect(find.byKey(const Key('campaign-member-list')), findsOneWidget);
expect(find.byKey(const Key('campaign-invite-share')), findsOneWidget);
```

普通玩家用例断言 `campaign-invite-share` 不存在。

运行：

```powershell
flutter test test/campaign_center_page_test.dart
```

预期：FAIL，仍显示“队伍”且成员和邀请码仍在旧面板。

- [ ] **步骤 2：移动成员和邀请到概览**

`CampaignOverviewPanel` 新增参数：

```dart
final List<CampaignMemberPreview> members;
final List<CampaignInvite> invites;
final Future<void> Function()? onCreateInvite;
final String campaignName;
final String serverUrl;
```

使用普通 `ListTile` 显示成员，管理者仅显示一个当前邀请码及复制/系统分享操作。

- [ ] **步骤 3：为角色分类编写失败测试**

```dart
expect(find.text('玩家角色'), findsOneWidget);
expect(find.text('NPC'), findsOneWidget);
expect(find.text('临时角色'), findsOneWidget);
expect(find.byKey(const Key('character-row-player-1')), findsOneWidget);
expect(find.byKey(const Key('character-row-temp-1')), findsOneWidget);
```

运行 `flutter test test/campaign_characters_panel_test.dart`，预期 FAIL，页面尚不存在。

- [ ] **步骤 4：实现角色目录**

分类函数保持纯函数以便测试：

```dart
String campaignCharacterSection(CampaignCharacter character) {
  if (character.status == 'archived') return 'archived';
  if (character.lifecycle == 'temporary') return 'temporary';
  if (character.characterType == 'player') return 'player';
  if (character.characterType == 'npc') return 'npc';
  return 'other';
}
```

空分类不渲染。DM 显示创建、转长期、归档和批量归档；玩家不构建这些控件。

- [ ] **步骤 5：迁移中心页面并删除旧队伍面板**

将手机 `NavigationDestination` 和桌面 `NavigationRailDestination` 的第二项改为角色，并让第二页构建 `CampaignCharactersPanel`。确认无引用后删除 `campaign_team_panel.dart` 及被替代测试。

- [ ] **步骤 6：验证并提交**

```powershell
flutter test test/campaign_center_page_test.dart test/campaign_characters_panel_test.dart
flutter analyze
git add apps/client_flutter/lib/src/features/campaigns/presentation/campaign_center_page.dart apps/client_flutter/lib/src/features/campaigns/presentation/center apps/client_flutter/test/campaign_center_page_test.dart apps/client_flutter/test/campaign_characters_panel_test.dart apps/client_flutter/test/campaign_team_panel_test.dart
git commit -m "refactor(v0.1): organize campaign overview and characters"
```

### 任务 4：统一完整角色卡和编辑权限

**文件：**
- 创建：`apps/client_flutter/lib/src/features/campaigns/presentation/characters/campaign_character_sheet_launcher.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/characters/campaign_character_sheet_page.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/campaign_chat_page.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/center/campaign_characters_panel.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/center/campaign_overview_panel.dart`
- 测试：`apps/client_flutter/test/campaign_character_pages_test.dart`
- 测试：`apps/client_flutter/test/campaign_chat_character_test.dart`

- [ ] **步骤 1：为权限函数编写失败测试**

```dart
expect(canEditCampaignCharacter(character: ownCharacter, currentUserId: 'u1', canEditAnyCharacter: false), isTrue);
expect(canEditCampaignCharacter(character: otherCharacter, currentUserId: 'u1', canEditAnyCharacter: false), isFalse);
expect(canEditCampaignCharacter(character: otherCharacter, currentUserId: 'u1', canEditAnyCharacter: true), isTrue);
```

运行 `flutter test test/campaign_character_pages_test.dart`，预期 FAIL，权限函数尚不存在。

- [ ] **步骤 2：实现权限函数和统一 launcher**

```dart
bool canEditCampaignCharacter({
  required CampaignCharacter character,
  required String currentUserId,
  required bool canEditAnyCharacter,
}) => canEditAnyCharacter || character.ownerUserId == currentUserId;
```

`openCampaignCharacterSheet` 根据该结果构建 `CampaignCharacterSheetPage(canEdit: canEdit)`。

- [ ] **步骤 3：为角色卡只读状态编写失败测试**

只读用例断言归档、头像编辑、HP 编辑、字段编辑和备注保存按钮不存在；编辑用例断言它们存在。

- [ ] **步骤 4：实现 `canEdit`**

`CampaignCharacterSheetPage` 新增：

```dart
final bool canEdit;
```

所有写操作仅在 `canEdit && character.status != 'archived'` 时构建。只读状态仍显示完整属性、资源、特性、法术、装备和备注内容。

- [ ] **步骤 5：迁移所有入口**

聊天消息头像、输入栏头像、角色目录条目和概览成员绑定角色都调用统一 launcher。移除这些入口对 `CampaignCharacterQuickSheet` 的使用。

- [ ] **步骤 6：验证并提交**

```powershell
flutter test test/campaign_character_pages_test.dart test/campaign_chat_character_test.dart test/campaign_center_page_test.dart
flutter analyze
git add apps/client_flutter/lib/src/features/campaigns/presentation/characters apps/client_flutter/lib/src/features/campaigns/presentation/campaign_chat_page.dart apps/client_flutter/lib/src/features/campaigns/presentation/center apps/client_flutter/test/campaign_character_pages_test.dart apps/client_flutter/test/campaign_chat_character_test.dart apps/client_flutter/test/campaign_center_page_test.dart
git commit -m "feat(v0.1): open full campaign sheets with real permissions"
```

### 任务 5：扩展服务端能力并修复档案兼容提示

**文件：**
- 修改：`apps/server_nest/src/modules/campaigns/campaigns.types.ts`
- 修改：`apps/server_nest/src/modules/campaigns/policies/campaign.policy.ts`
- 修改：`apps/server_nest/src/modules/server-info/server-metadata.type.ts`
- 修改：`apps/server_nest/src/modules/server-info/server-info.service.ts`
- 修改：`apps/client_flutter/lib/src/features/campaigns/domain/campaign.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/center/campaign_archive_panel.dart`
- 修改：`apps/client_flutter/lib/src/features/campaigns/presentation/campaign_controller.dart`
- 测试：`apps/server_nest/src/modules/campaigns/policies/campaign.policy.spec.ts`
- 测试：`apps/server_nest/test/server-info.e2e-spec.ts`
- 测试：`apps/server_nest/test/campaign-characters.e2e-spec.ts`
- 测试：`apps/client_flutter/test/campaign_archive_panel_test.dart`

- [ ] **步骤 1：编写服务端能力失败测试**

owner / dm 断言：

```typescript
expect(capabilities).toMatchObject({
  canInviteMembers: true,
  canManageCharacters: true,
  canEditAnyCharacter: true,
  canCreateArchive: true,
  canManageArchive: true,
});
```

player 对应字段均为 false。运行：

```powershell
npm run test:server -- --runInBand src/modules/campaigns/policies/campaign.policy.spec.ts
```

预期：FAIL，字段尚不存在。

- [ ] **步骤 2：扩展能力类型和 policy**

`CampaignCapabilitiesView` 与 policy 返回对象加入五个布尔字段，值全部由 `isManager` 派生，不引入新的角色体系。

- [ ] **步骤 3：编写 server-info 功能标识失败测试并实现**

测试断言：

```typescript
expect(body.apiVersion).toBe('1');
expect(body.features).toContain('campaignArchives');
```

`ServerMetadata` 加入：

```typescript
apiVersion: string;
features: string[];
```

服务返回 `apiVersion: '1'` 和 `features: ['campaignArchives', 'campaignCharacters', 'campaignChat']`。

- [ ] **步骤 4：为客户端档案错误映射编写失败测试**

构造 404 且正文包含 `Cannot GET`，断言页面显示“服务端版本过旧，请升级后使用战役档案”和重试/返回操作，不显示原始文本。

- [ ] **步骤 5：实现结构化错误分类**

在控制器中将档案 404 映射为 `serverOutdated`，403 映射为 `permissionDenied`，网络异常映射为 `networkUnavailable`。Panel 根据枚举渲染文案和动作。

- [ ] **步骤 6：验证服务端和客户端并提交**

```powershell
npm run test:server -- --runInBand src/modules/campaigns/policies/campaign.policy.spec.ts test/server-info.e2e-spec.ts test/campaign-characters.e2e-spec.ts
npm run lint:server
flutter test test/campaign_archive_panel_test.dart test/campaign_center_page_test.dart
flutter analyze
git add apps/server_nest/src/modules/campaigns apps/server_nest/src/modules/server-info apps/server_nest/test apps/client_flutter/lib/src/features/campaigns apps/client_flutter/test/campaign_archive_panel_test.dart apps/client_flutter/test/campaign_center_page_test.dart
git commit -m "fix(v0.1): publish campaign capabilities and archive compatibility"
```

### 任务 6：统一私人资料构建并修复子职业链路

**文件：**
- 修改：`apps/client_flutter/lib/src/features/content/data/import/bundled_content_installer.dart`
- 修改：`apps/client_flutter/lib/src/features/server_home/presentation/main_shell.dart`
- 修改：`scripts/build_private_client.ps1`
- 修改：`scripts/preview-client.ps1`
- 删除：`scripts/build-private-test-apk.ps1`
- 修改：`apps/client_flutter/test/bundled_content_installer_test.dart`
- 修改：`apps/client_flutter/test/tooling/private_content_package_validation_test.dart`

- [ ] **步骤 1：为内容哈希更新编写失败测试**

```dart
test('reinstalls same version and count when bundled hash changes', () async {
  repository.seedPackage(version: '2024.1.1', entryCount: 1106, contentHash: 'old');
  final installed = await installer.installIfAvailable();
  expect(installed, isTrue);
  expect(repository.lastContentHash, isNot('old'));
});
```

运行 `flutter test test/bundled_content_installer_test.dart`，预期 FAIL，当前安装器会跳过。

- [ ] **步骤 2：使用内容哈希并显式报告无效内置包**

安装跳过条件改为：

```dart
if (current.isNotEmpty && current.first.contentHash == report.contentHash) {
  return false;
}
```

内置 bundle 非空但 `report.valid == false` 时抛出 `BundledContentInstallException`，不再静默返回 false。

- [ ] **步骤 3：为启动门槛编写失败 widget 测试并实现**

`MainShell` 保存 `_bundledContentReady` 和 `_bundledContentError`。安装完成前显示 `CircularProgressIndicator`；失败显示包含“内置资料初始化失败”的阻断页；完成后再构建主导航。

- [ ] **步骤 4：扩展私人包真实验证测试**

验证测试从环境变量 `PRIVATE_CONTENT_DIR` 读取被忽略目录，解析所有条目后执行：

```dart
for (final classEntry in classes) {
  final subclassChoices = classEntry.rules!.progression
      .expand((level) => level.choices)
      .where((choice) => choice.optionType == 'subclass');
  for (final choice in subclassChoices) {
    expect(
      resolver.optionsFor(choice, sourceEntryId: classEntry.id),
      isNotEmpty,
      reason: '${classEntry.id} has no subclass options',
    );
  }
}
```

运行时显式设置路径，预期先暴露构建/聚合编码问题：

```powershell
$env:PRIVATE_CONTENT_DIR="$PWD\..\..\private-imports\phb-2024-v2"
flutter test test/tooling/private_content_package_validation_test.dart
```

- [ ] **步骤 5：重写唯一私人构建脚本**

所有文本读取改为：

```powershell
Get-Content -LiteralPath $path -Raw -Encoding UTF8
```

脚本在构建前运行私人包验证；任何 manifest 数量不一致或测试失败都 `throw`。脚本自身聚合目录，不依赖预先存在的 bundle 文件，并在 `finally` 恢复空资产。

- [ ] **步骤 6：让预览和 APK 使用同一入口**

`preview-client.ps1` 调用：

```powershell
& (Join-Path $PSScriptRoot 'build_private_client.ps1') -Target web -BuildArgs @('--release','--pwa-strategy=none')
```

APK 使用同一脚本的 `-Target apk`。删除 `build-private-test-apk.ps1` 并更新 README 中的命令引用。

- [ ] **步骤 7：验证并提交**

```powershell
flutter test test/bundled_content_installer_test.dart test/tooling/private_content_package_validation_test.dart
flutter analyze
powershell -ExecutionPolicy Bypass -File scripts/build_private_client.ps1 -Target web -BuildArgs --release,--pwa-strategy=none
git diff --exit-code -- apps/client_flutter/assets/bundled_content.json
git add apps/client_flutter/lib/src/features/content/data/import/bundled_content_installer.dart apps/client_flutter/lib/src/features/server_home/presentation/main_shell.dart apps/client_flutter/test/bundled_content_installer_test.dart apps/client_flutter/test/tooling/private_content_package_validation_test.dart scripts/build_private_client.ps1 scripts/preview-client.ps1 scripts/build-private-test-apk.ps1 README.md
git commit -m "fix(v0.1): validate private content test builds"
```

### 任务 7：跨端验收、服务端重建和测试产物

**文件：**
- 修改：`docs/roadmap/current-execution-status.md`
- 修改：`README.md`

- [ ] **步骤 1：运行客户端目标测试**

```powershell
flutter test test/campaign_workspace_mutation_coordinator_test.dart test/campaign_chat_character_test.dart test/campaign_center_page_test.dart test/campaign_characters_panel_test.dart test/campaign_character_pages_test.dart test/campaign_archive_panel_test.dart test/bundled_content_installer_test.dart test/tooling/private_content_package_validation_test.dart
flutter analyze
```

预期：全部通过，分析无问题。

- [ ] **步骤 2：运行服务端目标测试**

```powershell
npm run test:server -- --runInBand src/modules/campaigns/policies/campaign.policy.spec.ts test/campaigns.e2e-spec.ts test/campaign-characters.e2e-spec.ts test/server-info.e2e-spec.ts
npm run lint:server
```

预期：全部通过，lint 无错误。

- [ ] **步骤 3：重建服务端并执行冒烟测试**

```powershell
docker compose up -d --build server
Invoke-RestMethod http://127.0.0.1:3000/api/server-info
docker compose logs --tail 100 server
```

预期：server-info 包含 `campaignArchives`，日志中无启动错误。使用测试账号创建战役后的档案 e2e 已覆盖真实路由。

- [ ] **步骤 4：构建并启动私人 Web 预览**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/preview-client.ps1 -Port 5174 -ReplaceExisting
```

预期：`http://127.0.0.1:5174/` 可登录，资料库非空，战士 3 级可选择子职业。

- [ ] **步骤 5：构建私人测试 APK**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_private_client.ps1 -Target apk -BuildArgs --release
```

预期：输出 APK 路径、SHA-256 和资料内容哈希。

- [ ] **步骤 6：运行版本门禁**

```powershell
npm run doctor
```

预期：服务端 lint、Flutter analyze、服务端测试、Flutter 测试和 Compose 配置全部通过。若历史无关测试失败，逐项记录并修复，不以本计划目标测试替代版本门禁。

- [ ] **步骤 7：更新状态并提交**

```powershell
git add README.md docs/roadmap/current-execution-status.md
git commit -m "docs(v0.1): record unified campaign workspace verification"
```

---

## 计划自检

- 规格覆盖：DM 无绑定、玩家单角色、身份切换、临时角色管理、邀请码、成员概览、角色分类、完整角色卡、权限矩阵、档案兼容、说/做图标、私人构建、内容哈希和子职业均有对应任务。
- 依赖顺序：先稳定现有聊天室差异，再建立同步；角色目录先于统一角色卡入口；服务端能力先于最终兼容验收；私人资料修复先于 Web/APK 构建。
- 类型一致：统一使用 `canEditAnyCharacter`、`CampaignWorkspaceMutationCoordinator.refreshAfterCharacterMutation` 和 `openCampaignCharacterSheet`。
- 非目标约束：未加入战斗引擎、地图、多频道、公开资料市场或独立 DM 后台。
- 构建边界：私人正文继续只存在于被忽略目录和本地测试产物，公开资产始终恢复为 `{}`。
