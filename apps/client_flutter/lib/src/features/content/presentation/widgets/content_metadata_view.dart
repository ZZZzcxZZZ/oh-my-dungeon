import 'package:flutter/material.dart';

import '../../domain/content_entry.dart';
import '../content_type_registry.dart';

class ContentMetadataView extends StatelessWidget {
  const ContentMetadataView({required this.entry, super.key});

  final ContentEntry entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: ContentTypeRegistry.defaults()
          .definitionFor(entry.type)
          .buildMetadata(context, entry),
    );
  }
}
