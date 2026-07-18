import 'dart:async';

import 'package:flutter/material.dart';

import '../../characters/domain/character.dart';
import '../../characters/domain/dnd5e_rules.dart';
import '../../characters/presentation/character_detail_page.dart';
import '../../content/data/local/content_repository.dart';
import '../../content/domain/content_entry.dart';
import '../../content/presentation/content_detail_page.dart';
import '../../content/presentation/content_library_controller.dart';
import '../../../core/dice/dice_roller.dart';
import '../domain/campaign.dart';
import '../domain/campaign_actor.dart';
import 'actors/campaign_actor_controller.dart';
import 'actors/campaign_actor_sheet_launcher.dart';
import 'campaign_controller.dart';
import 'campaign_center_page.dart';
import 'campaign_workspace_mutation_coordinator.dart';
import 'chat/campaign_archive_create_dialog.dart';
import 'chat/campaign_chat_tool_sheet.dart';
import 'chat/campaign_chat_bubble.dart';
import 'chat/campaign_composer_identity.dart';
import 'chat/campaign_identity_sheet.dart';
import 'chat/chat_avatar.dart';
import 'chat/chat_helpers.dart';
import 'chat/chat_mode_picker.dart';
import 'chat/check_request_sheet.dart';
import 'content/campaign_content_controller.dart';

class CampaignChatPage extends StatefulWidget {
  const CampaignChatPage({
    required this.campaign,
    required this.character,
    required this.campaignController,
    required this.contentRepository,
    this.localCharacters = const [],
    this.campaignActorId,
    this.diceRoller,
    this.campaignContentController,
    this.actorController,
    super.key,
  });

  final Campaign campaign;
  final CharacterSheet? character;
  final CampaignController campaignController;
  final ContentRepository contentRepository;
  final List<CharacterSheet> localCharacters;
  final String? campaignActorId;
  final DiceRoller? diceRoller;
  final CampaignContentController? campaignContentController;
  final CampaignActorController? actorController;

  @override
  State<CampaignChatPage> createState() => _CampaignChatPageState();
}

