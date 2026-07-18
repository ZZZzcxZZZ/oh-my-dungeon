import 'package:flutter/material.dart';

class CampaignArchiveDraft {
  const CampaignArchiveDraft({
    required this.kind,
    required this.title,
    required this.summary,
  });

  final String kind;
  final String title;
  final String summary;
}

class CampaignArchiveCreateDialog extends StatefulWidget {
  const CampaignArchiveCreateDialog({required this.initialKind, super.key});

  final String initialKind;

  @override
  State<CampaignArchiveCreateDialog> createState() =>
      _CampaignArchiveCreateDialogState();
}

class _CampaignArchiveCreateDialogState
    extends State<CampaignArchiveCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  late String _kind = widget.initialKind;

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建战役条目'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: '类型'),
                items: const [
                  DropdownMenuItem(value: 'clue', child: Text('线索')),
                  DropdownMenuItem(value: 'location', child: Text('地点')),
                  DropdownMenuItem(value: 'document', child: Text('文档')),
                  DropdownMenuItem(value: 'file', child: Text('文件')),
                ],
                onChanged: (value) => setState(() => _kind = value ?? _kind),
              ),
              TextFormField(
                controller: _titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: '名称'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入名称' : null,
              ),
              TextField(
                controller: _summaryController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '说明（可选）'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('创建')),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      CampaignArchiveDraft(
        kind: _kind,
        title: _titleController.text.trim(),
        summary: _summaryController.text.trim(),
      ),
    );
  }
}
