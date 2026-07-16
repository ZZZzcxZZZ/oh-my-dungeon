import 'character.dart';
import 'character_content_reference.dart';

class CharacterEditDraft {
  const CharacterEditDraft({
    required this.name,
    required this.level,
    required this.classSummary,
    required this.raceSummary,
    required this.currentHp,
    required this.maxHp,
    required this.armorClass,
    required this.speed,
    required this.initiativeBonus,
    required this.abilities,
    required this.saves,
    required this.skills,
    required this.inventory,
    required this.currency,
    required this.notes,
    this.data = const {},
    this.contentReferences = const <CharacterContentReference>[],
  });

  final String name;
  final int level;
  final String classSummary;
  final String raceSummary;
  final int currentHp;
  final int maxHp;
  final int armorClass;
  final int speed;
  final int initiativeBonus;
  final Map<String, int> abilities;
  final Map<String, bool> saves;
  final Map<String, bool> skills;
  final List<Map<String, Object>> inventory;
  final Map<String, int> currency;
  final String notes;
  final Map<String, Object?> data;
  final List<CharacterContentReference> contentReferences;

  static int _idCounter = 0;

  CharacterSheet toLocalCharacter() {
    final id = 'character-${_idCounter + 1}';
    _idCounter += 1;
    return CharacterSheet.local(
      id: id,
      name: name,
      level: level,
      classSummary: classSummary,
      raceSummary: raceSummary,
      notes: notes,
      contentReferences: contentReferences,
    ).copyWith(
      currentHp: currentHp,
      maxHp: maxHp,
      armorClass: armorClass,
      speed: speed,
      initiativeBonus: initiativeBonus,
      abilities: abilities,
      saves: saves,
      skills: skills,
      inventory: inventory,
      currency: currency,
      data: data,
    );
  }
}
