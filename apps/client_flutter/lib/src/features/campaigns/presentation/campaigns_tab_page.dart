import 'package:flutter/material.dart';

import '../../app_preferences/presentation/app_preferences_controller.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../characters/domain/character.dart';
import '../../characters/presentation/character_controller.dart';
import '../../client_mode/domain/client_mode.dart';
import '../../content/data/local/content_repository.dart';
import '../../../core/dice/dice_roller.dart';
import '../../server_home/domain/active_server_session.dart';
import '../domain/campaign.dart';
import '../domain/campaign_conversation.dart';
import 'characters/campaign_character_controller.dart';
import 'campaign_chat_page.dart';
import 'campaign_controller.dart';
import 'campaign_mode_guard.dart';
import 'content/campaign_content_controller.dart';
import 'conversation_controller.dart';
import 'widgets/campaign_list_tile.dart';

/// Top-level "战役" tab.
///
/// Shows a login prompt when the user is not authenticated, otherwise the
/// list of campaigns with create/join entry points.
class CampaignsTabPage extends StatefulWidget {
  const CampaignsTabPage({
    required this.session,
    required this.authController,
    required this.campaignController,
    required this.characterController,
    required this.contentRepository,
    required this.modeController,
    required this.appPreferencesController,
    this.diceRoller,
    this.onCampaignOpened,
    this.campaignContentController,
    this.campaignCharacterController,
    this.conversationController,
    super.key,
  });

  final ActiveServerSession session;
  final AuthController authController;
  final CampaignController campaignController;
  final CharacterController characterController;
  final ContentRepository contentRepository;
  final ClientModeController modeController;
  final AppPreferencesController appPreferencesController;
  final DiceRoller? diceRoller;
  final Future<void> Function(String campaignId)? onCampaignOpened;
  final CampaignContentController? campaignContentController;
  final CampaignCharacterController? campaignCharacterController;
  final ConversationController? conversationController;

  @override
  State<CampaignsTabPage> createState() => _CampaignsTabPageState();
}

class _CampaignsTabPageState extends State<CampaignsTabPage> {
  /// Spec §客户端工作模式: 模式提示每个战役每会话只显示一次。已提示过
  /// 的战役 ID 加入此集合后不再弹窗，避免反复打扰用户。
  final Set<String> _modePromptShownCampaignIds = <String>{};

  @override
  void initState() {
    super.initState();
    _maybeLoadCampaigns();
  }

