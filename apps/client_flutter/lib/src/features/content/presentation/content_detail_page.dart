import 'package:flutter/material.dart';

import '../../rules/domain/rule_override_declaration.dart';
import '../data/local/content_repository.dart';
import '../domain/content_entry.dart';
import 'content_library_controller.dart';
import 'content_type_registry.dart';
import 'widgets/content_class_feature_list.dart';
import 'widgets/content_character_rules_view.dart';
import 'widgets/content_entry_reader.dart';
import '../../../core/widgets/empty_state.dart';

class ContentDetailPage extends StatefulWidget {
  const ContentDetailPage({
    required this.entryKey,
    required this.controller,
    required this.onOpenEntry,
    required this.onImportRequested,
    this.onClose,
    this.onBack,
    super.key,
  });

  final String? entryKey;
  final ContentLibraryController controller;
  final ValueChanged<String> onOpenEntry;
  final VoidCallback onImportRequested;
  final VoidCallback? onClose;
  final VoidCallback? onBack;

  @override
  State<ContentDetailPage> createState() => _ContentDetailPageState();
}

class _ContentDetailPageState extends State<ContentDetailPage> {
  ContentEntry? _entry;
  bool _isLoading = false;
  bool _isFavorite = false;
  List<ContentEntry> _classFeatures = const [];
  List<ContentEntry> _subclasses = const [];

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
      List<ContentEntry> subclasses = const [];
      if (entry != null && entry.type == 'class') {
        final packageId = RuleOverrideDeclaration.packageIdOf(entry.id);
        final allFeatures = await widget.controller.repository.search(
          ContentQuery(type: 'classFeature', packageId: packageId),
        );
        // 使用结构化关系 (featureOf) 过滤, 不解析正文字符串.
        features = allFeatures
            .where(
              (feature) => feature.relations.any(
                (relation) =>
                    relation.type == 'featureOf' &&
                    relation.targetId == entry.id,
              ),
            )
            .toList();
        final allSubclasses = await widget.controller.repository.search(
          ContentQuery(type: 'subclass', packageId: packageId),
        );
        subclasses = allSubclasses
            .where(
              (subclass) => subclass.relations.any(
                (relation) =>
                    relation.type == 'subclassOf' &&
                    relation.targetId == entry.id,
              ),
            )
            .toList();
      }
      if (mounted) {
        setState(() {
          _entry = entry;
          _isLoading = false;
          _isFavorite = isFav;
          _classFeatures = features;
          _subclasses = subclasses;
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

  Widget? _appBarLeading() {
    final onBack = widget.onBack;
    if (onBack != null) {
      return IconButton(
        key: const Key('content-detail-back'),
        tooltip: '返回',
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back),
      );
    }
    final onClose = widget.onClose;
    if (onClose == null) return null;
    return IconButton(
      key: const Key('content-detail-close'),
      tooltip: '关闭详情',
      onPressed: onClose,
      icon: const Icon(Icons.close),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entryKey = widget.entryKey;

    if (entryKey == null) {
      return Scaffold(
        appBar: AppBar(leading: _appBarLeading(), title: const Text('资料库')),
        body: EmptyState(
          icon: Icons.menu_book_outlined,
          title: '选择一个条目',
          message: '在此查看规则、关联条目与职业特性。',
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(leading: _appBarLeading(), title: const Text('加载中…')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final entry = _entry;
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(leading: _appBarLeading(), title: const Text('资料库')),
        body: const EmptyState(
          icon: Icons.error_outline,
          title: '条目不存在',
        ),
      );
    }

    final definition = ContentTypeRegistry.defaults().definitionFor(entry.type);
    final packageId = RuleOverrideDeclaration.packageIdOf(entry.id);

    return Scaffold(
      appBar: AppBar(
        leading: _appBarLeading(),
        title: Text(entry.name),
        actions: [
          IconButton(
            tooltip: _isFavorite ? '取消收藏' : '收藏',
            onPressed: _toggleFavorite,
            icon: Icon(_isFavorite ? Icons.bookmark : Icons.bookmark_outline),
          ),
        ],
      ),
      body: SingleChildScrollView(
        key: PageStorageKey<String>('content-detail-${entry.id}'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
            ContentEntryReader(
              entry: entry,
              packageId: packageId,
              readAsset: widget.controller.repository.readAsset,
              onOpenEntry: widget.onOpenEntry,
              showRules: false,
            ),
            if (entry.type == 'class') ...[
              ContentClassFeatureList(
                classEntry: entry,
                featureEntries: _classFeatures,
                onFeatureTap: (feature) => widget.onOpenEntry(feature.id),
              ),
              if (_subclasses.isNotEmpty)
                _ContentSubclassList(
                  subclasses: _subclasses,
                  onSubclassTap: (subclass) => widget.onOpenEntry(subclass.id),
                ),
            ],
            ContentCharacterRulesView(
              entry: entry,
              hiddenFeatureTargets: entry.type == 'class'
                  ? _classFeatures.map((feature) => feature.id).toSet()
                  : const {},
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentSubclassList extends StatelessWidget {
  const _ContentSubclassList({
    required this.subclasses,
    required this.onSubclassTap,
  });

  final List<ContentEntry> subclasses;
  final ValueChanged<ContentEntry> onSubclassTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('子职业', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final subclass in subclasses)
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: Text(subclass.name),
            subtitle: subclass.summary.isEmpty ? null : Text(subclass.summary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onSubclassTap(subclass),
          ),
      ],
    );
  }
}
