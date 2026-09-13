import 'package:dnd_table_client/src/features/characters/domain/character_rule_overrides.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromData 把带传输前缀的 disabled/pinned 归一化成规范 id', () {
    final overrides = CharacterRuleOverrides.fromData(<String, Object?>{
      'disabledOriginIds': <Object?>[
        'local:errata:class/wizard',
        'campaign:c1:base:class/wizard',
        'plain',
      ],
      'pinned': <String, Object?>{
        'spellcasting.prepared': 'campaign:c1:zeta:class/wizard',
      },
    });

    expect(overrides.disabledOriginIds, <String>{
      'errata:class/wizard',
      'base:class/wizard',
      'plain',
    });
    expect(overrides.pinned['spellcasting.prepared'], 'zeta:class/wizard');
  });

  test('disable/pin 写入的也是规范 id（两个视图写出同一份数据）', () {
    final overrides = const CharacterRuleOverrides()
        .disable('local:errata:class/wizard')
        .pin('spellcasting.prepared', 'campaign:c1:zeta:class/wizard');

    expect(overrides.disabledOriginIds, <String>{'errata:class/wizard'});
    expect(overrides.pinned['spellcasting.prepared'], 'zeta:class/wizard');
  });
}
