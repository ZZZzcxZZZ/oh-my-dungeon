import 'package:dnd_table_client/src/features/rules/domain/character_rule_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('选择系统字段（契约 §3.10.2）', () {
    test('repeatable / countsToward / group / help 无损往返', () {
      const source = <String, Object?>{
        'id': 'invocations',
        'label': '祈唤',
        'optionType': 'classFeature',
        'minimum': 1,
        'maximum': 3,
        'optionTags': ['eldritch-invocation'],
        'repeatable': true,
        'countsToward': 'prepared',
        'group': '1 级祈唤',
        'help': '同一祈唤最多选 3 次。',
      };

      final choice = RuleChoiceDefinition.fromJson(source);

      expect(choice.repeatable, isTrue);
      expect(choice.countsToward, 'prepared');
      expect(choice.group, '1 级祈唤');
      expect(choice.help, '同一祈唤最多选 3 次。');
      expect(choice.toJson(), source);
    });

    test('缺省即默认：repeatable=false，其余为 null 且不写回 JSON', () {
      final choice = RuleChoiceDefinition.fromJson(const {
        'id': 'pick',
        'optionType': 'feat',
      });

      expect(choice.repeatable, isFalse);
      expect(choice.countsToward, isNull);
      expect(choice.requires, isEmpty);
      expect(choice.group, isNull);
      expect(choice.help, isNull);
      final encoded = choice.toJson();
      for (final key in [
        'repeatable',
        'countsToward',
        'requires',
        'group',
        'help',
      ]) {
        expect(encoded.containsKey(key), isFalse, reason: key);
      }
    });

    test('countsToward 取值判据只有一处（isCountsTowardPool）', () {
      expect(kCountsTowardPools, {'spellbook', 'known', 'prepared'});
      expect(isCountsTowardPool(null), isTrue);
      for (final pool in ['spellbook', 'known', 'prepared']) {
        expect(isCountsTowardPool(pool), isTrue, reason: pool);
      }
      expect(isCountsTowardPool('rituals'), isFalse);
      expect(isCountsTowardPool(7), isFalse);

      expect(
        () => RuleChoiceDefinition.fromJson(const {
          'id': 'x',
          'optionType': 'spell',
          'countsToward': 'rituals',
        }),
        throwsFormatException,
      );
      expect(
        () => RuleChoiceDefinition.fromJson(const {
          'id': 'x',
          'optionType': 'spell',
          'countsToward': 3,
        }),
        throwsFormatException,
      );
    });

    test('requires 两种形态可解析且往返', () {
      const source = <String, Object?>{
        'id': 'invocations',
        'optionType': 'classFeature',
        'requires': [
          {'choice': 'spellbook', 'option': 'spell-a'},
          {'choice': 'pact', 'option': null},
          {'ability': 'cha', 'minimum': 13},
        ],
      };

      final choice = RuleChoiceDefinition.fromJson(source);

      expect(choice.requires, hasLength(3));
      expect(choice.requires[0].choice, 'spellbook');
      expect(choice.requires[0].option, 'spell-a');
      expect(choice.requires[0].ability, isNull);
      expect(choice.requires[0].minimum, isNull);
      expect(choice.requires[0].isChoiceForm, isTrue);
      expect(choice.requires[0].isAbilityForm, isFalse);
      expect(choice.requires[1].option, isNull);
      expect(choice.requires[2].ability, 'cha');
      expect(choice.requires[2].minimum, 13);
      expect(choice.requires[2].choice, isNull);
      expect(choice.requires[2].isAbilityForm, isTrue);
      // 省略 option 的形态不写回 null，避免制造第二种写法。
      expect((choice.toJson()['requires']! as List)[1], {'choice': 'pact'});
      expect(
        RuleChoiceDefinition.fromJson(choice.toJson()).toJson(),
        choice.toJson(),
      );
    });

    test('requires 元素混写或取值非法一律抛 FormatException', () {
      for (final bad in <Object?>[
        <String, Object?>{}, // 两种形态都不是
        {'choice': 'a', 'ability': 'cha', 'minimum': 13}, // 混写
        {'ability': 'cha'}, // 缺 minimum
        {'ability': 'cha', 'minimum': 0}, // 非正
        {'ability': 'cha', 'minimum': '13'}, // 非数字
        {'ability': 'cha', 'minimum': 13, 'extra': 1}, // 未定义字段
        {'choice': 'a', 'minimum': 13}, // choice 形态夹带 ability 形态字段
        {'ability': 'cha', 'option': 'x'}, // ability 形态夹带 choice 形态字段
        {'choice': 5}, // 非字符串
        {'choice': '   '}, // 空白 choice
        {'choice': 'a', 'option': ''}, // 空白 option
      ]) {
        expect(
          () => RuleChoiceDefinition.fromJson(<String, Object?>{
            'id': 'x',
            'optionType': 'feat',
            'requires': <Object?>[bad],
          }),
          throwsFormatException,
          reason: '$bad',
        );
      }
      expect(
        () => RuleChoiceDefinition.fromJson(const {
          'id': 'x',
          'optionType': 'feat',
          'requires': <String, Object?>{},
        }),
        throwsFormatException,
      );
      expect(
        () => RuleChoiceDefinition.fromJson(const {
          'id': 'x',
          'optionType': 'feat',
          'requires': <Object?>[5],
        }),
        throwsFormatException,
      );
    });

    test('合法形态不因白名单收紧而回归：两种形态各自只带自己的字段', () {
      const choiceForm = <String, Object?>{
        'choice': 'spellbook',
        'option': 'spell-a',
      };
      final parsedChoice = RuleRequiresDefinition.fromJson(choiceForm);
      expect(parsedChoice.choice, 'spellbook');
      expect(parsedChoice.option, 'spell-a');
      expect(parsedChoice.toJson(), choiceForm);

      // 省略 option 仍合法（不写回 null）。
      final parsedBare = RuleRequiresDefinition.fromJson(const {
        'choice': 'pact',
      });
      expect(parsedBare.option, isNull);
      expect(parsedBare.toJson(), {'choice': 'pact'});

      const abilityForm = <String, Object?>{'ability': 'cha', 'minimum': 13};
      final parsedAbility = RuleRequiresDefinition.fromJson(abilityForm);
      expect(parsedAbility.ability, 'cha');
      expect(parsedAbility.minimum, 13);
      expect(parsedAbility.toJson(), abilityForm);
    });

    test('requires 非法形状的异常类型与信息片段固定', () {
      expect(
        () => RuleRequiresDefinition.fromJson(const {
          'choice': 'a',
          'ability': 'cha',
          'minimum': 13,
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('必须是 {choice, option?} 或 {ability, minimum} 之一'),
          ),
        ),
      );
      for (final crossForm in <Map<String, Object?>>[
        {'choice': 'a', 'minimum': 13},
        {'ability': 'cha', 'option': 'x'},
      ]) {
        expect(
          () => RuleRequiresDefinition.fromJson(crossForm),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains('未定义或形态不允许的字段'),
            ),
          ),
          reason: '$crossForm',
        );
      }
    });

    test('const 构造器拒绝 fromJson 会拒绝的非法形状（自洽）', () {
      final ability = 'cha';
      final choice = 'a';
      expect(
        () => RuleRequiresDefinition(ability: ability), // 缺 minimum
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => RuleRequiresDefinition(ability: ability, minimum: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => RuleRequiresDefinition(choice: choice, ability: ability),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => RuleRequiresDefinition(choice: choice, minimum: 13),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => RuleRequiresDefinition(ability: ability, option: 'x'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('group / help 必须是非空字符串（空串拒绝，不允许"声明了但等于没写"）', () {
      for (final field in ['group', 'help']) {
        for (final bad in <Object?>['   ', 5]) {
          expect(
            () => RuleChoiceDefinition.fromJson({
              'id': 'x',
              'optionType': 'feat',
              field: bad,
            }),
            throwsFormatException,
            reason: '$field / $bad',
          );
        }
      }
    });

    test('repeatable 必须是 bool', () {
      expect(
        () => RuleChoiceDefinition.fromJson(const {
          'id': 'x',
          'optionType': 'feat',
          'repeatable': 'yes',
        }),
        throwsFormatException,
      );
    });

    test('options[].requires（决策 D6）可解析且无损往返', () {
      const source = <String, Object?>{
        'id': 'invocations',
        'label': '祈唤',
        'optionType': 'classFeature',
        'minimum': 1,
        'maximum': 3,
        'options': [
          {
            'id': 'a',
            'label': 'A',
            'requires': [
              {'choice': 'spellbook', 'option': 'spell-a'},
            ],
          },
          {
            'id': 'b',
            'label': 'B',
            'requires': [
              {'ability': 'cha', 'minimum': 13},
            ],
          },
        ],
      };

      final choice = RuleChoiceDefinition.fromJson(source);

      expect(choice.options[0].requires, hasLength(1));
      expect(choice.options[0].requires.single.choice, 'spellbook');
      expect(choice.options[0].requires.single.option, 'spell-a');
      expect(choice.options[1].requires.single.ability, 'cha');
      expect(choice.options[1].requires.single.minimum, 13);
      expect(choice.toJson(), source);
    });

    test('字符串简写选项没有 requires，且不写回 requires 键', () {
      final choice = RuleChoiceDefinition.fromJson(const {
        'id': 'pick',
        'optionType': 'skill',
        'options': ['察觉'],
      });

      expect(choice.options.single.requires, isEmpty);
      expect(choice.options.single.toJson(), {
        'id': '察觉',
        'label': '察觉',
      });
    });

    test('options[].requires 形状非法一律抛 FormatException', () {
      for (final bad in <Object?>[
        <String, Object?>{},
        {'choice': 'a', 'ability': 'cha', 'minimum': 13},
        {'ability': 'cha', 'minimum': 0},
        {'choice': 5},
        <String, Object?>{},
      ]) {
        expect(
          () => RuleChoiceDefinition.fromJson(<String, Object?>{
            'id': 'x',
            'optionType': 'classFeature',
            'options': [
              <String, Object?>{'id': 'a', 'requires': <Object?>[bad]},
            ],
          }),
          throwsFormatException,
          reason: '$bad',
        );
      }
      expect(
        () => RuleChoiceDefinition.fromJson(const {
          'id': 'x',
          'optionType': 'classFeature',
          'options': [
            {'id': 'a', 'requires': <String, Object?>{}},
          ],
        }),
        throwsFormatException,
      );
    });
  });
}
