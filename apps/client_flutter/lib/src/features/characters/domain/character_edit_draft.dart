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
    this.avatarUrl,
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

  /// 角色头像。本地角色以离线形式保存（data URL 或本地文件路径）；
  /// 绑定战役时由发布流程上传到服务端媒体服务。规范 §头像来源。
  final String? avatarUrl;
  final Map<String, Object?> data;
  final List<CharacterContentReference> contentReferences;

  CharacterEditDraft copyWith({Map<String, Object?>? data}) {
    return CharacterEditDraft(
      name: name,
      level: level,
      classSummary: classSummary,
      raceSummary: raceSummary,
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
      notes: notes,
      avatarUrl: avatarUrl,
      data: data ?? this.data,
      contentReferences: contentReferences,
    );
  }

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
      avatarUrl: avatarUrl,
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
