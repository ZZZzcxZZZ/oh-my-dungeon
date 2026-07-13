import 'package:flutter/material.dart';

import '../../domain/content.dart';

class ContentClassFeatureList extends StatelessWidget {
  const ContentClassFeatureList({
    required this.item,
    this.links = const [],
    this.onLinkTap,
    super.key,
  });

  final ContentItem item;
  final List<ContentItemLink> links;
  final ValueChanged<ContentItemLink>? onLinkTap;

  @override
  Widget build(BuildContext context) {
    final structured = item.structured;
    if (structured is! Map || structured['levelFeatures'] is! List) {
      return const SizedBox.shrink();
    }

    final grouped = <int, List<Map>>{};
    for (final raw in structured['levelFeatures'] as List) {
      if (raw is! Map) continue;
      final level = raw['level'] is num ? (raw['level'] as num).toInt() : 0;
      grouped.putIfAbsent(level, () => []).add(raw);
    }
    final levels = grouped.keys.toList()..sort();
    if (levels.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text('等级特性', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final level in levels)
          ExpansionTile(
            title: Text(level > 0 ? '等级 $level' : '未分级特性'),
            children: [
              for (final feature in grouped[level]!)
                ListTile(
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: Text('${feature['name'] ?? '职业特性'}'),
                  subtitle: feature['summary'] == null
                      ? null
                      : Text('${feature['summary']}'),
                  trailing: _linkForFeature(feature) == null
                      ? null
                      : const Icon(Icons.chevron_right),
                  onTap: _linkForFeature(feature) == null
                      ? null
                      : () => onLinkTap?.call(_linkForFeature(feature)!),
                ),
            ],
          ),
      ],
    );
  }

  ContentItemLink? _linkForFeature(Map feature) {
    final name = '${feature['name'] ?? ''}';
    final slug = '${feature['slug'] ?? ''}';
    for (final link in links) {
      if (link.label == name || link.target.name == name) return link;
      if (slug.isNotEmpty && link.target.slug == slug) return link;
    }
    return null;
  }
}