class _CampaignChatPageState extends State<CampaignChatPage> {
  final _controller = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final Map<String, GlobalKey> _messageKeys = {};
  ChatMode _mode = ChatMode.say;
  bool _sending = false;
  _TemporaryIdentityDraft? _draftIdentity;
  // Spec §顶部: 搜索结果跳转后高亮的目标 messageId, 由 AnimatedSwitcher 在
  // 800ms 后清空。
  String? _highlightedMessageId;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.campaignController.loadMessages(widget.campaign.id);
      widget.campaignController.loadWorkspaceContext(widget.campaign.id);
      widget.campaignController.connectCampaignChat(widget.campaign.id);
    });
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _controller.dispose();
    _chatScrollController.dispose();
    widget.campaignController.disconnectCampaignChat();
    super.dispose();
  }

  /// Spec §顶部: 搜索结果跳转。先确保消息加载, 再用 GlobalKey 调
  /// Scrollable.ensureVisible 滚动到目标气泡, 然后高亮 800ms。
  Future<void> _scrollToMessage(String messageId) async {
    final messages = widget.campaignController.messages;
    if (!messages.any((m) => m.id == messageId)) {
      // 消息不在当前时间线 (可能未加载), 简单提示用户。
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该消息不在当前加载范围')));
      return;
    }
    // 等待一帧让气泡 GlobalKey 注册到树中。
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final key = _messageKeys[messageId];
    final ctx = key?.currentContext;
    if (ctx == null) {
      // 气泡可能在屏幕外未构建 (ListView.builder lazy), 暂未实现强制构建,
      // 这里给出提示而非静默失败。
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('消息已找到, 请手动滚动查看')));
      return;
    }
    // ctx 来自 GlobalKey.currentContext, 不是 widget build context。
    // 转为 Object 避免触发 use_build_context_synchronously lint 误报。
    final ctxAsObject = ctx as Object;
    final pending = _ensureVisibleOf(ctxAsObject as BuildContext);
    await pending;
    if (!mounted) return;
    setState(() => _highlightedMessageId = messageId);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        if (_highlightedMessageId == messageId) {
          _highlightedMessageId = null;
        }
      });
    });
  }

  /// 独立 helper: 把 GlobalKey.currentContext 滚动到可视区域。
  /// ctx 不是 widget build context, 用独立函数避免 lint 误报。
  Future<void> _ensureVisibleOf(BuildContext ctx) {
    return Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      alignment: 0.4,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.campaignController,
        if (widget.actorController != null) widget.actorController!,
      ]),
      builder: (context, _) {
        final messages = widget.campaignController.messages;
        final workspace = widget.campaignController.workspaceContext;
        final memberCount =
            workspace?.members.length ?? widget.campaign.memberPreview.length;
        final speakerMode = workspace?.membership.speakerMode;
        final subtitle = _onlineStatusLine(memberCount, speakerMode);
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.campaign.name),
                Text(
                  subtitle,
                  key: const Key('campaign-chat-subtitle'),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            actions: [
              IconButton(
                key: const Key('campaign-chat-search'),
                tooltip: chatText('search'),
                onPressed: _openSearch,
                icon: const Icon(Icons.search),
              ),
              IconButton(
                key: const Key('campaign-open-center'),
                tooltip: '战役中心',
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => CampaignCenterPage(
                      campaign: widget.campaign,
                      controller: widget.campaignController,
                      actorController: widget.actorController,
                      contentRepository: widget.contentRepository,
                    ),
                  ),
                ),
                icon: const Icon(Icons.dashboard_outlined),
              ),
            ],
          ),
          body: _buildChat(messages),
        );
      },
    );
  }

  Widget _buildChat(List<CampaignChatMessage> messages) {
    return Column(
      key: const Key('campaign-chat-page'),
      children: [
        if (widget.campaignController.messagesError != null)
          MaterialBanner(
            content: Text(widget.campaignController.messagesError!),
            actions: [
              TextButton(
                onPressed: () =>
                    widget.campaignController.loadMessages(widget.campaign.id),
                child: Text(chatText('retry')),
              ),
            ],
          ),
        Expanded(
          child: widget.campaignController.isMessagesLoading
              ? const Center(child: CircularProgressIndicator())
              : messages.isEmpty
              ? Center(
                  child: Text(
                    chatText('emptyChat'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final key = _messageKeys.putIfAbsent(
                      message.id,
                      () => GlobalKey(),
                    );
                    final isHighlighted = _highlightedMessageId == message.id;
                    return AnimatedContainer(
                      key: key,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: isHighlighted
                            ? Theme.of(context).colorScheme.primaryContainer
                                  .withValues(alpha: 0.6)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CampaignChatBubble(
                        message: message,
                        onRespondCheckRequest: _canRespondToCheck(message)
                            ? () => _respondToCheckRequest(message)
                            : null,
                        hasResponded: _hasRespondedToCheck(message),
                        onAvatarTap: _resolveAvatarTap(message),
                      ),
                    );
                  },
                ),
        ),
        _buildInputBar(),
      ],
    );
  }

  bool get _canManageCampaign =>
      widget
          .campaignController
          .workspaceContext
          ?.capabilities
          .canManageCampaign ??
      false;

  CampaignComposerIdentity get _composerIdentity {
    final resolved = resolveCampaignComposerIdentity(
      workspace: widget.campaignController.workspaceContext,
      campaignActors: widget.actorController?.actors ?? const [],
      localCharacters: widget.localCharacters,
      fallbackCharacter: widget.character,
      fallbackActorId: widget.campaignActorId,
    );
    final draft = _draftIdentity;
    if (draft == null) return resolved;
    return CampaignComposerIdentity(
      displayName: draft.displayName,
      speakerMode: 'actor',
      actorId: null,
      avatarUrl: null,
      healthState: null,
      localCharacter: null,
      campaignActor: null,
      subtitle: '临时身份草稿',
    );
  }

  /// Spec §顶部: AppBar 副标题显示简要在线状态 — 成员数 + 当前发言身份。
  String _onlineStatusLine(int memberCount, String? speakerMode) {
    final memberPart = '$memberCount 位成员';
    final speakerPart = switch (speakerMode) {
      'narrator' => ' · 旁白',
      'ooc' => ' · 场外',
      'actor' => ' · 角色发言',
      'boundActor' => ' · 绑定角色',
      _ => '',
    };
    return '$memberPart$speakerPart';
  }

  /// 解析消息头像点击：只有能解析到战役 Actor 时才打开统一完整角色卡。
  VoidCallback? _resolveAvatarTap(CampaignChatMessage message) {
    final actorId = message.campaignActorId;
    if (actorId == null || actorId.isEmpty) return null;
    final controller = widget.actorController;
    if (controller == null) return null;
    final actor = controller.actors.cast<CampaignActor?>().firstWhere(
      (a) => a?.id == actorId,
      orElse: () => null,
    );
    if (actor == null) return null;
    return () => _openActorSheet(actor);
  }

  Future<void> _openActorSheet(CampaignActor actor) {
    final controller = widget.actorController;
    if (controller == null) return Future<void>.value();
    return openCampaignActorSheet(
      context: context,
      controller: controller,
      actor: actor,
      canEditAnyActor: _canManageCampaign,
      contentRepository: widget.contentRepository,
    );
  }

  /// Spec §顶部: 聊天顶部搜索入口。打开轻量搜索面板，直接调用
  /// `searchMessages` 检索战役历史消息，不替换实时聊天时间线。
  /// 选中搜索结果后关闭面板并跳转到对应消息气泡。
  Future<void> _openSearch() async {
    final selected = await showModalBottomSheet<CampaignChatMessage>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _CampaignChatSearchSheet(
        campaignId: widget.campaign.id,
        controller: widget.campaignController,
      ),
    );
    if (selected == null || !mounted) return;
    await _scrollToMessage(selected.id);
  }

  Widget _buildInputBar() {
    final draft = _draftIdentity;
    final identity = _composerIdentity;
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (draft != null)
            Container(
              key: const Key('draft-identity-banner'),
              margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_add_alt_1_outlined,
                    size: 18,
                    color: colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '临时身份草稿：${draft.displayName}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '放弃草稿',
                    onPressed: _sending
                        ? null
                        : () => setState(() => _draftIdentity = null),
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) => Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    key: const Key('campaign-chat-identity'),
                    tooltip: '当前身份与跑团工具',
                    onPressed: _showToolPanel,
                    icon: ChatAvatar(
                      name: identity.displayName,
                      avatarUrl: identity.avatarUrl,
                      healthState: identity.healthState,
                      size: 24,
                    ),
                  ),
                  if (!identity.isOoc) ...[
                    const SizedBox(width: 6),
                    SizedBox(
                      width: constraints.maxWidth >= 480 ? 104 : 76,
                      child: ChatModePicker(
                        mode: _mode,
                        enabled: !_sending,
                        onChanged: (mode) => setState(() => _mode = mode),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      key: const Key('campaign-chat-input'),
                      controller: _controller,
                      enabled: !_sending,
                      decoration: InputDecoration(
                        hintText: draft != null
                            ? '以 ${draft.displayName} 发言'
                            : identity.isOoc
                            ? '发送场外消息'
                            : (_mode == ChatMode.say
                                  ? chatText('sayHint')
                                  : chatText('actHint')),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: _sending ? null : (_) => _send(),
                    ),
                  ),
                  IconButton.filled(
                    key: const Key('campaign-chat-send'),
                    tooltip: chatText('send'),
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) return;

    final draft = _draftIdentity;
    final identity = _composerIdentity;
    setState(() => _sending = true);
    final sent = await widget.campaignController.sendMessage(
      campaignId: widget.campaign.id,
      kind: draft == null && identity.isOoc
          ? 'ooc'
          : (_mode == ChatMode.act ? 'action' : 'say'),
      content: content,
      campaignActorId: draft == null ? identity.actorId : null,
      draftActor: draft == null
          ? null
          : <String, Object?>{'displayName': draft.displayName},
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (sent) {
      _controller.clear();
      if (draft != null) {
        _draftIdentity = null;
        final actorController = widget.actorController;
        if (actorController == null) {
          await widget.campaignController.loadWorkspaceContext(
            widget.campaign.id,
          );
        } else {
          await CampaignWorkspaceMutationCoordinator(
            pullActors: actorController.pullUntilCurrent,
            loadWorkspace: widget.campaignController.loadWorkspaceContext,
          ).refreshAfterActorMutation(widget.campaign.id);
        }
      }
    } else if (draft != null) {
      // Spec: failed draft send keeps the draft and shows the spec error.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('临时角色创建失败，消息尚未发送。')));
    }
  }

  /// Spec §输入栏: 当前身份头像取代原有独立 `+` 按钮。点击后打开底部快捷面板，
  /// 包含 11 项工具。工具按成员能力和当前上下文动态出现，界面不显示不可用的
  /// DM 工具。
  Future<void> _showToolPanel() async {
    final action = await showModalBottomSheet<CampaignChatToolAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => CampaignChatToolSheet(
        identity: _composerIdentity,
        isManager: _canManageCampaign,
        hasCharacterActions: _characterActions.isNotEmpty,
        draftIdentityName: _draftIdentity?.displayName,
      ),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case CampaignChatToolAction.openCharacterSheet:
      case CampaignChatToolAction.hpStatus:
        _openCharacterSheet();
        break;
      case CampaignChatToolAction.switchIdentity:
        await _showIdentitySheet();
        break;
      case CampaignChatToolAction.rollDice:
        await _showRollSheet();
        break;
      case CampaignChatToolAction.skillCheck:
        await _showCheckRequestTargetPicker();
        break;
      case CampaignChatToolAction.contentEntries:
        await _showContentLibrary();
        break;
      case CampaignChatToolAction.recordClue:
        await _showArchiveCreationForm(initialKind: 'clue');
        break;
      case CampaignChatToolAction.shareLocation:
        await _showArchiveCreationForm(initialKind: 'location');
        break;
      case CampaignChatToolAction.groupFiles:
        await _showArchiveCreationForm(initialKind: 'file');
        break;
      case CampaignChatToolAction.characterActions:
        await _showCharacterActions();
        break;
      case CampaignChatToolAction.temporaryIdentity:
        await _showDraftIdentityForm();
        break;
    }
  }

  Future<void> _showIdentitySheet() async {
    final workspace = widget.campaignController.workspaceContext;
    final membership = workspace?.membership;
    if (workspace == null || membership == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('正在加载战役身份，请稍后重试')));
      return;
    }

    final activeActors = workspace.actors
        .where((actor) => actor.status == 'active')
        .toList(growable: false);
    final persistentActors = activeActors
        .where(
          (actor) =>
              actor.lifecycle != 'temporary' &&
              (actor.actorType == 'npc' ||
                  actor.actorType == 'monster' ||
                  actor.actorType == 'companion'),
        )
        .toList(growable: false);
    final temporaryActors = activeActors
        .where(
          (actor) =>
              actor.lifecycle == 'temporary' && actor.actorType != 'player',
        )
        .toList(growable: false);
    final proxyActors = activeActors
        .where(
          (actor) =>
              actor.ownerUserId != null &&
              actor.ownerUserId != membership.userId &&
              actor.actorType == 'player',
        )
        .toList(growable: false);

    final choice = await showModalBottomSheet<CampaignSpeakerChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => CampaignIdentitySheet(
        identity: _composerIdentity,
        membership: membership,
        isManager: _canManageCampaign,
        persistentActors: persistentActors,
        temporaryActors: temporaryActors,
        proxyActors: proxyActors,
        hasBoundCharacter:
            membership.boundActorId != null ||
            (widget.campaignActorId != null && widget.character != null),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice.createTemporary) {
      await _showDraftIdentityForm();
      return;
    }

    await _updateCampaignSpeaker(choice.speakerMode!, choice.actorId);
  }

  Future<void> _showDraftIdentityForm() {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _DraftIdentityFormSheet(
        onConfirm: (name) {
          setState(
            () => _draftIdentity = _TemporaryIdentityDraft(displayName: name),
          );
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  String? get _activeSpeakerActorId => _composerIdentity.actorId;

  Future<void> _updateCampaignSpeaker(
    String speakerMode, [
    String? actorId,
  ]) async {
    final updated = await widget.campaignController.updateSpeaker(
      campaignId: widget.campaign.id,
      speakerMode: speakerMode,
      actorId: actorId,
    );
    if (!mounted || updated) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.campaignController.workspaceContextError ?? '切换发言身份失败',
        ),
      ),
    );
  }

  /// Spec §档案: 资料、地点、线索和文件统一属于战役档案。聊天工具栏的
  /// 记录线索/分享地点/群文件 项跳转到档案创建表单, 预填入对应类型。
  Future<void> _showArchiveCreationForm({required String initialKind}) async {
    final draft = await showDialog<CampaignArchiveDraft>(
      context: context,
      builder: (context) =>
          CampaignArchiveCreateDialog(initialKind: initialKind),
    );
    if (draft == null || !mounted) return;

    final entry = await widget.campaignController.createArchiveEntry(
      campaignId: widget.campaign.id,
      kind: draft.kind,
      title: draft.title,
      summary: draft.summary,
    );
    if (!mounted) return;
    if (entry != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已保存到战役档案')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.campaignController.archivesError ?? '创建失败'),
      ),
    );
  }

  Future<void> _showRollSheet() {
    // Spec §输入栏: 关闭工具 sheet 由调用方负责, helper 不应自行 pop。
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chatText('quickRoll'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final notation in quickDice)
                      FilledButton.tonalIcon(
                        onPressed: _sending
                            ? null
                            : () => _sendRollExpression(notation),
                        icon: const Icon(Icons.casino_outlined),
                        label: Text(notation),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Map<String, Object?>> get _characterActions {
    final actions = _composerIdentity.characterData['actions'];
    if (actions is! List) return const [];
    return actions
        .whereType<Map>()
        .map((action) => Map<String, Object?>.from(action))
        .where(
          (action) =>
              action['id'] is String &&
              (action['id'] as String).trim().isNotEmpty &&
              action['name'] is String &&
              (action['name'] as String).trim().isNotEmpty,
        )
        .toList(growable: false);
  }

  Future<void> _showCharacterActions() {
    // Spec §输入栏: 关闭工具 sheet 由调用方负责, helper 不应自行 pop。
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text('角色动作', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final action in _characterActions)
              ListTile(
                key: Key('character-action-${action['id']}'),
                leading: const Icon(Icons.bolt_outlined),
                title: Text(action['name']! as String),
                subtitle: _actionSubtitle(action),
                onTap: _sending ? null : () => _sendCharacterAction(action),
              ),
          ],
        ),
      ),
    );
  }

  Widget? _actionSubtitle(Map<String, Object?> action) {
    final parts = [
      if (action['formula'] case final String formula) formula,
      if (action['entryId'] case final String entryId) '来源 $entryId',
    ];
    return parts.isEmpty ? null : Text(parts.join(' · '));
  }

  Future<void> _sendCharacterAction(Map<String, Object?> action) async {
    Navigator.of(context).pop();
    setState(() => _sending = true);
    final sent = await widget.campaignController.sendMessage(
      campaignId: widget.campaign.id,
      kind: 'action',
      content: action['name']! as String,
      campaignActorId: _activeSpeakerActorId,
      actionId: action['id']! as String,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (!sent) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(chatText('sendFailed'))));
    }
  }

  Future<void> _sendRollExpression(String notation) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final roll = (widget.diceRoller ?? DiceRoller()).rollExpression(notation);
      Navigator.of(context).pop();
      setState(() => _sending = true);
      final sent = await widget.campaignController.sendMessage(
        campaignId: widget.campaign.id,
        kind: 'roll',
        content: roll.label,
        campaignActorId: _activeSpeakerActorId,
      );
      if (!mounted) return;
      setState(() => _sending = false);
      if (!sent) {
        messenger.showSnackBar(SnackBar(content: Text(chatText('sendFailed'))));
      }
    } on DiceRollException catch (error) {
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text('${chatText('invalidDice')}$error')),
      );
    }
  }

  Future<void> _showContentLibrary() async {
    // Spec §输入栏: 关闭工具 sheet 由调用方负责, helper 不应自行 pop。
    final searchController = TextEditingController();
    var selectedType = 'all';
    var items = <ContentEntry>[];
    var loading = false;
    String? error;

    Future<void> loadItems() async {
      final query = searchController.text.trim();
      loading = true;
      error = null;
      try {
        items = await widget.contentRepository.search(
          ContentQuery(
            text: query.isEmpty ? null : query,
            type: selectedType == 'all' ? null : selectedType,
          ),
        );
      } catch (exception) {
        error = '$exception';
      } finally {
        loading = false;
      }
    }

    await loadItems();
    if (!mounted) {
      searchController.dispose();
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> refreshItems() async {
              setSheetState(() {});
              await loadItems();
              if (context.mounted) setSheetState(() {});
            }

            return SafeArea(
              child: FractionallySizedBox(
                heightFactor: 0.78,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chatText('campaignContentLibrary'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).closeButtonTooltip,
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          labelText: chatText('searchContent'),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            tooltip: chatText('search'),
                            onPressed: refreshItems,
                            icon: const Icon(Icons.arrow_forward),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => refreshItems(),
                      ),
                      const SizedBox(height: 12),
                      DropdownMenu<String>(
                        label: Text(chatText('contentType')),
                        initialSelection: selectedType,
                        expandedInsets: EdgeInsets.zero,
                        dropdownMenuEntries: [
                          DropdownMenuEntry(
                            value: 'all',
                            label: chatText('all'),
                          ),
                          for (final type in contentTypeFilters)
                            DropdownMenuEntry(
                              value: type,
                              label: contentTypeLabel(type),
                            ),
                        ],
                        onSelected: (value) async {
                          if (value == null) return;
                          selectedType = value;
                          await refreshItems();
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: loading
                            ? const Center(child: CircularProgressIndicator())
                            : error != null
                            ? Center(child: Text(error!))
                            : items.isEmpty
                            ? Center(child: Text(chatText('emptyContent')))
                            : ListView.separated(
                                itemCount: items.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  final source = item.source.label;
                                  return ListTile(
                                    leading: const Icon(
                                      Icons.menu_book_outlined,
                                    ),
                                    title: Text(item.name),
                                    subtitle: Text(
                                      source.isEmpty
                                          ? contentTypeLabel(item.type)
                                          : '${contentTypeLabel(item.type)} · $source',
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => _openContentEntry(item.id),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    searchController.dispose();
  }

  Future<void> _openContentEntry(
    String entryKey, {
    bool closeLibrary = true,
  }) async {
    if (closeLibrary) Navigator.of(context).pop();
    if (!mounted) return;
    final controller = ContentLibraryController(
      repository: widget.contentRepository,
    );
    String? nextEntryKey;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 960,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.9,
          ),
          child: ContentDetailPage(
            entryKey: entryKey,
            controller: controller,
            onOpenEntry: (next) {
              nextEntryKey = next;
              Navigator.of(dialogContext).pop();
            },
            onImportRequested: () {},
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      ),
    );
    controller.dispose();
    if (nextEntryKey != null && mounted) {
      await _openContentEntry(nextEntryKey!, closeLibrary: false);
    }
  }

  void _openCharacterSheet() {
    final identity = _composerIdentity;
    final character = identity.localCharacter;
    if (character != null) {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) => CharacterDetailPage(character: character),
        ),
      );
      return;
    }

    final actorId = identity.actorId;
    final actorController = widget.actorController;
    if (actorId != null && actorController != null) {
      final actor = actorController.actors
          .where((candidate) => candidate.id == actorId)
          .firstOrNull;
      if (actor != null) {
        openCampaignActorSheet(
          context: context,
          controller: actorController,
          actor: actor,
          canEditAnyActor: _canManageCampaign,
          contentRepository: widget.contentRepository,
        );
        return;
      }
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(chatText('noBoundCharacter'))));
  }

  Future<void> _showCheckRequestTargetPicker() async {
    final actors = (widget.actorController?.actors ?? const <CampaignActor>[])
        .where(
          (actor) => actor.status == 'active' && actor.actorType == 'player',
        )
        .toList(growable: false);
    if (actors.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前没有可代掷检定的玩家角色')));
      return;
    }
    final selected = await showModalBottomSheet<CampaignActor>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              leading: Icon(Icons.fact_check_outlined),
              title: Text('选择代掷目标'),
            ),
            for (final actor in actors)
              ListTile(
                key: Key('campaign-actor-${actor.id}'),
                leading: ChatAvatar(
                  name: actor.sheet['name']?.toString() ?? '?',
                  avatarUrl: actor.sheet['avatarUrl'] as String?,
                ),
                title: Text(actor.sheet['name']?.toString() ?? '未命名角色'),
                onTap: () => Navigator.of(context).pop(actor),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) await _showCheckRequestSheet(selected);
  }

  Future<void> _showCheckRequestSheet(CampaignActor actor) async {
    final draft = await showModalBottomSheet<CheckRequestDraft>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => CheckRequestSheet(actor: actor),
    );
    if (draft == null || !mounted || _sending) return;

    final character = campaignActorToCharacterSheet(actor);
    final modifier = switch (draft.type) {
      'skill' => Dnd5eRules.skillBonus(
        skillName: draft.key,
        abilities: character.abilityMap,
        level: character.level,
        proficient: character.skillMap[draft.key] == true,
      ),
      'save' => Dnd5eRules.saveBonus(
        ability: draft.key,
        abilities: character.abilityMap,
        level: character.level,
        proficient: character.saveMap[draft.key] == true,
      ),
      _ => Dnd5eRules.abilityBonus(character.abilityMap, draft.key),
    };
    final roller = widget.diceRoller ?? DiceRoller();
    final first = roller.rollD20().total;
    final second = draft.rollMode == 'normal' ? first : roller.rollD20().total;
    final die = switch (draft.rollMode) {
      'advantage' => first > second ? first : second,
      'disadvantage' => first < second ? first : second,
      _ => first,
    };
    final total = die + modifier;
    final actorName = character.name.trim().isEmpty ? '该角色' : character.name;

    setState(() => _sending = true);
    final sent = await widget.campaignController.sendMessage(
      campaignId: widget.campaign.id,
      kind: 'roll',
      content:
          '$actorName · ${draft.label}：$die ${Dnd5eRules.formatModifier(modifier)} = $total',
      campaignActorId: actor.id,
      eventData: {
        'targetActorId': actor.id,
        'checkType': draft.type,
        'checkKey': draft.key,
        'label': draft.label,
        'rollMode': draft.rollMode,
        'notation': draft.rollMode == 'normal' ? 'd20' : '2d20',
        'die': die,
        'modifier': modifier,
        'total': total,
        'dmRolled': true,
        if (draft.dc != null) 'dc': draft.dc,
        if (draft.dc != null) 'success': total >= draft.dc!,
      },
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (!sent) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(chatText('sendFailed'))));
    }
  }

  bool _canRespondToCheck(CampaignChatMessage message) {
    return message.kind == 'checkRequest' &&
        widget.campaignActorId != null &&
        message.eventData?['targetActorId'] == widget.campaignActorId &&
        widget.character != null;
  }

  /// 扫描当前战役消息列表，判断当前用户是否已对某 checkRequest 发过响应。
  /// 响应定义为：kind='roll' 且 eventData.requestId == message.id 且
  /// senderId == 当前用户 id。与后端 sendMessage 重复响应校验一致。
  bool _hasRespondedToCheck(CampaignChatMessage message) {
    if (message.kind != 'checkRequest') return false;
    final currentUserId = widget.campaignController.authController.user?.id;
    if (currentUserId == null) return false;
    return widget.campaignController.messages.any(
      (m) =>
          m.kind == 'roll' &&
          m.senderId == currentUserId &&
          m.eventData?['requestId'] == message.id,
    );
  }

  Future<void> _respondToCheckRequest(CampaignChatMessage message) async {
    final character = widget.character;
    final data = message.eventData;
    if (character == null || data == null || _sending) return;
    final checkType = data['checkType']?.toString() ?? 'ability';
    final checkKey = data['checkKey']?.toString() ?? 'str';
    final label = data['label']?.toString() ?? checkKey;
    final rollMode = data['rollMode']?.toString() ?? 'normal';
    final modifier = switch (checkType) {
      'skill' => Dnd5eRules.skillBonus(
        skillName: checkKey,
        abilities: character.abilityMap,
        level: character.level,
        proficient: character.skillMap[checkKey] == true,
      ),
      'save' => Dnd5eRules.saveBonus(
        ability: checkKey,
        abilities: character.abilityMap,
        level: character.level,
        proficient: character.saveMap[checkKey] == true,
      ),
      _ => Dnd5eRules.abilityBonus(character.abilityMap, checkKey),
    };
    final roller = widget.diceRoller ?? DiceRoller();
    final first = roller.rollD20().total;
    final second = rollMode == 'normal' ? first : roller.rollD20().total;
    final die = switch (rollMode) {
      'advantage' => first > second ? first : second,
      'disadvantage' => first < second ? first : second,
      _ => first,
    };
    final total = die + modifier;

    setState(() => _sending = true);
    final sent = await widget.campaignController.sendMessage(
      campaignId: widget.campaign.id,
      kind: 'roll',
      content: '$label：$die ${Dnd5eRules.formatModifier(modifier)} = $total',
      campaignActorId: widget.campaignActorId,
      eventData: {
        'requestId': message.id,
        'notation': 'd20',
        'label': label,
        'total': total,
      },
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (!sent) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(chatText('sendFailed'))));
    }
  }
}