  void _maybeLoadCampaigns() {
    if (widget.authController.isLoggedIn) {
      widget.campaignController.loadCampaigns();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.authController,
        widget.campaignController,
        widget.characterController,
        if (widget.campaignCharacterController != null)
          widget.campaignCharacterController!,
        widget.modeController,
        widget.appPreferencesController,
        widget.session,
        if (widget.conversationController != null)
          widget.conversationController!,
      ]),
      builder: (context, _) {
        if (!widget.session.isConfigured) {
          return _buildOfflinePrompt(context);
        }
        if (!widget.authController.isLoggedIn) {
          return _buildLoginPrompt(context);
        }

        final campaigns = widget.campaignController.campaigns;
        // Spec §客户端工作模式: 战役创建入口只在 DM 模式显示。Player 模式
        // 下隐藏 FAB，仅保留加入入口；owner 在 Player 模式进入战役
        // 时会收到一键切换 DM 模式的提示（见 Task 4.2）。
        final isDmMode = widget.modeController.mode == ClientMode.dungeonMaster;
        return Scaffold(
          appBar: AppBar(
            title: const Text('战役'),
            actions: [
              IconButton(
                tooltip: '使用邀请码加入战役',
                onPressed: _showJoinDialog,
                icon: const Icon(Icons.login_outlined),
              ),
            ],
          ),
          floatingActionButton: isDmMode
              ? FloatingActionButton.extended(
                  key: const Key('campaign-create-button'),
                  heroTag: 'create_campaign',
                  onPressed: _showCreateDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('创建战役'),
                )
              : null,
          body: _buildCampaignList(context, campaigns),
        );
      },
    );
  }

  Widget _buildOfflinePrompt(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('战役')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off,
                  size: 56,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text('未连接服务器', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text(
                  '在设置中添加跑团服务器后，可以创建和加入在线战役。',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('战役')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text('登录后管理战役', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text(
                  '创建属于你的战役，或使用邀请码加入朋友的团。',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCampaignList(BuildContext context, List<Campaign> campaigns) {
    if (widget.campaignController.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.campaignController.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.campaignController.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (campaigns.isEmpty) {
      // Spec §客户端工作模式: 创建入口只在 DM 模式显示，空态文案随模式调整。
      final isDmMode = widget.modeController.mode == ClientMode.dungeonMaster;
      final message = isDmMode
          ? '暂无战役\n点击右下角创建，或使用邀请码加入'
          : '暂无战役\n使用上方邀请码入口加入朋友的团';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
    }

    final compact = widget.appPreferencesController.preferences.compactLists;
    final currentUserId = widget.authController.user?.id;
    return ListView.separated(
      padding: compact
          ? const EdgeInsets.fromLTRB(8, 4, 8, 80)
          : const EdgeInsets.fromLTRB(12, 8, 12, 96),
      itemCount: campaigns.length,
      separatorBuilder: (context, index) =>
          Divider(height: compact ? 1 : 6, indent: 72),
      itemBuilder: (context, index) {
        final campaign = campaigns[index];
        final character = _primaryCharacter();
        // Plan 2026-07-23 task 5.3: conversations are scoped to the active
        // campaign in the conversation controller. When the controller tracks
        // a different campaign, fall back to an empty list (the card still
        // shows the main entry from Task 5.1).
        final conversationController = widget.conversationController;
        final conversations =
            conversationController != null &&
                conversationController.activeCampaignId == campaign.id
            ? conversationController.conversations
            : const <CampaignConversation>[];
        final secondaryConversations = conversations
            .where(
              (conversation) =>
                  !conversation.isMain && !conversation.isArchived,
            )
            .map(
              (conversation) => CampaignListConversation(
                id: conversation.id,
                title: conversation.title.isEmpty
                    ? (conversation.kind == 'group' ? '未命名小群' : '私聊')
                    : conversation.title,
                kind: conversation.kind == 'group'
                    ? CampaignConversationKind.group
                    : CampaignConversationKind.direct,
                lastMessage: conversation.lastMessage?.content,
                unreadCount: conversation.unreadCount,
              ),
            )
            .toList(growable: false);
        return CampaignListTile(
          campaign: campaign,
          currentUserId: currentUserId ?? '',
          conversations: secondaryConversations,
          onExpand: () {
            if (widget.conversationController != null &&
                widget.conversationController!.activeCampaignId !=
                    campaign.id) {
              widget.conversationController!.loadConversations(campaign.id);
            }
          },
          onTap: () => _openCampaignChat(campaign, character),
          onConversationTap: (conversationId) {
            final conversation = conversations
                .where((item) => item.id == conversationId)
                .firstOrNull;
            if (conversation == null) return;
            _openCampaignChat(campaign, character, conversation: conversation);
          },
          onCreateDirect: () => _showCreateDirectDialog(campaign),
          onCreateGroup: () => _showCreateGroupDialog(campaign),
        );
      },
    );
  }

  CharacterSheet? _primaryCharacter() {
    final characters = widget.characterController.characters;
    if (characters.isEmpty) return null;
    return characters.first;
  }

  Future<void> _openCampaignChat(
    Campaign campaign,
    CharacterSheet? character, {
    CampaignConversation? conversation,
  }) async {
    // Spec §客户端工作模式: 进入战役前根据用户角色与当前模式给出提示。
    // - owner/dm 在 Player 模式：提示一键切换 DM 模式
    // - 非 owner 在 DM 模式：提示只能以玩家身份参与
    // 每个战役每会话只提示一次，用户取消后不再打扰。
    final canOpen = await _maybeShowModePrompt(campaign);
    if (!mounted || !canOpen) return;

    await widget.onCampaignOpened?.call(campaign.id);
    if (!mounted) return;
    // The campaign summary is always the main-room entry. Explicit secondary
    // conversation taps provide an id; a null conversation must clear any
    // previously selected private/group chat.
    if (widget.conversationController != null) {
      widget.conversationController!.setActiveConversation(
        conversation != null && !conversation.isMain ? conversation.id : null,
      );
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => CampaignChatPage(
          campaign: campaign,
          character: character,
          localCharacters: widget.characterController.characters,
          campaignController: widget.campaignController,
          contentRepository: widget.contentRepository,
          campaignContentController: widget.campaignContentController,
          characterController: widget.campaignCharacterController,
          appPreferencesController: widget.appPreferencesController,
          campaignCharacterId: null,
          diceRoller: widget.diceRoller,
          conversationController: widget.conversationController,
        ),
      ),
    );
  }

  /// 根据当前用户在战役中的角色与客户端模式显示一次性提示。
  ///
  /// 返回 true 表示用户已确认继续（或无需提示），返回 false 表示用户
  /// 取消进入战役（仅在非 owner 误入 DM 模式时给用户机会退回）。
  Future<bool> _maybeShowModePrompt(Campaign campaign) async {
    if (_modePromptShownCampaignIds.contains(campaign.id)) return true;
    final currentUserId = widget.authController.user?.id;
    if (currentUserId == null) return false;

    final isOwner = campaign.ownerId == currentUserId;
    final currentMode = widget.modeController.mode;
    final access = CampaignModeGuard.evaluate(
      isCampaignOwner: isOwner,
      currentMode: currentMode,
    );

    if (access == CampaignModeAccess.switchToDungeonMaster) {
      _modePromptShownCampaignIds.add(campaign.id);
      final switchToDm = await _showSwitchToDmDialog(campaign);
      if (switchToDm && mounted) {
        await widget.modeController.setMode(ClientMode.dungeonMaster);
      } else {
        _modePromptShownCampaignIds.remove(campaign.id);
      }
      return switchToDm;
    }

    if (access == CampaignModeAccess.switchToPlayer) {
      _modePromptShownCampaignIds.add(campaign.id);
      final switchToPlayer = await _showSwitchToPlayerDialog(campaign);
      if (switchToPlayer && mounted) {
        await widget.modeController.setMode(ClientMode.player);
      } else {
        _modePromptShownCampaignIds.remove(campaign.id);
      }
      return switchToPlayer;
    }
    return true;
  }

  Future<bool> _showSwitchToDmDialog(Campaign campaign) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            key: const Key('mode-switch-to-dm-dialog'),
            title: const Text('切换到主持人模式？'),
            content: Text(
              '你是战役「${campaign.name}」的主持人。当前处于玩家模式，'
              '切换到主持人模式后才能使用 DM 工具（创建 NPC、管理档案、'
              '邀请成员等）。',
            ),
            actions: [
              TextButton(
                key: const Key('mode-switch-stay-player'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('继续以玩家身份'),
              ),
              FilledButton(
                key: const Key('mode-switch-confirm-dm'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('切换到主持人模式'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showSwitchToPlayerDialog(Campaign campaign) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            key: const Key('mode-player-only-dialog'),
            title: const Text('切换到玩家模式？'),
            content: Text(
              '你在战役「${campaign.name}」中是玩家。切换到玩家模式后即可进入，'
              '主持人工具只对战役创建者开放。',
            ),
            actions: [
              TextButton(
                key: const Key('mode-switch-stay-dm'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                key: const Key('mode-switch-confirm-player'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('切换到玩家模式'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showCreateDialog() async {
    final messenger = ScaffoldMessenger.of(context);

    final result = await showDialog<_CampaignCreationDraft>(
      context: context,
      builder: (context) => const _CampaignCreationGuide(),
    );

    if (result == null) return;

    final success = await widget.campaignController.createCampaign(
      name: result.name,
      description: result.description.isEmpty ? null : result.description,
      system: 'dnd5e-2024',
    );

    if (!mounted) return;
    if (success) {
      messenger.showSnackBar(const SnackBar(content: Text('战役已创建')));
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('创建失败：${widget.campaignController.error ?? '未知错误'}'),
        ),
      );
    }
  }

  Future<void> _showJoinDialog() async {
    final codeController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final code = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('加入战役'),
          content: TextField(
            controller: codeController,
            decoration: const InputDecoration(labelText: '邀请码'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(codeController.text.trim()),
              child: const Text('加入'),
            ),
          ],
        );
      },
    );

    if (code == null || code.isEmpty) return;

    final success = await widget.campaignController.joinCampaign(code: code);

    if (!mounted) return;
    if (success) {
      messenger.showSnackBar(const SnackBar(content: Text('已加入战役')));
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('加入失败：${widget.campaignController.error ?? '未知错误'}'),
        ),
      );
    }
  }

  /// Plan 2026-07-23 task 5.3: pick a campaign member to start a 1:1 chat.
  Future<void> _showCreateDirectDialog(Campaign campaign) async {
    final controller = widget.conversationController;
    if (controller == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final currentUserId = widget.authController.user?.id;
    final candidates = campaign.memberPreview
        .where((m) => m.userId != currentUserId)
        .toList();
    if (candidates.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('暂无其他成员可发起私聊')));
      return;
    }
    final selected = await showDialog<CampaignMemberPreview>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('发起私聊'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: candidates.length,
              itemBuilder: (context, index) {
                final member = candidates[index];
                return ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(
                    member.displayName.isEmpty
                        ? '玩家 ${member.userId.substring(0, 4)}'
                        : member.displayName,
                  ),
                  subtitle: Text(member.role),
                  onTap: () => Navigator.of(context).pop(member),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
    if (selected == null || !mounted) return;

    final conversation = await controller.createDirectConversation(
      campaignId: campaign.id,
      otherUserId: selected.userId,
    );
    if (!mounted) return;
    if (conversation != null) {
      final character = _primaryCharacter();
      await _openCampaignChat(campaign, character, conversation: conversation);
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text('创建私聊失败：${controller.error ?? '未知错误'}')),
      );
    }
  }

  /// Plan 2026-07-23 task 5.3: DM-only group conversation creation.
  Future<void> _showCreateGroupDialog(Campaign campaign) async {
    final controller = widget.conversationController;
    if (controller == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final currentUserId = widget.authController.user?.id;
    final candidates = campaign.memberPreview
        .where((m) => m.userId != currentUserId)
        .toList();
    final titleController = TextEditingController();
    final selectedIds = <String>{};
    final result = await showDialog<({String title, List<String> ids})>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('创建小群'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: '小群名称',
                        border: OutlineInputBorder(),
                      ),
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '至少选择两名成员',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: candidates.isEmpty
                          ? const Center(child: Text('暂无其他成员'))
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: candidates.length,
                              itemBuilder: (context, index) {
                                final member = candidates[index];
                                return CheckboxListTile(
                                  value: selectedIds.contains(member.userId),
                                  onChanged: (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        selectedIds.add(member.userId);
                                      } else {
                                        selectedIds.remove(member.userId);
                                      }
                                    });
                                  },
                                  title: Text(
                                    member.displayName.isEmpty
                                        ? '玩家 ${member.userId.substring(0, 4)}'
                                        : member.displayName,
                                  ),
                                  subtitle: Text(member.role),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed:
                      titleController.text.trim().isEmpty ||
                          selectedIds.length < 2
                      ? null
                      : () => Navigator.of(context).pop((
                          title: titleController.text.trim(),
                          ids: selectedIds.toList(),
                        )),
                  child: const Text('创建'),
                ),
              ],
            );
          },
        );
      },
    );
    titleController.dispose();
    if (result == null || !mounted) return;

    final conversation = await controller.createGroupConversation(
      campaignId: campaign.id,
      title: result.title,
      participantIds: result.ids,
    );
    if (!mounted) return;
    if (conversation != null) {
      final character = _primaryCharacter();
      await _openCampaignChat(campaign, character, conversation: conversation);
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text('创建小群失败：${controller.error ?? '未知错误'}')),
      );
    }
  }
}

