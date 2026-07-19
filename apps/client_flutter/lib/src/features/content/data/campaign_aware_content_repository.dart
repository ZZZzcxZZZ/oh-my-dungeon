import 'dart:typed_data';

import '../../campaigns/data/local/campaign_cache_repository.dart';
import '../../campaigns/domain/campaign_change.dart';
import '../domain/content_entry.dart';
import '../domain/content_package_manifest.dart';
import '../../rules/domain/character_rule_definition.dart';
import 'local/content_repository.dart';

/// 组合 [ContentRepository] 与战役缓存，对外暴露统一的只读 Wiki 查询接口。
///
/// 本地条目键前缀为 `local:`，战役条目键前缀为 `campaign:<campaignId>:`，
/// 同名条目互不覆盖。收藏与笔记仍写入个人 Vault（本地 Repository），
/// 不写战役条目服务端。
class CampaignAwareContentRepository implements ContentRepository {
  CampaignAwareContentRepository({
    required this.local,
    required this.campaign,
    required this.activeCampaignId,
  });

  final ContentRepository local;
  final CampaignCacheRepository campaign;
  final String? Function() activeCampaignId;

  static const _localPrefix = 'local:';
  static const _campaignPrefix = 'campaign:';

  String _localKey(String id) => '$_localPrefix$id';
  String _campaignKey(String campaignId, String entryId) =>
      '$_campaignPrefix$campaignId:$entryId';

  @override
  Stream<List<ContentPackageManifest>> watchPackages() => local.watchPackages();

  @override
  Future<List<ContentEntry>> search(ContentQuery query) async {
    // 查询本地时剥离 favoritesOnly 标记，由本方法统一按合并键筛选收藏。
    final localQuery = ContentQuery(
      text: query.text,
      type: query.type,
      favoritesOnly: false,
      packageId: query.packageId,
      facets: query.facets,
    );
    final localEntries = await local.search(localQuery);
    final merged = <ContentEntry>[];

    for (final entry in localEntries) {
      merged.add(_rebase(entry, _localKey(entry.id), ContentOrigin.local));
    }

    final campaignId = activeCampaignId();
    if (campaignId != null) {
      final campaignEntries = await campaign
          .watchContentEntries(campaignId)
          .first;
      for (final summary in campaignEntries) {
        if (summary.deletedAt != null) continue;
        final entry = _toContentEntry(campaignId, summary);
        if (_matchesQuery(entry, query)) {
          merged.add(entry);
        }
      }
    }

    if (query.favoritesOnly) {
      final favoritedKeys = <String>{};
      for (final entry in merged) {
        if (await local.isFavorite(entry.id)) {
          favoritedKeys.add(entry.id);
        }
      }
      merged.removeWhere((entry) => !favoritedKeys.contains(entry.id));
    }

    return merged;
  }

  @override
  Future<ContentEntry?> getByKey(String entryKey) async {
    if (entryKey.startsWith(_localPrefix)) {
      final originalKey = entryKey.substring(_localPrefix.length);
      final entry = await local.getByKey(originalKey);
      if (entry == null) return null;
      return _rebase(entry, entryKey, ContentOrigin.local);
    }
    if (entryKey.startsWith(_campaignPrefix)) {
      final rest = entryKey.substring(_campaignPrefix.length);
      final separator = rest.indexOf(':');
      if (separator <= 0 || separator == rest.length - 1) return null;
      final campaignId = rest.substring(0, separator);
      final entryId = rest.substring(separator + 1);
      final summary = await campaign.getContentEntry(campaignId, entryId);
      if (summary == null || summary.deletedAt != null) return null;
      return _toContentEntry(campaignId, summary);
    }
    return null;
  }

  @override
  Future<List<ContentLink>> outgoingLinks(String entryKey) async {
    if (entryKey.startsWith(_localPrefix)) {
      return local.outgoingLinks(entryKey.substring(_localPrefix.length));
    }
    // 战役条目不维护链接图。
    return const <ContentLink>[];
  }

  @override
  Future<List<ContentLink>> incomingLinks(String entryKey) async {
    if (entryKey.startsWith(_localPrefix)) {
      return local.incomingLinks(entryKey.substring(_localPrefix.length));
    }
    return const <ContentLink>[];
  }

