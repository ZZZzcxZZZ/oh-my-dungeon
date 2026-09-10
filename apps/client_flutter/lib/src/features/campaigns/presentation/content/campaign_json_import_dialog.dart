import 'package:flutter/material.dart';

import 'campaign_content_controller.dart';
import '../../../../app/theme/app_text_styles.dart';

/// JSON 导入对话框。允许粘贴单对象或数组，先本地解析预览，再逐条调用
/// [CampaignContentController.createEntry] 发布到服务器。
class CampaignJsonImportDialog extends StatefulWidget {
  const CampaignJsonImportDialog({required this.controller, super.key});

  final CampaignContentController controller;

  @override
  State<CampaignJsonImportDialog> createState() =>
      _CampaignJsonImportDialogState();
}

class _CampaignJsonImportDialogState extends State<CampaignJsonImportDialog> {
  final _textController = TextEditingController();
  List<Map<String, Object?>>? _preview;
  String? _parseError;
  bool _importing = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _previewJson() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _preview = null;
        _parseError = '请粘贴 JSON 内容';
      });
      return;
    }
    final parsed = widget.controller.parseImportJson(text);
    setState(() {
      if (parsed.isEmpty) {
        _preview = null;
        _parseError = 'JSON 解析失败，请检查格式';
      } else {
        _preview = parsed;
        _parseError = null;
      }
    });
  }

  Future<void> _importAll() async {
    final entries = _preview;
    if (entries == null || entries.isEmpty) return;
    setState(() => _importing = true);
    var successCount = 0;
    var failCount = 0;
    for (final entry in entries) {
      final success = await widget.controller.createEntry(
        type: entry['type']?.toString() ?? '',
        name: entry['name']?.toString() ?? '',
        entry: entry['entry'] is Map
            ? Map<String, Object?>.from(entry['entry'] as Map)
            : <String, Object?>{'body': <Map<String, Object?>>[]},
      );
      if (success) {
        successCount++;
      } else {
        failCount++;
      }
    }
    if (!mounted) return;
    setState(() => _importing = false);
    if (failCount == 0) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('成功导入 $successCount 个条目')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入 $successCount 个成功，$failCount 个失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      key: const Key('campaign-json-import-dialog'),
      title: const Text('导入 JSON'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('json-import-text-field'),
                controller: _textController,
                decoration: const InputDecoration(
                  hintText: '粘贴单个对象或数组 JSON',
                  isDense: true,
                ),
                maxLines: 8,
                style: AppTextStyles.monoCode(Theme.of(context).textTheme),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('json-import-preview-button'),
                  icon: const Icon(Icons.preview_outlined, size: 18),
                  label: const Text('预览'),
                  onPressed: _previewJson,
                ),
              ),
              if (_parseError != null) ...[
                Text(_parseError!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.error)),
              ],
              if (_preview != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${_preview!.length} 个条目',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                ...(_preview!.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry['name']?.toString() ?? '(未命名)',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          entry['type']?.toString() ?? '?',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _importing ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _preview == null || _importing ? null : _importAll,
          child: const Text('导入'),
        ),
      ],
    );
  }
}
