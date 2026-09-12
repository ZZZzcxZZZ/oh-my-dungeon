// test/rules/class_rule_declared_columns_test.dart
//
// 列级"已声明"判据（S3 任务 1，契约 §3.6/§3.7 与决策 D5）：只有
// `ClassSpellcasting.declares` / `ClassResourceRule.declares` 一处判据，
// 且判据是"键是否出现"而**不是**"值是否为 null"——显式 null（`archetype: null`）
// 是"清空该列"，与未声明不同。
import 'package:dnd_table_client/src/features/rules/domain/class_rule_set.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_diagnostic.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_field_path.dart';
import 'package:flutter_test/flutter_test.dart';

const _path = r'$.structured.classRules';

void main() {
  group('列级声明集合', () {
    test('spellcasting 只记录真正出现过的键', () {
      final diagnostics = <RuleDiagnostic>[];
      final rules = ClassRuleSet.parse({
        'spellcasting': {
          'prepared': {'5': 9},
        },
      }, path: _path, diagnostics: diagnostics);

      expect(
        diagnostics.where((d) => d.severity == RuleSeverity.error),
        isEmpty,
      );
      final spellcasting = rules.spellcasting!;
      expect(spellcasting.declares('prepared'), isTrue);
      for (final absent in [
        'mode',
        'ability',
        'listTags',
        'archetype',
        'slots',
        'slotLevel',
        'cantrips',
        'maximumSpellLevel',
      ]) {
        expect(spellcasting.declares(absent), isFalse, reason: absent);
      }
      // 缺省值仍然照契约生效，但**不算声明**。
      expect(spellcasting.mode, 'none');
      expect(spellcasting.listTags, isEmpty);
    });

    test('显式 null 的 archetype 记为已声明（可用来清空档案的列）', () {
      final diagnostics = <RuleDiagnostic>[];
      final rules = ClassRuleSet.parse({
        'spellcasting': {'mode': 'prepared', 'ability': 'cha', 'archetype': null},
      }, path: _path, diagnostics: diagnostics);

      expect(rules.spellcasting!.declares('archetype'), isTrue);
      expect(rules.spellcasting!.archetype, isNull);
      expect(rules.spellcasting!.declares('mode'), isTrue);
    });

    test('listTags 显式空数组算已声明，与"未声明"可区分', () {
      final diagnostics = <RuleDiagnostic>[];
      final rules = ClassRuleSet.parse({
        'spellcasting': {'listTags': <Object?>[]},
      }, path: _path, diagnostics: diagnostics);

      expect(
        diagnostics.where((d) => d.severity == RuleSeverity.error),
        isEmpty,
      );
      expect(rules.spellcasting!.declares('listTags'), isTrue);
      expect(rules.spellcasting!.listTags, isEmpty);
    });

    test('资源只记录真正出现过的键；缺省值不算声明', () {
      final diagnostics = <RuleDiagnostic>[];
      final rules = ClassRuleSet.parse({
        'resources': [
          {'id': 'rage', 'name': '狂暴', 'maximum': 2},
        ],
      }, path: _path, diagnostics: diagnostics);

      expect(diagnostics.where((d) => d.severity == RuleSeverity.error), isEmpty);
      final rage = rules.resources.single;
      expect(rage.declares('name'), isTrue);
      expect(rage.declares('maximum'), isTrue);
      expect(rage.declares('recovery'), isFalse);
      expect(rage.declares('startsAtLevel'), isFalse);
      expect(rage.recoveryAt(1), 'longRest', reason: '运行期默认值不变');
      expect(rage.startsAtLevel, 1, reason: '缺省值不变');
    });

    test('资源显式 0 算已声明，不被当成"未声明"', () {
      final diagnostics = <RuleDiagnostic>[];
      final rules = ClassRuleSet.parse({
        'resources': [
          {
            'id': 'rage',
            'name': '狂暴',
            'maximum': 0,
            'startsAtLevel': 1,
          },
          {
            'id': 'ward',
            'name': '守护',
            'maximum': {
              'table': {'1': 0},
            },
          },
        ],
      }, path: _path, diagnostics: diagnostics);

      expect(diagnostics.where((d) => d.severity == RuleSeverity.error), isEmpty);
      expect(rules.resources, hasLength(2));
      final rage = rules.resources[0];
      expect(rage.declares('maximum'), isTrue);
      expect(rage.maximum!.resolve(level: 1, abilities: const {}), 0);
      expect(rage.declares('startsAtLevel'), isTrue);
      expect(rules.resources[1].maximum!.resolve(level: 1, abilities: const {}), 0);
    });

    test('构造后 declares 与解析时出现的键逐项一致（fields 必填，漏填即编译错误）', () {
      // `fields` 是**必填**参数：漏填会让 declares 恒 false、整块静默退回低 tier，
      // 所以这里锁定"parse 填进去的集合 == 输入里出现过的键"这一契约。
      const rawSpellcasting = <String, Object?>{
        'mode': 'known',
        'ability': 'cha',
        'slots': {
          '1': {'1': 2},
        },
        'prepared': {'1': 4},
      };
      const rawResource = <String, Object?>{
        'id': 'rage',
        'name': '狂暴',
        'maximum': 2,
        'recovery': 'longRest',
      };
      final diagnostics = <RuleDiagnostic>[];
      final rules = ClassRuleSet.parse({
        'spellcasting': rawSpellcasting,
        'resources': [rawResource],
      }, path: _path, diagnostics: diagnostics);

      expect(
        diagnostics.where((d) => d.severity == RuleSeverity.error),
        isEmpty,
        reason: '$diagnostics',
      );
      final spellcasting = rules.spellcasting!;
      for (final column in RuleFieldPath.spellcastingColumns) {
        expect(
          spellcasting.declares(column),
          rawSpellcasting.containsKey(column),
          reason: 'spellcasting.$column',
        );
      }
      final rage = rules.resources.single;
      for (final column in RuleFieldPath.resourceColumns) {
        expect(
          rage.declares(column),
          rawResource.containsKey(column),
          reason: 'resources.rage.$column',
        );
      }
    });
  });

  group('来源字段路径', () {
    test('构造与列白名单', () {
      expect(RuleFieldPath.spellcasting('prepared'), 'spellcasting.prepared');
      expect(
        RuleFieldPath.resource('rage', 'maximum'),
        'resources.rage.maximum',
      );
      expect(RuleFieldPath.spellcastingColumns, {
        'mode',
        'ability',
        'listTags',
        'archetype',
        'slots',
        'slotLevel',
        'prepared',
        'cantrips',
        'maximumSpellLevel',
      });
      expect(RuleFieldPath.resourceColumns, {
        'name',
        'maximum',
        'recovery',
        'startsAtLevel',
      });
    });

    test('解析白名单由 RuleFieldPath 派生，不是第二份字面量', () {
      // 防漂移：`kSpellcastingFields` 必须就是列白名单本身；资源侧则是
      // "参与列级合并 / 记来源的列" ∪ {id 合键, description 无数值语义}。
      expect(kSpellcastingFields, same(RuleFieldPath.spellcastingColumns));
      expect(
        kResourceFields,
        {...RuleFieldPath.resourceColumns, 'id', 'description'},
      );
      expect(RuleFieldPath.resourceColumns, isNot(contains('id')));
      expect(RuleFieldPath.resourceColumns, isNot(contains('description')));
      expect(kResourceFields, containsAll(const ['id', 'description']));
    });

    test('每个路径都有中文展示名（UI 不得自己拼）', () {
      expect(RuleFieldPath.labelFor('hitDie'), '生命骰');
      expect(RuleFieldPath.labelFor('savingThrowAbilities'), '豁免熟练');
      expect(RuleFieldPath.labelFor('spellcasting.prepared'), '准备法术上限');
      // 资源列的中文名由调用方带上资源展示名（档案 / 条目的 `name`）；
      // 缺省时退回资源 id，绝不猜中文名。
      expect(
        RuleFieldPath.labelFor('resources.rage.maximum', resourceName: '狂暴'),
        '狂暴 · 次数上限',
      );
      expect(
        RuleFieldPath.labelFor('resources.rage.recovery', resourceName: '狂暴'),
        '狂暴 · 恢复',
      );
      expect(
        RuleFieldPath.labelFor(
          'resources.rage.startsAtLevel',
          resourceName: '狂暴',
        ),
        '狂暴 · 起始等级',
      );
      expect(RuleFieldPath.labelFor('resources.rage.maximum'), 'rage · 次数上限');
    });

    test('资源路径拆解，未知路径原样返回', () {
      expect(
        RuleFieldPath.parseResource('resources.storm-aura.maximum'),
        (id: 'storm-aura', column: 'maximum'),
      );
      expect(RuleFieldPath.parseResource('hitDie'), isNull);
      expect(RuleFieldPath.labelFor('unknown.path'), 'unknown.path');
    });
  });
}
