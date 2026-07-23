import 'package:flutter/material.dart';

import '../../app_preferences/presentation/app_preferences_controller.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../characters/domain/character.dart';
import '../../characters/presentation/character_controller.dart';
import '../../client_mode/domain/client_mode.dart';
import '../../content/data/local/content_repository.dart';
import '../../encounters/presentation/encounter_controller.dart';
import '../../../core/dice/dice_roller.dart';
import '../../server_home/domain/active_server_session.dart';
import '../domain/campaign.dart';
import '../domain/campaign_conversation.dart';
import 'actors/campaign_actor_controller.dart';
import 'campaign_chat_page.dart';
import 'campaign_controller.dart';
import 'content/campaign_content_controller.dart';
import 'conversation_controller.dart';

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
    this.actorController,
    this.encounterController,
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
  final CampaignActorController? actorController;
  final EncounterController? encounterController;
  final ConversationController? conversationController;

  @override
  State<CampaignsTabPage> createState() => _CampaignsTabPageState();
}

class _CampaignsTabPageState extends State<CampaignsTabPage> {
  /// Spec §客户端工作模式: 模式提示每个战役每会话只显示一次。已提示过
  /// 的战役 ID 加入此集合后不再弹窗，避免反复打扰用户。
  final Set<String> _modePromptShownCampaignIds = <String>{};