  @override
  Future<Uint8List?> readAsset(String packageId, String relativePath) =>
      local.readAsset(packageId, relativePath);

  @override
  Future<void> replacePackage({
    required ContentPackageManifest manifest,
    required List<ContentEntry> entries,
    required String contentHash,
    Map<String, Uint8List> assets = const {},
  }) => local.replacePackage(
    manifest: manifest,
    entries: entries,
    contentHash: contentHash,
    assets: assets,
  );

  @override
  Future<void> setPackageEnabled(String packageId, bool enabled) =>
      local.setPackageEnabled(packageId, enabled);

  @override
  Future<bool> isPackageEnabled(String packageId) =>
      local.isPackageEnabled(packageId);

  @override
  Future<ContentDeletionImpact> deletionImpact(String packageId) =>
      local.deletionImpact(packageId);

  @override
  Future<void> deletePackage(String packageId) =>
      local.deletePackage(packageId);

  @override
  Future<int> clearAllPackages() => local.clearAllPackages();

  @override
  Future<void> setFavorite(String entryKey, bool favorite) =>
      local.setFavorite(entryKey, favorite);

  @override
  Future<bool> isFavorite(String entryKey) => local.isFavorite(entryKey);

  @override
  Future<void> saveNote(String entryKey, String markdown) =>
      local.saveNote(entryKey, markdown);

  @override
  Future<void> updateEntry(ContentEntry entry) {
    // 战役条目 (campaign: 前缀) 不支持本地编辑; 只允许本地条目.
    if (entry.id.startsWith(_localPrefix)) {
      final originalKey = entry.id.substring(_localPrefix.length);
      final rebased = _stripOrigin(entry, originalKey);
      return local.updateEntry(rebased);
    }
    if (entry.id.startsWith(_campaignPrefix)) {
      throw StateError(
        'Cannot edit campaign-scoped entry ${entry.id} locally',
      );
    }
    return local.updateEntry(entry);
  }

  @override
  Future<ContentEntry?> duplicateEntry(
    String entryKey, {
    required String newName,
  }) async {
    if (entryKey.startsWith(_localPrefix)) {
      final originalKey = entryKey.substring(_localPrefix.length);
      final duplicate = await local.duplicateEntry(
        originalKey,
        newName: newName,
      );
      if (duplicate == null) return null;
      return _rebase(duplicate, _localKey(duplicate.id), ContentOrigin.local);
    }
    // 战役条目不支持本地复制.
    return null;
  }

  /// Spec §资料库 GUI 增强: 编辑时把组合 Repository 暴露的 entryKey
  /// (带 `local:` 前缀) 还原回本地 Repository 的原始 key, 再交给本地
  /// Repository 写入. 其余字段保持不变.
  ContentEntry _stripOrigin(ContentEntry entry, String originalKey) {
    return ContentEntry(
      id: originalKey,
      type: entry.type,
      slug: entry.slug,
      name: entry.name,
      body: entry.body,
      revision: entry.revision,
      aliases: entry.aliases,
      summary: entry.summary,
      structured: entry.structured,
      tags: entry.tags,
      source: entry.source,
      relations: entry.relations,
      rules: entry.rules,
    );
  }

  ContentEntry _rebase(
    ContentEntry source,
    String newId,
    ContentOrigin origin,
  ) {
    return ContentEntry(
      id: newId,
      type: source.type,
      slug: source.slug,
      name: source.name,
      body: source.body,
      revision: source.revision,
      aliases: source.aliases,
      summary: source.summary,
      structured: source.structured,
      tags: source.tags,
      source: source.source,
      origin: origin,
      relations: [
        for (final relation in source.relations)
          ContentRelation(
            type: relation.type,
            targetId: _localKey(relation.targetId),
          ),
      ],
      rules: source.rules == null
          ? null
          : CharacterRuleDefinition.fromJson(
              _rebaseRuleReferences(source.rules!.toJson(), _localKey),
            ),
    );
  }

