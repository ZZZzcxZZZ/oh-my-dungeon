import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/campaign.dart';
import '../../domain/campaign_actor.dart';
import '../widgets/campaign_avatar.dart';
import '../widgets/campaign_actor_quick_sheet.dart';
import '../widgets/campaign_invite_tile.dart';
import '../widgets/invite_share.dart';

/// Team panel: lists campaign members with their bound actor avatars and
/// opens the quick sheet on tap.
///
/// Spec §队伍 / §完整管理: 邀请和管理成员在 `战役中心 → 队伍`，DM 就地操作。
/// 当 `isManager` 为 true 时：
/// - 顶部显示已有邀请码列表（[invites]）+ "邀请成员"按钮（[onCreateInvite]）。
/// - 顶部显示"创建常驻角色"按钮（[onCreatePersistentActor]）。
/// - 底部显示"DM 角色管理"区块，列出 DM 创建的 NPC/怪物/同伴，支持
///   转为常驻（[onConvertToPersistent]）、切换为当前发言身份
///   （[onSetActiveSpeaker]）和批量归档（[onBatchArchive]）。
class CampaignTeamPanel extends StatefulWidget {
  const CampaignTeamPanel({
    required this.members,
    required this.actors,
    required this.isManager,
    this.invites = const [],
    this.onCreateInvite,
    this.campaignName,
    this.serverUrl,
    this.onCreatePersistentActor,
    this.onConvertToPersistent,
    this.onBatchArchive,
    this.onSetActiveSpeaker,
    this.activeSpeakerActorId,
    super.key,
  });

  final List<CampaignMemberPreview> members;
  final List<CampaignActor> actors;
  final bool isManager;

  /// Spec §队伍: 已有邀请码列表。DM 在队伍面板就地查看和分享，
  /// 不必绕到战役详情页。
  final List<CampaignInvite> invites;

  /// 创建邀请码的回调。仅 DM 调用；返回邀请码对象或 null（失败时）。
  final Future<CampaignInvite?> Function()? onCreateInvite;

  /// 战役名称，用于格式化分享文本。
  final String? campaignName;

  /// 服务器地址，用于格式化分享文本。
  final String? serverUrl;

  /// Spec §DM 角色生命周期: DM 创建常驻 NPC/怪物/同伴的回调。
  /// 仅 `isManager` 为 true 时显示入口；为 null 时不显示。
  /// 返回 null 表示成功，非 null 字符串表示错误消息。
  final Future<String?> Function({
    required String actorType,
    required String displayName,
    int? maxHp,
    String? avatarUrl,
  })? onCreatePersistentActor;

  /// Spec §完整管理: 转为常驻 — DM 把 temporary 角色升级为 persistent。
  /// 返回 null 表示成功，非 null 字符串表示错误消息。
  final Future<String?> Function({required CampaignActor actor})?
      onConvertToPersistent;

  /// Spec §完整管理: 单个或批量归档 — DM 选中多个角色后一键归档。
  /// 返回 null 表示成功，非 null 字符串表示错误消息。
  final Future<String?> Function({required List<String> actorIds})?
      onBatchArchive;

  /// Spec §完整管理: 切换为当前发言身份 — DM 把发言身份切到指定 actor。
  /// 返回 null 表示成功，非 null 字符串表示错误消息。
  final Future<String?> Function({required CampaignActor actor})?
      onSetActiveSpeaker;

  /// 当前发言身份 actorId，用于高亮"正在使用"的 actor。
  final String? activeSpeakerActorId;

  @override
  State<CampaignTeamPanel> createState() => _CampaignTeamPanelState();
}

class _CampaignTeamPanelState extends State<CampaignTeamPanel> {
  /// Spec §完整管理: 多选模式状态。开启后每个 DM 角色显示复选框，
  /// 底部出现"批量归档"按钮。关闭后恢复单条管理模式。
  bool _selectMode = false;
  final Set<String> _selectedActorIds = <String>{};

