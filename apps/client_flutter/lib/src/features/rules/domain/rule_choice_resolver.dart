import '../../content/domain/content_entry.dart';
import 'character_rule_definition.dart';

class RuleChoiceResolver {
  const RuleChoiceResolver({required this.entries});

  final Map<String, ContentEntry> entries;

  List<ContentEntry> optionsFor(
    RuleChoiceDefinition definition, {
    String? sourceEntryId,
  }) {
    final explicitIds = definition.optionEntryIds.toSet();
    final options = entries.values
        .where((entry) {
          if (entry.type != definition.optionType) return false;
          if (explicitIds.isNotEmpty && !explicitIds.contains(entry.id)) {
            return false;
          }
          if (!definition.optionTags.every(entry.tags.contains)) return false;
          if (definition.optionType == 'subclass' &&
              !_isSubclassOf(entry, sourceEntryId)) {
            return false;
          }
          final maximumLevel = definition.maximumOptionLevel;
          if (maximumLevel != null) {
            final optionLevel = _optionLevel(entry);
            if (optionLevel == null || optionLevel > maximumLevel) return false;
          }
          return true;
        })
        .toList(growable: false);
    return options..sort((left, right) {
      final byLevel = (_optionLevel(left) ?? -1).compareTo(
        _optionLevel(right) ?? -1,
      );
      return byLevel != 0 ? byLevel : left.name.compareTo(right.name);
    });
  }

  bool allows(
    RuleChoiceDefinition definition,
    String entryId, {
    String? sourceEntryId,
  }) {
    return optionsFor(
      definition,
      sourceEntryId: sourceEntryId,
    ).any((entry) => entry.id == entryId);
  }

  List<String> recommendedFor(
    RuleChoiceDefinition definition, {
    String? sourceEntryId,
  }) {
    final allowedIds = optionsFor(
      definition,
      sourceEntryId: sourceEntryId,
    ).map((entry) => entry.id).toSet();
    return definition.recommendedEntryIds
        .where(allowedIds.contains)
        .take(definition.maximum)
        .toList(growable: false);
  }

  bool _isSubclassOf(ContentEntry entry, String? sourceEntryId) {
    if (sourceEntryId == null || sourceEntryId.isEmpty) return false;
    return entry.relations.any(
      (relation) =>
          relation.type == 'subclassOf' && relation.targetId == sourceEntryId,
    );
  }

  int? _optionLevel(ContentEntry entry) {
    final value = entry.structured['level'];
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }
}
