import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/local/local_homebrew_content_service.dart';
import '../domain/content_block.dart';
import '../domain/content_entry.dart';
import '../domain/content_entry_id.dart';
import 'homebrew_class_rule_form.dart';

/// 作者 GUI 的一次提交（S4）：`structured` 与 `rules` 都按作者写的 JSON 传出去，
/// 由 [LocalHomebrewContentService] 负责解析、校验与落库。
class HomebrewEntryDraft {
  const HomebrewEntryDraft({
    required this.type,
    required this.name,
    required this.summary,
    required this.description,
    required this.structured,
    required this.rules,
  });

  final String type;
  final String name;
  final String summary;
  final String description;
  final Map<String, Object?> structured;

  /// `null` = 不声明 `rules`（编辑既有条目时表示"保留原值"）。
  final Map<String, Object?>? rules;
}

/// 自制条目的新建 / 编辑对话框（S4 的作者 GUI）。
///
/// 定位：**契约 JSON 的可视化外壳**。它做四件必须做好的事：
/// 1. 类型从 `ContentSchemaRegistry.creatableSchemas` 选（不手写字符串）；
/// 2. `class` 类型默认进 [HomebrewClassRuleForm]（`classRules` + `progression` 填表），
///    其余形状与 `rules.choices` 切到 JSON 编辑，**边写边校验**（解析错误、schema
///    错误、服务层错误都就地显示，不弹 SnackBar 让人找不到字段）；
/// 3. `overrideOf` 非空 = 基于既有条目创建覆盖（类型锁定、对齐键钉住）；
/// 4. 保存走 [LocalHomebrewContentService]（唯一写入边界），失败保持在对话框里。
///
/// `rules.choices` 的可视化编辑仍是后续工作，见规格 §11.4。
class HomebrewEntryEditorDialog extends StatefulWidget {
  const HomebrewEntryEditorDialog({
    required this.service,
    this.existing,
    this.overrideOf,
    super.key,
  });

  final LocalHomebrewContentService service;

  /// 非空 = 编辑模式（类型不可改，`rules` 留空表示保留原值）。
  final ContentEntry? existing;

  /// 非空 = 「基于已有条目创建覆盖」（S4）：类型锁定为来源条目的类型，对齐键
  /// （id 末段，契约 D3）钉在来源上，写入走
  /// `LocalHomebrewContentService.create(overrideOf:)`。
  final ContentEntry? overrideOf;

  /// 预填来源：编辑既有条目优先，其次是"要覆盖的那一条"。
  ContentEntry? get source => existing ?? overrideOf;

  @override
  State<HomebrewEntryEditorDialog> createState() =>
      _HomebrewEntryEditorDialogState();
}

