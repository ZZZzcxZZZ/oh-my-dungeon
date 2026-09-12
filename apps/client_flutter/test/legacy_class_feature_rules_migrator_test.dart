import 'package:dnd_table_client/src/features/content/data/import/legacy_class_feature_rules_migrator.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:flutter_test/flutter_test.dart';

// 缺陷 2：旧版 `structured.features` 逐级特性与既有多等级步骤（`levels: [4,8,12,16]`）
// 合并时，旧的"level → step"映射会把同一步骤按等级复制成多份，并留下重叠区间：
// 规则页重复渲染、`activeChoices`/`pendingChoices` 重复、升级页同一 choice 出现多次。
void main() {
  ContentEntry classEntry() => ContentEntry.fromJson(<String, Object?>{
    'id': 'legacy:class/fighter',
    'type': 'class',
    'slug': 'fighter',
    'name': '战士',
    'body': <Object?>[],
    'revision': 1,
    'structured': <String, Object?>{
      'classRules': <String, Object?>{'hitDie': 10},
      'features': <String>[
        '2级：回气 你可以恢复生命值。',
        '8级：坚不可摧 你获得额外生命。',
      ],
    },
    'rules': <String, Object?>{
      'progression': <Map<String, Object?>>[
        <String, Object?>{
          'levels': <int>[4, 8, 12, 16],
          'grants': <Map<String, Object?>>[
            <String, Object?>{
              'id': 'asi-int',
              'kind': 'ability',
              'target': 'int',
              'value': 1,
              'label': '属性提升：智力 +1',
            },
          ],
          'choices': <Map<String, Object?>>[
            <String, Object?>{
              'id': 'asi-or-feat',
              'label': '属性提升或专长',
              'optionType': 'feat',
              'minimum': 1,
              'maximum': 1,
            },
          ],
        },
      ],
    },
  });

  List<ContentEntry> migrateClassEntries() {
    final entries = const LegacyClassFeatureRulesMigrator().migrate([
      classEntry(),
    ]);
    return entries.where((entry) => entry.type == 'class').toList();
  }

  test('多等级步骤按对象身份只输出一次，不按等级复制', () {
    final migrated = migrateClassEntries().single;
    final progression = migrated.rules!.progression;

    final signatures = progression
        .map((step) => step.levels.join(','))
        .toList(growable: false);
    expect(
      signatures.toSet(),
      hasLength(signatures.length),
      reason: '同一步骤不能被复制成多份：$signatures',
    );
    expect(
      progression
          .where((step) => step.levels.contains(4) && step.levels.contains(16)),
      hasLength(1),
      reason: 'levels:[4,8,12,16] 的步骤只能出现一次',
    );
  });

  test('被替换的等级从原步骤 levels 里摘掉，同一等级不被两个步骤覆盖', () {
    final migrated = migrateClassEntries().single;
    final progression = migrated.rules!.progression;

    final covered = <int>[];
    for (final step in progression) {
      covered.addAll(step.levels);
    }
    expect(
      covered.toSet(),
      hasLength(covered.length),
      reason: '同一等级被两个步骤同时覆盖：$covered',
    );

    // 8 级由旧版逐级特性接管：原步骤只保留 4/12/16，8 级单独成步。
    final multi = progression.singleWhere((step) => step.levels.contains(16));
    expect(multi.levels, <int>[4, 12, 16]);
    final levelEight = progression.singleWhere((step) => step.levels.contains(8));
    expect(levelEight.levels, <int>[8]);
    expect(
      levelEight.grants.map((grant) => grant.id),
      containsAll(<String>['asi-int', 'feature-8-1']),
      reason: '被替换等级要保留原步骤的授予并并入旧版特性',
    );
    expect(
      levelEight.choices.map((choice) => choice.id),
      contains('asi-or-feat'),
      reason: '原步骤的选择也要跟着被替换的等级走',
    );
    expect(
      multi.grants.map((grant) => grant.id),
      <String>['asi-int'],
      reason: '原步骤剩余的等级仍带原来的授予',
    );
    expect(progression.singleWhere((step) => step.levels.contains(2)).levels, [
      2,
    ]);
  });

  test('旧版特性仍生成独立条目', () {
    final entries = const LegacyClassFeatureRulesMigrator().migrate([
      classEntry(),
    ]);

    expect(entries.where((entry) => entry.type == 'classFeature'), hasLength(2));
  });
}
