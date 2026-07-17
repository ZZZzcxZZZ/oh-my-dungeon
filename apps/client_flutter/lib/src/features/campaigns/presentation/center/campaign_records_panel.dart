import 'package:flutter/material.dart';

import '../../domain/campaign.dart';

/// Records panel: searches the durable campaign history without replacing
/// the live chat timeline, and surfaces system / roll / checkRequest events
/// when no query is entered.
///
/// Plan 3 task 2 — extracted from the legacy `_RecordsTab`.
class CampaignRecordsPanel extends StatefulWidget {
  const CampaignRecordsPanel({
    required this.messages,
    required this.onSearch,
    super.key,
  });

  final List<CampaignChatMessage> messages;
  final Future<List<CampaignChatMessage>> Function(String query) onSearch;

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
                    itemBuilder: (context, index) => ListTile(
                      leading: const Icon(Icons.history_edu_outlined),
                      title: Text(records[index].content),
                      subtitle: Text(records[index].displayName),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