  /// Plan 2026-07-23 task 5.1: 同一时间只允许一个卡片展开（accordion）。
  /// null 表示全部收起。
  String? _expandedCampaignId;

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
        // 下隐藏 FAB，仅保留加入/刷新入口；owner 在 Player 模式进入战役
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
              IconButton(
                tooltip: '刷新战役',
                onPressed: _maybeLoadCampaigns,
                icon: const Icon(Icons.refresh),
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
        final isOwner = campaign.ownerId == currentUserId;
        final character = _primaryCharacter();
        // Plan 2026-07-23 task 5.3: conversations are scoped to the active
        // campaign in the conversation controller. When the controller tracks
        // a different campaign, fall back to an empty list (the card still
        // shows the main entry from Task 5.1).
        final conversationController = widget.conversationController;
        final conversations = conversationController != null &&
                conversationController.activeCampaignId == campaign.id
            ? conversationController.conversations
            : const <CampaignConversation>[];
        return _CampaignChatListItem(
          campaign: campaign,
          character: character,
          isOwner: isOwner,
          compact: compact,
          isExpanded: _expandedCampaignId == campaign.id,
          conversations: conversations,
          onExpandToggle: () {
            // Load conversations lazily when the card is first expanded so
            // the list shows direct/group entries alongside the main room.
            if (widget.conversationController != null &&
                widget.conversationController!.activeCampaignId !=
                    campaign.id) {
              widget.conversationController!.loadConversations(campaign.id);
            }
            setState(() {
              // Toggle this card; if another card was expanded, it collapses.
              _expandedCampaignId =
                  _expandedCampaignId == campaign.id ? null : campaign.id;
            });
          },
          onTap: () => _openCampaignChat(campaign, character),
          onConversationTap: (conversation) =>
              _openCampaignChat(campaign, character, conversation: conversation),
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
    // Plan 2026-07-23 task 5.3: pre-select the tapped conversation so the
    // chat page scopes messages to it on load.
    if (conversation != null && widget.conversationController != null) {
      widget.conversationController!
          .setActiveConversation(conversation.isMain ? null : conversation.id);
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
          actorController: widget.actorController,
          encounterController: widget.encounterController,
          appPreferencesController: widget.appPreferencesController,
          campaignActorId: null,
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

    final membership = campaign.memberPreview
        .where((m) => m.userId == currentUserId)
        .firstOrNull;
    final isOwnerOrDm =
        campaign.ownerId == currentUserId ||
        membership?.role == 'owner' ||
        membership?.role == 'dm';
    final currentMode = widget.modeController.mode;

    // Spec §客户端工作模式: owner/dm 在 Player 模式提示一键切换 DM 模式。
    if (isOwnerOrDm && currentMode == ClientMode.player) {
      _modePromptShownCampaignIds.add(campaign.id);
      final switchToDm = await _showSwitchToDmDialog(campaign);
      if (switchToDm && mounted) {
        await widget.modeController.setMode(ClientMode.dungeonMaster);
      } else {
        _modePromptShownCampaignIds.remove(campaign.id);
      }
      return switchToDm;
    }

    // Spec §客户端工作模式: 普通玩家即使切换到 DM 模式，仍然只拥有
    // 该战役的 player 权限。提示用户当前模式不影响其权限。
    if (!isOwnerOrDm && currentMode == ClientMode.dungeonMaster) {
      _modePromptShownCampaignIds.add(campaign.id);
      await _showPlayerOnlyDialog(campaign);
      return true;
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

  Future<void> _showPlayerOnlyDialog(Campaign campaign) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        key: const Key('mode-player-only-dialog'),
        title: const Text('以玩家身份参与'),
        content: Text(
          '你在战役「${campaign.name}」中是玩家。主持人模式是应用偏好，'
          '不会改变你在该战役中的权限；只有战役主持人才能使用 DM 工具。',
        ),
        actions: [
          FilledButton(
            key: const Key('mode-player-only-ack'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
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
      messenger.showSnackBar(
        const SnackBar(content: Text('暂无其他成员可发起私聊')),
      );
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
        SnackBar(
          content: Text('创建私聊失败：${controller.error ?? '未知错误'}'),
        ),
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
                    ),
                    const SizedBox(height: 12),
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
                  onPressed: titleController.text.trim().isEmpty
                      ? null
                      : () => Navigator.of(context).pop(
                            (
                              title: titleController.text.trim(),
                              ids: selectedIds.toList(),
                            ),
                          ),
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
        SnackBar(
          content: Text('创建小群失败：${controller.error ?? '未知错误'}'),
        ),
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

/// 群聊式战役列表条目。
///
/// 左侧是绑定角色头像（若有）叠放战役成员头像缩略；右侧是战役名 + 时间，
/// 副标题为最近消息摘要或成员/系统占位。整条可点击进入战役聊天室。
class _CampaignChatListItem extends StatelessWidget {
  const _CampaignChatListItem({
    required this.campaign,
    required this.character,
    required this.isOwner,
    required this.compact,
    required this.isExpanded,
    required this.conversations,
    required this.onExpandToggle,
    required this.onTap,
    required this.onConversationTap,
    required this.onCreateDirect,
    required this.onCreateGroup,
  });

  final Campaign campaign;
  final CharacterSheet? character;
  final bool isOwner;
  final bool compact;
  final bool isExpanded;
  final List<CampaignConversation> conversations;
  final VoidCallback onExpandToggle;
  final VoidCallback onTap;
  final ValueChanged<CampaignConversation> onConversationTap;
  final VoidCallback onCreateDirect;
  final VoidCallback onCreateGroup;

  static const _memberAvatarOverlap = 14.0;
  static const _memberAvatarSize = 22.0;
  static const _memberAvatarMax = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastMessage = campaign.lastMessage;
    final memberPreview = campaign.memberPreview;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 6 : 10,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Collapsed row — always visible.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLeading(context),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(theme),
                      const SizedBox(height: 4),
                      _buildSubtitle(theme, lastMessage, memberPreview),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildTrailing(theme, lastMessage),
                // Plan 2026-07-23 task 5.1: expand/collapse chevron.
                IconButton(
                  key: const Key('campaign-card-expand-toggle'),
                  icon: Icon(
                    isExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 22,
                  ),
                  tooltip: isExpanded ? '收起' : '展开',
                  onPressed: onExpandToggle,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
            // Plan 2026-07-23 task 5.1: expanded content with smooth size
            // animation. AnimatedSize handles the reveal/collapse transition.
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: isExpanded
                  ? _buildExpandedContent(theme)
                  : const SizedBox(width: double.infinity, height: 0),
            ),
          ],
        ),
      ),
    );
  }

  /// Expanded content: description, member count, unread summary, the pinned
  /// main chat entry, and any direct/group conversations the user can see.
  /// Plan 2026-07-23 task 5.1 + task 5.3.
  Widget _buildExpandedContent(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final memberCount = campaign.memberPreview.length;
    final mainConversation = conversations.where((c) => c.isMain).toList();
    final directConversations = conversations
        .where((c) => c.kind == 'direct' && !c.isArchived)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final groupConversations = conversations
        .where((c) => c.kind == 'group' && !c.isArchived)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final mainConversationObj =
        mainConversation.isNotEmpty ? mainConversation.first : null;
    final directCount = directConversations.length;
    final groupCount = groupConversations.length;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (campaign.description.isNotEmpty)
            Text(
              campaign.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (memberCount > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.group_outlined,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$memberCount 位成员',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              if (campaign.unreadCount > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mark_chat_unread_outlined,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '未读 ${campaign.unreadCount}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Pinned main chat entry — primary action.
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('campaign-card-main-chat-entry'),
              onPressed: mainConversationObj == null
                  ? onTap
                  : () => onConversationTap(mainConversationObj),
              icon: const Icon(Icons.push_pin_outlined, size: 18),
              label: const Text('主聊天室'),
            ),
          ),
          if (directCount > 0) ...[
            const SizedBox(height: 12),
            _ConversationSectionHeader(
              icon: Icons.person_outline,
              label: '私聊 ($directCount)',
            ),
            ...directConversations.map(
              (c) => _ConversationRow(
                conversation: c,
                onTap: () => onConversationTap(c),
              ),
            ),
          ],
          if (groupCount > 0) ...[
            const SizedBox(height: 12),
            _ConversationSectionHeader(
              icon: Icons.groups_outlined,
              label: '小群 ($groupCount)',
            ),
            ...groupConversations.map(
              (c) => _ConversationRow(
                conversation: c,
                onTap: () => onConversationTap(c),
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Secondary entries: create private chat / create group chat.
          Row(
            children: [
              Expanded(
                child: _SecondaryEntryButton(
                  icon: Icons.person_add_alt_1_outlined,
                  label: '发起私聊',
                  countText: directCount == 0 ? '0' : '$directCount',
                  onPressed: onCreateDirect,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SecondaryEntryButton(
                  icon: Icons.group_add_outlined,
                  label: '创建小群',
                  countText: groupCount == 0 ? '0' : '$groupCount',
                  onPressed: onCreateGroup,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeading(BuildContext context) {
    final character = this.character;
    final avatarUrl = character?.avatarUrl?.trim();
    final hasCharacterAvatar = character != null;
    final leadingAvatar = hasCharacterAvatar
        ? CircleAvatar(
            radius: 22,
            backgroundImage: avatarUrl == null || avatarUrl.isEmpty
                ? null
                : NetworkImage(avatarUrl),
            child: avatarUrl == null || avatarUrl.isEmpty
                ? Text(_avatarText(character.name))
                : null,
          )
        : const CircleAvatar(radius: 22, child: Icon(Icons.castle_outlined));

    final extraMembers = campaign.memberPreview
        .where((m) => m.userId != character?.id)
        .take(_memberAvatarMax)
        .toList();
    if (extraMembers.isEmpty) {
      return leadingAvatar;
    }

    return SizedBox(
      width: 44 + extraMembers.length * _memberAvatarOverlap.toDouble(),
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ...extraMembers.asMap().entries.map((entry) {
            final index = entry.key;
            final member = entry.value;
            final left = 22 + index * _memberAvatarOverlap;
            return Positioned(
              left: left,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: CircleAvatar(
                  radius: _memberAvatarSize / 2,
                  backgroundColor: Colors.grey.shade400,
                  child: Text(
                    _avatarText(member.displayName),
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
              ),
            );
          }),
          leadingAvatar,
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Text(
            campaign.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (isOwner)
          Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '主持人',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSubtitle(
    ThemeData theme,
    CampaignChatMessage? lastMessage,
    List<CampaignMemberPreview> memberPreview,
  ) {
    if (lastMessage != null) {
      final prefix = lastMessage.displayName.isEmpty
          ? ''
          : '${lastMessage.displayName}: ';
      final content = lastMessage.kind == 'action'
          ? '* ${lastMessage.content}'
          : lastMessage.content;
      return Text(
        '$prefix$content',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final memberCount = memberPreview.length;
    final summary = memberCount == 0
        ? campaign.description.isEmpty
              ? campaign.system
              : campaign.description
        : '$memberCount 位成员';
    return Text(
      summary,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildTrailing(ThemeData theme, CampaignChatMessage? lastMessage) {
    final timeText = _formatListTime(lastMessage?.createdAt);
    if (timeText == null && campaign.unreadCount == 0) {
      return const SizedBox(width: 0);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (timeText != null)
          Text(
            timeText,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (campaign.unreadCount > 0) ...[
          const SizedBox(height: 4),
          Badge(
            label: Text(
              campaign.unreadCount > 99 ? '99+' : '${campaign.unreadCount}',
            ),
          ),
        ],
      ],
    );
  }
}

/// Secondary entry button (private chat / group chat) in the expanded card.
/// Shows an icon + label + count badge. Plan 2026-07-23 task 5.1.
class _SecondaryEntryButton extends StatelessWidget {
  const _SecondaryEntryButton({
    required this.icon,
    required this.label,
    required this.countText,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String countText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              countText,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Plan 2026-07-23 task 5.3: section header for direct/group conversation
/// groups inside the expanded card.
class _ConversationSectionHeader extends StatelessWidget {
  const _ConversationSectionHeader({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Plan 2026-07-23 task 5.3: a single conversation row inside the expanded
/// card. Shows the conversation title (or a fallback), the last message
/// preview, time, and an unread badge. Tapping opens that conversation.
class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.conversation,
    required this.onTap,
  });

  final CampaignConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final lastMessage = conversation.lastMessage;
    final lastMessageText = lastMessage == null
        ? '暂无消息'
        : lastMessage.kind == 'action'
            ? '* ${lastMessage.content}'
            : lastMessage.content;
    final title = conversation.kind == 'group'
        ? (conversation.title.isEmpty ? '未命名小群' : conversation.title)
        : (conversation.title.isEmpty ? '私聊' : conversation.title);
    final timeText = _formatListTime(lastMessage?.createdAt ?? conversation.updatedAt);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: colorScheme.secondaryContainer,
              child: Icon(
                conversation.kind == 'group'
                    ? Icons.groups_outlined
                    : Icons.person_outline,
                size: 16,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    lastMessageText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (timeText != null)
                  Text(
                    timeText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (conversation.unreadCount > 0) ...[
                  const SizedBox(height: 2),
                  Badge(
                    label: Text(
                      conversation.unreadCount > 99
                          ? '99+'
                          : '${conversation.unreadCount}',
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _avatarText(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '?';
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}

String? _formatListTime(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final dt = DateTime.tryParse(iso);
  if (dt == null) return null;
  final local = dt.toLocal();
  final now = DateTime.now();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
  return '${local.month.toString().padLeft(2, '0')}/'
      '${local.day.toString().padLeft(2, '0')}';
}
