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

  // 应修项：两个既有步骤共享同一等级时，旧实现"先占先得"会把后者整步丢弃
  // （`kept.isEmpty` 时连 grants 一起丢）——静默丢内容。
  test('两个既有步骤共享同一等级 → grants/choices 合并到同一步，不丢内容', () {
    final overlapping = ContentEntry.fromJson(<String, Object?>{
      'id': 'legacy:class/overlap',
      'type': 'class',
      'slug': 'overlap',
      'name': '重叠者',
      'body': <Object?>[],
      'revision': 1,
      'structured': <String, Object?>{
        'classRules': <String, Object?>{'hitDie': 8},
        'features': <String>['3级：旧版特性 说明。'],
      },
      'rules': <String, Object?>{
        'progression': <Map<String, Object?>>[
          <String, Object?>{
            'levels': <int>[3],
            'grants': <Map<String, Object?>>[
              <String, Object?>{'id': 'g-a', 'kind': 'feature', 'label': '甲'},
            ],
          },
          <String, Object?>{
            'levels': <int>[3],
            'grants': <Map<String, Object?>>[
              <String, Object?>{'id': 'g-b', 'kind': 'feature', 'label': '乙'},
            ],
            'choices': <Map<String, Object?>>[
              <String, Object?>{
                'id': 'choice-b',
                'label': '乙的选择',
                'optionType': 'feat',
                'minimum': 1,
                'maximum': 1,
              },
            ],
          },
        ],
      },
    });

    final migrated = const LegacyClassFeatureRulesMigrator()
        .migrate([overlapping])
        .singleWhere((entry) => entry.type == 'class');
    final progression = migrated.rules!.progression;

    expect(progression, hasLength(1));
    final levelThree = progression.single;
    expect(levelThree.levels, <int>[3]);
    expect(
      levelThree.grants.map((grant) => grant.id),
      containsAll(<String>['g-a', 'g-b']),
      reason: '两个步骤的授予都要保留，后者不能被丢弃',
    );
    expect(
      levelThree.choices.map((choice) => choice.id),
      containsAll(<String>['choice-b']),
      reason: '后者的选择也不能丢',
    );
    expect(
      levelThree.grants.where((grant) => grant.id == 'feature-3-1'),
      hasLength(1),
      reason: '旧版逐级特性的授予并入同一步',
    );
  });

  test('migrate 幂等：连续迁移两次结果完全相同', () {
    final migrator = const LegacyClassFeatureRulesMigrator();
    // 独立构造条目：migrator 会把 `structured.features` 摘掉后再产出，
    // 复用同一实例会让"第二次迁移"的输入带上前一次的副作用。
    final first = migrator.migrate([classEntry()]);
    final second = migrator.migrate(first);

    String signature(List<ContentEntry> entries) => entries
        .map(
          (entry) =>
              '${entry.id}|${entry.type}|'
              '${entry.rules?.progression.map((step) => step.levels.join('.')).join(',') ?? ''}',
        )
        .join('\n');

    expect(second.map((entry) => entry.id).toList(), first.map((entry) => entry.id).toList());
    expect(
      signature(second),
      signature(first),
      reason: '把迁移结果再迁移一次不得改变条目集合与 progression 形状',
    );
  });
}
