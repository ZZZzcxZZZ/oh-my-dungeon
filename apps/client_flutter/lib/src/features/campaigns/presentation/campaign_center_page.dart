import 'package:flutter/material.dart';

import '../domain/campaign.dart';
import '../domain/campaign_actor.dart';
import '../domain/campaign_archive_entry.dart';
import 'actors/campaign_actor_controller.dart';
import 'campaign_controller.dart';

/// The campaign's non-chat workspace. Chat stays fast and focused; durable
/// information lives here behind a compact Material 3 tab bar.
class CampaignCenterPage extends StatefulWidget {
  const CampaignCenterPage({
    required this.campaign,
    required this.controller,
    this.actorController,
    super.key,
  });

  final Campaign campaign;
  final CampaignController controller;
  final CampaignActorController? actorController;

  @override
  State<CampaignCenterPage> createState() => _CampaignCenterPageState();
}

class _CampaignCenterPageState extends State<CampaignCenterPage> {
  String? _archiveKind;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadWorkspaceContext(widget.campaign.id);
      widget.controller.loadArchives(widget.campaign.id);
    });
  }

  bool get _canManage =>
      widget.controller.workspaceContext?.capabilities.canManageCampaign ??
      false;

  List<CampaignActor> get _actors => widget.actorController?.actors ?? const [];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.controller,
        if (widget.actorController != null) widget.actorController!,
      ]),
      builder: (context, _) => DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.campaign.name),
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.info_outline), text: '概览'),
                Tab(icon: Icon(Icons.group_outlined), text: '成员'),
                Tab(icon: Icon(Icons.folder_outlined), text: '档案'),
                Tab(icon: Icon(Icons.history_outlined), text: '记录'),
              ],
            ),
          ),
          floatingActionButton: _canManage
              ? FloatingActionButton.extended(
                  onPressed: _showCreateArchiveDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('新建条目'),
                )
              : null,
          body: TabBarView(
            children: [
              _OverviewTab(campaign: widget.campaign, canManage: _canManage),
              _MembersTab(
                members: widget.controller.workspaceContext?.members ??
                    widget.campaign.memberPreview,
                actors: _actors,
              ),
              _ArchivesTab(
                entries: widget.controller.archives,
                isLoading: widget.controller.isArchivesLoading,
                error: widget.controller.archivesError,
                canManage: _canManage,
                selectedKind: _archiveKind,
                onKindChanged: (kind) {
                  setState(() => _archiveKind = kind);
                  widget.controller.loadArchives(widget.campaign.id, kind: kind);
                },
                onRefresh: () => widget.controller.loadArchives(widget.campaign.id),
                onArchive: (entry) => widget.controller.archiveEntry(
                  campaignId: widget.campaign.id,
                  entryId: entry.id,
                ),
              ),
              _RecordsTab(
                messages: widget.controller.messages,
                onSearch: (query) => widget.controller.searchMessages(
                  widget.campaign.id,
                  query: query,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateArchiveDialog() async {
    var kind = 'clue';
    final title = TextEditingController();
    final summary = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final create = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建战役条目'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: kind,
                decoration: const InputDecoration(labelText: '类型'),
                items: const [
                  DropdownMenuItem(value: 'clue', child: Text('线索')),
                  DropdownMenuItem(value: 'location', child: Text('地点')),
                  DropdownMenuItem(value: 'document', child: Text('文档')),
                  DropdownMenuItem(value: 'file', child: Text('文件')),
                ],
                onChanged: (value) => kind = value ?? kind,
              ),
              TextFormField(
                controller: title,
                autofocus: true,
                decoration: const InputDecoration(labelText: '名称'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? '请输入名称'
                    : null,
              ),
              TextField(
                controller: summary,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '说明（可选）'),
              ),
            ],
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
    );
    if (create != true || !mounted) return;
    final entry = await widget.controller.createArchiveEntry(
      campaignId: widget.campaign.id,
      kind: kind,
      title: title.text,
      summary: summary.text,
    );
    title.dispose();
    summary.dispose();
    if (!mounted || entry != null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.controller.archivesError ?? '创建失败')),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.campaign, required this.canManage});

  final Campaign campaign;
  final bool canManage;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(campaign.description.trim().isEmpty ? '尚未填写战役简介' : campaign.description),
          const SizedBox(height: 20),
          ListTile(
            leading: Icon(canManage ? Icons.shield_outlined : Icons.person_outline),
            title: Text(canManage ? '地下城主' : '玩家'),
            subtitle: Text('系统：${campaign.system}'),
          ),
        ],
      );
}

class _MembersTab extends StatelessWidget {
  const _MembersTab({required this.members, required this.actors});

