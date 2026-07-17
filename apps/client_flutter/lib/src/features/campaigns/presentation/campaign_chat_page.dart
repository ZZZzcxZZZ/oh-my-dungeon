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
import 'actors/campaign_actor_sheet_page.dart';
import 'campaign_controller.dart';
import 'campaign_center_page.dart';
import 'campaign_detail_page.dart';
import 'chat/campaign_chat_bubble.dart';
import 'chat/chat_avatar.dart';
import 'chat/chat_helpers.dart';
import 'chat/chat_mode_picker.dart';
import 'chat/check_request_sheet.dart';
import 'content/campaign_content_controller.dart';
import 'content/campaign_content_page.dart';
import 'widgets/campaign_actor_quick_sheet.dart';

class CampaignChatPage extends StatefulWidget {
  const CampaignChatPage({
    required this.campaign,
    required this.character,
    required this.campaignController,
    required this.contentRepository,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该消息不在当前加载范围')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('消息已找到, 请手动滚动查看')),
      );
      return;
    }
    // ctx 来自 GlobalKey.currentContext, 不是 widget build context。
    // 转为 Object 避免触发 use_build_context_synchronously lint 误报。
    final ctxAsObject = ctx as Object;
    final pending = _ensureVisibleOf(ctxAsObject as BuildContext);
    await pending;
    if (!mounted) return;
    setState(() => _highlightedMessageId = messageId);
    Future<void>.delayed(const Duration(milliseconds: 800), () {
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
        final memberCount = workspace?.members.length ??
            widget.campaign.memberPreview.length;
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
                    ),
                  ),
                ),
                icon: const Icon(Icons.dashboard_outlined),
              ),
              PopupMenuButton<String>(
                key: const Key('campaign-chat-more-menu'),
                icon: const Icon(Icons.more_vert),
                onSelected: _onGlobalSettingSelected,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'editDetails',
                    child: Text('战役名称、封面和简介'),
                  ),
                  PopupMenuItem(
                    value: 'transferOwnership',
                    child: Text('所有权转移'),
                  ),
                  PopupMenuItem(
                    value: 'archive',
                    child: Text('战役归档'),
                  ),
                  PopupMenuItem(
                    value: 'leave',
                    child: Text('离开战役'),
                  ),
                ],
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
                    final isHighlighted =
                        _highlightedMessageId == message.id;
                    return AnimatedContainer(
                      key: key,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: isHighlighted
                            ? Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.6)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CampaignChatBubble(
                        message: message,
                        onRespondCheckRequest: _canRespondToCheck(message)
                            ? () => _respondToCheckRequest(message)
                            : null,
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

  /// 解析消息头像点击：当消息绑定的 campaignActorId 能在 actorController 中
  /// 找到 active 角色时，返回弹出 CampaignActorQuickSheet 的回调；否则返回
  /// null，头像保持静默（避免点击无 actor 的陌生人头像时出现空弹窗）。
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
    return () => _showActorQuickSheet(actor);
  }

  Future<void> _showActorQuickSheet(CampaignActor actor) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => CampaignActorQuickSheet(
        actor: actor,
        isManager: _canManageCampaign,
        onOpenSheet: widget.actorController == null
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => CampaignActorSheetPage(
                      controller: widget.actorController!,
                      actorId: actor.id,
                    ),
                  ),
                );
              },
      ),
    );
  }

  Future<void> _openCampaignManagement() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CampaignDetailPage(
          controller: widget.campaignController,
          campaignId: widget.campaign.id,
        ),
      ),
    );
  }

  Future<void> _openCampaignContent() async {
    final controller = widget.campaignContentController;
    if (controller == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CampaignContentPage(
          controller: controller,
          campaignId: widget.campaign.id,
          canEdit: _canManageCampaign,
        ),
      ),
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

  /// Spec §全局设置: 右上角更多菜单四项低频操作。
  void _onGlobalSettingSelected(String value) {
    final messenger = ScaffoldMessenger.of(context);
    switch (value) {
      case 'editDetails':
        _openCampaignManagement();
        break;
      case 'transferOwnership':
      case 'archive':
      case 'leave':
        messenger.showSnackBar(
          const SnackBar(content: Text('该功能正在开发中')),
        );
        break;
    }
  }

  Widget _buildInputBar() {
    final draft = _draftIdentity;
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
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Row(
              children: [
                IconButton.filledTonal(
                  key: const Key('campaign-chat-identity'),
                  tooltip: chatText('characterSheet'),
                  onPressed: _showToolPanel,
                  icon: ChatAvatar(
                    name: widget.character?.name ?? '?',
                    avatarUrl: widget.character?.avatarUrl,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 104,
                  child: ChatModePicker(
                    mode: _mode,
                    enabled: !_sending,
                    onChanged: (mode) => setState(() => _mode = mode),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    key: const Key('campaign-chat-input'),
                    controller: _controller,
                    enabled: !_sending,
                    decoration: InputDecoration(
                      hintText: draft != null
                          ? '以 ${draft.displayName} 发言'
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
        ],
      ),
    );
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) return;

    final draft = _draftIdentity;
    setState(() => _sending = true);
    final sent = await widget.campaignController.sendMessage(
      campaignId: widget.campaign.id,
      kind: _mode == ChatMode.act ? 'action' : 'say',
      content: content,
      campaignActorId: draft == null ? _activeSpeakerActorId : null,
      draftActor: draft == null
          ? null
          : <String, Object?>{'displayName': draft.displayName},
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (sent) {
      _controller.clear();
      if (draft != null) {
        // First message of a draft identity creates the temporary actor on
        // the server; refresh workspace context so the new actor shows up.
        _draftIdentity = null;
        await widget.campaignController.loadWorkspaceContext(widget.campaign.id);
      }
    } else if (draft != null) {
      // Spec: failed draft send keeps the draft and shows the spec error.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('临时角色创建失败，消息尚未发送。')),
      );
    }
  }

  /// Spec §输入栏: 当前身份头像取代原有独立 `+` 按钮。点击后打开底部快捷面板，
  /// 包含 11 项工具。工具按成员能力和当前上下文动态出现，界面不显示不可用的
  /// DM 工具。
  Future<void> _showToolPanel() {
    final character = widget.character;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
          children: [
            // 1. 当前身份精确信息 (header)
            ListTile(
              key: const Key('tool-current-identity'),
              leading: ChatAvatar(
                name: character?.name ?? '?',
                avatarUrl: character?.avatarUrl,
              ),
              title: Text(character?.name ?? chatText('unboundCharacter')),
              subtitle: character == null
                  ? null
                  : Text(
                      'HP ${character.currentHp}/${character.maxHp} · AC ${character.armorClass}',
                    ),
              onTap: character == null
                  ? null
                  : () {
                      Navigator.of(sheetContext).pop();
                      _openCharacterSheet();
                    },
            ),
            const Divider(height: 1),
            // 2. 打开角色卡
            ListTile(
              key: const Key('tool-open-character-sheet'),
              leading: const Icon(Icons.badge_outlined),
              title: const Text('打开角色卡'),
              enabled: character != null,
              onTap: character == null
                  ? null
                  : () {
                      Navigator.of(sheetContext).pop();
                      _openCharacterSheet();
                    },
            ),
            // 3. 掷骰
            ListTile(
              key: const Key('tool-roll-dice'),
              leading: const Icon(Icons.casino_outlined),
              title: Text(chatText('rollDice')),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showRollSheet();
              },
            ),
            // 4. 技能检定
            ListTile(
              key: const Key('tool-skill-check'),
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('技能检定'),
              subtitle: _canManageCampaign
                  ? const Text('从战役角色中选择检定项目')
                  : const Text('DM 发起的检定会显示在聊天室'),
              onTap: _canManageCampaign
                  ? () {
                      Navigator.of(sheetContext).pop();
                      _showCheckRequestTargetPicker();
                    }
                  : null,
            ),
            // 5. HP 与状态
            ListTile(
              key: const Key('tool-hp-status'),
              leading: const Icon(Icons.favorite_outline),
              title: const Text('HP 与状态'),
              enabled: character != null,
              onTap: character == null
                  ? null
                  : () {
                      Navigator.of(sheetContext).pop();
                      _openCharacterSheet();
                    },
            ),
            // 6. 资料条目 — Spec §输入栏: 战役资料入口迁移到头像快捷面板。
            // 当 campaignContentController 可用时进入 CampaignContentPage；
            // 否则回退到本地资料库浏览（_showContentLibrary）。
            ListTile(
              key: const Key('tool-content-entries'),
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('资料条目'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                if (widget.campaignContentController != null) {
                  _openCampaignContent();
                } else {
                  _showContentLibrary();
                }
              },
            ),
            // 7. 记录线索 (Phase 5 will implement)
            ListTile(
              key: const Key('tool-record-clue'),
              leading: const Icon(Icons.lightbulb_outline),
              title: const Text('记录线索'),
              subtitle: const Text('敬请期待'),
              enabled: false,
            ),
            // 8. 分享地点 (Phase 5 will implement)
            ListTile(
              key: const Key('tool-share-location'),
              leading: const Icon(Icons.place_outlined),
              title: const Text('分享地点'),
              subtitle: const Text('敬请期待'),
              enabled: false,
            ),
            // 9. 群文件 (Phase 5 will implement)
            ListTile(
              key: const Key('tool-group-files'),
              leading: const Icon(Icons.folder_outlined),
              title: const Text('群文件'),
              subtitle: const Text('敬请期待'),
              enabled: false,
            ),
            // 角色动作 (dynamic — when character has actions and is bound)
            if (_characterActions.isNotEmpty &&
                widget.campaignActorId != null)
              ListTile(
                key: const Key('tool-character-actions'),
                leading: const Icon(Icons.bolt_outlined),
                title: const Text('角色动作'),
                subtitle: Text('${_characterActions.length} 个可用动作'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showCharacterActions();
                },
              ),
            // 10. DM 身份切换 (DM only — opens identity sheet sub-panel)
            if (_canManageCampaign)
              ListTile(
                key: const Key('tool-dm-identity-switch'),
                leading: const Icon(Icons.shield_outlined),
                title: const Text('DM 身份切换'),
                subtitle: const Text('旁白、场外、NPC、怪物、同伴、代管'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showIdentitySheet();
                },
              ),
            // 切换发言身份 (player only — spec §发言身份 玩家: 绑定角色 + 场外)
            // Per spec §输入栏 "工具按成员能力和当前上下文动态出现", this entry
            // appears for players who need to switch between bound character
            // and OOC. DM uses the "DM 身份切换" entry above instead.
            if (!_canManageCampaign)
              ListTile(
                key: const Key('tool-player-identity-switch'),
                leading: const Icon(Icons.shield_outlined),
                title: const Text('切换发言身份'),
                subtitle: const Text('绑定角色、场外'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showIdentitySheet();
                },
              ),
            // 11. 快速临时身份 (DM only — opens draft form)
            if (_canManageCampaign)
              ListTile(
                key: const Key('identity-temporary-entry'),
                leading: const Icon(Icons.person_add_alt_1_outlined),
                title: _draftIdentity != null
                    ? Text('草稿：${_draftIdentity!.displayName}')
                    : const Text('快速临时身份'),
                subtitle: _draftIdentity != null
                    ? const Text('首次发送消息后将自动创建临时身份')
                    : const Text('只输入显示名称即可发言，首次发送时由服务器创建临时角色'),
                trailing: _draftIdentity != null
                    ? IconButton(
                        tooltip: '放弃草稿',
                        onPressed: () {
                          setState(() => _draftIdentity = null);
                          Navigator.of(sheetContext).pop();
                        },
                        icon: const Icon(Icons.close),
                      )
                    : null,
                onTap: _draftIdentity != null
                    ? null
                    : () {
                        Navigator.of(sheetContext).pop();
                        _showDraftIdentityForm();
                      },
              ),
            // DM 控场 (DM only, transitional — Phase 4 Task 4.2 will migrate
            // encounter control to 战役中心 → 队伍 panel per spec)
            if (_canManageCampaign)
              ListTile(
                key: const Key('campaign-dm-control-entry'),
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(chatText('dmControl')),
                subtitle: Text(chatText('dmControlHint')),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showDmControl();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showIdentitySheet() {
    final character = widget.character;
    final workspace = widget.campaignController.workspaceContext;
    final membership = workspace?.membership;
    final currentSpeakerMode = membership?.speakerMode ?? 'boundActor';
    final activeActorId = membership?.activeSpeakerActorId ?? widget.campaignActorId;
    final currentUserId = membership?.userId;

    // Per spec §发言身份 DM, DM speakers are: 旁白/DM, 场外, 常驻 NPC/怪物/同伴,
    // 临时角色, 代管玩家角色. The "绑定角色" entry is player-only and must not
    // appear for DM.
    //
    // Per spec §发言身份 玩家, player speakers are: 绑定角色, 场外 only. Player
    // must not see narrator/temporary/proxy entries.
    final activeActors = (workspace?.actors ?? const <CampaignWorkspaceActor>[])
        .where((actor) => actor.status == 'active')
        .toList(growable: false);

    // DM-owned persistent NPC/怪物/同伴 actors. Per spec these are the DM's
    // own actor pool.
    final dmPersistentActors = activeActors
        .where(
          (actor) =>
              actor.lifecycle != 'temporary' &&
              actor.ownerUserId == currentUserId &&
              (actor.actorType == 'npc' ||
                  actor.actorType == 'monster' ||
                  actor.actorType == 'companion'),
        )
        .toList(growable: false);

    // Player-owned actors the DM can proxy. Per spec §发言身份 DM the DM can
    // "明确开启的玩家角色临时代管" — proxy with explicit opt-in.
    final proxyActors = activeActors
        .where(
          (actor) =>
              actor.ownerUserId != null &&
              actor.ownerUserId != currentUserId &&
              actor.actorType == 'player',
        )
        .toList(growable: false);

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            // Current identity summary at top.
            ListTile(
              leading: ChatAvatar(
                name: character?.name ?? '?',
                avatarUrl: character?.avatarUrl,
              ),
              title: Text(character?.name ?? chatText('unboundCharacter')),
              subtitle: character == null
                  ? null
                  : Text(
                      'HP ${character.currentHp}/${character.maxHp} · AC ${character.armorClass}',
                    ),
              onTap: character == null
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      _openCharacterSheet();
                    },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                '切换身份',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            if (_canManageCampaign) ...[
              ListTile(
                key: const Key('identity-narrator-entry'),
                leading: const Icon(Icons.auto_stories_outlined),
                title: const Text('旁白 / DM'),
                selected: currentSpeakerMode == 'narrator',
                onTap: () => _selectCampaignSpeaker('narrator'),
              ),
              ListTile(
                key: const Key('identity-ooc-entry'),
                leading: const Icon(Icons.forum_outlined),
                title: const Text('场外'),
                selected: currentSpeakerMode == 'ooc',
                onTap: () => _selectCampaignSpeaker('ooc'),
              ),
              if (dmPersistentActors.isNotEmpty) ...[
                _IdentitySectionHeader(label: '常驻 NPC / 怪物 / 同伴'),
                for (final actor in dmPersistentActors)
                  ListTile(
                    key: Key('identity-actor-${actor.id}'),
                    leading: ChatAvatar(
                      name: actor.displayName,
                      avatarUrl: null,
                      healthState: actor.publicHealthState,
                    ),
                    title: Text(actor.displayName),
                    subtitle: Text(_actorTypeLabel(actor.actorType)),
                    selected:
                        currentSpeakerMode == 'actor' && activeActorId == actor.id,
                    onTap: () => _selectCampaignSpeaker('actor', actor.id),
                  ),
              ],
              // Spec §快速临时身份: DM 可以直接在身份切换面板里发起快速临时
              // 身份草稿。该入口同时存在于输入栏工具面板 (identity-temporary-
              // entry), 两处共享同一份 _draftIdentity 状态。
              ListTile(
                key: const Key('identity-quick-temporary-entry'),
                leading: const Icon(Icons.person_add_alt_1_outlined),
                title: _draftIdentity != null
                    ? Text('草稿：${_draftIdentity!.displayName}')
                    : const Text('快速临时身份'),
                subtitle: _draftIdentity != null
                    ? const Text('首次发送消息后将自动创建临时身份')
                    : const Text('只输入显示名称即可发言'),
                trailing: _draftIdentity != null
                    ? IconButton(
                        tooltip: '放弃草稿',
                        onPressed: () {
                          setState(() => _draftIdentity = null);
                        },
                        icon: const Icon(Icons.close),
                      )
                    : null,
                onTap: _draftIdentity != null
                    ? null
                    : () => _showDraftIdentityForm(),
              ),
              if (proxyActors.isNotEmpty) ...[
                _IdentitySectionHeader(label: '代管玩家角色'),
                for (final actor in proxyActors)
                  ListTile(
                    key: Key('identity-actor-${actor.id}'),
                    leading: ChatAvatar(
                      name: actor.displayName,
                      avatarUrl: null,
                      healthState: actor.publicHealthState,
                    ),
                    title: Text(actor.displayName),
                    subtitle: const Text('DM 代管'),
                    selected:
                        currentSpeakerMode == 'actor' && activeActorId == actor.id,
                    onTap: () => _selectCampaignSpeaker('actor', actor.id),
                  ),
              ],
            ] else ...[
              ListTile(
                key: const Key('identity-bound-character-entry'),
                leading: const Icon(Icons.person_outline),
                title: const Text('绑定角色'),
                subtitle: character == null
                    ? const Text('未绑定，前往战役中心绑定角色')
                    : null,
                selected: currentSpeakerMode == 'boundActor',
                onTap: () {
                  if (character == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请前往战役中心绑定角色')),
                    );
                    return;
                  }
                  Navigator.of(context).pop();
                  _openCharacterSheet();
                },
              ),
              ListTile(
                key: const Key('identity-ooc-entry'),
                leading: const Icon(Icons.forum_outlined),
                title: const Text('场外'),
                selected: currentSpeakerMode == 'ooc',
                onTap: () => _selectCampaignSpeaker('ooc'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showDraftIdentityForm() {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _DraftIdentityFormSheet(
        onConfirm: (name) {
          setState(() => _draftIdentity = _TemporaryIdentityDraft(displayName: name));
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  String? get _activeSpeakerActorId =>
      widget.campaignController.workspaceContext?.membership.activeSpeakerActorId ??
      widget.campaignActorId;

  Future<void> _selectCampaignSpeaker(String speakerMode, [String? actorId]) async {
    final updated = await widget.campaignController.updateSpeaker(
      campaignId: widget.campaign.id,
      speakerMode: speakerMode,
      actorId: actorId,
    );
    if (!mounted) return;
    if (updated) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.campaignController.workspaceContextError ?? '切换发言身份失败'),
        ),
      );
    }
  }

  Future<void> _showDmControl() {
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
                  chatText('dmControl'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(chatText('dmControlDescription')),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: Text(chatText('encounterControl')),
                  subtitle: Text(chatText('encounterControlHint')),
                ),
                ListTile(
                  leading: const Icon(Icons.group_outlined),
                  title: Text(chatText('memberStatus')),
                  subtitle: Text(chatText('memberStatusHint')),
                ),
              ],
            ),
          ),
        );
      },
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
    final actions = widget.character?.dataMap['actions'];
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
      campaignActorId: widget.campaignActorId,
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
        campaignActorId: widget.campaignActorId,
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
                          DropdownMenuEntry(value: 'all', label: chatText('all')),
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

  Future<void> _openContentEntry(String entryKey) async {
    Navigator.of(context).pop();
    final controller = ContentLibraryController(
      repository: widget.contentRepository,
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ContentDetailPage(
          entryKey: entryKey,
          controller: controller,
          onOpenEntry: _openContentEntry,
          onImportRequested: () {},
        ),
      ),
    );
    controller.dispose();
  }

  void _openCharacterSheet() {
    // Spec §输入栏: 关闭工具 sheet / 身份 sheet 由调用方负责, helper 不应自行 pop。
    final character = widget.character;
    if (character == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(chatText('noBoundCharacter'))));
      return;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CharacterDetailPage(character: character),
      ),
    );
  }

  Future<void> _showCheckRequestTargetPicker() async {
    final actors = (widget.actorController?.actors ?? const <CampaignActor>[])
        .where((actor) => actor.status == 'active' && actor.actorType == 'player')
        .toList(growable: false);
    if (actors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前没有可请求检定的玩家角色')),
      );
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
              title: Text('选择检定目标'),
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
    if (draft == null || !mounted) return;

    final name = actor.sheet['name']?.toString().trim();
    final actorName = name == null || name.isEmpty ? '该角色' : name;
    final eventData = <String, Object?>{
      'targetActorId': actor.id,
      'checkType': draft.type,
      'checkKey': draft.key,
      'label': draft.label,
      if (draft.dc != null) 'dc': draft.dc,
      'rollMode': draft.rollMode,
    };
    final sent = await widget.campaignController.sendMessage(
      campaignId: widget.campaign.id,
      kind: 'checkRequest',
      content: '要求 $actorName 进行${draft.label}',
      eventData: eventData,
    );
    if (!mounted || sent) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(chatText('sendFailed'))));
  }

  bool _canRespondToCheck(CampaignChatMessage message) {
    return message.kind == 'checkRequest' &&
        widget.campaignActorId != null &&
        message.eventData?['targetActorId'] == widget.campaignActorId &&
        widget.character != null;
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
            Text(
              '快速临时身份',
              style: Theme.of(context).textTheme.titleLarge,
            ),
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

/// Section header inside the identity switching sheet.
class _IdentitySectionHeader extends StatelessWidget {
  const _IdentitySectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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

/// Display label for a CampaignActor.actorType value.
String _actorTypeLabel(String actorType) => switch (actorType) {
      'npc' => 'NPC',
      'monster' => '怪物',
      'companion' => '同伴',
      'player' => '玩家角色',
      _ => actorType,
    };
