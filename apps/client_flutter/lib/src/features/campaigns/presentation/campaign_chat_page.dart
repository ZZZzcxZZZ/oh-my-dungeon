import 'package:flutter/material.dart';

import '../../app_preferences/presentation/app_preferences_controller.dart';
import '../../characters/domain/character.dart';
import '../../characters/domain/dnd5e_rules.dart';
import '../../characters/presentation/character_detail_page.dart';
import '../../content/data/local/content_repository.dart';
import '../../content/domain/content_entry.dart';
import '../../content/presentation/content_detail_page.dart';
import '../../content/presentation/content_library_controller.dart';
import '../../../core/dice/dice_roller.dart';
import '../../../core/dice/dice_tray_dialog.dart';
import '../domain/campaign.dart';
import '../domain/campaign_character.dart';
import '../domain/campaign_conversation.dart';
import '../domain/campaign_message_speaker.dart';
import '../data/sync/campaign_sync_api_client.dart';
import 'characters/campaign_character_controller.dart';
import 'characters/campaign_character_picker_sheet.dart';
import 'characters/campaign_character_sheet_launcher.dart';
import 'characters/dm_quick_ops_sheet.dart';
import 'campaign_controller.dart';
import 'campaign_center_page.dart';
import 'campaign_event_dispatcher.dart';
import 'center/campaign_archive_editor_page.dart';
import 'character_roll_sink.dart';
import 'chat/campaign_chat_composer.dart';
import 'chat/campaign_chat_tool_sheet.dart';
import 'chat/campaign_chat_timeline.dart';
import 'chat/campaign_composer_identity.dart';
import 'chat/campaign_identity_sheet.dart';
import 'chat/chat_helpers.dart';
import 'chat/chat_mode_picker.dart';
import 'chat/check_request_sheet.dart';
import 'content/campaign_content_controller.dart';
import 'conversation_controller.dart';
import 'widgets/campaign_avatar.dart';

class CampaignChatPage extends StatefulWidget {
  const CampaignChatPage({
    required this.campaign,
    required this.character,
    required this.campaignController,
    required this.contentRepository,
    this.localCharacters = const [],
    this.campaignCharacterId,
    this.diceRoller,
    this.campaignContentController,
    this.characterController,
    this.appPreferencesController,
    this.conversationController,
    this.conversationId,
    this.syncApiClient,
    super.key,
  });

  final Campaign campaign;
  final CharacterSheet? character;
  final CampaignController campaignController;
  final ContentRepository contentRepository;
  final List<CharacterSheet> localCharacters;
  final String? campaignCharacterId;
  final DiceRoller? diceRoller;
  final CampaignContentController? campaignContentController;
  final CampaignCharacterController? characterController;
  final AppPreferencesController? appPreferencesController;

  /// 战役同步 API 客户端; 由上层注入共享实例, 未提供时页面自行创建.
  final CampaignSyncApiClient? syncApiClient;

  /// Plan 2026-07-23 task 5.3: optional conversation scoping. When provided,
  /// messages are loaded/sent into this conversation (main/direct/group).
  /// When null, the page falls back to the conversation controller's active
  /// conversation, or the campaign-wide main room (legacy behaviour).
  final ConversationController? conversationController;
  final String? conversationId;

  @override
  State<CampaignChatPage> createState() => _CampaignChatPageState();
}

class _CampaignChatPageState extends State<CampaignChatPage> {
  final _controller = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  ChatMode _mode = ChatMode.say;
  bool _sending = false;
  _TemporaryIdentityDraft? _draftIdentity;

  /// The conversation id to scope message load/send with. Resolved from the
  /// explicit widget param, then the conversation controller's active id,
  /// then null (main room / legacy behaviour).
  String? get _conversationId {
    final explicit = widget.conversationId;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final controller = widget.conversationController;
    if (controller != null) {
      final active = controller.activeConversationId;
      if (active != null && active.isNotEmpty) return active;
    }
    return null;
  }

