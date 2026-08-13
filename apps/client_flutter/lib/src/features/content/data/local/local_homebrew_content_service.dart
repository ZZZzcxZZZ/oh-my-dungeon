import '../../domain/content_block.dart';
import '../../domain/content_entry.dart';
import '../../domain/content_package_manifest.dart';
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
  static const packageManifest = ContentPackageManifest(
    formatVersion: 1,
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
      rules: existing?.rules,
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