  ContentEntry _toContentEntry(
    String campaignId,
    CampaignContentEntrySummary summary,
  ) {
    final bodyJson = summary.entry['body'];
    final json = <String, Object?>{
      'id': _campaignKey(campaignId, summary.id),
      'type': summary.type,
      'slug': summary.slug,
      'name': summary.name,
      'body': bodyJson is List ? bodyJson : const <Map<String, Object?>>[],
      'revision': summary.revision,
      'source': {'label': '战役'},
    };
    final structuredJson = summary.entry['structured'];
    if (structuredJson is Map) {
      json['structured'] = structuredJson;
    }
    final summaryText = summary.entry['summary'];
    if (summaryText is String) {
      json['summary'] = summaryText;
    }
    final relations = summary.entry['relations'];
    if (relations is List) {
      json['relations'] = [
        for (final raw in relations.whereType<Map>())
          {
            ...Map<String, Object?>.from(raw),
            if (raw['targetId'] is String)
              'targetId': _campaignKey(campaignId, raw['targetId'] as String),
          },
      ];
    }
    final rules = summary.entry['rules'];
    if (rules is Map) {
      json['rules'] = _rebaseRuleReferences(
        Map<String, Object?>.from(rules),
        (entryId) => _campaignKey(campaignId, entryId),
      );
    }
    return ContentEntry.fromJson(json).withOrigin(ContentOrigin.campaign);
  }

  bool _matchesQuery(ContentEntry entry, ContentQuery query) {
    if (query.type != null && entry.type != query.type) return false;
    // 战役条目不属于任何资料包。
    if (query.packageId != null) return false;
    if (query.text != null && query.text!.isNotEmpty) {
      final needle = query.text!.toLowerCase();
      final hay = [
        entry.name,
        entry.summary,
        entry.source.label,
        ...entry.aliases,
        ...entry.tags,
      ].join('\n').toLowerCase();
      if (!hay.contains(needle)) return false;
    }
    return contentEntryMatchesFacets(entry, query.facets);
  }

  Map<String, Object?> _rebaseRuleReferences(
    Map<String, Object?> source,
    String Function(String entryId) rebase,
  ) {
    String rebaseOnce(String entryId) {
      if (entryId.startsWith(_localPrefix) ||
          entryId.startsWith(_campaignPrefix)) {
        return entryId;
      }
      return rebase(entryId);
    }

    Map<String, Object?> rewriteGrant(Object? raw) {
      final grant = Map<String, Object?>.from(raw! as Map);
      final entryId = grant['entryId'];
      if (entryId is String) grant['entryId'] = rebaseOnce(entryId);
      return grant;
    }

    Map<String, Object?> rewriteChoice(Object? raw) {
      final choice = Map<String, Object?>.from(raw! as Map);
      final optionIds = choice['optionEntryIds'];
      if (optionIds is List) {
        choice['optionEntryIds'] = [
          for (final id in optionIds) rebaseOnce('$id'),
        ];
      }
      final recommendedIds = choice['recommendedEntryIds'];
      if (recommendedIds is List) {
        choice['recommendedEntryIds'] = [
          for (final id in recommendedIds) rebaseOnce('$id'),
        ];
      }
      return choice;
    }

    List<Map<String, Object?>> rewriteList(
      Object? raw,
      Map<String, Object?> Function(Object? raw) rewrite,
    ) {
      if (raw is! List) return const [];
      return raw.whereType<Map>().map(rewrite).toList(growable: false);
    }

    final result = Map<String, Object?>.from(source);
    if (source['grants'] is List) {
      result['grants'] = rewriteList(source['grants'], rewriteGrant);
    }
    if (source['choices'] is List) {
      result['choices'] = rewriteList(source['choices'], rewriteChoice);
    }
    final progression = source['progression'];
    if (progression is List) {
      result['progression'] = [
        for (final rawStep in progression.whereType<Map>())
          () {
            final step = Map<String, Object?>.from(rawStep);
            if (step['grants'] is List) {
              step['grants'] = rewriteList(step['grants'], rewriteGrant);
            }
            if (step['choices'] is List) {
              step['choices'] = rewriteList(step['choices'], rewriteChoice);
            }
            return step;
          }(),
      ];
    }
    return result;
  }
}