class _CampaignCreationGuide extends StatefulWidget {
  const _CampaignCreationGuide();

  @override
  State<_CampaignCreationGuide> createState() => _CampaignCreationGuideState();
}

class _CampaignCreationGuideState extends State<_CampaignCreationGuide> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onDraftChanged);
    _descriptionController.addListener(_onDraftChanged);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_onDraftChanged)
      ..dispose();
    _descriptionController
      ..removeListener(_onDraftChanged)
      ..dispose();
    super.dispose();
  }

  void _onDraftChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['基本信息', '规则与资料', '确认创建'];
    return Dialog(
      key: const Key('campaign-creation-guide'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '创建战役',
                      style: Theme.of(context).textTheme.headlineSmall,
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
              LinearProgressIndicator(value: (_step + 1) / 3),
              const SizedBox(height: 12),
              Text(
                '第 ${_step + 1} 步，共 3 步',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(
                titles[_step],
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              Flexible(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: switch (_step) {
                      0 => _buildBasics(),
                      1 => _buildRules(),
                      _ => _buildReview(),
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const Spacer(),
                  if (_step > 0)
                    TextButton(
                      onPressed: () => setState(() => _step -= 1),
                      child: const Text('上一步'),
                    ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _canContinue ? _continue : null,
                    child: Text(_step == 2 ? '创建战役' : '下一步'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasics() {
    return SingleChildScrollView(
      child: Column(
        children: [
          TextField(
            key: const Key('campaign-name-field'),
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '战役名称',
              hintText: '例如：失落矿坑周末团',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: '战役简介（可选）',
              hintText: '团期、风格和玩家需要提前知道的内容',
              border: OutlineInputBorder(),
            ),
            minLines: 3,
            maxLines: 5,
          ),
        ],
      ),
    );
  }

  Widget _buildRules() {
    return ListView(
      shrinkWrap: true,
      children: const [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.auto_stories_outlined),
          title: Text('D&D 2024'),
          subtitle: Text('当前版本仅支持 2024 规则结构'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.inventory_2_outlined),
          title: Text('资料包稍后管理'),
          subtitle: Text('战役创建成功后，DM 可在战役信息页启用并同步自定义条目'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.offline_bolt_outlined),
          title: Text('本地功能保持离线'),
          subtitle: Text('角色、资料库与规则计算继续保存在客户端；聊天室和战役协作连接服务器'),
        ),
      ],
    );
  }

  Widget _buildReview() {
    final description = _descriptionController.text.trim();
    return ListView(
      shrinkWrap: true,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.castle_outlined),
          title: Text(_nameController.text.trim()),
          subtitle: Text(description.isEmpty ? '未填写简介' : description),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.shield_outlined),
          title: Text('你将成为战役 DM'),
          subtitle: Text('其他成员通过邀请码加入后固定为玩家身份'),
        ),
      ],
    );
  }

  bool get _canContinue {
    return _step > 0 || _nameController.text.trim().isNotEmpty;
  }

  void _continue() {
    if (_step < 2) {
      setState(() => _step += 1);
      return;
    }
    Navigator.of(context).pop(
      _CampaignCreationDraft(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
      ),
    );
  }
}

class _CampaignCreationDraft {
  const _CampaignCreationDraft({required this.name, required this.description});

  final String name;
  final String description;
}
