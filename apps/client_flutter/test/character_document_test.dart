import 'package:dnd_table_client/src/features/characters/domain/character_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adapts legacy hp text into a v2 character document', () {
    final document = CharacterDocument.fromJson({'hp': '25/40'});

    expect(document.schemaVersion, 2);
    expect(document.hitPoints.current, 25);
    expect(document.hitPoints.maximum, 40);
    expect(document.hitPoints.temporary, 0);
    expect(document.toJson()['schemaVersion'], 2);
  });

  test('round trips custom resources, items, conditions and extensions', () {
    final document = CharacterDocument.fromJson({
      'schemaVersion': 2,
      'hitPoints': {'current': 9, 'maximum': 12, 'temporary': 3},
      'resources': [
        {
          'id': 'focus',
          'name': '专注点',
          'current': 1,
          'maximum': 2,
          'restoreOn': 'shortRest',
          'custom': true,
        },
      ],
      'conditions': [
        {'id': 'poison-1', 'type': 'poisoned', 'remaining': 2},
      ],
      'items': [
        {'id': 'potion-1', 'name': '治疗药水', 'quantity': 2},
      ],
      'extensions': {
        'homebrew.dragonBloodline': {'element': 'fire'},
        'invalid': {'ignored': true},
      },
    });

    expect(document.resources.single.name, '专注点');
    expect(document.conditions.single.remaining, 2);
    expect(document.items.single.quantity, 2);
    expect(document.extensions.keys, ['homebrew.dragonBloodline']);
    expect(CharacterDocument.fromJson(document.toJson()), document);
  });

  test('normalizes unsafe hit point and death save values', () {
    final document = CharacterDocument.fromJson({
      'hitPoints': {'current': 99, 'maximum': 20, 'temporary': -1},
      'deathSaves': {'successes': 8, 'failures': -2},
    });

    expect(
      document.hitPoints,
      const CharacterHitPoints(current: 20, maximum: 20, temporary: 0),
    );
    expect(
      document.deathSaves,
      const CharacterDeathSaves(successes: 3, failures: 0),
    );
  });
}
