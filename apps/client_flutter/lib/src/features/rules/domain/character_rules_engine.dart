import '../../content/domain/content_entry.dart';
import 'character_build.dart';
import 'character_rule_definition.dart';
import 'rule_choice_resolver.dart';

class ResolvedRuleGrant {
  const ResolvedRuleGrant({
    required this.id,
    required this.kind,
    required this.label,
    required this.sourceEntryId,
    required this.sourceEntryName,
    required this.sourceLevel,
    this.target,
    this.entryId,
    this.value,
    this.formula,
    this.data = const <String, Object?>{},
  });

  final String id;
  final RuleGrantKind kind;
  final String label;
  final String sourceEntryId;
  final String sourceEntryName;
  final int? sourceLevel;
  final String? target;
  final String? entryId;
  final num? value;
  final String? formula;
  final Map<String, Object?> data;
}

class PendingRuleChoice {
  const PendingRuleChoice({
    required this.key,
    required this.choiceId,
    required this.label,
    required this.optionType,
    required this.minimum,
    required this.maximum,
    required this.selected,
    required this.sourceEntryId,
    required this.sourceLevel,
    this.invalidSelected = const <String>[],
  });

  final String key;
  final String choiceId;
  final String label;
  final String optionType;
  final int minimum;
  final int maximum;
  final List<String> selected;
  final String sourceEntryId;
  final int? sourceLevel;
  final List<String> invalidSelected;

  int get remaining => (minimum - selected.length).clamp(0, minimum);
}

class ActiveRuleChoice {
  const ActiveRuleChoice({
    required this.key,
    required this.definition,
    required this.selected,
    required this.invalidSelected,
    required this.sourceEntryId,
    required this.sourceEntryName,
    required this.sourceLevel,
  });

  final String key;
  final RuleChoiceDefinition definition;
  final List<String> selected;
  final List<String> invalidSelected;
  final String sourceEntryId;
  final String sourceEntryName;
  final int? sourceLevel;

  bool get isValid =>
      invalidSelected.isEmpty &&
      selected.length >= definition.minimum &&
      selected.length <= definition.maximum;
}

class CharacterGrantLedger {
  const CharacterGrantLedger({
    required this.grants,
    required this.pendingChoices,
    required this.missingEntryIds,
    required this.resolvedChoiceEntryIds,
    required this.resolvedChoices,
    required this.activeChoices,
  });

  final List<ResolvedRuleGrant> grants;
  final List<PendingRuleChoice> pendingChoices;
  final List<String> missingEntryIds;
  final List<String> resolvedChoiceEntryIds;
  final Map<String, List<String>> resolvedChoices;
  final List<ActiveRuleChoice> activeChoices;

  Iterable<ResolvedRuleGrant> grantsOfKind(RuleGrantKind kind) {
    return grants.where((grant) => grant.kind == kind);
  }
}

class CharacterRulesEngine {
  const CharacterRulesEngine({required this.entries});

  final Map<String, ContentEntry> entries;

  CharacterGrantLedger evaluate(CharacterBuild build) {
    final grants = <String, ResolvedRuleGrant>{};
    final pendingChoices = <PendingRuleChoice>[];
    final missingEntryIds = <String>[];
    final resolvedChoiceEntryIds = <String>{};
    final resolvedChoices = <String, List<String>>{};
    final activeChoices = <ActiveRuleChoice>[];
    final queue = build.selections.values.toList(growable: true);
    final visited = <String>{};

    while (queue.isNotEmpty) {
      final entryId = queue.removeAt(0);
      if (!visited.add(entryId)) continue;
      final entry = entries[entryId];
      if (entry == null) {
        missingEntryIds.add(entryId);
        continue;
      }
      final rules = entry.rules;
      if (rules == null) continue;

      _resolveGrants(
        entry: entry,
        sourceLevel: null,
        definitions: rules.grants,
        target: grants,
      );
      _resolveChoices(
        build: build,
        entry: entry,
        sourceLevel: null,
        definitions: rules.choices,
        pending: pendingChoices,
        queue: queue,
        resolvedChoiceEntryIds: resolvedChoiceEntryIds,
        resolvedChoices: resolvedChoices,
        activeChoices: activeChoices,
      );

      for (final step in rules.progression) {
        if (step.level > build.level) continue;
        _resolveGrants(
          entry: entry,
          sourceLevel: step.level,
          definitions: step.grants,
          target: grants,
        );
        _resolveChoices(
          build: build,
          entry: entry,
          sourceLevel: step.level,
          definitions: step.choices,
          pending: pendingChoices,
          queue: queue,
          resolvedChoiceEntryIds: resolvedChoiceEntryIds,
          resolvedChoices: resolvedChoices,
          activeChoices: activeChoices,
        );
      }
    }

    return CharacterGrantLedger(
      grants: grants.values.toList(growable: false),
      pendingChoices: pendingChoices,
      missingEntryIds: missingEntryIds,
      resolvedChoiceEntryIds: resolvedChoiceEntryIds.toList(growable: false),
      resolvedChoices: resolvedChoices,
      activeChoices: activeChoices,
    );
  }

  void _resolveGrants({
    required ContentEntry entry,
    required int? sourceLevel,
    required List<RuleGrantDefinition> definitions,
    required Map<String, ResolvedRuleGrant> target,
  }) {
    for (final definition in definitions) {
      final key = '${entry.id}#${definition.id}';
      target[key] = ResolvedRuleGrant(
        id: definition.id,
        kind: definition.kind,
        label: definition.label,
        sourceEntryId: entry.id,
        sourceEntryName: entry.name,
        sourceLevel: sourceLevel,
        target: definition.target,
        entryId: definition.entryId,
        value: definition.value,
        formula: definition.formula,
        data: definition.data,
      );
    }
  }

  void _resolveChoices({
    required CharacterBuild build,
    required ContentEntry entry,
    required int? sourceLevel,
    required List<RuleChoiceDefinition> definitions,
    required List<PendingRuleChoice> pending,
    required List<String> queue,
    required Set<String> resolvedChoiceEntryIds,
    required Map<String, List<String>> resolvedChoices,
    required List<ActiveRuleChoice> activeChoices,
  }) {
    final resolver = RuleChoiceResolver(entries: entries);
    for (final definition in definitions) {
      final key = '${entry.id}#${definition.id}';
      final requested = build.choices[key] ?? const <String>[];
      final selected = requested
          .where(
            (entryId) =>
                resolver.allows(definition, entryId, sourceEntryId: entry.id),
          )
          .toList(growable: false);
      final invalidSelected = requested
          .where((entryId) => !selected.contains(entryId))
          .toList(growable: false);
      activeChoices.add(
        ActiveRuleChoice(
          key: key,
          definition: definition,
          selected: selected,
          invalidSelected: invalidSelected,
          sourceEntryId: entry.id,
          sourceEntryName: entry.name,
          sourceLevel: sourceLevel,
        ),
      );
      if (selected.length < definition.minimum ||
          selected.length > definition.maximum ||
          invalidSelected.isNotEmpty) {
        pending.add(
          PendingRuleChoice(
            key: key,
            choiceId: definition.id,
            label: definition.label,
            optionType: definition.optionType,
            minimum: definition.minimum,
            maximum: definition.maximum,
            selected: selected,
            sourceEntryId: entry.id,
            sourceLevel: sourceLevel,
            invalidSelected: invalidSelected,
          ),
        );
      }
      final accepted = selected
          .take(definition.maximum)
          .toList(growable: false);
      resolvedChoices[key] = accepted;
      resolvedChoiceEntryIds.addAll(accepted);
      queue.addAll(accepted);
    }
  }
}
