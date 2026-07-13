import 'package:flutter/material.dart';

import 'content_entry.dart';

abstract interface class ContentTypeDefinition {
  String get type;
  String get label;
  IconData get icon;
  List<ContentFieldDefinition> get searchableFields;
  Widget buildSummary(BuildContext context, ContentEntry entry);
  Widget buildMetadata(BuildContext context, ContentEntry entry);
}

class ContentFieldDefinition {
  const ContentFieldDefinition({required this.key, required this.label});

  final String key;
  final String label;
}