  /// DM 管理的角色：ownerUserId 为空且 actorType 不是 player（即 NPC/怪物/同伴）。
  /// 已归档的角色不进入管理列表。
  List<CampaignActor> get _managedActors => widget.actors
      .where(
        (actor) =>
            actor.ownerUserId == null &&
            actor.actorType != 'player' &&
            actor.status != 'archived',
      )
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final hasInviteHeader = widget.isManager && widget.onCreateInvite != null;
    final hasCreateActorHeader =
        widget.isManager && widget.onCreatePersistentActor != null;
    final hasInviteList =
        widget.isManager && widget.invites.isNotEmpty;
    final headerCount =
        (hasInviteHeader ? 1 : 0) +
        (hasCreateActorHeader ? 1 : 0) +
        (hasInviteList ? 1 : 0);
    final managedActors = _managedActors;
    final showManagedSection =
        widget.isManager && managedActors.isNotEmpty;

    return KeyedSubtree(
      key: widget.key ?? const Key('campaign-team-panel'),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount:
            widget.members.length + headerCount + (showManagedSection ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          var slot = 0;
          if (hasInviteHeader && index == slot) {
            return _InviteButton(
              campaignName: widget.campaignName,
              serverUrl: widget.serverUrl,
              onCreateInvite: widget.onCreateInvite!,
            );
          }
          if (hasInviteHeader) slot += 1;
          if (hasInviteList && index == slot) {
            return _InviteListSection(
              invites: widget.invites,
              campaignName: widget.campaignName,
              serverUrl: widget.serverUrl,
            );
          }
          if (hasInviteList) slot += 1;
          if (hasCreateActorHeader && index == slot) {
            return _CreatePersistentActorButton(
              onCreatePersistentActor: widget.onCreatePersistentActor!,
            );
          }
          if (hasCreateActorHeader) slot += 1;
          if (index < slot + widget.members.length) {
            final memberIndex = index - slot;
            final member = widget.members[memberIndex];
            return _buildMemberTile(member);
          }
          // Last slot: DM 角色管理 section.
          return _buildManagedSection(managedActors);
        },
      ),
    );
  }

  Widget _buildMemberTile(CampaignMemberPreview member) {
    final actor = widget.actors
        .where((item) => item.ownerUserId == member.userId)
        .firstOrNull;
    final name = actor?.sheet['name']?.toString().trim();
    return ListTile(
      onTap:
          actor == null ? null : () => _showQuickSheet(context, actor),
      leading: CampaignAvatar(
        initials: (name?.isNotEmpty ?? false) ? name! : member.displayName,
        imageUrl: actor?.sheet['avatarUrl'] as String?,
        health: CampaignAvatar.healthFromHp(
          actor?.sheet['currentHp'] as num?,
          actor?.sheet['maxHp'] as num?,
        ),
        size: 40,
      ),
      title: Text(member.displayName),
      subtitle: Text(
        name?.isNotEmpty ?? false ? name! : _roleLabel(member.role),
      ),
      trailing: actor == null ? null : const Icon(Icons.chevron_right),
    );
  }

  /// Spec §完整管理: DM 角色管理区块。列出 NPC/怪物/同伴，支持：
  /// - 临时角色显示"转为常驻"按钮（[onConvertToPersistent]）
  /// - "管理"切换进入多选模式，显示"批量归档"按钮（[onBatchArchive]）
  Widget _buildManagedSection(List<CampaignActor> managedActors) {
    return Card(
      key: const Key('team-managed-section'),
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'DM 角色管理',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (_selectMode && _selectedActorIds.isNotEmpty)
                  FilledButton.tonalIcon(
                    key: const Key('team-batch-archive-button'),
                    onPressed: _onBatchArchive,
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('批量归档'),
                  ),
                IconButton(
                  key: const Key('team-managed-toggle-select'),
                  onPressed: () => setState(() {
                    _selectMode = !_selectMode;
                    if (!_selectMode) _selectedActorIds.clear();
                  }),
                  icon: Icon(_selectMode ? Icons.close : Icons.checklist),
                  tooltip: _selectMode ? '退出管理' : '管理',
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final actor in managedActors)
              _buildManagedActorTile(actor),
          ],
        ),
      ),
    );
  }

  Widget _buildManagedActorTile(CampaignActor actor) {
    final name = actor.sheet['name']?.toString().trim() ?? '未命名';
    final isTemporary = actor.lifecycle == 'temporary';
    final isSelected = _selectedActorIds.contains(actor.id);
    final isActive =
        widget.activeSpeakerActorId == actor.id;
    return ListTile(
      dense: true,
      leading: _selectMode
          ? Checkbox(
              key: Key('team-actor-checkbox-${actor.id}'),
              value: isSelected,
              onChanged: (value) => setState(() {
                if (value == true) {
                  _selectedActorIds.add(actor.id);
                } else {
                  _selectedActorIds.remove(actor.id);
                }
              }),
            )
          : CampaignAvatar(
              initials: name,
              imageUrl: actor.sheet['avatarUrl'] as String?,
              size: 32,
            ),
      title: Text(name),
      subtitle: Row(
        children: [
          _ActorTypeBadge(actorType: actor.actorType),
          const SizedBox(width: 6),
          if (isTemporary) const _LifecycleBadge(lifecycle: 'temporary'),
          if (isActive)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _ActiveSpeakerBadge(),
            ),
        ],
      ),
      trailing: _selectMode
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onSetActiveSpeaker != null && !isActive)
                  IconButton(
                    key: Key('team-set-active-speaker-${actor.id}'),
                    tooltip: '切换为当前发言身份',
                    onPressed: () => _onSetActiveSpeaker(actor),
                    icon: const Icon(Icons.record_voice_over_outlined),
                  ),
                if (isTemporary && widget.onConvertToPersistent != null)
                  IconButton(
                    key: Key('team-convert-persistent-${actor.id}'),
                    tooltip: '转为常驻',
                    onPressed: () => _onConvertToPersistent(actor),
                    icon: const Icon(Icons.push_pin_outlined),
                  ),
              ],
            ),
    );
  }

  Future<void> _onSetActiveSpeaker(CampaignActor actor) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await widget.onSetActiveSpeaker!(actor: actor);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? '已切换发言身份为「${actor.sheet['name'] ?? '未命名'}」')),
    );
  }

  Future<void> _onConvertToPersistent(CampaignActor actor) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await widget.onConvertToPersistent!(actor: actor);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? '已转为常驻角色')),
    );
  }

  Future<void> _onBatchArchive() async {
    final messenger = ScaffoldMessenger.of(context);
    final ids = List<String>.of(_selectedActorIds);
    final error = await widget.onBatchArchive!(actorIds: ids);
    if (!mounted) return;
    if (error == null) {
      setState(() {
        _selectMode = false;
        _selectedActorIds.clear();
      });
    }
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? '已归档 ${ids.length} 个角色')),
    );
  }

  void _showQuickSheet(BuildContext context, CampaignActor actor) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => CampaignActorQuickSheet(
        actor: actor,
        isManager: widget.isManager,
      ),
    );
  }
}

