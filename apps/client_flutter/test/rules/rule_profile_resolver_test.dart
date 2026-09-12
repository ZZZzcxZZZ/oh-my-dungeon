// test/rules/rule_profile_resolver_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:dnd_table_client/src/features/rules/domain/class_rule_set.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_diagnostic.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_field_path.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rule_profile_test_support.dart';

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

      test('mode 不再接受 pact：契约魔法只由 archetype 表示', () {
        // 契约魔法是"法术位进阶"而不是"法术选择模型"：`mode` 的枚举里没有 pact，
        // 唯一信号是 `archetype`（§3.3）。旧值必须报 invalidSpellcastingMode。
        final diagnostics = <RuleDiagnostic>[];
        final rules = ClassRuleSet.parse(
          {
            'hitDie': 10,
            'spellcasting': {'mode': 'pact', 'ability': 'cha'},
          },
          path: _path,
          diagnostics: diagnostics,
        );
        expect(diagnostics.single.code, 'invalidSpellcastingMode');
        expect(diagnostics.single.path, '$_path.spellcasting.mode');
        expect(
          diagnostics.single.message,
          'spellcasting.mode 必须是 prepared / known / none',
        );
        // 解析器保留原值交给诊断，但契约侧不再把 mode 当契约魔法信号。
        expect(rules.spellcasting!.mode, 'pact');
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
        for (final mode in ['prepared', 'known']) {
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

  group('RuleProfileResolver', () {
    Map<String, Object?> archive() => {
      'rulebookVersion': 1,
      'system': 'dnd5e-2024',
      'abilities': ['str', 'dex', 'con', 'int', 'wis', 'cha'],
      'skills': [
        {'name': '察觉', 'ability': 'wis'},
      ],
      'progressions': {
        'none': {'slots': []},
        // 原型**只承载** slots / slotLevel / maximumSpellLevel / minimumLevel（§3.1）；
        // 白名单之外的键（典型是 prepared / cantrips）由解析期报 unknownField，
        // 并有专门的测试守住——本 fixture 不得再往原型里塞这两列。
        'half-caster': {
          'minimumLevel': 1,
          'slots': List.generate(20, (_) => <String, Object?>{'1': 2}),
          'maximumSpellLevel': List.filled(20, 1),
        },
        'third-caster': {
          'minimumLevel': 3,
          'slots': List.generate(20, (_) => <String, Object?>{'1': 1}),
          'maximumSpellLevel': List.filled(20, 2),
        },
        // pact：minimumLevel(3) 比 slotLevel 表自身的最早声明等级(1) 更晚，
        // 用来区分"原型的 minimumLevel 守卫"与"表自己的下界"。
        'pact': {
          'minimumLevel': 3,
          'slots': List.generate(20, (_) => <String, Object?>{'1': 1}),
          'slotLevel': {'1': 1, '3': 2, '5': 3},
          'maximumSpellLevel': List.filled(20, 1),
        },
      },
      'classes': {
        'barbarian': {
          'hitDie': 12,
          'savingThrowAbilities': ['str', 'con'],
        },
      },
    };

    test('解析内置档案并可查询', () {
      final result = RuleProfileResolver.resolveBuiltin(archive());
      expect(result.errors, isEmpty);
      final profile = result.profile!;
      expect(profile.abilities, hasLength(6));
      expect(profile.classRules('barbarian')!.hitDie, 12);
      expect(profile.classRules('BARBARIAN')!.hitDie, 12); // 大小写归一
      expect(profile.classRules('nope'), isNull);
    });

    group('classAliases（§3.6 档案补齐的别名表）', () {
      test('合法别名：键与 slug 都归一为小写，写入 profile.aliases', () {
        final raw = archive()
          ..['classAliases'] = {'野蛮人': 'BARBARIAN', 'Brute': 'barbarian'};
        final result = RuleProfileResolver.resolveBuiltin(raw);
        expect(result.errors, isEmpty);
        final profile = result.profile!;
        expect(profile.aliases, {'野蛮人': 'barbarian', 'brute': 'barbarian'});
        // 别名经 `classRules` 回退命中：老角色的散文展示名也能解析到规则。
        expect(profile.classRules('野蛮人')!.hitDie, 12);
        expect(profile.classRules('  Brute  ')!.hitDie, 12);
      });

      test('classAliases 不是对象 → invalidTable 并整包阻断', () {
        final result = RuleProfileResolver.resolveBuiltin(
          archive()..['classAliases'] = <Object?>['野蛮人', 'barbarian'],
        );
        expect(result.profile, isNull);
        expect(result.errors.single.code, 'invalidTable');
        expect(result.errors.single.path, r'$.classAliases');
        expect(result.errors.single.severity, RuleSeverity.error);
      });

      test('别名键或 slug 为空 → invalidTable，path 精确到该别名', () {
        final cases = <(String, Map<String, Object?>)>[
          ('别名键为空', {'   ': 'barbarian'}),
          ('slug 为空', {'brute': '   '}),
          ('slug 不是字符串', {'brute': 12}),
        ];
        for (final (label, aliases) in cases) {
          final result = RuleProfileResolver.resolveBuiltin(
            archive()..['classAliases'] = aliases,
          );
          expect(result.profile, isNull, reason: label);
          expect(result.errors.single.code, 'invalidTable', reason: label);
          expect(
            result.errors.single.path,
            '\$.classAliases.${aliases.keys.single}',
            reason: label,
          );
          expect(result.errors.single.severity, RuleSeverity.error);
        }
      });

      test('别名指向不存在的 slug → invalidTable，消息带该 slug', () {
        final result = RuleProfileResolver.resolveBuiltin(
          archive()..['classAliases'] = {'圣武士': 'paladin'},
        );
        expect(result.profile, isNull);
        expect(result.errors.single.code, 'invalidTable');
        expect(result.errors.single.path, r'$.classAliases.圣武士');
        expect(result.errors.single.message, contains('paladin'));
        expect(result.errors.single.severity, RuleSeverity.error);
      });

      test('classAliases 缺省或为空对象都是合法（可选节）', () {
        expect(
          RuleProfileResolver.resolveBuiltin(archive()).profile!.aliases,
          isEmpty,
        );
        expect(
          RuleProfileResolver.resolveBuiltin(
            archive()..['classAliases'] = <String, Object?>{},
          ).profile!.aliases,
          isEmpty,
        );
      });
    });

    group('原型 slots 模板压缩编码（§3.1 唯一展开点）', () {
      // 直接读真实内置档案喂 `resolveBuiltin`——不经过 `RuleProfileStore`，
      // 守住"展开发生在解析器里"（数据层只读资产）。
      Map<String, Object?> realArchive() =>
          jsonDecode(
                File('assets/rules/dnd5e-2024.rules.json').readAsStringSync(),
              )
              as Map<String, Object?>;

      Map<String, Object?> withProgression(
        String name,
        Map<String, Object?> progression,
      ) => archive()..['progressions'] = {name: progression};

      test('真实内置档案：没有 store 参与也能解析出 profile', () {
        final result = RuleProfileResolver.resolveBuiltin(realArchive());
        expect(result.errors, isEmpty);
        final profile = result.profile;
        expect(profile, isNotNull);
        // `slotLevel` / `maximumSpellLevel` 仍走 `IntTable`（完整 20 项数组），
        // 口径不因 `slots` 的展开而改变（§3.1）。
        expect(profile!.progression('pact')!.slotLevel!.at(5), 3);
        expect(profile.progression('pact')!.slotLevel!.at(17), 5);
        expect(profile.progression('full-caster')!.maximumSpellLevel!.at(9), 5);
        expect(
          profile.progression('full-caster')!.maximumSpellLevel!.at(17),
          9,
        );
      });

      test('普通原型：计数数组下标 + 1 即环阶；pact 的环阶来自同级 slotLevel', () {
        final profile = RuleProfileResolver.resolveBuiltin(
          realArchive(),
        ).profile!;

        // 普通施法者：行内下标 + 1 就是环阶。
        expect(profile.progression('full-caster')!.slots!.at(3), {
          '1': 4,
          '2': 2,
        });
        expect(profile.progression('half-caster')!.slots!.at(5), {
          '1': 4,
          '2': 2,
        });
        expect(profile.progression('third-caster')!.slots!.at(3), {'1': 2});
        // 空行是"该级有法术位表但一个位也没有"的显式空表，不是"未声明"（§3.12）。
        expect(profile.progression('third-caster')!.slots!.at(1), isEmpty);

        // pact：环阶来自同级的 `slotLevel`，不是行下标（§3.3）。
        // 与旧 `Dnd5eRules.pactSlotMaximums` 的返回值一致。
        expect(profile.progression('pact')!.slots!.at(1), {'1': 1});
        expect(profile.progression('pact')!.slots!.at(5), {'3': 2});
        expect(profile.progression('pact')!.slots!.at(10), {'5': 2});
        expect(profile.progression('pact')!.slots!.at(11), {'5': 3});
        expect(profile.progression('pact')!.slots!.at(17), {'5': 4});

        // `none` 仍是"没有法术位表"，不是空表。
        expect(profile.progression('none')!.slots, isNull);
      });

      test('压缩编码展开：省略 0 值，空行是显式空表', () {
        final profile = RuleProfileResolver.resolveBuiltin(
          withProgression('caster', {
            'slots': [
              <Object?>[2],
              <Object?>[],
              <Object?>[4, 0, 2],
            ],
          }),
        ).profile!;
        final slots = profile.progression('caster')!.slots!;
        expect(slots.at(1), {'1': 2});
        expect(slots.at(2), isEmpty, reason: '空行 = 显式空表，不是未声明（§3.12）');
        expect(slots.at(3), {'1': 4, '3': 2}, reason: '编码约定：0 值省略（§3.1）');
      });

      test('pact 展开：每级一个计数，环阶取同级 slotLevel', () {
        final profile = RuleProfileResolver.resolveBuiltin(
          withProgression('pact', {
            'slots': [
              <Object?>[1],
              <Object?>[2],
              <Object?>[2],
              <Object?>[2],
              <Object?>[2],
            ],
            'slotLevel': [1, 1, 2, 2, 3],
          }),
        ).profile!;
        final slots = profile.progression('pact')!.slots!;
        expect(slots.at(1), {'1': 1});
        expect(slots.at(3), {'2': 2});
        expect(slots.at(5), {'3': 2});
      });

      test('形状非法 → invalidTable（error）并整包阻断，不静默修正', () {
        final cases = <(String, String, Map<String, Object?>)>[
          (
            '某级不是数组',
            'caster',
            {
              'slots': [
                <Object?>[2],
                3,
              ],
            },
          ),
          (
            '级数 > 20',
            'caster',
            {
              'slots': List.generate(21, (_) => <Object?>[2]),
            },
          ),
          (
            '计数为负数',
            'caster',
            {
              'slots': [
                <Object?>[-1],
              ],
            },
          ),
          (
            '计数非整数',
            'caster',
            {
              'slots': [
                <Object?>[2.5],
              ],
            },
          ),
          (
            '每级最多 9 个环阶',
            'caster',
            {
              'slots': [List.filled(10, 1)],
            },
          ),
          (
            'pact 缺 slotLevel',
            'pact',
            {
              'slots': [
                <Object?>[1],
                <Object?>[2],
              ],
            },
          ),
          (
            'pact 每级只能有一个计数',
            'pact',
            {
              'slots': [
                <Object?>[1, 2],
              ],
              'slotLevel': [3],
            },
          ),
          (
            'pact 级数 > 20',
            'pact',
            {
              'slots': List.generate(21, (_) => <Object?>[1]),
              'slotLevel': List.filled(20, 1),
            },
          ),
          (
            'pact 计数为负数',
            'pact',
            {
              'slots': [
                <Object?>[-1],
              ],
              'slotLevel': [1],
            },
          ),
          (
            'pact 计数非整数',
            'pact',
            {
              'slots': [
                <Object?>[2.5],
              ],
              'slotLevel': [1],
            },
          ),
          (
            'pact 的 slotLevel 越界（> 9）',
            'pact',
            {
              'slots': [
                <Object?>[2],
              ],
              'slotLevel': [10],
            },
          ),
          (
            'pact 的 slotLevel 越界（< 1）',
            'pact',
            {
              'slots': [
                <Object?>[2],
              ],
              'slotLevel': [0],
            },
          ),
        ];
        for (final (label, name, progression) in cases) {
          final result = RuleProfileResolver.resolveBuiltin(
            withProgression(name, progression),
          );
          expect(result.profile, isNull, reason: label);
          expect(result.errors.single.code, 'invalidTable', reason: label);
          expect(
            result.errors.single.path,
            '\$.progressions.$name.slots',
            reason: label,
          );
          expect(
            result.errors.single.severity,
            RuleSeverity.error,
            reason: label,
          );
        }
      });
    });

    test('未知原型报 error', () {
      final raw = archive();
      (raw['classes']! as Map)['barbarian'] = {
        'hitDie': 12,
        'spellcasting': {
          'mode': 'prepared',
          'ability': 'wis',
          'archetype': 'three-quarter',
        },
      };
      final result = RuleProfileResolver.resolveBuiltin(raw);
      expect(result.errors.single.code, 'unknownArchetype');
      // error ⇒ 整包阻断：消费方拿不到半成品档案（§4.4）。
      expect(result.profile, isNull);
    });

    test('原型白名单：prepared / cantrips 等原型不得承载的键报 unknownField', () {
      for (final extra in ['prepared', 'cantrips']) {
        final raw = archive();
        (raw['progressions']! as Map)['half-caster'] = {
          'minimumLevel': 1,
          'slots': List.generate(20, (_) => <String, Object?>{'1': 2}),
          'maximumSpellLevel': List.filled(20, 1),
          extra: List.filled(20, 1),
        };
        final result = RuleProfileResolver.resolveBuiltin(raw);
        expect(result.profile, isNull, reason: extra);
        expect(result.errors.single.code, 'unknownField', reason: extra);
        expect(
          result.errors.single.severity,
          RuleSeverity.error,
          reason: extra,
        );
        expect(
          result.errors.single.path,
          '\$.progressions.half-caster.$extra',
          reason: extra,
        );
      }
    });

    test('档案必须显式声明 abilities 与 skills（缺失 / 为空 / 类型错误都阻断）', () {
      final cases = <(String, Map<String, Object?>)>[
        ('abilities 缺失', archive()..remove('abilities')),
        ('abilities 为空', archive()..['abilities'] = <Object?>[]),
        ('abilities 类型错误', archive()..['abilities'] = 'str,dex'),
        ('abilities 项类型错误', archive()..['abilities'] = ['str', 3]),
        ('skills 缺失', archive()..remove('skills')),
        ('skills 为空', archive()..['skills'] = <Object?>[]),
        ('skills 类型错误', archive()..['skills'] = {'察觉': 'wis'}),
        ('skills 项类型错误', archive()..['skills'] = ['察觉']),
        (
          'skills 项缺 ability',
          archive()
            ..['skills'] = [
              {'name': '察觉'},
            ],
        ),
      ];
      for (final (label, raw) in cases) {
        final result = RuleProfileResolver.resolveBuiltin(raw);
        expect(result.profile, isNull, reason: label);
        expect(result.errors.map((d) => d.code).toSet(), {
          'invalidTable',
        }, reason: label);
      }
    });

    test('progressions / classes 及单项类型错误报 invalidTable，不静默吞掉', () {
      final cases = <(String, Map<String, Object?>)>[
        ('progressions 缺失', archive()..remove('progressions')),
        ('progressions 类型错误', archive()..['progressions'] = <Object?>[]),
        ('进度原型不是对象', archive()..['progressions'] = {'none': <Object?>[]}),
        (
          'slotLevel 非法',
          archive()
            ..['progressions'] = {
              'pact': {
                'slots': <Object?>[],
                'slotLevel': {'21': 3},
              },
            },
        ),
        (
          'minimumLevel 类型错误',
          archive()
            ..['progressions'] = {
              'third-caster': {'slots': <Object?>[], 'minimumLevel': '3'},
            },
        ),
        ('classes 缺失', archive()..remove('classes')),
        ('classes 类型错误', archive()..['classes'] = 'barbarian'),
        ('职业规则不是对象', archive()..['classes'] = {'barbarian': 12}),
      ];
      for (final (label, raw) in cases) {
        final result = RuleProfileResolver.resolveBuiltin(raw);
        expect(result.profile, isNull, reason: label);
        expect(result.errors.single.code, 'invalidTable', reason: label);
        expect(
          result.errors.single.severity,
          RuleSeverity.error,
          reason: label,
        );
      }
    });

    test('顶层字段 + 列级合并：条目优先，档案补齐，并记录来源', () {
      final profile = RuleProfileResolver.resolveBuiltin(archive()).profile!;
      final diagnostics = <RuleDiagnostic>[];
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'barbarian',
        entryRules: ClassRuleSet.parse(
          {
            'savingThrowAbilities': ['dex'],
          },
          path: r'$.structured.classRules',
          diagnostics: diagnostics,
        ),
      );
      expect(merged.hitDie, 12, reason: '档案补齐');
      expect(merged.savingThrowAbilities, {'dex'}, reason: '条目优先，整字段替换');
      expect(merged.fieldSources['hitDie']!.originId, 'builtin:dnd5e-2024');
      expect(
        merged.fieldSources['hitDie']!.tier,
        kBuiltinTier,
        reason: '档案来源 tier 0',
      );
      expect(merged.fieldSources['savingThrowAbilities']!.originId, '<entry>');
      expect(
        merged.fieldSources['savingThrowAbilities']!.tier,
        kEntryTier,
        reason: '条目来源 tier 100',
      );
      // 来源只记录真正被声明过的列/字段：双方都没声明 spellcasting / resources 时
      // 不得因为"默认空集合"而凭空记一条来源。
      expect(merged.fieldSources.keys, {'hitDie', 'savingThrowAbilities'});
    });

    test('spellcasting 的来源键是列级路径，不再是整块 spellcasting', () {
      final profile = RuleProfileResolver.resolveBuiltin(
        overrideArchive(),
      ).profile!;
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'wizard',
        entryRules: ClassRuleSet.parse(
          {
            'spellcasting': {
              'prepared': {'5': 9},
            },
          },
          path: _path,
          diagnostics: <RuleDiagnostic>[],
        ),
        entryId: 'errata:class/wizard',
      );
      expect(merged.fieldSources.containsKey('spellcasting'), isFalse);
      expect(
        merged.fieldSources[RuleFieldPath.spellcasting('prepared')]!.originId,
        'errata:class/wizard',
      );
      expect(
        merged.fieldSources[RuleFieldPath.spellcasting('slots')]!.originId,
        'builtin:dnd5e-2024',
      );
      expect(
        merged.fieldSources[RuleFieldPath.spellcasting('mode')]!.originId,
        'builtin:dnd5e-2024',
      );
    });

    test('条目完全没有规则时用档案，完全未声明时为空', () {
      final profile = RuleProfileResolver.resolveBuiltin(archive()).profile!;
      final fromArchive = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'barbarian',
        entryRules: null,
      );
      expect(fromArchive.hitDie, 12);
      final unknown = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'astral-knight',
        entryRules: null,
      );
      expect(unknown.hitDie, isNull);
      expect(unknown.savingThrowAbilities, isEmpty);
    });

    test('法术位解析：原型展开 + 整级替换 + minimumLevel', () {
      final profile = RuleProfileResolver.resolveBuiltin(archive()).profile!;
      final half = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'barbarian',
        entryRules: null,
      );
      expect(half.spellcasting, isNull);
      final caster = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'astral',
        entryRules: ClassRuleSet.parse(
          {
            'spellcasting': {
              'mode': 'prepared',
              'ability': 'wis',
              'archetype': 'half-caster',
              'slots': {
                '3': <String, Object?>{},
                '5': {'1': 9},
              },
            },
          },
          path: r'$.structured.classRules',
          diagnostics: <RuleDiagnostic>[],
        ),
      );
      expect(caster.spellSlots(1), {'1': 2}, reason: '原型展开');
      expect(caster.spellSlots(3), isEmpty, reason: '条目显式空表不回落原型');
      expect(caster.spellSlots(5), {'1': 9}, reason: '整级替换');
      expect(caster.preparedLimit(5), isNull, reason: '原型不承载 prepared（§3.1）');
      expect(caster.cantripLimit(5), isNull, reason: '原型不承载 cantrips（§3.1）');

      final third = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'astral',
        entryRules: ClassRuleSet.parse(
          {
            'spellcasting': {
              'mode': 'prepared',
              'ability': 'wis',
              'archetype': 'third-caster',
            },
          },
          path: r'$.structured.classRules',
          diagnostics: <RuleDiagnostic>[],
        ),
      );
      expect(third.spellSlots(2), isEmpty, reason: '低于原型 minimumLevel');
      expect(third.spellSlots(3), {'1': 1}, reason: '达到原型 minimumLevel 后展开');
    });

    test('maxSpellLevel：自身稀疏表低于最早声明等级时回退原型（§3.12）', () {
      final profile = RuleProfileResolver.resolveBuiltin(archive()).profile!;
      ResolvedClassRules withArchetype(String archetype, Object? ownTable) =>
          RuleProfileResolver.resolveClassRules(
            profile: profile,
            slug: 'astral',
            entryRules: ClassRuleSet.parse(
              {
                'spellcasting': {
                  'mode': 'prepared',
                  'ability': 'wis',
                  'archetype': archetype,
                  'maximumSpellLevel': ?ownTable,
                },
              },
              path: r'$.structured.classRules',
              diagnostics: <RuleDiagnostic>[],
            ),
          );

      // half-caster 的 minimumLevel = 1：自身表 5 级才声明，1..4 级回退原型。
      final half = withArchetype('half-caster', {'5': 3});
      expect(half.maxSpellLevel(1), 1, reason: '自身未声明该等级 → 回退原型');
      expect(half.maxSpellLevel(4), 1, reason: '低于自身表最早声明等级仍回退原型');
      expect(half.maxSpellLevel(5), 3, reason: '自身已声明 → 用自身值');
      expect(half.maxSpellLevel(9), 3, reason: '高于最后声明沿用自身最后值');

      // third-caster 的 minimumLevel = 3：原型的 minimumLevel 守卫独立生效
      // （它的 maximumSpellLevel 表本身最早声明等级是 1，两者不能互相冒充）。
      final third = withArchetype('third-caster', {'5': 4});
      expect(third.maxSpellLevel(2), isNull, reason: '低于原型 minimumLevel → 未声明');
      expect(third.maxSpellLevel(3), 2, reason: '达到原型 minimumLevel 后回退原型');
      expect(third.maxSpellLevel(5), 4, reason: '自身已声明 → 用自身值');
    });

    test('maxSpellLevel：none / 低于 minimumLevel / 正常三态都走统一守卫（§3.3）', () {
      final profile = RuleProfileResolver.resolveBuiltin(archive()).profile!;
      ResolvedClassRules withMode(String mode) =>
          RuleProfileResolver.resolveClassRules(
            profile: profile,
            slug: 'astral',
            entryRules: ClassRuleSet.parse(
              {
                'spellcasting': {
                  'mode': mode,
                  'ability': 'cha',
                  'archetype': 'pact',
                },
              },
              path: r'$.structured.classRules',
              diagnostics: <RuleDiagnostic>[],
            ),
          );

      expect(
        withMode('none').maxSpellLevel(5),
        isNull,
        reason: 'mode none → 最高环阶不存在（无守卫的旧实现会回退原型）',
      );
      expect(
        withMode('prepared').maxSpellLevel(2),
        isNull,
        reason: '低于原型 minimumLevel（原型表本身 1 级就有值）',
      );
      expect(
        withMode('prepared').maxSpellLevel(3),
        1,
        reason: '达到 minimumLevel 后回退原型（fixture 的 pact 表每级都是 1）',
      );
      expect(withMode('prepared').maxSpellLevel(9), 1, reason: '高于最后声明沿用');
    });

    test('spellcastingAbility：mode none 时不返回属性（§3.6 第 3 步）', () {
      final profile = RuleProfileResolver.resolveBuiltin(archive()).profile!;
      ResolvedClassRules withMode(String mode) =>
          RuleProfileResolver.resolveClassRules(
            profile: profile,
            slug: 'astral',
            entryRules: ClassRuleSet.parse(
              {
                'spellcasting': {'mode': mode, 'ability': 'cha'},
              },
              path: r'$.structured.classRules',
              diagnostics: <RuleDiagnostic>[],
            ),
          );
      expect(withMode('none').spellcastingAbility, isNull);
      expect(withMode('prepared').spellcastingAbility, 'cha');
    });

    test('资源：startsAtLevel 过滤 + 未声明上限跳过（不产出上限 0）', () {
      final profile = RuleProfileResolver.resolveBuiltin(archive()).profile!;
      final rules = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'astral',
        entryRules: ClassRuleSet.parse(
          {
            'resources': [
              {
                'id': 'surge',
                'name': '星界涌动',
                'recovery': 'shortRestOne',
                'maximum': {
                  'table': {'5': 3},
                },
              },
              {'id': 'late', 'name': '晚成', 'maximum': 2, 'startsAtLevel': 7},
            ],
          },
          path: r'$.structured.classRules',
          diagnostics: <RuleDiagnostic>[],
        ),
      );
      // 上限表 5 级才声明：3 级是"未声明"，必须整条跳过而不是上限 0。
      expect(rules.resourcesAt(3, const {}), isEmpty);
      final at5 = rules.resourcesAt(5, const {});
      expect(at5.single.id, 'surge');
      expect(at5.single.maximum, 3);
      expect(at5.single.recovery, 'shortRestOne');
      // startsAtLevel = 7 之前不出现该资源。
      expect(rules.resourcesAt(7, const {}).map((r) => r.id).toList(), [
        'surge',
        'late',
      ]);
    });

    test('resourcesAt：表内显式 0 仍是"存在但上限 0"的资源（§3.12）', () {
      final profile = RuleProfileResolver.resolveBuiltin(archive()).profile!;
      final rules = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'astral',
        entryRules: ClassRuleSet.parse(
          {
            'resources': [
              {
                'id': 'drained',
                'name': '枯竭',
                'maximum': {
                  'table': {'5': 0},
                },
              },
            ],
          },
          path: r'$.structured.classRules',
          diagnostics: <RuleDiagnostic>[],
        ),
      );
      expect(rules.resourcesAt(4, const {}), isEmpty, reason: '未声明等级整条跳过');
      final at5 = rules.resourcesAt(5, const {});
      expect(at5.single.id, 'drained');
      expect(at5.single.maximum, 0, reason: '显式 0 是合法上限，不是"未声明"');
    });
  });
}