class _HomebrewEntryEditorDialogState extends State<HomebrewEntryEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _summary;
  late final TextEditingController _description;
  late final TextEditingController _structured;
  late final TextEditingController _rules;
  late String _type;
  List<String> _errors = const [];
  bool _saving = false;

  /// 「表单 / JSON」开关（仅 `class` 类型）。表单不持有状态，写回的是同两段 JSON。
  bool _visualForm = true;

  bool get _isEditing => widget.existing != null;

  bool get _isOverride => widget.overrideOf != null;

  /// 编辑与覆盖都不允许改类型：前者类型是条目身份，后者必须与来源同类型才能对齐。
  bool get _typeLocked => _isEditing || _isOverride;

  @override
  void initState() {
    super.initState();
    final source = widget.source;
    final creatable = widget.service.registry.creatableSchemas
        .map((schema) => schema.type)
        .toList(growable: false);
    _type = source?.type ?? (creatable.isEmpty ? '' : creatable.first);
    _name = TextEditingController(text: source?.name ?? '');
    _summary = TextEditingController(text: source?.summary ?? '');
    _description = TextEditingController(
      text: source == null ? '' : _descriptionOf(source),
    );
    _structured = TextEditingController(
      text: source == null
          ? '{}'
          : const JsonEncoder.withIndent('  ').convert(source.structured),
    );
    _rules = TextEditingController(
      text: source?.rules == null
          ? '{}'
          : const JsonEncoder.withIndent('  ').convert(source!.rules!.toJson()),
    );
  }

  static String _descriptionOf(ContentEntry entry) => entry.body
      .whereType<ParagraphBlock>()
      .map((block) => block.text)
      .join('\n\n');

  @override
  void dispose() {
    _name.dispose();
    _summary.dispose();
    _description.dispose();
    _structured.dispose();
    _rules.dispose();
    super.dispose();
  }

  /// JSON 文本框 → Map；`{}` / 空 = 空表；非法 JSON 记为错误（不抛）。
  Map<String, Object?>? _parseJson(
    TextEditingController controller,
    String label,
    List<String> errors,
  ) {
    final raw = controller.text.trim();
    if (raw.isEmpty) return const <String, Object?>{};
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      errors.add('$label 不是合法 JSON：${error.message}');
      return null;
    }
    if (decoded is! Map) {
      errors.add('$label 必须是 JSON 对象（形如 { … }）');
      return null;
    }
    return Map<String, Object?>.from(decoded);
  }

  Future<void> _save() async {
    final errors = <String>[];
    final structured = _parseJson(_structured, 'structured', errors);
    final rules = _parseJson(_rules, 'rules', errors);
    if (errors.isNotEmpty || structured == null || rules == null) {
      setState(() => _errors = errors);
      return;
    }
    setState(() {
      _saving = true;
      _errors = const [];
    });
    try {
      final existing = widget.existing;
      if (existing == null) {
        await widget.service.create(
          type: _type,
          name: _name.text,
          summary: _summary.text,
          description: _description.text,
          structured: structured,
          rules: rules,
          overrideOf: widget.overrideOf,
        );
      } else {
        await widget.service.update(
          existing: existing,
          name: _name.text,
          summary: _summary.text,
          description: _description.text,
          structured: structured,
          rules: rules,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on LocalHomebrewValidationException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errors = error.errors;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errors = <String>['保存失败：$error'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final creatable = widget.service.registry.creatableSchemas.toList(
      growable: false,
    );
    final source = widget.source;
    return AlertDialog(
      title: Text(
        _isEditing
            ? '编辑自制条目'
            : _isOverride
            ? '创建覆盖：${source?.name ?? ''}'
            : '新建自制条目',
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isOverride)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '对齐键「${contentEntryAlignmentKey(source?.id ?? '')}」已钉在来源条目上：'
                    '本地包 tier 100 高于内置 0，声明过的列按契约 §3.6 覆盖来源，'
                    '未声明的列仍用来源的值。\n'
                    '注意：列级合并链只消费 classRules；本条目自己的 rules（progression / '
                    'choices / grants）只有在角色**直接指向本条目**时才生效——仍指向来源'
                    '条目的角色读不到它们。',
                    key: const Key('homebrew-entry-override-hint'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              DropdownButtonFormField<String>(
                key: const Key('homebrew-entry-type'),
                initialValue: _type.isEmpty ? null : _type,
                decoration: const InputDecoration(labelText: '类型'),
                items: [
                  for (final schema in creatable)
                    DropdownMenuItem(
                      value: schema.type,
                      child: Text('${schema.label}（${schema.type}）'),
                    ),
                ],
                onChanged: _typeLocked
                    ? null
                    : (value) => setState(() => _type = value ?? _type),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('homebrew-entry-name'),
                controller: _name,
                decoration: const InputDecoration(labelText: '名称'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('homebrew-entry-summary'),
                controller: _summary,
                decoration: const InputDecoration(labelText: '一句话摘要（可选）'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('homebrew-entry-description'),
                controller: _description,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '描述（可选）'),
              ),
              const SizedBox(height: 16),
              if (_type == 'class') ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '职业规则（可视化表单 / JSON）',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    SegmentedButton<bool>(
                      key: const Key('homebrew-entry-editor-mode'),
                      segments: const [
                        ButtonSegment(value: true, label: Text('表单')),
                        ButtonSegment(value: false, label: Text('JSON')),
                      ],
                      selected: <bool>{_visualForm},
                      onSelectionChanged: (selection) =>
                          setState(() => _visualForm = selection.first),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (_type == 'class' && _visualForm)
                HomebrewClassRuleForm(
                  structuredJson: () => _structured.text,
                  rulesJson: () => _rules.text,
                  onChanged: (structured, rules) => setState(() {
                    _structured.text = structured;
                    _rules.text = rules;
                  }),
                )
              else ...[
                Text('structured（契约 §9.2：数值与枚举）',
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                TextField(
                  key: const Key('homebrew-entry-structured'),
                  controller: _structured,
                  minLines: 6,
                  maxLines: 12,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                Text('rules（可选：progression / choices / grants）',
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                TextField(
                  key: const Key('homebrew-entry-rules'),
                  controller: _rules,
                  minLines: 6,
                  maxLines: 12,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                ),
              ],
              if (_errors.isNotEmpty) ...[
                const SizedBox(height: 12),
                Column(
                  key: const Key('homebrew-entry-errors'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final error in _errors)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 16,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                error,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('homebrew-entry-save'),
          onPressed: _saving ? null : _save,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
