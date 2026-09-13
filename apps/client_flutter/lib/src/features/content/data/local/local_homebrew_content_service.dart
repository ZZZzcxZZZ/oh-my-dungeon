import '../../domain/content_block.dart';
import '../../domain/content_entry.dart';
import '../../domain/content_package_manifest.dart';
import '../../../rules/domain/character_rule_definition.dart';
import '../../domain/content_schema_registry.dart';
import 'content_repository.dart';

class LocalHomebrewValidationException implements Exception {
  const LocalHomebrewValidationException(this.errors);

  final List<String> errors;

  @override
  String toString() => errors.join('\n');
}

/// The single mutation boundary for user-authored compendium entries.
///
/// UI, import tools and future agent tools should call this service instead of
/// writing package rows directly.
class LocalHomebrewContentService {
  LocalHomebrewContentService({
    required ContentRepository repository,
    this.registry = ContentSchemaRegistry.defaults,
  }) : _repository = repository;

  static const packageId = 'local-homebrew';
  /// 本地自制内容包的清单行。**`formatVersion` 必须是 3**：契约只有一个包格式版本，
  /// 导出 `.dndpack` 时直接把它写进 `manifest.json`，写 1 会产出自己都导不回的包。
  static const packageManifest = ContentPackageManifest(
    formatVersion: 3,
    id: packageId,
    name: '我的自制内容',
    version: '1.0.0',
    locale: 'zh-CN',
    system: 'dnd5e-2024',
    entryCount: 0,
    contentHash: 'local-homebrew',
  );

  final ContentRepository _repository;
  final ContentSchemaRegistry registry;

  Future<ContentEntry> create({
    required String type,
    required String name,
    String summary = '',
    String description = '',
    Map<String, Object?> structured = const {},
    List<String> tags = const [],
    /// 条目自己的 `rules`（`progression` / `choices` / `grants`，契约 §3.2）。
    /// 传 `null` = 不声明；传 `{}` = 显式声明为空（清空）。
    Map<String, Object?>? rules,
  }) async {
    final validated = _validate(type: type, name: name, structured: structured);
    final slug = await _availableSlug(validated.normalizedType, name);
    final entry = _buildEntry(
      id: '$packageId:${validated.normalizedType}/$slug',
      type: validated.normalizedType,
      slug: slug,
      name: name,
      summary: summary,
      description: description,
      structured: validated.normalizedStructured,
      tags: tags,
      rules: _parseRules(rules),
      revision: 1,
    );
    await _repository.upsertPackageEntry(
      manifest: packageManifest,
      entry: entry,
    );
    return entry;
  }

  Future<ContentEntry> update({
    required ContentEntry existing,
    required String name,
    String summary = '',
    String description = '',
    Map<String, Object?> structured = const {},
    List<String> tags = const [],
    /// `null` = 保留既有 `rules`；`{}` = 清空；其余按 JSON 解析（形状非法即报错）。
    Map<String, Object?>? rules,
  }) async {
    _requireOwned(existing);
    final validated = _validate(
      type: existing.type,
      name: name,
      structured: {...existing.structured, ...structured},
    );
    final entry = _buildEntry(
      id: existing.id,
      type: validated.normalizedType,
      slug: existing.slug,
      name: name,
      summary: summary,
      description: description,
      structured: validated.normalizedStructured,
      tags: tags,
      rules: rules == null ? existing.rules : _parseRules(rules),
      revision: existing.revision + 1,
      existing: existing,
    );
    await _repository.upsertPackageEntry(
      manifest: packageManifest,
      entry: entry,
    );
    return entry;
  }

  Future<void> delete(ContentEntry entry) async {
    _requireOwned(entry);
    await _repository.deletePackageEntry(entry.id);
  }

  /// `rules` 原始 JSON → [CharacterRuleDefinition]（**唯一解析点**）。
  ///
  /// 形状非法（缺 `id`/`kind`、类型不符……）时抛
  /// [LocalHomebrewValidationException]，把底层异常原文带给作者；绝不静默丢弃
  /// `rules`——那会让作者以为"写了就生效"，而角色卡上什么都没有。
  CharacterRuleDefinition? _parseRules(Map<String, Object?>? rules) {
    if (rules == null) return null;
    try {
      return CharacterRuleDefinition.fromJson(rules);
    } catch (error) {
      throw LocalHomebrewValidationException(<String>['rules 形状不合法：$error']);
    }
  }

  ContentSchemaValidationResult _validate({
    required String type,
    required String name,
    required Map<String, Object?> structured,
  }) {
    final result = registry.validateForCreation(
      type: type,
      name: name,
      structured: structured,
    );
    if (!result.isValid) {
      throw LocalHomebrewValidationException(result.errors);
    }
    return result;
  }

  ContentEntry _buildEntry({
    required String id,
    required String type,
    required String slug,
    required String name,
    required String summary,
    required String description,
    required Map<String, Object?> structured,
    required List<String> tags,
    required int revision,
    CharacterRuleDefinition? rules,
    ContentEntry? existing,
  }) {
    final cleanDescription = description.trim();
    return ContentEntry(
      id: id,
      type: type,
      slug: slug,
      name: name.trim(),
      aliases: existing?.aliases ?? const [],
      summary: summary.trim(),
      body: [
        if (cleanDescription.isNotEmpty) ParagraphBlock(text: cleanDescription),
      ],
      structured: structured,
      tags: tags
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList(),
      source: const ContentSource(label: '我的自制内容'),
      relations: existing?.relations ?? const [],
      rules: rules,
      revision: revision,
    );
  }

  Future<String> _availableSlug(String type, String name) async {
    final base = _slugify(name);
    var candidate = base;
    var suffix = 2;
    while (await _repository.getByKey('$packageId:$type/$candidate') != null) {
      candidate = '$base-${suffix++}';
    }
    return candidate;
  }

  String _slugify(String name) {
    final slug = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[:/\\?#%]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return slug.isEmpty ? 'untitled' : slug;
  }

  void _requireOwned(ContentEntry entry) {
    if (!entry.id.startsWith('$packageId:') &&
        !entry.id.startsWith('local:$packageId:')) {
      throw const LocalHomebrewValidationException(['只能修改我的自制内容']);
    }
  }
}
