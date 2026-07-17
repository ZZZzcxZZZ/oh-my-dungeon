import 'package:flutter/material.dart';

import '../../domain/campaign.dart';

/// Records panel: searches the durable campaign history without replacing
/// the live chat timeline, and surfaces system / roll / checkRequest events
/// when no query is entered.
///
/// Spec §档案 / §记录: 记录面板条目可点击。点击后若有 [onMessageTap] 则
/// 委托给调用方（例如跳转到聊天对应位置）；否则弹出默认详情浮窗。
///
/// Plan 3 task 2 — extracted from the legacy `_RecordsTab`.
class CampaignRecordsPanel extends StatefulWidget {
  const CampaignRecordsPanel({
    required this.messages,
    required this.onSearch,
    this.onMessageTap,
    super.key,
  });

  final List<CampaignChatMessage> messages;
  final Future<List<CampaignChatMessage>> Function(String query) onSearch;

  /// 自定义点击行为。为 null 时弹出默认详情浮窗。
  final void Function(CampaignChatMessage message)? onMessageTap;

  @override
  State<CampaignRecordsPanel> createState() => _CampaignRecordsPanelState();
}

class _CampaignRecordsPanelState extends State<CampaignRecordsPanel> {
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

  void _onTapRecord(CampaignChatMessage message) {
    final customTap = widget.onMessageTap;
    if (customTap != null) {
      customTap(message);
      return;
    }
    _showDefaultDetail(message);
  }

  void _showDefaultDetail(CampaignChatMessage message) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _kindLabel(message.kind),
                  style: Theme.of(sheetContext).textTheme.labelLarge?.copyWith(
                        color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  message.content,
                  style: Theme.of(sheetContext).textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  '发言者：${message.displayName}',
                  style: Theme.of(sheetContext).textTheme.labelSmall?.copyWith(
                        color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                      ),
                ),
                Text(
                  '时间：${message.createdAt}',
                  style: Theme.of(sheetContext).textTheme.labelSmall?.copyWith(
                        color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
    return KeyedSubtree(
      key: widget.key ?? const Key('campaign-records-panel'),
      child: Column(
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
                    itemBuilder: (context, index) {
                      final message = records[index];
                      return ListTile(
                        leading: const Icon(Icons.history_edu_outlined),
                        title: Text(message.content),
                        subtitle: Text(message.displayName),
                        onTap: () => _onTapRecord(message),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

String _kindLabel(String kind) => switch (kind) {
      'system' => '系统事件',
      'roll' => '掷骰',
      'checkRequest' => '检定请求',
      'say' => '对话',
      'action' => '动作',
      'ooc' => '场外',
      _ => '消息',
    };