  final List<CampaignMemberPreview> members;
  final List<CampaignActor> actors;

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: members.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final member = members[index];
          final actor = actors.where((item) => item.ownerUserId == member.userId).firstOrNull;
          final name = actor?.sheet['name']?.toString().trim();
          return ListTile(
            leading: CircleAvatar(child: Text((name?.isNotEmpty ?? false) ? name!.characters.first : member.displayName.characters.first)),
            title: Text(member.displayName),
            subtitle: Text(name?.isNotEmpty ?? false ? name! : _roleLabel(member.role)),
            trailing: actor == null ? null : const Icon(Icons.chevron_right),
          );
        },
      );
}

class _ArchivesTab extends StatelessWidget {
  const _ArchivesTab({required this.entries, required this.isLoading, required this.error, required this.canManage, required this.selectedKind, required this.onKindChanged, required this.onRefresh, required this.onArchive});

  final List<CampaignArchiveEntry> entries;
  final bool isLoading;
  final String? error;
  final bool canManage;
  final String? selectedKind;
  final ValueChanged<String?> onKindChanged;
  final Future<void> Function() onRefresh;
  final Future<bool> Function(CampaignArchiveEntry entry) onArchive;

  @override
  Widget build(BuildContext context) {
    if (isLoading && entries.isEmpty) return const Center(child: CircularProgressIndicator());
    if (error != null && entries.isEmpty) return Center(child: Text(error!));
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              for (final option in const <(String?, String)>[(null, '全部'), ('document', '资料'), ('location', '地点'), ('clue', '线索'), ('file', '文件')])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(option.$2),
                    selected: selectedKind == option.$1,
                    onSelected: (_) => onKindChanged(option.$1),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? Center(child: Text('尚无共享档案', style: Theme.of(context).textTheme.bodyLarge))
              : RefreshIndicator(
                  onRefresh: onRefresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return Card(
                        child: ListTile(
                          leading: Icon(_archiveIcon(entry.kind)),
                          title: Text(entry.title),
                          subtitle: entry.summary.isEmpty ? Text(_archiveKindLabel(entry.kind)) : Text(entry.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: canManage
                              ? IconButton(
                                  tooltip: '归档条目',
                                  icon: const Icon(Icons.archive_outlined),
                                  onPressed: () => onArchive(entry),
                                )
                              : null,
                          onTap: () => _showArchiveDetail(context, entry),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _RecordsTab extends StatefulWidget {
  const _RecordsTab({required this.messages, required this.onSearch});

  final List<CampaignChatMessage> messages;
  final Future<List<CampaignChatMessage>> Function(String query) onSearch;

  @override
  State<_RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<_RecordsTab> {
  String _query = '';
  List<CampaignChatMessage> _searchResults = const [];
  bool _isSearching = false;
  int _searchRequest = 0;

  Future<void> _onQueryChanged(String value) async {
    final query = value.trim();
    final request = ++_searchRequest;
    setState(() {
      _query = value;
      _isSearching = query.isNotEmpty;
      if (query.isEmpty) _searchResults = const [];
    });
    if (query.isEmpty) return;

    final results = await widget.onSearch(query);
    if (!mounted || request != _searchRequest) return;
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final records = query.isEmpty
        ? widget.messages
              .where(
                (message) =>
                    message.kind == 'system' ||
                    message.kind == 'roll' ||
                    message.kind == 'checkRequest',
              )
              .toList()
        : _searchResults;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SearchBar(
            key: const Key('campaign-record-search'),
            hintText: '搜索检定、事件和发言者',
            leading: const Icon(Icons.search),
            onChanged: _onQueryChanged,
          ),
        ),
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : records.isEmpty
              ? const Center(child: Text('战役记录会在这里沉淀'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: records.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: const Icon(Icons.history_edu_outlined),
                    title: Text(records[index].content),
                    subtitle: Text(records[index].displayName),
                  ),
                ),
          ),
      ],
    );
  }
}

void _showArchiveDetail(BuildContext context, CampaignArchiveEntry entry) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_archiveKindLabel(entry.kind), style: Theme.of(context).textTheme.labelLarge),
            if (entry.summary.isNotEmpty) ...[const SizedBox(height: 12), Text(entry.summary)],
          ],
        ),
      ),
    ),
  );
}

IconData _archiveIcon(String kind) => switch (kind) {
      'location' => Icons.place_outlined,
      'document' => Icons.description_outlined,
      'file' => Icons.attach_file_outlined,
      _ => Icons.lightbulb_outline,
    };

String _archiveKindLabel(String kind) => switch (kind) {
      'location' => '地点',
      'document' => '文档',
      'file' => '文件',
      _ => '线索',
    };

String _roleLabel(String role) => switch (role) {
      'owner' || 'dm' => '地下城主',
      'spectator' => '旁观者',
      _ => '玩家',
    };
