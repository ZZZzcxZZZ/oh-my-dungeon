import 'package:flutter/material.dart';

import '../data/local/content_repository.dart';
import '../domain/content_entry.dart';
import 'content_library_controller.dart';
import 'content_type_registry.dart';
import 'widgets/content_block_view.dart';
import 'widgets/content_class_feature_list.dart';
import 'widgets/content_metadata_view.dart';

class ContentDetailPage extends StatefulWidget {
  const ContentDetailPage({
    required this.entryKey,
    required this.controller,
    required this.onOpenEntry,
    required this.onImportRequested,
    super.key,
  });

  final String? entryKey;
  final ContentLibraryController controller;
  final ValueChanged<String> onOpenEntry;
  final VoidCallback onImportRequested;

  @override
  State<ContentDetailPage> createState() => _ContentDetailPageState();
}

class _ContentDetailPageState extends State<ContentDetailPage> {
  ContentEntry? _entry;
  bool _isLoading = false;
  bool _isFavorite = false;
  List<ContentEntry> _classFeatures = const [];
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEntry();
  }

  @override
  void didUpdateWidget(covariant ContentDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entryKey != oldWidget.entryKey) {
      _loadEntry();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadEntry() async {
    final entryKey = widget.entryKey;
    if (entryKey == null) {
      setState(() {
        _entry = null;
        _isLoading = false;
      });
      return;
    }
    setState(() => _isLoading = true);
    try {
      final entry = await widget.controller.getByKey(entryKey);
      final isFav = entry == null
          ? false
          : await widget.controller.isFavorite(entryKey);
      List<ContentEntry> features = const [];
      if (entry != null && entry.type == 'class') {
        final packageId = entry.id.split(':').first;
        features = await widget.controller.repository.search(
          ContentQuery(type: 'classFeature', packageId: packageId),
        );
      }
      if (mounted) {
        setState(() {
          _entry = entry;
          _isLoading = false;
          _isFavorite = isFav;
          _classFeatures = features;
          _noteController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final entryKey = widget.entryKey;
    if (entryKey == null) return;
    await widget.controller.toggleFavorite(entryKey);
    final isFav = await widget.controller.isFavorite(entryKey);
    if (mounted) {
      setState(() => _isFavorite = isFav);
    }
  }

  Future<void> _saveNote() async {
    final entryKey = widget.entryKey;
    if (entryKey == null) return;
    await widget.controller.repository.saveNote(
      entryKey,
      _noteController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final entryKey = widget.entryKey;

    if (entryKey == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('资料库')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 48,
                  color: colorScheme.outline,
                ),
                const SizedBox(height: 12),
                Text('选择一个条目', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '在此查看规则、关联条目与职业特性。',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('加载中…')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final entry = _entry;
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('资料库')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: colorScheme.outline,
                ),
                const SizedBox(height: 12),
                Text('条目不存在', style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ),
      );
    }

    final definition = ContentTypeRegistry.defaults().definitionFor(entry.type);
    final packageId = entry.id.split(':').first;

    return Scaffold(
      appBar: AppBar(
        title: Text(entry.name),
        actions: [
          IconButton(
            tooltip: _isFavorite ? '取消收藏' : '收藏',
            onPressed: _toggleFavorite,
            icon: Icon(
              _isFavorite ? Icons.bookmark : Icons.bookmark_outline,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(
                  avatar: Icon(definition.icon, size: 16),
                  label: Text(definition.label),
                ),
                if (entry.source.label.isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.book_outlined, size: 16),
                    label: Text(entry.source.label),
                  ),
                Chip(
                  avatar: Icon(
                    entry.origin == ContentOrigin.campaign
                        ? Icons.campaign_outlined
                        : Icons.cloud_off_outlined,
                    size: 16,
                  ),
                  label: Text(
                    entry.origin == ContentOrigin.campaign ? '战役' : '本地',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ContentMetadataView(entry: entry),
            const SizedBox(height: 16),
            ContentBlockView(
              blocks: entry.body,
              packageId: packageId,
              readAsset: widget.controller.repository.readAsset,
              onOpenEntry: widget.onOpenEntry,
            ),
            if (entry.type == 'class')
              ContentClassFeatureList(
                classEntry: entry,
                featureEntries: _classFeatures,
                onFeatureTap: (feature) => widget.onOpenEntry(feature.id),
              ),
            const SizedBox(height: 24),
            Text('笔记', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '记录你的笔记…',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _saveNote(),
            ),
          ],
        ),
      ),
    );
  }
}
