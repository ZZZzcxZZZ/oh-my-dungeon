import 'package:flutter/material.dart';

import '../../domain/campaign_archive_entry.dart';

/// 编辑器提交时收集的草稿。包含全部七个字段：类型、标题、摘要、
/// 正文 blocks、标签、关联条目 ID、附件引用（占位）。
///
/// Plan 2026-07-23 task 4.4: 合并原 `_showCreateArchiveDialog`（campaign
/// center FAB）与 `CampaignArchiveCreateDialog`（chat 工具栏）两套表单，
/// 统一通过 [CampaignArchiveEditorPage] 收集草稿后交给调用方的 `onSubmit`。
class CampaignArchiveDraft {
  const CampaignArchiveDraft({
    required this.kind,
    required this.title,
    required this.summary,
    this.bodyBlocks = const [],
    this.tags = const [],
    this.linkedEntryIds = const [],
  });

  final String kind;
  final String title;
  final String summary;
  final List<Map<String, Object?>> bodyBlocks;
  final List<String> tags;
  final List<String> linkedEntryIds;
}

/// 单一的战役档案创建/编辑页面。Plan 2026-07-23 task 4.4。
///
/// 字段顺序参考 D&D Beyond wiki entry 编辑器：
/// 1. 类型（DropdownButtonFormField，4 选）
/// 2. 标题（必填，autofocus）
/// 3. 摘要（minLines 2, maxLines 3）
/// 4. 正文（块编辑器：heading/paragraph/list，每块独立卡片）
/// 5. 标签（Chip 输入：输入文本 + 回车添加，已加标签 FilterChip 可删除）
/// 6. 关联条目（多选，从战役档案其他条目选取）
/// 7. 附件引用（占位，未来对接文件上传）
///
/// 字段间距统一 `SizedBox(height: 16)`，提交按钮为全宽 `FilledButton`。
/// 调用方通过 [onSubmit] 接收草稿，返回 `true` 时页面关闭。
class CampaignArchiveEditorPage extends StatefulWidget {
  const CampaignArchiveEditorPage({
    required this.initialKind,
    required this.onSubmit,
    this.existingEntries = const [],
    super.key,
  });

  /// 初始类型。来自 FAB 菜单选择或聊天工具栏预设。
  final String initialKind;

  /// 提交回调。返回 `true` 表示创建成功（页面关闭），`false` 表示失败
  /// （页面停留并显示错误）。
  final Future<bool> Function(CampaignArchiveDraft draft) onSubmit;

  /// 当前战役中已有的档案条目，用于关联条目多选。可空。
  final List<CampaignArchiveEntry> existingEntries;

  @override
  State<CampaignArchiveEditorPage> createState() =>
      _CampaignArchiveEditorPageState();
}

