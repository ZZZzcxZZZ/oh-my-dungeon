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
import 'actors/campaign_actor_controller.dart';
import 'campaign_chat_page.dart';
import 'campaign_controller.dart';
import 'content/campaign_content_controller.dart';

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

  @override
  State<CampaignsTabPage> createState() => _CampaignsTabPageState();
}

class _CampaignsTabPageState extends State<CampaignsTabPage> {
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
      ]),
      builder: (context, _) {
        if (!widget.session.isConfigured) {
          return _buildOfflinePrompt(context);
        }
        if (!widget.authController.isLoggedIn) {
          return _buildLoginPrompt(context);
        }

        final campaigns = widget.campaignController.campaigns;
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
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'create_campaign',
            onPressed: _showCreateDialog,
            icon: const Icon(Icons.add),
            label: const Text('创建战役'),
          ),
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('暂无战役\n点击右下角创建或加入', textAlign: TextAlign.center),
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
        return _CampaignChatListItem(
          campaign: campaign,
          character: character,
          isOwner: isOwner,
          compact: compact,
          onTap: () => _openCampaignChat(campaign, character),
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
    CharacterSheet? character,
  ) async {
    await widget.onCampaignOpened?.call(campaign.id);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => CampaignChatPage(
          campaign: campaign,
          character: character,
          campaignController: widget.campaignController,
          contentRepository: widget.contentRepository,
          campaignContentController: widget.campaignContentController,
          actorController: widget.actorController,
          isDm: campaign.ownerId == widget.authController.user?.id,
          campaignActorId: null,
          diceRoller: widget.diceRoller,
        ),
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
    required this.onTap,
  });

  final Campaign campaign;
  final CharacterSheet? character;
  final bool isOwner;
  final bool compact;
  final VoidCallback onTap;

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
        child: Row(
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
          ],
        ),
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
            label: Text(campaign.unreadCount > 99 ? '99+' : '${campaign.unreadCount}'),
          ),
        ],
      ],
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
