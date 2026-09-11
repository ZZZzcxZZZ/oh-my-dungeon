// test/rules/rule_profile_resolver_test.dart
import 'package:dnd_table_client/src/features/rules/domain/class_rule_set.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_diagnostic.dart';
import 'package:flutter_test/flutter_test.dart';

const _path = r'$.structured.classRules';

void main() {
  group('ClassRuleSet.parse', () {
    test('解析完整职业规则块', () {
      final diagnostics = <RuleDiagnostic>[];
      final rules = ClassRuleSet.parse(
        {
          'hitDie': 10,
          'savingThrowAbilities': ['wis', 'cha'],
          'spellcasting': {
            'mode': 'prepared',
            'ability': 'cha',
            'listTags': ['spell-list:astral'],
            'archetype': 'half-caster',
            'slots': {
              '5': {'1': 4, '2': 2},
            },
          },
          'resources': [
            {
              'id': 'surge',
              'name': '星界涌动',
              'recovery': 'shortRestOne',
              'maximum': {'formula': 'level'},
            },
          ],
        },
        path: _path,
        diagnostics: diagnostics,
      );

      expect(diagnostics, isEmpty);
      expect(rules.hitDie, 10);
      expect(rules.savingThrowAbilities, {'wis', 'cha'});
      expect(rules.spellcasting!.mode, 'prepared');
      expect(rules.spellcasting!.ability, 'cha');
      expect(rules.spellcasting!.archetype, 'half-caster');
      expect(rules.spellcasting!.slots!.at(5), {'1': 4, '2': 2});
      expect(rules.resources.single.recovery, 'shortRestOne');
      expect(
        rules.resources.single.maximum.resolve(
          level: 7,
          abilities: const {'cha': 16},
        ),
        7,
      );
    });

    test('未知字段报 error 并给出候选', () {
      final diagnostics = <RuleDiagnostic>[];
      ClassRuleSet.parse(
        {'hitDices': 10},
        path: _path,
        diagnostics: diagnostics,
      );
      final errors = diagnostics
          .where((d) => d.severity == RuleSeverity.error)
          .toList();
      expect(errors.single.code, 'unknownField');
      expect(errors.single.message, contains('hitDie'));
    });

    test('未知字段 path 精确到该字段，短键不崩溃', () {
      final diagnostics = <RuleDiagnostic>[];
      ClassRuleSet.parse(
        {'hitDie': 10, 'hitDex': 10, 'ab': 1},
        path: _path,
        diagnostics: diagnostics,
      );
      final unknown = diagnostics
          .where((d) => d.code == 'unknownField')
          .toList();
      expect(unknown.map((d) => d.path).toList(), [
        '$_path.hitDex',
        '$_path.ab',
      ]);
      expect(unknown.every((d) => d.severity == RuleSeverity.error), isTrue);
      expect(unknown.first.message, contains('hitDie'));
    });

    group('hitDie', () {
      test('只接受标准骰面且诊断精确到字段', () {
        // 非整数、非标准骰面（d5/d7/d9/d20 这类不存在或非标准的骰子）、越界都报错。
        for (final raw in <Object?>[
          'd12',
          '10',
          3,
          5,
          7,
          9,
          11,
          13,
          20,
          21,
          true,
        ]) {
          final diagnostics = <RuleDiagnostic>[];
          ClassRuleSet.parse(
            {'hitDie': raw},
            path: _path,
            diagnostics: diagnostics,
          );
          expect(diagnostics.single.code, 'invalidHitDie', reason: '$raw');
          expect(diagnostics.single.path, '$_path.hitDie', reason: '$raw');
          expect(
            diagnostics.single.severity,
            RuleSeverity.error,
            reason: '$raw',
          );
        }
        // 标准骰面全部接受。
        for (final raw in <Object?>[4, 6, 8, 10, 12]) {
          final diagnostics = <RuleDiagnostic>[];
          final rules = ClassRuleSet.parse(
            {'hitDie': raw},
            path: _path,
            diagnostics: diagnostics,
          );
          expect(diagnostics, isEmpty, reason: '$raw');
          expect(rules.hitDie, raw, reason: '$raw');
        }
      });

      test('缺 hitDie 给 warning 而不是 error', () {
        final diagnostics = <RuleDiagnostic>[];
        ClassRuleSet.parse(
          {
            'savingThrowAbilities': ['str'],
          },
          path: _path,
          diagnostics: diagnostics,
        );
        expect(diagnostics.single.severity, RuleSeverity.warning);
        expect(diagnostics.single.code, 'missingCoreField');
      });

      test('非法生命骰与未知属性各报一条 error', () {
        final diagnostics = <RuleDiagnostic>[];
        ClassRuleSet.parse(
          {
            'hitDie': 7,
            'savingThrowAbilities': ['luck'],
          },
          path: _path,
          diagnostics: diagnostics,
          abilities: const {'str', 'dex', 'con', 'int', 'wis', 'cha'},
        );
        // 集合全等：多出任何一条诊断都算回归。
        final codes = diagnostics.map((d) => d.code).toSet();
        expect(codes, {'invalidHitDie', 'unknownAbility'});
      });
    });

    group('savingThrowAbilities', () {
      test('未知豁免属性 path 精确到字段', () {
        final diagnostics = <RuleDiagnostic>[];
        ClassRuleSet.parse(
          {
            'hitDie': 10,
            'savingThrowAbilities': ['str', 'luck'],
          },
          path: _path,
          diagnostics: diagnostics,
        );
        expect(diagnostics.single.code, 'unknownAbility');
        expect(diagnostics.single.path, '$_path.savingThrowAbilities');
        expect(diagnostics.single.message, contains('luck'));
      });
    });

    group('spellcasting', () {
      test('mode 非法精确到 mode', () {
        final diagnostics = <RuleDiagnostic>[];
        ClassRuleSet.parse(
          {
            'hitDie': 10,
            'spellcasting': {'mode': 'spontaneous', 'ability': 'cha'},
          },
          path: _path,
          diagnostics: diagnostics,
        );
        expect(diagnostics.single.code, 'invalidSpellcastingMode');
        expect(diagnostics.single.path, '$_path.spellcasting.mode');
      });

      test('施法属性缺失或非法报 unknownAbility', () {
        final missing = <RuleDiagnostic>[];
        ClassRuleSet.parse(
          {
            'hitDie': 10,
            'spellcasting': {'mode': 'prepared'},
          },
          path: _path,
          diagnostics: missing,
        );
        expect(missing.single.code, 'unknownAbility');
        expect(missing.single.path, '$_path.spellcasting.ability');

        final invalid = <RuleDiagnostic>[];
        ClassRuleSet.parse(
          {
            'hitDie': 10,
            'spellcasting': {'mode': 'known', 'ability': 'luck'},
          },
          path: _path,
          diagnostics: invalid,
        );
        expect(invalid.single.code, 'unknownAbility');
        expect(invalid.single.path, '$_path.spellcasting.ability');
      });

      test('mode != none 时 ability 必填', () {
        for (final mode in ['prepared', 'known', 'pact']) {
          final diagnostics = <RuleDiagnostic>[];
          ClassRuleSet.parse(
            {
              'hitDie': 10,
              'spellcasting': {'mode': mode},
            },
            path: _path,
            diagnostics: diagnostics,
          );
          expect(diagnostics.single.code, 'unknownAbility', reason: mode);
          expect(
            diagnostics.single.path,
            '$_path.spellcasting.ability',
            reason: mode,
          );
        }
      });

      test('mode 为 none 时 ability 出现即必须合法', () {
        // 旧实现只在 mode != none 时校验 ability，`{"mode":"none","ability":"luck"}`
        // 会整条静默通过。
        final invalid = <RuleDiagnostic>[];
        ClassRuleSet.parse(
          {
            'hitDie': 10,
            'spellcasting': {'mode': 'none', 'ability': 'luck'},
          },
          path: _path,
          diagnostics: invalid,
        );
        expect(invalid.single.code, 'unknownAbility');
        expect(invalid.single.path, '$_path.spellcasting.ability');

        // 合法属性照常接受（none 只表示"不使用施法"，不禁止声明属性）。
        final valid = <RuleDiagnostic>[];
        final rules = ClassRuleSet.parse(
          {
            'hitDie': 10,
            'spellcasting': {'mode': 'none', 'ability': 'cha'},
          },
          path: _path,
          diagnostics: valid,
        );
        expect(valid, isEmpty);
        expect(rules.spellcasting!.ability, 'cha');
      });

      test('mode 缺省为 none 且可省略 ability', () {
        final diagnostics = <RuleDiagnostic>[];
        final rules = ClassRuleSet.parse(
          {'hitDie': 10, 'spellcasting': <String, Object?>{}},
          path: _path,
          diagnostics: diagnostics,
        );
        expect(diagnostics, isEmpty);
        expect(rules.spellcasting!.mode, 'none');
        expect(rules.spellcasting!.ability, isNull);
      });

      test('表非法报 invalidTable，path 精确到表字段', () {
        final diagnostics = <RuleDiagnostic>[];
        ClassRuleSet.parse(
          {
            'hitDie': 10,
            'spellcasting': {
              'mode': 'prepared',
              'ability': 'cha',
              'prepared': {'21': 5},
            },
          },
          path: _path,
          diagnostics: diagnostics,
        );
        expect(diagnostics.single.code, 'invalidTable');
        expect(diagnostics.single.path, '$_path.spellcasting.prepared');
      });

      test('listTags 非数组报 invalidTable，path 精确到字段', () {
        // 类型不符不得静默吞成 []。
        final diagnostics = <RuleDiagnostic>[];
        ClassRuleSet.parse(
          {
            'hitDie': 10,
            'spellcasting': {'mode': 'none', 'listTags': 'spell-list:astral'},
          },
          path: _path,
          diagnostics: diagnostics,
        );
        expect(diagnostics.single.code, 'invalidTable');
        expect(diagnostics.single.path, '$_path.spellcasting.listTags');
      });

      test('内的未知键报 unknownField，path 精确到键', () {
        final diagnostics = <RuleDiagnostic>[];
        ClassRuleSet.parse(
          {
            'hitDie': 10,
            'spellcasting': {
              'mode': 'prepared',
              'ability': 'cha',
              'spellLists': ['spell-list:astral'],
            },
          },
          path: _path,
          diagnostics: diagnostics,
        );
        expect(diagnostics.single.code, 'unknownField');
        expect(diagnostics.single.path, '$_path.spellcasting.spellLists');
        expect(diagnostics.single.severity, RuleSeverity.error);
      });
    });

    group('resources', () {
      test('资源对象内的未知键报 unknownField，path 精确到键', () {
        final diagnostics = <RuleDiagnostic>[];
        ClassRuleSet.parse(
          {
            'hitDie': 10,
            'resources': [
              {'id': 'a', 'name': 'A', 'maximum': 1, 'recover': 'longRest'},
            ],
          },
          path: _path,
          diagnostics: diagnostics,
        );
        expect(diagnostics.single.code, 'unknownField');
        expect(diagnostics.single.path, '$_path.resources[0].recover');
        expect(diagnostics.single.severity, RuleSeverity.error);
      });

      test('资源可选 description（第三方包可用）', () {
        final diagnostics = <RuleDiagnostic>[];
        final rules = ClassRuleSet.parse(
          {
            'hitDie': 10,
            'resources': [
              {'id': 'a', 'name': 'A', 'maximum': 1, 'description': '每回合可用一次'},
            ],
          },
          path: _path,
          diagnostics: diagnostics,
        );
        expect(diagnostics, isEmpty);
        expect(rules.resources.single.description, '每回合可用一次');
      });

      test('recovery 默认 longRest，表形态随等级变化', () {
        final diagnostics = <RuleDiagnostic>[];
        final rules = ClassRuleSet.parse(
          {
            'hitDie': 10,
            'resources': [
              {'id': 'a', 'name': 'A', 'maximum': 1},
              {
                'id': 'b',
                'name': 'B',
                'maximum': 1,
                'recovery': {
                  'table': {'1': 'longRest', '5': 'shortRest'},
                },
              },
              {
                'id': 'c',
                'name': 'C',
                'maximum': 1,
                'recovery': {
                  'table': {'5': 'shortRest'},
                },
              },
            ],
          },
          path: _path,
          diagnostics: diagnostics,
        );
        expect(diagnostics, isEmpty);
        expect(rules.resources[0].recovery, 'longRest');
        expect(rules.resources[0].recoveryAt(9), 'longRest');
        expect(rules.resources[1].recoveryTable, isNotNull);
        // 表形态不得把表在 minLevel 的值合成写回常量字段。
        expect(rules.resources[1].recovery, isNull);
        expect(rules.resources[1].recoveryAt(1), 'longRest');
        expect(rules.resources[1].recoveryAt(5), 'shortRest');
        expect(rules.resources[1].recoveryAt(12), 'shortRest');
        // 低于表的最早声明等级（5 级）视为未声明，回退到默认 longRest。
        expect(rules.resources[2].recoveryAt(3), 'longRest');
        expect(rules.resources[2].recoveryAt(5), 'shortRest');
      });

      test('recovery 非法报 invalidRecovery，path 精确到字段', () {
        final diagnostics = <RuleDiagnostic>[];
        ClassRuleSet.parse(
          {
            'hitDie': 10,
            'resources': [
              {'id': 'a', 'name': 'A', 'maximum': 1, 'recovery': 'weekly'},
              {
                'id': 'b',
                'name': 'B',
                'maximum': 1,
                'recovery': {
                  'table': {'1': 'weekly'},
                },
              },
              {'id': 'c', 'name': 'C', 'maximum': 1, 'recovery': 5},
            ],
          },
          path: _path,
          diagnostics: diagnostics,
        );
        expect(diagnostics.map((d) => d.code).toSet(), {'invalidRecovery'});
        expect(diagnostics.map((d) => d.path).toList(), [
          '$_path.resources[0].recovery',
          '$_path.resources[1].recovery.table',
          '$_path.resources[2].recovery',
        ]);
      });

      test('maximum 三种写法互斥：多写/全缺/已废弃 value 都报 invalidMaxSpec', () {
        final diagnostics = <RuleDiagnostic>[];
        final rules = ClassRuleSet.parse(
          {
            'hitDie': 10,
            'resources': [
              {
                'id': 'a',
                'name': 'A',
                'maximum': {
                  'formula': 'level',
                  'table': {'1': 2},
                },
              },
              {'id': 'b', 'name': 'B', 'maximum': <String, Object?>{}},
              {
                'id': 'c',
                'name': 'C',
                'maximum': {'value': 3},
              },
              {'id': 'd', 'name': 'D', 'maximum': 3},
              {
                'id': 'e',
                'name': 'E',
                'maximum': {'formula': 'level'},
              },
              {
                'id': 'f',
                'name': 'F',
                'maximum': {
                  'table': {'1': 2},
                },
              },
            ],
          },
          path: _path,
          diagnostics: diagnostics,
        );
        expect(diagnostics.map((d) => d.code).toSet(), {'invalidMaxSpec'});
        expect(diagnostics.map((d) => d.path).toList(), [
          '$_path.resources[0].maximum',
          '$_path.resources[1].maximum',
          '$_path.resources[2].maximum',
        ]);
        expect(rules.resources.map((r) => r.id).toList(), ['d', 'e', 'f']);
      });

      test('资源 id 职业内唯一', () {
        final diagnostics = <RuleDiagnostic>[];
        final rules = ClassRuleSet.parse(
          {
            'hitDie': 10,
            'resources': [
              {'id': 'surge', 'name': '甲', 'maximum': 1},
              {'id': 'surge', 'name': '乙', 'maximum': 2},
            ],
          },
          path: _path,
          diagnostics: diagnostics,
        );
        expect(diagnostics.single.code, 'duplicateResourceId');
        expect(diagnostics.single.path, '$_path.resources[1].id');
        expect(rules.resources.single.name, '甲');
      });

      test('资源 id 或 name 为空报错', () {
        final diagnostics = <RuleDiagnostic>[];
        ClassRuleSet.parse(
          {
            'hitDie': 10,
            'resources': [
              {'id': '', 'name': '甲', 'maximum': 1},
              {'id': 'b', 'name': '  ', 'maximum': 1},
            ],
          },
          path: _path,
          diagnostics: diagnostics,
        );
        expect(diagnostics.map((d) => d.code).toSet(), {'invalidMaxSpec'});
        expect(diagnostics.map((d) => d.path).toList(), [
          '$_path.resources[0]',
          '$_path.resources[1]',
        ]);
      });

      test('startsAtLevel 越界报错并精确到字段，默认 1', () {
        final diagnostics = <RuleDiagnostic>[];
        final rules = ClassRuleSet.parse(
          {
            'hitDie': 10,
            'resources': [
              {'id': 'a', 'name': 'A', 'maximum': 1, 'startsAtLevel': 21},
              {'id': 'b', 'name': 'B', 'maximum': 1, 'startsAtLevel': 0},
              {'id': 'c', 'name': 'C', 'maximum': 1},
              {'id': 'd', 'name': 'D', 'maximum': 1, 'startsAtLevel': 3},
            ],
          },
          path: _path,
          diagnostics: diagnostics,
        );
        expect(diagnostics.map((d) => d.code).toSet(), {'invalidTable'});
        expect(diagnostics.map((d) => d.path).toList(), [
          '$_path.resources[0].startsAtLevel',
          '$_path.resources[1].startsAtLevel',
        ]);
        expect(rules.resources.map((r) => r.startsAtLevel).toList(), [1, 3]);
      });

      test('startsAtLevel 非整数报 invalidTable，不做静默强转', () {
        // '3' / 2.7 / true / 显式 null 都不得被悄悄改成 1 或截断成 2。
        final diagnostics = <RuleDiagnostic>[];
        final rules = ClassRuleSet.parse(
          {
            'hitDie': 10,
            'resources': [
              {'id': 'a', 'name': 'A', 'maximum': 1, 'startsAtLevel': '3'},
              {'id': 'b', 'name': 'B', 'maximum': 1, 'startsAtLevel': 2.7},
              {'id': 'c', 'name': 'C', 'maximum': 1, 'startsAtLevel': true},
              {'id': 'd', 'name': 'D', 'maximum': 1, 'startsAtLevel': null},
              {'id': 'e', 'name': 'E', 'maximum': 1, 'startsAtLevel': 3},
              {'id': 'f', 'name': 'F', 'maximum': 1},
            ],
          },
          path: _path,
          diagnostics: diagnostics,
        );
        expect(diagnostics.map((d) => d.code).toSet(), {'invalidTable'});
        expect(diagnostics.map((d) => d.path).toList(), [
          '$_path.resources[0].startsAtLevel',
          '$_path.resources[1].startsAtLevel',
          '$_path.resources[2].startsAtLevel',
          '$_path.resources[3].startsAtLevel',
        ]);
        expect(rules.resources.map((r) => r.startsAtLevel).toList(), [3, 1]);
      });
    });

    test('fields / declares 记录显式声明过的字段', () {
      final diagnostics = <RuleDiagnostic>[];
      final rules = ClassRuleSet.parse(
        {'hitDie': 8, 'resources': <Object?>[]},
        path: _path,
        diagnostics: diagnostics,
      );
      expect(rules.fields, {'hitDie', 'resources'});
      expect(rules.declares('hitDie'), isTrue);
      expect(rules.declares('resources'), isTrue);
      expect(rules.declares('spellcasting'), isFalse);
      expect(rules.declares('savingThrowAbilities'), isFalse);
    });

    group('declaredLevels', () {
      test('declaredMaxLevel 只统计职业自身声明的表', () {
        final archetypeOnly = ClassRuleSet.parse(
          {
            'hitDie': 10,
            'spellcasting': {
              'mode': 'prepared',
              'ability': 'cha',
              'archetype': 'full-caster',
            },
          },
          path: _path,
          diagnostics: <RuleDiagnostic>[],
        );
        expect(archetypeOnly.declaredMaxLevel, isNull, reason: '原型不算职业自身声明');

        final withSlots = ClassRuleSet.parse(
          {
            'hitDie': 10,
            'spellcasting': {
              'mode': 'prepared',
              'ability': 'cha',
              'archetype': 'full-caster',
              'slots': {
                '5': {'1': 4, '2': 2},
              },
            },
          },
          path: _path,
          diagnostics: <RuleDiagnostic>[],
        );
        expect(withSlots.declaredMaxLevel, 5);

        final formulaOnlyResource = ClassRuleSet.parse(
          {
            'hitDie': 10,
            'resources': [
              {
                'id': 'a',
                'name': 'A',
                'maximum': {'formula': 'level'},
              },
            ],
          },
          path: _path,
          diagnostics: <RuleDiagnostic>[],
        );
        expect(formulaOnlyResource.declaredMaxLevel, isNull, reason: '公式不贡献等级');

        final withTables = ClassRuleSet.parse(
          {
            'hitDie': 10,
            'spellcasting': {
              'mode': 'prepared',
              'ability': 'cha',
              'prepared': {'4': 6},
            },
            'resources': [
              {'id': 'a', 'name': 'A', 'maximum': 3},
              {
                'id': 'b',
                'name': 'B',
                'maximum': {
                  'table': {'3': 2},
                },
              },
            ],
          },
          path: _path,
          diagnostics: <RuleDiagnostic>[],
        );
        expect(withTables.declaredMaxLevel, 4);
      });

      test('declaredMinLevel 只统计职业自身声明的表', () {
        final archetypeOnly = ClassRuleSet.parse(
          {
            'hitDie': 10,
            'spellcasting': {
              'mode': 'prepared',
              'ability': 'cha',
              'archetype': 'full-caster',
            },
          },
          path: _path,
          diagnostics: <RuleDiagnostic>[],
        );
        expect(archetypeOnly.declaredMinLevel, isNull, reason: '无表则无声明范围');

        final withSlots = ClassRuleSet.parse(
          {
            'hitDie': 10,
            'spellcasting': {
              'mode': 'prepared',
              'ability': 'cha',
              'slots': {
                '5': {'1': 4, '2': 2},
              },
            },
          },
          path: _path,
          diagnostics: <RuleDiagnostic>[],
        );
        expect(withSlots.declaredMinLevel, 5);

        final formulaOnlyResource = ClassRuleSet.parse(
          {
            'hitDie': 10,
            'resources': [
              {
                'id': 'a',
                'name': 'A',
                'maximum': {'formula': 'level'},
              },
            ],
          },
          path: _path,
          diagnostics: <RuleDiagnostic>[],
        );
        expect(formulaOnlyResource.declaredMinLevel, isNull, reason: '公式不贡献等级');

        final withTables = ClassRuleSet.parse(
          {
            'hitDie': 10,
            'spellcasting': {
              'mode': 'prepared',
              'ability': 'cha',
              'prepared': {'4': 6},
            },
            'resources': [
              {'id': 'a', 'name': 'A', 'maximum': 3},
              {
                'id': 'b',
                'name': 'B',
                'maximum': {
                  'table': {'3': 2},
                },
              },
            ],
          },
          path: _path,
          diagnostics: <RuleDiagnostic>[],
        );
        expect(withTables.declaredMinLevel, 3, reason: '取各表最早声明等级');
      });
    });
  });
}
