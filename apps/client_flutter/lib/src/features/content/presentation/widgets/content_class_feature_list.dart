import 'package:flutter/material.dart';

import '../../domain/content_entry.dart';

class ContentClassFeatureList extends StatelessWidget {
  const ContentClassFeatureList({
    required this.classEntry,
    this.featureEntries = const [],
    this.onFeatureTap,
    super.key,
  });

  final ContentEntry classEntry;
  final List<ContentEntry> featureEntries;
  final ValueChanged<ContentEntry>? onFeatureTap;

  @override
  Widget build(BuildContext context) {
    if (featureEntries.isEmpty) return const SizedBox.shrink();

    final grouped = <int, List<ContentEntry>>{};
    for (final feature in featureEntries) {
      final level = _levelOf(feature);
      grouped.putIfAbsent(level, () => []).add(feature);
    }
    final levels = grouped.keys.toList()..sort();
    if (levels.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text('等级特性', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final level in levels)
          ExpansionTile(
            title: Text(level > 0 ? '等级 $level' : '未分级特性'),
            children: [
              for (final feature in grouped[level]!)
                ListTile(
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: Text(feature.name),
                  subtitle:
                      feature.summary.isEmpty ? null : Text(feature.summary),
                  trailing: onFeatureTap == null
                      ? null
                      : const Icon(Icons.chevron_right),
                  onTap: onFeatureTap == null
                      ? null
                      : () => onFeatureTap!(feature),
                ),
            ],
          ),
      ],
    );
  }

  int _levelOf(ContentEntry entry) {
    final value = entry.structured['level'];
    if (value is num) return value.toInt();
    return 0;
  }
}
