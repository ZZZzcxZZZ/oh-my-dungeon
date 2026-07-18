import 'package:dnd_table_client/src/features/characters/domain/structured_class_rules.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads normalized saving throws and skill choice fields', () {
    const entry = ContentEntry(
      id: 'test:class/warden',
      type: 'class',
      slug: 'warden',
      name: '守望者',
      body: [],
      revision: 1,
      structured: {
        'savingThrowAbilities': ['str', 'wis'],
        'skillChoice': {
          'count': 2,
          'options': ['运动', '察觉', '求生'],
        },
      },
    );

    expect(StructuredClassRules.savingThrowAbilities(entry), {'str', 'wis'});
    expect(StructuredClassRules.skillChoice(entry).count, 2);
    expect(StructuredClassRules.skillChoice(entry).options, ['运动', '察觉', '求生']);
  });

  test('supports current PHB package proficiency strings', () {
    const entry = ContentEntry(
      id: 'test:class/fighter',
      type: 'class',
      slug: 'fighter',
      name: '战士',
      body: [],
      revision: 1,
      structured: {
        'savingThrows': '力量与体质',
        'skills': '选择2项：特技、驯兽、运动、历史、洞悉、威吓、游说、察觉、求生',
      },
    );

    expect(StructuredClassRules.savingThrowAbilities(entry), {'str', 'con'});
    expect(StructuredClassRules.skillChoice(entry).count, 2);
    expect(StructuredClassRules.skillChoice(entry).options, contains('运动'));
    expect(StructuredClassRules.skillChoice(entry).options, contains('察觉'));
    expect(StructuredClassRules.skillChoice(entry).options, contains('杂技'));
    expect(StructuredClassRules.skillChoice(entry).options, contains('说服'));
  });
}
