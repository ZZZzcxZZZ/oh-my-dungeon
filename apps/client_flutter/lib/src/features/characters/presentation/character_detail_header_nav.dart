// character_detail_page.dart 的 part：角色卡头部、页签与属性总览。
part of 'character_detail_page.dart';

class _CharacterHeader extends StatelessWidget {
  const _CharacterHeader({required this.character});

  final CharacterSheet character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = [
      if (character.raceSummary.isNotEmpty) character.raceSummary,
      if (character.classSummary.isNotEmpty) character.classSummary,
      if (!character.isNonPlayerCharacter) 'Lv.${character.level}',
    ].join(' / ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          CircleAvatar(
            key: const Key('character-detail-avatar'),
            radius: 18,
            backgroundImage: avatarImageProvider(character.avatarUrl),
            child: character.avatarUrl == null || character.avatarUrl!.isEmpty
                ? Text(character.name.characters.first.toUpperCase())
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(character.name, style: theme.textTheme.titleMedium),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    'HP ${character.currentHp}/${character.maxHp}',
                    style: theme.textTheme.labelLarge,
                  ),
                  Text(
                    'AC ${character.armorClass}',
                    style: theme.textTheme.labelLarge,
                  ),
                  Text(
                    '先攻 ${Dnd5eRules.formatModifier(character.initiativeBonus)}',
                    style: theme.textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 规范 §头像来源：本地角色头像以 data URL 离线保存，战役角色头像为网络 URL。
  // 这里同时支持两种格式，无头像时返回 null 让 CircleAvatar 退回首字母。
}

List<ContentEntry> _characterContentEntries(
  CharacterSheet character,
  List<ContentEntry> libraryEntries,
) {
  final byId = <String, ContentEntry>{
    for (final entry in libraryEntries) entry.id: entry,
  };
  final snapshots = character.dataMap['ruleSnapshots'];
  if (snapshots is! Map) return byId.values.toList(growable: false);
  for (final value in snapshots.values) {
    if (value is! Map) continue;
    try {
      final entry = ContentEntry.fromJson(Map<String, Object?>.from(value));
      byId[entry.id] = entry;
    } catch (_) {
      // Older, partial snapshots remain readable through their stored labels.
    }
  }
  return byId.values.toList(growable: false);
}

class _SheetTab extends StatelessWidget {
  const _SheetTab({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: child,
        ),
      ),
    );
  }
}

class _AbilityOverview extends StatelessWidget {
  const _AbilityOverview({
    required this.character,
    this.diceRoller,
    this.onRoll,
  });

  final CharacterSheet character;
  final DiceRoller? diceRoller;
  final CharacterRollCallback? onRoll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: '属性',
          icon: Icons.tune_outlined,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in Dnd5eRules.abilityLabels.entries)
                _AbilityTile(
                  label: entry.value,
                  score: Dnd5eRules.abilityScore(
                    character.abilityMap,
                    entry.key,
                  ),
                ),
            ],
          ),
        ),
        _Section(
          title: '豁免',
          icon: Icons.shield_outlined,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in Dnd5eRules.abilityLabels.entries)
                _RollChip(
                  label: entry.value,
                  value: Dnd5eRules.saveBonus(
                    ability: entry.key,
                    abilities: character.abilityMap,
                    level: character.level,
                    proficient: character.saveMap[entry.key] == true,
                  ),
                  proficient: character.saveMap[entry.key] == true,
                  diceRoller: diceRoller,
                  onRoll: onRoll,
                ),
            ],
          ),
        ),
        _Section(
          title: '技能',
          icon: Icons.checklist_outlined,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final skill in Dnd5eRules.skills)
                _RollChip(
                  label: skill.name,
                  value: Dnd5eRules.skillBonus(
                    skillName: skill.name,
                    abilities: character.abilityMap,
                    level: character.level,
                    proficient: character.skillMap[skill.name] == true,
                  ),
                  proficient: character.skillMap[skill.name] == true,
                  diceRoller: diceRoller,
                  onRoll: onRoll,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