class _ActorTypeBadge extends StatelessWidget {
  const _ActorTypeBadge({required this.actorType});

  final String actorType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = switch (actorType) {
      'npc' => 'NPC',
      'monster' => '怪物',
      'companion' => '同伴',
      'unclaimed' => '未认领',
      _ => actorType,
    };
    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _LifecycleBadge extends StatelessWidget {
  const _LifecycleBadge({required this.lifecycle});

  final String lifecycle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (lifecycle != 'temporary') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '临时',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _ActiveSpeakerBadge extends StatelessWidget {
  const _ActiveSpeakerBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '使用中',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// Spec §队伍: 已有邀请码列表区块。DM 在队伍面板就地查看和分享所有邀请码，
/// 不必绕到战役详情页。复用 [CampaignInviteTile] 渲染每条邀请码。
class _InviteListSection extends StatelessWidget {
  const _InviteListSection({
    required this.invites,
    required this.campaignName,
    required this.serverUrl,
  });

  final List<CampaignInvite> invites;
  final String? campaignName;
  final String? serverUrl;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('team-invite-list-section'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '邀请码',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final invite in invites)
              CampaignInviteTile(
                invite: invite,
                onCopy: () {
                  Clipboard.setData(ClipboardData(text: invite.code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('邀请码已复制')),
                  );
                },
                onShare: () async {
                  await copyInviteToClipboard(
                    code: invite.code,
                    campaignName: campaignName,
                    serverUrl: serverUrl,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('分享文本已复制，可粘贴到聊天工具')),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _InviteButton extends StatelessWidget {
  const _InviteButton({
    required this.campaignName,
    required this.serverUrl,
    required this.onCreateInvite,
  });

  final String? campaignName;
  final String? serverUrl;
  final Future<CampaignInvite?> Function() onCreateInvite;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FilledButton.tonalIcon(
        key: const Key('team-invite-button'),
        onPressed: () => _createAndShowInvite(context),
        icon: const Icon(Icons.person_add),
        label: const Text('邀请成员'),
      ),
    );
  }

  Future<void> _createAndShowInvite(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final invite = await onCreateInvite();
    if (!context.mounted) return;
    if (invite == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('创建邀请码失败')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('邀请码已创建'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('将以下邀请码分享给玩家：'),
              const SizedBox(height: 16),
              SelectableText(
                invite.code,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: invite.code));
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('邀请码已复制')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('复制'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await copyInviteToClipboard(
                  code: invite.code,
                  campaignName: campaignName,
                  serverUrl: serverUrl,
                );
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('分享文本已复制，可粘贴到聊天工具')),
                );
              },
              icon: const Icon(Icons.share),
              label: const Text('分享'),
            ),
          ],
        );
      },
    );
  }
}