class _CampaignArchiveEditorPageState
    extends State<CampaignArchiveEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _tagInputController = TextEditingController();

  late String _kind = widget.initialKind;
  final List<_BodyBlockDraft> _blocks = [];
  final List<String> _tags = [];
  final Set<String> _linkedEntryIds = {};
  bool _submitting = false;

  static const List<({String value, String label})> _kindOptions = [
    (value: 'document', label: '资料'),
    (value: 'location', label: '地点'),
    (value: 'clue', label: '线索'),
    (value: 'file', label: '文件'),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _tagInputController.dispose();
    for (final block in _blocks) {
      block.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('新建战役条目')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          // SingleChildScrollView + Column (not ListView) so every field
          // section is always built — tests can assert on off-screen labels
          // without manual scrolling, and the form is short enough that lazy
          // building brings no real benefit.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildKindField(theme),
                const SizedBox(height: 16),
                _buildTitleField(theme),
                const SizedBox(height: 16),
                _buildSummaryField(theme),
                const SizedBox(height: 16),
                _buildBodySection(theme),
                const SizedBox(height: 16),
                _buildTagsSection(theme),
                const SizedBox(height: 16),
                _buildLinksSection(theme),
                const SizedBox(height: 16),
                _buildAttachmentPlaceholder(theme),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      // Submit button stays pinned at the bottom so it is always reachable
      // regardless of form length. Plan 2026-07-23 task 4.4: 全宽 FilledButton.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildSubmitButton(),
        ),
      ),
    );
  }

  Widget _buildKindField(ThemeData theme) {
    return DropdownButtonFormField<String>(
      initialValue: _kind,
      decoration: const InputDecoration(labelText: '类型'),
      items: [
        for (final option in _kindOptions)
          DropdownMenuItem(value: option.value, child: Text(option.label)),
      ],
      onChanged: (value) => setState(() => _kind = value ?? _kind),
    );
  }

  Widget _buildTitleField(ThemeData theme) {
    return TextFormField(
      controller: _titleController,
      autofocus: true,
      decoration: const InputDecoration(labelText: '标题'),
      textInputAction: TextInputAction.next,
      validator: (value) =>
          value == null || value.trim().isEmpty ? '请输入标题' : null,
    );
  }

  Widget _buildSummaryField(ThemeData theme) {
    return TextFormField(
      controller: _summaryController,
      decoration: const InputDecoration(labelText: '摘要'),
      minLines: 2,
      maxLines: 3,
    );
  }

  Widget _buildBodySection(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('正文', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        for (int i = 0; i < _blocks.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _BodyBlockCard(
              key: ValueKey('archive-editor-block-$i'),
              index: i,
              block: _blocks[i],
              onRemove: () => setState(() {
                _blocks[i].dispose();
                _blocks.removeAt(i);
              }),
            ),
          ),
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              label: const Text('添加段落'),
              avatar: const Icon(Icons.notes, size: 18),
              onPressed: () => setState(() {
                _blocks.add(_BodyBlockDraft(type: 'paragraph'));
              }),
            ),
            ActionChip(
              label: const Text('添加标题'),
              avatar: const Icon(Icons.title, size: 18),
              onPressed: () => setState(() {
                _blocks.add(_BodyBlockDraft(type: 'heading'));
              }),
            ),
            ActionChip(
              label: const Text('添加列表'),
              avatar: const Icon(Icons.list, size: 18),
              onPressed: () => setState(() {
                _blocks.add(_BodyBlockDraft(type: 'list'));
              }),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '每个块独立编辑；列表块用换行分隔条目',
          style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildTagsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('标签', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        if (_tags.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in _tags)
                Chip(
                  label: Text(tag),
                  onDeleted: () => setState(() => _tags.remove(tag)),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          key: const Key('archive-editor-tag-input'),
          controller: _tagInputController,
          decoration: InputDecoration(
            labelText: '添加标签',
            hintText: '输入后回车添加',
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addTag,
            ),
          ),
          onSubmitted: (_) => _addTag(),
        ),
      ],
    );
  }

  void _addTag() {
    final text = _tagInputController.text.trim();
    if (text.isEmpty) return;
    if (_tags.contains(text)) {
      _tagInputController.clear();
      return;
    }
    setState(() {
      _tags.add(text);
      _tagInputController.clear();
    });
  }

  Widget _buildLinksSection(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    if (widget.existingEntries.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('关联条目', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            '当前战役暂无其他档案可关联',
            style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('关联条目', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          '勾选要关联的档案条目',
          style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        for (final entry in widget.existingEntries)
          CheckboxListTile(
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: _linkedEntryIds.contains(entry.id),
            onChanged: (selected) => setState(() {
              if (selected == true) {
                _linkedEntryIds.add(entry.id);
              } else {
                _linkedEntryIds.remove(entry.id);
              }
            }),
            title: Text(entry.title),
            subtitle: Text(_kindLabel(entry.kind)),
          ),
      ],
    );
  }

  Widget _buildAttachmentPlaceholder(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('附件引用', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          '附件上传功能即将推出',
          style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return FilledButton(
      onPressed: _submitting ? null : _submit,
      child: const Text('创建'),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final draft = CampaignArchiveDraft(
      kind: _kind,
      title: _titleController.text.trim(),
      summary: _summaryController.text.trim(),
      bodyBlocks: _blocks.map((b) => b.toJson()).toList(growable: false),
      tags: List<String>.unmodifiable(_tags),
      linkedEntryIds: _linkedEntryIds.toList(),
    );
    final ok = await widget.onSubmit(draft);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('创建失败，请重试')),
      );
    }
  }

  String _kindLabel(String kind) {
    for (final option in _kindOptions) {
      if (option.value == kind) return option.label;
    }
    return kind;
  }
}

/// 正文块草稿。每个块有类型（heading/paragraph/list）与文本内容。
/// 列表块的文本用换行分隔条目。
class _BodyBlockDraft {
  _BodyBlockDraft({required this.type});

  String type;
  final TextEditingController controller = TextEditingController();

  Map<String, Object?> toJson() {
    final text = controller.text.trim();
    if (type == 'list') {
      final items = text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      return {'type': 'list', 'items': items};
    }
    return {'type': type, 'text': text};
  }

  void dispose() => controller.dispose();
}

/// 单个正文块卡片。显示类型标签、文本输入与删除按钮。
class _BodyBlockCard extends StatelessWidget {
  const _BodyBlockCard({
    required this.index,
    required this.block,
    required this.onRemove,
    super.key,
  });

  final int index;
  final _BodyBlockDraft block;
  final VoidCallback onRemove;

  static const _typeLabels = {
    'paragraph': '段落',
    'heading': '标题',
    'list': '列表',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _typeLabels[block.type] ?? block.type,
                    style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                        ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: '删除块',
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: Key('archive-editor-block-$index-text'),
              controller: block.controller,
              decoration: InputDecoration(
                labelText: block.type == 'list' ? '每行一个条目' : '内容',
                alignLabelWithHint: true,
              ),
              minLines: block.type == 'heading' ? 1 : 2,
              maxLines: block.type == 'list' ? 5 : 3,
            ),
          ],
        ),
      ),
    );
  }
}