  /// The active conversation object, if a controller is wired in.
  CampaignConversation? get _activeConversation {
    final controller = widget.conversationController;
    if (controller == null) return null;
    final id = _conversationId;
    if (id == null) return controller.mainConversation;
    for (final c in controller.conversations) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.campaignController.loadMessages(
        widget.campaign.id,
        conversationId: _conversationId,
      );
      widget.campaignController.loadWorkspaceContext(widget.campaign.id);
      widget.campaignController.connectCampaignChat(widget.campaign.id);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _chatScrollController.dispose();
    widget.campaignController.disconnectCampaignChat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.campaignController,
        if (widget.characterController != null) widget.characterController!,
        if (widget.appPreferencesController != null)
          widget.appPreferencesController!,
        if (widget.conversationController != null)
          widget.conversationController!,
      ]),
      builder: (context, _) {
        final messages = widget.campaignController.messages;
        return Scaffold(
          appBar: AppBar(
            title: Text(_appBarTitle()),
            actions: [
              IconButton(
                key: const Key('campaign-open-center'),
                tooltip: '战役中心',
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => CampaignCenterPage(
                      campaign: widget.campaign,
                      controller: widget.campaignController,
                      characterController: widget.characterController,
                      contentRepository: widget.contentRepository,
                      syncApiClient: widget.syncApiClient,
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

  /// Plan 2026-07-23 task 5.3: AppBar shows campaign name for the main room,
  /// or campaign name + conversation title for direct/group rooms.
  String _appBarTitle() {
    final conversation = _activeConversation;
    if (conversation == null || conversation.isMain) {
      return widget.campaign.name;
    }
    final title = conversation.title;
    if (title.isEmpty) return widget.campaign.name;
    return '${widget.campaign.name} · $title';
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
                onPressed: () => widget.campaignController.loadMessages(
                  widget.campaign.id,
                  conversationId: _conversationId,
                ),
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
              : CampaignChatTimeline(
                  messages: messages,
                  currentUserId:
                      widget.campaignController.authController.user?.id,
                  scrollController: _chatScrollController,
                  onAvatarTap: _resolveAvatarTap,
                  canRespondToCheck: _canRespondToCheck,
                  hasRespondedToCheck: _hasRespondedToCheck,
                  onRespondToCheck: _respondToCheckRequest,
                  groupConsecutiveMessages:
                      widget
                          .appPreferencesController
                          ?.preferences
                          .groupConsecutiveChatMessages ??
                      true,
                ),
        ),
        CampaignChatComposer(
          identity: _composerIdentity,
          mode: _mode,
          controller: _controller,
          sending: _sending,
          onIdentityTap: _showToolPanel,
          onModeChanged: (mode) => setState(() => _mode = mode),
          onSend: _send,
          draftIdentityName: _draftIdentity?.displayName,
          onDiscardDraft: () => setState(() => _draftIdentity = null),
        ),
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
      campaignCharacters: widget.characterController?.characters ?? const [],
      localCharacters: widget.localCharacters,
      fallbackCharacter: widget.character,
      fallbackCharacterId: widget.campaignCharacterId,
    );
    final draft = _draftIdentity;
    if (draft == null) return resolved;
    return CampaignComposerIdentity(
      displayName: draft.displayName,
      speakerMode: 'character',
      characterId: null,
      avatarUrl: null,
      healthState: null,
      localCharacter: null,
      campaignCharacter: null,
      subtitle: '临时身份草稿',
    );
  }

  /// 解析消息头像点击：只有能解析到战役 Character 时才打开统一完整角色卡。
  VoidCallback? _resolveAvatarTap(CampaignChatMessage message) {
    final characterId = message.campaignCharacterId;
    if (characterId == null || characterId.isEmpty) return null;
    final controller = widget.characterController;
    if (controller == null) return null;
    final character = controller.characters
        .cast<CampaignCharacter?>()
        .firstWhere((a) => a?.id == characterId, orElse: () => null);
    if (character == null) return null;
    return () => _openCampaignCharacterSheet(character);
  }

  Future<void> _openCampaignCharacterSheet(CampaignCharacter character) {
    final controller = widget.characterController;
    if (controller == null) return Future<void>.value();
    return openCampaignCharacterSheet(
      context: context,
      controller: controller,
      character: character,
      canEditAnyCharacter: _canManageCampaign,
      contentRepository: widget.contentRepository,
      sink: CharacterRollSink(
        campaignId: widget.campaign.id,
        campaignController: widget.campaignController,
        campaignCharacterId: character.id,
        conversationId: _conversationId,
      ),
      returnToChatAfterRoll:
          widget.appPreferencesController?.preferences.returnToChatAfterRoll ??
          true,
    );
  }

  Future<bool> _send(String submittedContent) async {
    final content = submittedContent.trim();
    if (content.isEmpty || _sending) return false;

    final draft = _draftIdentity;
    final identity = _composerIdentity;
    setState(() => _sending = true);
    final sent = await widget.campaignController.sendMessage(
      campaignId: widget.campaign.id,
      kind: draft == null && identity.isOoc
          ? 'ooc'
          : (_mode == ChatMode.act ? 'action' : 'say'),
      content: content,
      // Keep the legacy fields during the 0.1 rolling upgrade. The explicit
      // speaker is authoritative on upgraded servers.
      campaignCharacterId: draft == null ? identity.characterId : null,
      speakerSnapshot: draft == null
          ? null
          : <String, Object?>{'displayName': draft.displayName},
      speaker: draft != null
          ? CampaignMessageSpeaker.temporary(displayName: draft.displayName)
          : switch (identity.speakerMode) {
              'narrator' => const CampaignMessageSpeaker.narrator(),
              'ooc' => const CampaignMessageSpeaker.ooc(),
              _ when identity.characterId != null =>
                CampaignMessageSpeaker.character(identity.characterId),
              _ => const CampaignMessageSpeaker.ooc(),
            },
      conversationId: _conversationId,
    );
    if (!mounted) return sent;
    setState(() => _sending = false);
    if (sent) {
      _controller.clear();
      if (draft != null) {
        // Plan 2026-07-23 task 5.2: the snapshot is use-once — clear the draft
        // and do NOT refresh the workspace/character list (no character was created,
        // so the DM's previously selected speaker is still active).
        _draftIdentity = null;
      }
      await WidgetsBinding.instance.endOfFrame;
      if (_chatScrollController.hasClients) {
        await _chatScrollController.animateTo(
          _chatScrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    } else if (draft != null) {
      // Spec: failed draft send keeps the draft and shows the spec error.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('临时身份发送失败，消息尚未发送。')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(chatText('sendFailed'))));
    }
    return sent;
  }

  /// Spec §输入栏: 当前身份头像取代原有独立 `+` 按钮。点击后打开底部快捷面板，
  /// 工具按成员能力和当前上下文动态出现，界面不显示不可用的 DM 工具。
  Future<void> _showToolPanel() async {
    final action = await showModalBottomSheet<CampaignChatToolAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => CampaignChatToolSheet(
        identity: _composerIdentity,
        isManager: _canManageCampaign,
        hasCharacterActions: _characterActions.isNotEmpty,
      ),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case CampaignChatToolAction.openCharacterSheet:
        _openCharacterSheet();
        break;
      case CampaignChatToolAction.switchIdentity:
        await _showIdentitySheet();
        break;
      case CampaignChatToolAction.rollDice:
        await _showRollSheet();
        break;
      case CampaignChatToolAction.skillCheck:
        await _showDirectCheckTargetPicker();
        break;
      case CampaignChatToolAction.manageHp:
        await _openDmHpOperation();
        break;
      case CampaignChatToolAction.grantItem:
        await _openDmGrantItemOperation();
        break;
      case CampaignChatToolAction.addCondition:
        await _openDmConditionOperation();
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
      case CampaignChatToolAction.characterActions:
        await _showCharacterActions();
        break;
    }
  }

  Future<void> _openDmHpOperation() async {
    final resources = _dmOperationResources();
    if (resources == null) return;
    await DmQuickOpsSheet.showHpOperation(
      context: context,
      campaignId: widget.campaign.id,
      characterController: resources.$1,
      eventDispatcher: resources.$2,
    );
    resources.$2.dispose();
  }

  Future<void> _openDmGrantItemOperation() async {
    final resources = _dmOperationResources();
    if (resources == null) return;
    await DmQuickOpsSheet.showGrantItemOperation(
      context: context,
      campaignId: widget.campaign.id,
      characterController: resources.$1,
      eventDispatcher: resources.$2,
      contentRepository: widget.contentRepository,
    );
    resources.$2.dispose();
  }

  Future<void> _openDmConditionOperation() async {
    final resources = _dmOperationResources();
    if (resources == null) return;
    await DmQuickOpsSheet.showConditionOperation(
      context: context,
      campaignId: widget.campaign.id,
      characterController: resources.$1,
      eventDispatcher: resources.$2,
    );
    resources.$2.dispose();
  }

  (CampaignCharacterController, CampaignEventDispatcher)?
  _dmOperationResources() {
    final characterController = widget.characterController;
    if (characterController == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('角色资料仍在加载，请稍后重试')));
      return null;
    }
    final dispatcher = CampaignEventDispatcher(
      apiClient: widget.syncApiClient ?? HttpCampaignSyncApiClient(),
      apiBaseUrlProvider: () => widget.campaignController.apiBaseUrl,
      accessTokenProvider: () => widget.campaignController.accessToken ?? '',
      onCharacterChanged: (_) => characterController.pullUntilCurrent(),
    );
    return (characterController, dispatcher);
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

    final activeCharacters = workspace.characters
        .where((character) => character.status == 'active')
        .toList(growable: false);
    final persistentCharacters = activeCharacters
        .where(
          (character) =>
              character.lifecycle != 'temporary' &&
              (character.characterType == 'npc' ||
                  character.characterType == 'monster' ||
                  character.characterType == 'companion'),
        )
        .toList(growable: false);
    final proxyCharacters = activeCharacters
        .where(
          (character) =>
              character.ownerUserId != null &&
              character.ownerUserId != membership.userId &&
              character.characterType == 'player',
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
        persistentCharacters: persistentCharacters,
        proxyCharacters: proxyCharacters,
        campaignCharacters:
            widget.characterController?.characters ??
            const <CampaignCharacter>[],
        hasBoundCharacter:
            membership.boundCharacterId != null ||
            (widget.campaignCharacterId != null && widget.character != null),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice.createTemporary) {
      await _showDraftIdentityForm();
      return;
    }
    if (choice.changeBinding) {
      await _showCharacterBindingSheet(workspace);
      return;
    }

    await _updateCampaignSpeaker(choice.speakerMode!, choice.characterId);
  }

  Future<void> _showCharacterBindingSheet(
    CampaignWorkspaceContext workspace,
  ) async {
    final membership = workspace.membership;
    final publishedCandidates = workspace.characters
        .where(
          (character) =>
              character.ownerUserId == membership.userId &&
              character.characterType == 'player' &&
              character.status == 'active' &&
              character.lifecycle != 'temporary',
        )
        .toList(growable: false);
    final publishedSourceIds = <String>{
      ...publishedCandidates
          .map((character) => character.sourceCharacterId)
          .whereType<String>(),
      ...?widget.characterController?.characters
          .where(
            (character) =>
                character.campaignId == widget.campaign.id &&
                character.ownerUserId == membership.userId &&
                character.characterType == 'player' &&
                character.status == 'active',
          )
          .map((character) => character.sourceCharacterId)
          .whereType<String>(),
    };
    final localCandidates = widget.localCharacters
        .where((character) => !publishedSourceIds.contains(character.id))
        .toList(growable: false);

    if (publishedCandidates.isEmpty && localCandidates.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先在角色页创建一名玩家角色')));
      return;
    }

    final selected = await showModalBottomSheet<_BindingCandidate>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '绑定角色',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final character in publishedCandidates)
              ListTile(
                key: Key('binding-character-${character.id}'),
                leading: CampaignAvatar(
                  initials: character.displayName,
                  health: CampaignAvatar.healthFromState(
                    character.publicHealthState,
                  ),
                ),
                title: Text(character.displayName),
                subtitle: Text(
                  character.id == membership.boundCharacterId ? '当前绑定' : '玩家角色',
                ),
                trailing: character.id == membership.boundCharacterId
                    ? const Icon(Icons.check_rounded)
                    : const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(
                  context,
                ).pop(_BindingCandidate.published(character)),
              ),
            if (publishedCandidates.isNotEmpty && localCandidates.isNotEmpty)
              const Divider(height: 1),
            for (final character in localCandidates)
              ListTile(
                key: Key('binding-local-character-${character.id}'),
                leading: CampaignAvatar(
                  initials: character.name,
                  imageUrl: character.avatarUrl,
                  healthFraction: CampaignAvatar.fractionFromHp(
                    character.currentHp,
                    character.maxHp,
                  ),
                ),
                title: Text(character.name),
                subtitle: const Text('本地角色 · 选择后自动加入战役'),
                trailing: const Icon(Icons.add_link_rounded),
                onTap: () => Navigator.of(
                  context,
                ).pop(_BindingCandidate.local(character)),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;

    var campaignCharacterId = selected.publishedCharacter?.id;
    final localCharacter = selected.localCharacter;
    if (localCharacter != null) {
      final controller = widget.characterController;
      if (controller == null) {
        _showBindingError('角色同步服务尚未就绪');
        return;
      }
      if (controller.selectedCampaignId != widget.campaign.id) {
        await controller.selectCampaign(widget.campaign.id);
      }
      final published = await controller.publishCharacter(localCharacter);
      if (!mounted) return;
      if (!published) {
        _showBindingError(controller.error ?? '发布角色失败');
        return;
      }
      for (final character in controller.characters.reversed) {
        if (character.sourceCharacterId == localCharacter.id &&
            character.characterType == 'player') {
          campaignCharacterId = character.id;
          break;
        }
      }
      if (campaignCharacterId == null) {
        _showBindingError('角色已发布，但无法读取战役角色');
        return;
      }
    }

    final updated = await widget.campaignController.updateMemberBinding(
      campaignId: widget.campaign.id,
      characterId: campaignCharacterId!,
    );
    if (!mounted) return;
    if (!updated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.campaignController.workspaceContextError ?? '绑定角色失败',
          ),
        ),
      );
      return;
    }
  }

  void _showBindingError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

  String? get _activeSpeakerCharacterId => _composerIdentity.characterId;

  Future<void> _updateCampaignSpeaker(
    String speakerMode, [
    String? characterId,
  ]) async {
    final updated = await widget.campaignController.updateSpeaker(
      campaignId: widget.campaign.id,
      speakerMode: speakerMode,
      characterId: characterId,
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
  ///
  /// Plan 2026-07-23 task 4.4: 统一使用 CampaignArchiveEditorPage（原
  /// CampaignArchiveCreateDialog 已退役）。聊天工具栏发起的快速归档
  /// 也走完整编辑器，让玩家可以一次性补齐正文、标签与关联条目。
  Future<void> _showArchiveCreationForm({required String initialKind}) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CampaignArchiveEditorPage(
          initialKind: initialKind,
          existingEntries: widget.campaignController.archives,
          onSubmit: (draft) async {
            final linksPayload = draft.linkedEntryIds.isEmpty
                ? null
                : draft.linkedEntryIds
                      .map(
                        (id) => <String, Object?>{'kind': 'archive', 'id': id},
                      )
                      .toList(growable: false);
            final entry = await widget.campaignController.createArchiveEntry(
              campaignId: widget.campaign.id,
              kind: draft.kind,
              title: draft.title,
              summary: draft.summary,
              bodyBlocks: draft.bodyBlocks.isEmpty ? null : draft.bodyBlocks,
              tags: draft.tags.isEmpty ? null : draft.tags,
              links: linksPayload,
            );
            if (entry != null) {
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已保存到战役档案')));
              }
              return true;
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    widget.campaignController.archivesError ?? '创建失败',
                  ),
                ),
              );
            }
            return false;
          },
        ),
      ),
    );
    if (created == true && mounted) {
      await widget.campaignController.loadArchives(widget.campaign.id);
    }
  }

  Future<void> _showRollSheet() {
    // Spec §输入栏: 关闭工具 sheet 由调用方负责, helper 不应自行 pop。
    final quickPresets =
        widget.appPreferencesController?.preferences.quickDicePresets ??
        const <String>[];
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: DiceTrayDialog(
            diceRoller: widget.diceRoller ?? DiceRoller(),
            quickPresets: quickPresets,
            onSend: _sendDiceTrayResult,
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
      campaignCharacterId: _activeSpeakerCharacterId,
      actionId: action['id']! as String,
      conversationId: _conversationId,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (!sent) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(chatText('sendFailed'))));
    }
  }

  /// Task 3.2: 处理组合式骰子编辑器的发送结果.
  /// 携带结构化 eventData (notation/total/rollMode/dc/success) 供聊天渲染检定卡片.
  Future<void> _sendDiceTrayResult(DiceTrayResult result) async {
    final messenger = ScaffoldMessenger.of(context);
    final label = result.dc == null
        ? '${result.notation} = ${result.total}'
        : '${result.notation} = ${result.total} '
              '${result.success == true ? '✓' : '✗'} DC ${result.dc}';
    Navigator.of(context).pop();
    setState(() => _sending = true);
    final sent = await widget.campaignController.sendMessage(
      campaignId: widget.campaign.id,
      kind: 'roll',
      content: label,
      campaignCharacterId: _activeSpeakerCharacterId,
      conversationId: _conversationId,
      eventData: <String, Object?>{
        'notation': result.notation,
        'total': result.total,
        'rollMode': result.rollMode,
        if (result.dc != null) 'dc': result.dc,
        if (result.success != null) 'success': result.success,
      },
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (!sent) {
      messenger.showSnackBar(SnackBar(content: Text(chatText('sendFailed'))));
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
    final characterId = identity.characterId;
    final characterController = widget.characterController;
    if (characterId != null && characterController != null) {
      final character =
          identity.campaignCharacter ??
          characterController.characters
              .where((candidate) => candidate.id == characterId)
              .firstOrNull;
      if (character != null) {
        openCampaignCharacterSheet(
          context: context,
          controller: characterController,
          character: character,
          canEditAnyCharacter: _canManageCampaign,
          contentRepository: widget.contentRepository,
          sink: CharacterRollSink(
            campaignId: widget.campaign.id,
            campaignController: widget.campaignController,
            campaignCharacterId: character.id,
          ),
          returnToChatAfterRoll:
              widget
                  .appPreferencesController
                  ?.preferences
                  .returnToChatAfterRoll ??
              true,
        );
        return;
      }
    }

    final character = identity.localCharacter;
    if (character != null) {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) => CharacterDetailPage(
            character: character,
            returnToChatAfterRoll:
                widget
                    .appPreferencesController
                    ?.preferences
                    .returnToChatAfterRoll ??
                true,
            sink: CharacterRollSink(
              campaignId: widget.campaign.id,
              campaignController: widget.campaignController,
              campaignCharacterId: _activeSpeakerCharacterId,
            ),
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(chatText('noBoundCharacter'))));
  }

  Future<void> _showDirectCheckTargetPicker() async {
    final characters =
        (widget.characterController?.characters ?? const <CampaignCharacter>[])
            .where((character) => character.status == 'active')
            .toList(growable: false);
    if (characters.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前没有可代掷检定的角色')));
      return;
    }
    final selected = await showCampaignCharacterPickerSheet(
      context: context,
      title: '选择代掷目标',
      characters: characters,
    );
    if (selected != null && mounted) await _showDirectCheckSheet(selected);
  }

  Future<void> _showDirectCheckSheet(CampaignCharacter character) async {
    final draft = await showModalBottomSheet<CheckRequestDraft>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => CheckRequestSheet(character: character),
    );
    if (draft == null || !mounted || _sending) return;

    final characterSheet = campaignCharacterToCharacterSheet(character);
    final modifier = switch (draft.type) {
      'skill' => Dnd5eRules.skillBonus(
        skillName: draft.key,
        abilities: characterSheet.abilityMap,
        level: characterSheet.level,
        proficient: characterSheet.skillMap[draft.key] == true,
      ),
      'save' => Dnd5eRules.saveBonus(
        ability: draft.key,
        abilities: characterSheet.abilityMap,
        level: characterSheet.level,
        proficient: characterSheet.saveMap[draft.key] == true,
      ),
      _ => Dnd5eRules.abilityBonus(characterSheet.abilityMap, draft.key),
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
    final characterName = characterSheet.name.trim().isEmpty
        ? '该角色'
        : characterSheet.name;

    setState(() => _sending = true);
    final sent = await widget.campaignController.sendMessage(
      campaignId: widget.campaign.id,
      kind: 'roll',
      content:
          '$characterName · ${draft.label}：$die ${Dnd5eRules.formatModifier(modifier)} = $total',
      campaignCharacterId: character.id,
      conversationId: _conversationId,
      eventData: {
        'targetCharacterId': character.id,
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
        widget.campaignCharacterId != null &&
        message.eventData?['targetCharacterId'] == widget.campaignCharacterId &&
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
      campaignCharacterId: widget.campaignCharacterId,
      conversationId: _conversationId,
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
/// composer until the first message is sent. It is serialized into that
/// message's speaker snapshot and then cleared; no CampaignCharacter is persisted.
/// Unsent drafts never leave the client.
class _TemporaryIdentityDraft {
  const _TemporaryIdentityDraft({required this.displayName});

  final String displayName;
}

class _BindingCandidate {
  const _BindingCandidate._({this.publishedCharacter, this.localCharacter});

  factory _BindingCandidate.published(CampaignWorkspaceCharacter character) =>
      _BindingCandidate._(publishedCharacter: character);

  factory _BindingCandidate.local(CharacterSheet character) =>
      _BindingCandidate._(localCharacter: character);

  final CampaignWorkspaceCharacter? publishedCharacter;
  final CharacterSheet? localCharacter;
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
              '只需填写显示名称即可。发送消息时，该名称会直接写入消息行，不会创建常驻角色。',
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
