import 'package:flutter/material.dart';

import 'campaign_content_controller.dart';

/// 战役资料条目编辑器。只展示类型、名称、slug 和摘要，不展示 package、
/// dependency、overlay 或 patch 概念。保存时调用 [CampaignContentController.createEntry]。
class CampaignContentEditor extends StatefulWidget {
  const CampaignContentEditor({
    required this.controller,
    super.key,
  });

  final CampaignContentController controller;

  @override
  State<CampaignContentEditor> createState() => _CampaignContentEditorState();
}

class _CampaignContentEditorState extends State<CampaignContentEditor> {
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _summaryController = TextEditingController();
  String _type = 'location';
  bool _saving = false;

  static const _typeOptions = <String, String>{
    'location': '地点',
    'npc': 'NPC',
    'monster': '怪物',
    'item': '物品',
    'quest': '任务',
    'note': '笔记',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final slug = _slugController.text.trim();
    if (name.isEmpty || slug.isEmpty) return;
    setState(() => _saving = true);
    final entry = <String, Object?>{
      'body': <Map<String, Object?>>[
        {'type': 'paragraph', 'text': _summaryController.text},
      ],
    };
    final success = await widget.controller.createEntry(
      type: _type,
      slug: slug,
      name: name,
      entry: entry,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存失败，请稍后重试')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('campaign-content-editor'),
      title: const Text('新建条目'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownMenu<String>(
              key: const Key('editor-type-dropdown'),
              initialSelection: _type,
              label: const Text('类型'),
              dropdownMenuEntries: _typeOptions.entries
                  .map(
                    (e) => DropdownMenuEntry(
                      value: e.key,
                      label: e.value,
                    ),
                  )
                  .toList(),
              onSelected: (value) {
                if (value != null) {
                  setState(() => _type = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('editor-field-name'),
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '名称',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('editor-field-slug'),
              controller: _slugController,
              decoration: const InputDecoration(
                labelText: 'Slug（唯一标识）',
                border: OutlineInputBorder(),
                isDense: true,
                hintText: '如 moon-harbor',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _summaryController,
              decoration: const InputDecoration(
                labelText: '摘要',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
