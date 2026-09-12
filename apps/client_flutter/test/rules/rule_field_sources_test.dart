// test/rules/rule_field_sources_test.dart
//
// S3 任务 4：来源表的列级序列化与确定性排序（契约 §3.7）。
import 'package:dnd_table_client/src/features/rules/domain/rule_field_path.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuleFieldSource 序列化', () {
    test('往返不丢字段，未知 origin 原样保留', () {
      const source = RuleFieldSource(
        field: 'spellcasting.prepared',
        originId: 'errata-pack:class/wizard',
        tier: 140,
      );
      final json = source.toJson();
      expect(json, {
        'field': 'spellcasting.prepared',
        'originId': 'errata-pack:class/wizard',
        'tier': 140,
      });
      final restored = RuleFieldSource.fromJson(json);
      expect(restored, isNotNull);
      expect(restored!.field, source.field);
      expect(restored.originId, source.originId);
      expect(restored.tier, source.tier);
    });

    test('坏数据返回 null（不抛异常、不静默造值）', () {
      expect(RuleFieldSource.fromJson({'field': '', 'originId': 'a'}), isNull);
      expect(
        RuleFieldSource.fromJson({
          'field': 'hitDie',
          'originId': '',
          'tier': 0,
        }),
        isNull,
      );
      expect(
        RuleFieldSource.fromJson({'field': 'hitDie', 'originId': 'a', 'tier': '0'}),
        isNull,
      );
      expect(RuleFieldSource.fromJson(null), isNull);
      expect(RuleFieldSource.fromJson('hitDie'), isNull);
    });
  });

  group('RuleFieldSourceMap', () {
    test('toData 按字段路径升序（持久化稳定，UI 不抖动）', () {
      final data = RuleFieldSourceMap.toData({
        RuleFieldPath.spellcasting('slots'): const RuleFieldSource(
          field: 'spellcasting.slots',
          originId: 'builtin:dnd5e-2024',
          tier: 0,
        ),
        RuleFieldPath.hitDie: const RuleFieldSource(
          field: 'hitDie',
          originId: 'builtin:dnd5e-2024',
          tier: 0,
        ),
        RuleFieldPath.spellcasting('prepared'): const RuleFieldSource(
          field: 'spellcasting.prepared',
          originId: 'x:class/wizard',
          tier: 100,
        ),
      });
      expect(data.keys.toList(), [
        'hitDie',
        'spellcasting.prepared',
        'spellcasting.slots',
      ]);
    });

    test('fromData 跳过坏条目而不是整块丢掉', () {
      final sources = RuleFieldSourceMap.fromData({
        'hitDie': {'field': 'hitDie', 'originId': 'builtin:dnd5e-2024', 'tier': 0},
        'broken': {'field': '', 'originId': ''},
      });
      expect(sources.keys, {'hitDie'});
      expect(sources['hitDie']!.originId, 'builtin:dnd5e-2024');
    });

    test('fromData 对非 Map 输入返回空表（不抛异常）', () {
      expect(RuleFieldSourceMap.fromData(null), isEmpty);
      expect(RuleFieldSourceMap.fromData(<Object?>[]), isEmpty);
    });

    test('往返：toData → fromData 保持列级路径与 tier', () {
      final sources = RuleFieldSourceMap.fromData(
        RuleFieldSourceMap.toData({
          RuleFieldPath.resource('rage', 'maximum'): const RuleFieldSource(
            field: 'resources.rage.maximum',
            originId: 'errata:class/barbarian',
            tier: 130,
          ),
        }),
      );
      expect(sources['resources.rage.maximum']!.originId, 'errata:class/barbarian');
      expect(sources['resources.rage.maximum']!.tier, 130);
    });
  });

  group('ResolvedClassRules 来源读取口', () {
    test('未声明该列时返回 null；资源列按完整路径查', () {
      const rules = ResolvedClassRules(
        fieldSources: {
          'resources.rage.maximum': RuleFieldSource(
            field: 'resources.rage.maximum',
            originId: 'builtin:dnd5e-2024',
            tier: 0,
          ),
        },
      );
      expect(rules.sourceOf('resources.rage.maximum')!.tier, 0);
      expect(rules.sourceOf('resources.rage.recovery'), isNull);
    });

    test('activeOriginIds 去重且升序；只有内置档案时没有覆盖来源', () {
      const builtinOnly = ResolvedClassRules(
        fieldSources: {
          'hitDie': RuleFieldSource(
            field: 'hitDie',
            originId: 'builtin:dnd5e-2024',
            tier: 0,
          ),
          'spellcasting.mode': RuleFieldSource(
            field: 'spellcasting.mode',
            originId: 'builtin:dnd5e-2024',
            tier: 0,
          ),
        },
      );
      expect(builtinOnly.activeOriginIds, ['builtin:dnd5e-2024']);

      const withOverride = ResolvedClassRules(
        fieldSources: {
          'hitDie': RuleFieldSource(
            field: 'hitDie',
            originId: 'builtin:dnd5e-2024',
            tier: 0,
          ),
          'spellcasting.prepared': RuleFieldSource(
            field: 'spellcasting.prepared',
            originId: 'errata:class/wizard',
            tier: 100,
          ),
          'spellcasting.slots': RuleFieldSource(
            field: 'spellcasting.slots',
            originId: 'errata:class/wizard',
            tier: 100,
          ),
        },
      );
      expect(withOverride.activeOriginIds, [
        'builtin:dnd5e-2024',
        'errata:class/wizard',
      ]);
    });
  });
}
