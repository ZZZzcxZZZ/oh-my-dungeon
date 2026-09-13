import '../../domain/content_block.dart';
import '../../domain/content_entry.dart';
import '../../domain/content_entry_id.dart';
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
    /// 基于某条既有条目创建**覆盖**（S4）：新条目的对齐键（id 末段，契约 D3）钉在
    /// 来源条目上，类型也随之取来源条目的类型。**不再**按名称生成 slug——否则作者
    /// 改个名字就对不上来源，覆盖链永远不生效。
    ContentEntry? overrideOf,
  }) async {
    if (overrideOf != null && type != overrideOf.type) {
      throw LocalHomebrewValidationException(<String>[
        '覆盖的 type 必须与来源一致（来源 ${overrideOf.type}，收到 $type）',
      ]);
    }
    final alignmentKey = overrideOf == null
        ? null
        : contentEntryAlignmentKey(overrideOf.id);
    if (alignmentKey != null && alignmentKey.isEmpty) {
      throw const LocalHomebrewValidationException(['覆盖来源的条目标识为空']);
    }
    final validated = _validate(
      type: overrideOf?.type ?? type,
      name: name,
      structured: structured,
    );
    // 「覆盖」必须真的参与列级合并链：只收 `structured.classRules` 是映射的条目
    // （§3.8）。清空/不声明 classRules 的产物只会占住对齐键却什么都不覆盖——
    // 作者以为生效了，实际链上根本没有它。
    final overrideClassRules = validated.normalizedStructured['classRules'];
    if (overrideOf != null &&
        (overrideClassRules is! Map || overrideClassRules.isEmpty)) {
      throw const LocalHomebrewValidationException(<String>[
        '覆盖必须声明 classRules：否则它不参与列级合并链（契约 §3.8）',
      ]);
    }
    final taken = await _takenEntryIds();
    final slug = alignmentKey ?? _availableSlug(validated.normalizedType, name, taken);
    final id = '$packageId:${validated.normalizedType}/$slug';
    if (taken.contains(id)) {
      throw LocalHomebrewValidationException(<String>[
        alignmentKey != null
            ? '已存在同键条目 $id：直接编辑它即可，不要再建一条覆盖'
            : '条目 $id 已存在：请换一个名称',
      ]);
    }
    final entry = _buildEntry(
      id: id,
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
    return ContentEntry(
      id: id,
      type: type,
      slug: slug,
      name: name.trim(),
      aliases: existing?.aliases ?? const [],
      summary: summary.trim(),
      body: _mergedBody(existing: existing, description: description.trim()),
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

  /// `description` 只是**段落文本**，而 `body` 还能装标题、列表、表格等块。
  ///
  /// 编辑既有条目时必须把描述框承载不了的块原样留下：那些块在 GUI 里看不见，
  /// 一旦丢弃，作者"改个名字再保存"就静默删掉了自己的富文本。段落则折叠成
  /// 这一个描述框——替换第一个旧段落的位置（没有旧段落就追加到末尾），其余块
  /// 保持原有顺序；描述清空 = 删掉全部段落、仅保留其它块。
  static List<ContentBlock> _mergedBody({
    required ContentEntry? existing,
    required String description,
  }) {
    final replacement = description.isEmpty
        ? null
        : ParagraphBlock(text: description);
    final body = <ContentBlock>[];
    var placed = false;
    for (final block in existing?.body ?? const <ContentBlock>[]) {
      if (block is ParagraphBlock) {
        if (!placed) {
          if (replacement != null) body.add(replacement);
          placed = true;
        }
        continue;
      }
      body.add(block);
    }
    if (!placed && replacement != null) body.add(replacement);
    return body;
  }

  /// 本包**已占用的条目 id**（规范形式，已剥传输前缀）。
  ///
  /// 不能用 `getByKey('$packageId:…')`：生产装配注入的是
  /// `CampaignAwareContentRepository`，它只解析 `local:` / `campaign:<cid>:` 前缀键，
  /// 无前缀键一律返回 null。那样"重名后缀"与"同键覆盖检测"会双双失效——重名直接
  /// 覆盖前一条（数据丢失）、同键覆盖静默替换。用 `search` + 规范 id 比较，与仓储
  /// 边界无关。
  Future<Set<String>> _takenEntryIds() async {
    final entries = await _repository.search(
      const ContentQuery(packageId: packageId),
    );
    return <String>{
      for (final entry in entries) canonicalContentEntryId(entry.id),
    };
  }

  String _availableSlug(String type, String name, Set<String> taken) {
    final base = _slugify(name);
    var candidate = base;
    var suffix = 2;
    while (taken.contains('$packageId:$type/$candidate')) {
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
