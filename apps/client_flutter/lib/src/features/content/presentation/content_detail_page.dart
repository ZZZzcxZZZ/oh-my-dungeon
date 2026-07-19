import 'package:flutter/material.dart';

import '../data/local/content_repository.dart';
import '../domain/content_entry.dart';
import 'content_library_controller.dart';
import 'content_type_registry.dart';
import 'widgets/content_class_feature_list.dart';
import 'widgets/content_character_rules_view.dart';
import 'widgets/content_entry_reader.dart';

class ContentDetailPage extends StatefulWidget {
  const ContentDetailPage({
    required this.entryKey,
    required this.controller,
    required this.onOpenEntry,
    required this.onImportRequested,
    this.onClose,
    super.key,
  });

  final String? entryKey;
  final ContentLibraryController controller;
  final ValueChanged<String> onOpenEntry;
  final VoidCallback onImportRequested;
  final VoidCallback? onClose;

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
    await widget.controller.repository.saveNote(entryKey, _noteController.text);
  }

  /// Spec §资料库 GUI 增强: 编辑条目名称、摘要等可变字段, 保留 id/slug/type.
  /// 入口在 AppBar 编辑按钮, 仅本地条目可编辑. 保存时调用 repository
  /// .updateEntry, 自动 +1 revision 防止与远端同步混淆.
  Future<void> _showEditDialog() async {
    final entry = _entry;
    if (entry == null) return;
    final nameController = TextEditingController(text: entry.name);
    final summaryController = TextEditingController(text: entry.summary);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('编辑条目'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('content-edit-name-field'),
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '名称'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('content-edit-summary-field'),
                  controller: summaryController,
                  decoration: const InputDecoration(labelText: '摘要'),
                  minLines: 2,
                  maxLines: 5,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    // 在 dialog 关闭动画结束前不要 dispose controller, 否则
    // dialog 退出动画期间 TextField 仍会访问已 dispose 的 controller.
    // 局部 controller 在 dialog 退出动画完成后会自动被 GC.
    if (confirmed != true || !mounted) {
      return;
    }
    final newName = nameController.text.trim();
    final newSummary = summaryController.text.trim();

    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('名称不能为空')),
      );
      return;
    }
    final updated = ContentEntry.fromJson({
      ...entry.toJson(),
      'name': newName,
      'summary': newSummary,
      'revision': entry.revision + 1,
    });
    try {
      await widget.controller.repository.updateEntry(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存修改')),
        );
        await _loadEntry();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $error')),
        );
      }
    }
  }

  /// Spec §资料库 GUI 增强: 复制条目. 在同一资料包内创建一个新条目,
  /// slug 自动加 -copy 后缀, name 由用户输入. 仅本地条目可复制.
  Future<void> _showDuplicateDialog() async {
    final entry = _entry;
    if (entry == null) return;
    final nameController = TextEditingController(text: '${entry.name}（副本）');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('复制条目'),
          content: TextField(
            key: const Key('content-duplicate-name-field'),
            controller: nameController,
            decoration: const InputDecoration(
              labelText: '新条目名称',
              hintText: '例如: 火球术（家规副本）',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('创建副本'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final newName = nameController.text.trim();
    if (newName.isEmpty) return;
    try {
      final duplicate = await widget.controller.repository.duplicateEntry(
        entry.id,
        newName: newName,
      );
      if (!mounted) return;
      if (duplicate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('复制失败: 找不到源条目')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已创建副本: ${duplicate.name}')),
      );
      widget.onOpenEntry(duplicate.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('复制失败: $error')),
        );
      }
    }
  }

  Widget? _appBarLeading() {
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final entryKey = widget.entryKey;

    if (entryKey == null) {
      return Scaffold(
        appBar: AppBar(leading: _appBarLeading(), title: const Text('资料库')),
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
                Text('在此查看规则、关联条目与职业特性。', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
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
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: colorScheme.outline),
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
    // Spec §资料库 GUI 增强: 只允许编辑本地条目, 战役条目只读.
    final canEdit = entry.origin == ContentOrigin.local;

    return Scaffold(
      appBar: AppBar(
        leading: _appBarLeading(),
        title: Text(entry.name),
        actions: [
          if (canEdit)
            IconButton(
              key: const Key('content-detail-edit'),
              tooltip: '编辑条目',
              onPressed: _showEditDialog,
              icon: const Icon(Icons.edit_outlined),
            ),
          if (canEdit)
            IconButton(
              key: const Key('content-detail-duplicate'),
              tooltip: '复制条目',
              onPressed: _showDuplicateDialog,
              icon: const Icon(Icons.content_copy_outlined),
            ),
          IconButton(
            tooltip: _isFavorite ? '取消收藏' : '收藏',
            onPressed: _toggleFavorite,
            icon: Icon(_isFavorite ? Icons.bookmark : Icons.bookmark_outline),
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
            ContentEntryReader(
              entry: entry,
              packageId: packageId,
              readAsset: widget.controller.repository.readAsset,
              onOpenEntry: widget.onOpenEntry,
              showRules: false,
            ),
            if (entry.type == 'class')
              ContentClassFeatureList(
                classEntry: entry,
                featureEntries: _classFeatures,
                onFeatureTap: (feature) => widget.onOpenEntry(feature.id),
              ),
            ContentCharacterRulesView(entry: entry),
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
