import 'dart:convert';

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
import 'content/campaign_content_controller.dart';
import 'content/campaign_content_page.dart';

class CampaignChatPage extends StatefulWidget {
  const CampaignChatPage({
    required this.campaign,
    required this.character,
    required this.campaignController,
    required this.contentRepository,
    required this.isDm,
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
  final bool isDm;
  final String? campaignActorId;
  final DiceRoller? diceRoller;
  final CampaignContentController? campaignContentController;
  final CampaignActorController? actorController;

  @override
  State<CampaignChatPage> createState() => _CampaignChatPageState();
}

class _CampaignChatPageState extends State<CampaignChatPage> {
  final _controller = TextEditingController();
  _ChatMode _mode = _ChatMode.say;
  bool _sending = false;

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
    widget.campaignController.disconnectCampaignChat();
    super.dispose();
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
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.campaign.name),
                Text(
                  _t('campaignChatRoom'),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            actions: [
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
              if (widget.campaignContentController != null)
                IconButton(
                  tooltip: '战役资料',
                  onPressed: _openCampaignContent,
                  icon: const Icon(Icons.library_books_outlined),
                ),
              IconButton(
                tooltip: _t('members'),
                onPressed: _showMembers,
                icon: const Icon(Icons.people_outline),
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
                child: Text(_t('retry')),
              ),
            ],
          ),
        Expanded(
          child: widget.campaignController.isMessagesLoading
              ? const Center(child: CircularProgressIndicator())
              : messages.isEmpty
              ? Center(
                  child: Text(
                    _t('emptyChat'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _CampaignChatBubble(
                      message: message,
                      onRespondCheckRequest: _canRespondToCheck(message)
                          ? () => _respondToCheckRequest(message)
                          : null,
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

  // Kept as a composable overview for a future embedded desktop workspace;
  // mobile and web chat intentionally use the explicit campaign center route.
  Widget buildCampaignHub() {
    final actors = widget.actorController?.actors ?? const <CampaignActor>[];
    final colorScheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      key: const Key('campaign-hub-page'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '战役信息',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    Chip(
                      avatar: Icon(
                        _canManageCampaign
                            ? Icons.shield_outlined
                            : Icons.person_outline,
                        size: 18,
                      ),
                      label: Text(_canManageCampaign ? 'DM' : '玩家'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.campaign.description.trim().isEmpty
                      ? '尚未填写战役简介'
                      : widget.campaign.description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _showMembers,
                      icon: const Icon(Icons.people_outline),
                      label: const Text('成员'),
                    ),
                    if (widget.campaignContentController != null)
                      FilledButton.tonalIcon(
                        onPressed: _openCampaignContent,
                        icon: const Icon(Icons.library_books_outlined),
                        label: const Text('共享资料'),
                      ),
                    if (_canManageCampaign)
                      FilledButton.tonalIcon(
                        onPressed: _openCampaignManagement,
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                        label: const Text('战役管理'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: Divider(color: colorScheme.outlineVariant)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Text('战役角色', style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        if (actors.isEmpty)
          const SliverToBoxAdapter(
            child: ListTile(
              leading: Icon(Icons.person_off_outlined),
              title: Text('尚未同步战役角色'),
              subtitle: Text('玩家发布角色后会显示在这里'),
            ),
          )
        else
          SliverList.builder(
            itemCount: actors.length,
            itemBuilder: (context, index) {
              final actor = actors[index];
              final name = actor.sheet['name']?.toString().trim();
              return ListTile(
                key: Key('campaign-actor-${actor.id}'),
                leading: _ChatAvatar(
                  name: name == null || name.isEmpty ? '?' : name,
                  avatarUrl: actor.sheet['avatarUrl'] as String?,
                ),
                title: Text(name == null || name.isEmpty ? '未命名角色' : name),
                subtitle: Text(_actorStatusLine(actor)),
                trailing: _canManageCampaign
                    ? const Icon(Icons.chevron_right)
                    : null,
                onTap: _canManageCampaign
                    ? () => _showActorActions(actor)
                    : null,
              );
            },
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
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

  Widget _buildInputBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Row(
          children: [
            IconButton.filledTonal(
              key: const Key('campaign-chat-identity'),
              tooltip: _t('characterSheet'),
              onPressed: _showIdentitySheet,
              icon: _ChatAvatar(
                name: widget.character?.name ?? '?',
                avatarUrl: widget.character?.avatarUrl,
                size: 24,
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filledTonal(
              tooltip: _t('moreTableTools'),
              onPressed: _showMoreActions,
              icon: const Icon(Icons.add),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 104,
              child: _ChatModePicker(
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
                  hintText: _mode == _ChatMode.say
                      ? _t('sayHint')
                      : _t('actHint'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: _sending ? null : (_) => _send(),
              ),
            ),
            IconButton.filled(
              key: const Key('campaign-chat-send'),
              tooltip: _t('send'),
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) return;

    setState(() => _sending = true);
    final sent = await widget.campaignController.sendMessage(
      campaignId: widget.campaign.id,
      kind: _mode == _ChatMode.act ? 'action' : 'say',
      content: content,
      campaignActorId: _activeSpeakerActorId,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (sent) {
      _controller.clear();
    }
  }

  Future<void> _showMoreActions() {
    return showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.casino_outlined),
                  title: Text(_t('rollDice')),
                  onTap: _showRollSheet,
                ),
                if (_characterActions.isNotEmpty &&
                    widget.campaignActorId != null)
                  ListTile(
                    leading: const Icon(Icons.bolt_outlined),
                    title: const Text('角色动作'),
                    subtitle: Text('${_characterActions.length} 个可用动作'),
                    onTap: _showCharacterActions,
                  ),
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(_t('characterSheet')),
                  onTap: _openCharacterSheet,
                ),
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(_t('contentLibrary')),
                  onTap: _showContentLibrary,
                ),
                ListTile(
                  leading: const Icon(Icons.table_restaurant_outlined),
                  title: Text(_t('tableTools')),
                  subtitle: Text(_t('tableToolsHint')),
                  onTap: _showTableTools,
                ),
                ListTile(
                  leading: const Icon(Icons.fact_check_outlined),
                  title: Text(_t('checkRequest')),
                  subtitle: _canManageCampaign
                      ? const Text('从战役角色中选择检定项目')
                      : const Text('DM 发起的检定会显示在聊天室'),
                  onTap: _canManageCampaign
                      ? () {
                          Navigator.of(context).pop();
                          _showCheckRequestTargetPicker();
                        }
                      : null,
                ),
                if (_canManageCampaign)
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: Text(_t('dmControl')),
                    subtitle: Text(_t('dmControlHint')),
                    onTap: _showDmControl,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showIdentitySheet() {
    final character = widget.character;
    final workspace = widget.campaignController.workspaceContext;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: _ChatAvatar(
                name: character?.name ?? '?',
                avatarUrl: character?.avatarUrl,
              ),
              title: Text(character?.name ?? _t('unboundCharacter')),
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
            if (_canManageCampaign) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.auto_stories_outlined),
                title: const Text('旁白'),
                selected: workspace?.membership.speakerMode == 'narrator',
                onTap: () => _selectCampaignSpeaker('narrator'),
              ),
              for (final actor in workspace?.actors.where((actor) => actor.status == 'active') ?? const <CampaignWorkspaceActor>[])
                ListTile(
                  leading: _ChatAvatar(
                    name: actor.displayName,
                    avatarUrl: null,
                    healthState: actor.publicHealthState,
                  ),
                  title: Text(actor.displayName),
                  subtitle: Text(actor.actorType == 'npc' ? 'NPC' : '角色'),
                  selected: workspace?.membership.activeSpeakerActorId == actor.id,
                  onTap: () => _selectCampaignSpeaker('actor', actor.id),
                ),
            ],
          ],
        ),
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

  Future<void> _showTableTools() {
    Navigator.of(context).pop();
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
                  _t('tableTools'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(_t('tableToolsDescription')),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.fact_check_outlined),
                  title: Text(_t('checkRequest')),
                  subtitle: Text(_t('checkRequestHint')),
                ),
                ListTile(
                  leading: const Icon(Icons.history_edu_outlined),
                  title: Text(_t('tableLog')),
                  subtitle: Text(_t('tableLogHint')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDmControl() {
    Navigator.of(context).pop();
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
                  _t('dmControl'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(_t('dmControlDescription')),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: Text(_t('encounterControl')),
                  subtitle: Text(_t('encounterControlHint')),
                ),
                ListTile(
                  leading: const Icon(Icons.group_outlined),
                  title: Text(_t('memberStatus')),
                  subtitle: Text(_t('memberStatusHint')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showRollSheet() {
    Navigator.of(context).pop();
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
                  _t('quickRoll'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final notation in _quickDice)
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
    Navigator.of(context).pop();
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
      ).showSnackBar(SnackBar(content: Text(_t('sendFailed'))));
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
        messenger.showSnackBar(SnackBar(content: Text(_t('sendFailed'))));
      }
    } on DiceRollException catch (error) {
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text('${_t('invalidDice')}$error')),
      );
    }
  }

  Future<void> _showContentLibrary() async {
    Navigator.of(context).pop();
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
                              _t('campaignContentLibrary'),
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
                          labelText: _t('searchContent'),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            tooltip: _t('search'),
                            onPressed: refreshItems,
                            icon: const Icon(Icons.arrow_forward),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => refreshItems(),
                      ),
                      const SizedBox(height: 12),
                      DropdownMenu<String>(
                        label: Text(_t('contentType')),
                        initialSelection: selectedType,
                        expandedInsets: EdgeInsets.zero,
                        dropdownMenuEntries: [
                          DropdownMenuEntry(value: 'all', label: _t('all')),
                          for (final type in _contentTypeFilters)
                            DropdownMenuEntry(
                              value: type,
                              label: _contentTypeLabel(type),
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
                            ? Center(child: Text(_t('emptyContent')))
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
                                          ? _contentTypeLabel(item.type)
                                          : '${_contentTypeLabel(item.type)} · $source',
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
    Navigator.of(context).pop();
    final character = widget.character;
    if (character == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_t('noBoundCharacter'))));
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
                leading: _ChatAvatar(
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

  Future<void> _showActorActions(CampaignActor actor) {
    final name = actor.sheet['name']?.toString().trim();
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                name == null || name.isEmpty ? '未命名角色' : name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('查看并编辑角色'),
                subtitle: const Text('DM 拥有该战役角色的完整编辑权'),
                onTap: widget.actorController == null
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
              ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('发起检定'),
                subtitle: const Text('选择属性、豁免或技能并发送到聊天室'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showCheckRequestSheet(actor);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCheckRequestSheet(CampaignActor actor) async {
    final draft = await showModalBottomSheet<_CheckRequestDraft>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _CheckRequestSheet(actor: actor),
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
    ).showSnackBar(SnackBar(content: Text(_t('sendFailed'))));
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
      ).showSnackBar(SnackBar(content: Text(_t('sendFailed'))));
    }
  }

  Future<void> _showMembers() {
    final members = widget.campaign.memberPreview;
    final actors = widget.actorController?.actors ?? const <CampaignActor>[];
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _t('campaignMembers'),
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
                if (members.isEmpty && actors.isEmpty)
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person_off)),
                    title: Text(_t('emptyMembers')),
                  )
                else if (members.isNotEmpty)
                  for (final member in members)
                    _CampaignMemberTile(
                      member: member,
                      actor: actors
                          .where((actor) => actor.ownerUserId == member.userId)
                          .firstOrNull,
                    )
                else
                  for (final actor in actors)
                    _ActorOnlyMemberTile(actor: actor),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CheckRequestSheet extends StatefulWidget {
  const _CheckRequestSheet({required this.actor});

  final CampaignActor actor;

  @override
  State<_CheckRequestSheet> createState() => _CheckRequestSheetState();
}

class _CheckRequestSheetState extends State<_CheckRequestSheet> {
  final _dcController = TextEditingController();
  String _type = 'ability';
  String _key = 'str';
  String _rollMode = 'normal';

  @override
  void dispose() {
    _dcController.dispose();
    super.dispose();
  }

  List<MapEntry<String, String>> get _options {
    if (_type == 'skill') {
      return [
        for (final skill in Dnd5eRules.skills) MapEntry(skill.name, skill.name),
      ];
    }
    return Dnd5eRules.abilityLabels.entries.toList(growable: false);
  }

  void _setType(String type) {
    setState(() {
      _type = type;
      _key = type == 'skill' ? Dnd5eRules.skills.first.name : 'str';
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.actor.sheet['name']?.toString().trim();
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '向 ${name == null || name.isEmpty ? '该角色' : name} 发起检定',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'ability',
                  label: Text('属性', key: Key('check-type-ability')),
                ),
                ButtonSegment(
                  value: 'save',
                  label: Text('豁免', key: Key('check-type-save')),
                ),
                ButtonSegment(
                  value: 'skill',
                  label: Text('技能', key: Key('check-type-skill')),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) => _setType(selection.single),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('check-key-$_type'),
              initialValue: _key,
              decoration: const InputDecoration(
                labelText: '检定项目',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final option in _options)
                  DropdownMenuItem(
                    value: option.key,
                    child: Text(option.value),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _key = value);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _dcController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '难度等级 DC（可选）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'normal', label: Text('普通')),
                ButtonSegment(value: 'advantage', label: Text('优势')),
                ButtonSegment(value: 'disadvantage', label: Text('劣势')),
              ],
              selected: {_rollMode},
              onSelectionChanged: (selection) {
                setState(() => _rollMode = selection.single);
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('send-check-request'),
                onPressed: _submit,
                icon: const Icon(Icons.send_outlined),
                label: const Text('发送检定请求'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final dc = int.tryParse(_dcController.text.trim());
    final option = _options.firstWhere((item) => item.key == _key);
    final suffix = switch (_type) {
      'skill' => '技能检定',
      'save' => '豁免检定',
      _ => '属性检定',
    };
    Navigator.of(context).pop(
      _CheckRequestDraft(
        type: _type,
        key: _key,
        label: '${option.value}$suffix',
        dc: dc,
        rollMode: _rollMode,
      ),
    );
  }
}

class _CheckRequestDraft {
  const _CheckRequestDraft({
    required this.type,
    required this.key,
    required this.label,
    required this.dc,
    required this.rollMode,
  });

  final String type;
  final String key;
  final String label;
  final int? dc;
  final String rollMode;
}

class _CampaignMemberTile extends StatelessWidget {
  const _CampaignMemberTile({required this.member, this.actor});

  final CampaignMemberPreview member;
  final CampaignActor? actor;

  @override
  Widget build(BuildContext context) {
    final actorName = actor?.sheet['name']?.toString().trim();
    final subtitle = [
      if (actorName != null && actorName.isNotEmpty) actorName,
      if (actor != null) _actorStatusLine(actor!),
    ].where((item) => item.isNotEmpty).join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _ChatAvatar(
        name: actorName == null || actorName.isEmpty
            ? member.displayName
            : actorName,
        avatarUrl: actor?.sheet['avatarUrl'] as String?,
      ),
      title: Text(member.displayName),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: Chip(label: Text(_campaignRoleLabel(member.role))),
    );
  }
}

class _ActorOnlyMemberTile extends StatelessWidget {
  const _ActorOnlyMemberTile({required this.actor});

  final CampaignActor actor;

  @override
  Widget build(BuildContext context) {
    final name = actor.sheet['name']?.toString().trim();
    final displayName = name == null || name.isEmpty ? '未命名角色' : name;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _ChatAvatar(
        name: displayName,
        avatarUrl: actor.sheet['avatarUrl'] as String?,
      ),
      title: Text(displayName),
      subtitle: Text(_actorStatusLine(actor)),
      trailing: const Chip(label: Text('角色')),
    );
  }
}

class _ChatModePicker extends StatelessWidget {
  const _ChatModePicker({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  final _ChatMode mode;
  final bool enabled;
  final ValueChanged<_ChatMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          children: [
            Expanded(
              child: _ChatModeHalf(
                key: const Key('chat-mode-say'),
                selected: mode == _ChatMode.say,
                enabled: enabled,
                icon: Icons.chat_bubble_outline,
                label: _t('say'),
                onTap: () => onChanged(_ChatMode.say),
              ),
            ),
            Expanded(
              child: _ChatModeHalf(
                key: const Key('chat-mode-action'),
                selected: mode == _ChatMode.act,
                enabled: enabled,
                icon: Icons.directions_run_outlined,
                label: _t('act'),
                onTap: () => onChanged(_ChatMode.act),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatModeHalf extends StatelessWidget {
  const _ChatModeHalf({
    super.key,
    required this.selected,
    required this.enabled,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final bool enabled;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colorScheme.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: foreground),
            if (MediaQuery.sizeOf(context).width >= 420) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: foreground),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CampaignChatBubble extends StatelessWidget {
  const _CampaignChatBubble({
    required this.message,
    this.onRespondCheckRequest,
  });

  final CampaignChatMessage message;
  final VoidCallback? onRespondCheckRequest;

  @override
  Widget build(BuildContext context) {
    final displayName = message.displayName.trim().isEmpty
        ? _t('unknownSpeaker')
        : message.displayName;
    if (message.kind == 'system') {
      return Padding(
        key: const Key('system-message'),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Center(
          child: Text(
            message.content,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    if (message.kind == 'checkRequest') {
      final data = message.eventData;
      final dc = data?['dc'];
      return Card.filled(
        key: const Key('check-request-message'),
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: ListTile(
          leading: const Icon(Icons.fact_check_outlined),
          title: Text(
            message.content,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: dc == null ? null : Text('DC $dc'),
          trailing: onRespondCheckRequest == null
              ? null
              : FilledButton.tonal(
                  key: const Key('respond-check-request'),
                  onPressed: onRespondCheckRequest,
                  child: const Text('进行检定'),
                ),
        ),
      );
    }

    if (message.kind == 'roll') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ChatAvatar(
              name: displayName,
              avatarUrl: message.avatarUrl,
              healthState: message.publicHealthState,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Chip(
                    avatar: const Icon(Icons.casino_outlined, size: 18),
                    label: Text(message.content),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (message.kind == 'action') {
      final snapshot = message.actionSnapshot;
      return Padding(
        key: snapshot == null
            ? const Key('action-message')
            : const Key('rules-action-message'),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ChatAvatar(
              name: displayName,
              avatarUrl: message.avatarUrl,
              healthState: message.publicHealthState,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Card(
                    margin: const EdgeInsets.only(top: 4),
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.content,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontStyle: FontStyle.italic),
                          ),
                          if (snapshot != null &&
                              (snapshot['formula'] != null ||
                                  snapshot['entryId'] != null)) ...[
                            const SizedBox(height: 4),
                            Text(
                              [
                                if (snapshot['formula'] != null)
                                  '${snapshot['formula']}',
                                if (snapshot['entryId'] != null)
                                  '来源 ${snapshot['entryId']}',
                              ].join(' · '),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      key: const Key('say-message'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChatAvatar(
            name: displayName,
            avatarUrl: message.avatarUrl,
            healthState: message.publicHealthState,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Card(
                  margin: const EdgeInsets.only(top: 4),
                  color: colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(message.content),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({
    required this.name,
    required this.avatarUrl,
    this.size = 40,
    this.healthState,
  });

  final String name;
  final String? avatarUrl;
  final double size;
  final String? healthState;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final image = _avatarImage(url);
    final color = _healthRingColor(context, healthState);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircleAvatar(
            backgroundImage: image,
            child: image == null ? Text(_avatarText(name)) : null,
          ),
          if (color != null)
            IgnorePointer(
              child: DecoratedBox(
                key: Key('campaign-avatar-ring-$healthState'),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 3),
                ),
              ),
            ),
        ],
      ),
    );
  }

  ImageProvider<Object>? _avatarImage(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('data:image/')) {
      final separator = url.indexOf(',');
      if (separator < 0) return null;
      try {
        return MemoryImage(base64Decode(url.substring(separator + 1)));
      } on FormatException {
        return null;
      }
    }
    return NetworkImage(url);
  }
}

Color? _healthRingColor(BuildContext context, String? state) {
  final colors = Theme.of(context).colorScheme;
  return switch (state) {
    'healthy' => colors.primary,
    'injured' => colors.tertiary,
    'critical' || 'down' => colors.error,
    _ => null,
  };
}

enum _ChatMode { say, act }

const _quickDice = ['d20', 'd12', 'd10', 'd8', 'd6', 'd4', 'd100'];
const _contentTypeFilters = [
  'spell',
  'equipment',
  'item',
  'species',
  'class',
  'background',
  'feat',
  'condition',
  'monster',
];

String _avatarText(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.characters.first;
}

String _actorStatusLine(CampaignActor actor) {
  final currentHp = actor.sheet['currentHp'];
  final maxHp = actor.sheet['maxHp'];
  final armorClass = actor.sheet['armorClass'];
  final classSummary = actor.sheet['classSummary']?.toString().trim();
  final level = actor.sheet['level'];
  return [
    if (classSummary != null && classSummary.isNotEmpty)
      level is num ? '$classSummary ${level.toInt()}级' : classSummary,
    if (currentHp is num && maxHp is num)
      'HP ${currentHp.toInt()}/${maxHp.toInt()}',
    if (armorClass is num) 'AC ${armorClass.toInt()}',
  ].join(' · ');
}

String _campaignRoleLabel(String role) => switch (role) {
  'owner' => '创建者',
  'dm' || 'manager' => 'DM',
  'spectator' => '旁观',
  _ => '玩家',
};

String _contentTypeLabel(String type) => switch (type) {
  'background' => '\u80cc\u666f',
  'class' => '\u804c\u4e1a',
  'condition' => '\u72b6\u6001',
  'equipment' => '\u88c5\u5907',
  'feat' => '\u4e13\u957f',
  'item' => '\u7269\u54c1',
  'monster' => '\u602a\u7269',
  'species' => '\u79cd\u65cf',
  'spell' => '\u6cd5\u672f',
  _ => type,
};

String _t(String key) => switch (key) {
  'act' => '\u505a',
  'actHint' => '\u63cf\u8ff0\u52a8\u4f5c...',
  'all' => '\u5168\u90e8',
  'campaignChatRoom' => '\u6218\u5f79\u804a\u5929\u5ba4',
  'campaignContentLibrary' => '\u6218\u5f79\u8d44\u6599\u5e93',
  'campaignMembers' => '\u6218\u5f79\u6210\u5458',
  'characterSheet' => '\u89d2\u8272\u5361',
  'checkRequest' => '\u68c0\u5b9a\u8bf7\u6c42',
  'checkRequestHint' => '向玩家发起属性、技能或豁免检定',
  'contentLibrary' => '\u8d44\u6599\u5e93',
  'contentType' => '\u8d44\u6599\u7c7b\u578b',
  'dmControl' => 'DM 控场',
  'dmControlDescription' => '这里会继续整合遭遇、成员状态和隐藏信息。',
  'dmControlHint' => '遭遇、成员状态和 DM 私有工具',
  'emptyMembers' => '\u8fd8\u6ca1\u6709\u7ed1\u5b9a\u89d2\u8272',
  'emptyContent' => '\u6ca1\u6709\u627e\u5230\u53ef\u7528\u8d44\u6599',
  'emptyChat' =>
    '\u8fd8\u6ca1\u6709\u6d88\u606f\n\u4ece\u4e0b\u65b9\u5f00\u59cb\u8bf4\u8bdd\u6216\u505a\u52a8\u4f5c',
  'encounterControl' => '遭遇控场',
  'encounterControlHint' => '管理先攻、回合、敌人生命值和状态',
  'members' => '\u6210\u5458',
  'memberStatus' => '成员状态',
  'memberStatusHint' => '查看角色 HP、AC、状态和可见信息',
  'moreTableTools' => '\u66f4\u591a\u8dd1\u56e2\u529f\u80fd',
  'noBoundCharacter' =>
    '\u8bf7\u5148\u5728\u6218\u5f79\u4e2d\u7ed1\u5b9a\u89d2\u8272',
  'invalidDice' => '\u63b7\u9ab0\u8868\u8fbe\u5f0f\u65e0\u6548\uff1a',
  'quickRoll' => '\u5feb\u901f\u63b7\u9ab0',
  'retry' => '\u91cd\u8bd5',
  'rollDice' => '\u63b7\u9ab0',
  'say' => '\u8bf4',
  'sayHint' => '\u8bf4\u4e9b\u4ec0\u4e48...',
  'search' => '\u641c\u7d22',
  'searchContent' => '\u641c\u7d22\u8d44\u6599',
  'sendFailed' => '\u53d1\u9001\u5931\u8d25',
  'send' => '\u53d1\u9001',
  'tableLog' => '跑团日志',
  'tableLogHint' => '查看聊天、掷骰、状态变化和关键事件',
  'tableTools' => '桌面工具',
  'tableToolsDescription' => '桌面能力已经并入战役聊天室；常用操作从这里打开。',
  'tableToolsHint' => '检定、日志和战役现场工具',
  'unknownSpeaker' => '\u672a\u77e5\u53d1\u8a00\u8005',
  'unboundCharacter' => '\u672a\u7ed1\u5b9a\u89d2\u8272',
  _ => key,
};