/// Local-only draft for a DM "快速临时身份".
///
/// Per `2026-07-16-campaign-workspace-refactor-design.md` §快速临时身份:
/// the DM only needs to enter a display name. The draft lives locally in the
/// composer until the first message is sent; the server then atomically
/// creates a temporary CampaignActor + message in a single transaction.
/// Unsent drafts never reach the server.
class _TemporaryIdentityDraft {
  const _TemporaryIdentityDraft({required this.displayName});

  final String displayName;
}

/// Bottom sheet form for collecting the display name of a temporary identity.
///
/// Manages its own [TextEditingController] so the controller is disposed only
/// when the widget leaves the tree (after the sheet's close animation), not
/// when [Navigator.pop] is called.
class _DraftIdentityFormSheet extends StatefulWidget {
  const _DraftIdentityFormSheet({required this.onConfirm});

  final ValueChanged<String> onConfirm;

  @override
  State<_DraftIdentityFormSheet> createState() =>
      _DraftIdentityFormSheetState();
}

class _DraftIdentityFormSheetState extends State<_DraftIdentityFormSheet> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    widget.onConfirm(name);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('快速临时身份', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '只需填写显示名称即可。发送第一条消息时，服务器会在一个事务中创建临时角色并写入消息。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('draft-identity-name'),
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: '显示名称',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('draft-identity-confirm'),
              onPressed: _submit,
              child: const Text('确认使用此身份'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Spec §顶部: 聊天搜索面板。从聊天页 AppBar 搜索入口打开，调用
/// `CampaignController.searchMessages` 检索战役历史消息，不替换
/// 实时聊天时间线。
class _CampaignChatSearchSheet extends StatefulWidget {
  const _CampaignChatSearchSheet({
    required this.campaignId,
    required this.controller,
  });

  final String campaignId;
  final CampaignController controller;

  @override
  State<_CampaignChatSearchSheet> createState() =>
      _CampaignChatSearchSheetState();
}

class _CampaignChatSearchSheetState extends State<_CampaignChatSearchSheet> {
  final _searchController = TextEditingController();
  List<CampaignChatMessage> _results = const [];
  bool _searching = false;
  int _request = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onChanged(String value) async {
    final query = value.trim();
    final request = ++_request;
    setState(() {
      _searching = query.isNotEmpty;
      if (query.isEmpty) _results = const [];
    });
    if (query.isEmpty) return;
    final results = await widget.controller.searchMessages(
      widget.campaignId,
      query: query,
    );
    if (!mounted || request != _request) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SearchBar(
                key: const Key('campaign-chat-search-field'),
                hintText: '搜索发言者、消息内容',
                leading: const Icon(Icons.search),
                controller: _searchController,
                onChanged: _onChanged,
              ),
            ),
            SizedBox(
              height: 320,
              child: _searching
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                  ? const Center(child: Text('输入关键词搜索战役消息'))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final message = _results[index];
                        return ListTile(
                          key: Key('campaign-chat-search-result-${message.id}'),
                          leading: const Icon(Icons.history),
                          title: Text(message.content),
                          subtitle: Text(message.displayName),
                          onTap: () => Navigator.of(context).pop(message),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