String _roleLabel(String role) => switch (role) {
      'owner' || 'dm' => '地下城主',
      'spectator' => '旁观者',
      _ => '玩家',
    };

/// Spec §DM 角色生命周期: DM 创建常驻 NPC/怪物/同伴入口。
/// 点击后弹出表单：显示名称、actorType 选择、初始 HP，调用
/// [onCreatePersistentActor] 提交到 `/actors` 端点（lifecycle=persistent）。
class _CreatePersistentActorButton extends StatelessWidget {
  const _CreatePersistentActorButton({required this.onCreatePersistentActor});

  final Future<String?> Function({
    required String actorType,
    required String displayName,
    int? maxHp,
    String? avatarUrl,
  }) onCreatePersistentActor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FilledButton.tonalIcon(
        key: const Key('team-create-persistent-actor-button'),
        onPressed: () => _showCreateForm(context),
        icon: const Icon(Icons.smart_toy_outlined),
        label: const Text('创建常驻角色'),
      ),
    );
  }

  Future<void> _showCreateForm(BuildContext context) async {
    final nameController = TextEditingController();
    final hpController = TextEditingController();
    var actorType = 'npc';
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('创建常驻角色'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: const Text('NPC'),
                        selected: actorType == 'npc',
                        onSelected: (_) =>
                            setDialogState(() => actorType = 'npc'),
                      ),
                      ChoiceChip(
                        label: const Text('怪物'),
                        selected: actorType == 'monster',
                        onSelected: (_) =>
                            setDialogState(() => actorType = 'monster'),
                      ),
                      ChoiceChip(
                        label: const Text('同伴'),
                        selected: actorType == 'companion',
                        onSelected: (_) =>
                            setDialogState(() => actorType = 'companion'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: '显示名称'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '请输入名称'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: hpController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '初始最大 HP（可选）'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      nameController.dispose();
      hpController.dispose();
      return;
    }

    if (!context.mounted) {
      nameController.dispose();
      hpController.dispose();
      return;
    }
    final messenger = ScaffoldMessenger.of(context);

    final maxHpText = hpController.text.trim();
    final error = await onCreatePersistentActor(
      actorType: actorType,
      displayName: nameController.text.trim(),
      maxHp: maxHpText.isEmpty ? null : int.tryParse(maxHpText),
    );

    nameController.dispose();
    hpController.dispose();

    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? '已创建常驻角色')),
    );
  }
}
