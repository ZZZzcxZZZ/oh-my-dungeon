import 'package:dnd_table_client/src/features/characters/domain/class_rule_summary.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_editor_page.dart';
import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_library_controller.dart';
import 'package:dnd_table_client/src/features/content/presentation/widgets/content_metadata_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/content_test_support.dart';

ContentEntry _classEntry(
  String id, {
  String name = '守望者',
  Map<String, Object?> structured = const {},
  Map<String, Object?>? rules,
}) => ContentEntry.fromJson({
  'id': id,
  'type': 'class',
  'slug': id.split('/').last,
  'name': name,
  'body': <Map<String, Object?>>[],
  'revision': 1,
  'structured': structured,
  'rules': ?rules,
});

/// 只有 `classRules` 的职业条目（旧散文键一律不存在）。
final _declaredOnly = _classEntry(
  'test:class/warden',
  structured: const {
    'primaryAbility': '力量或敏捷',
    'weaponProficiency': '简易武器',
    'armorProficiency': '轻甲',
    'classRules': {
      'hitDie': 10,
      'savingThrowAbilities': ['str', 'con'],
    },
  },
  rules: const {
    'choices': [
      {
        'id': 'skills',
        'label': '选择两项技能熟练',
        'optionType': 'skill',
        'minimum': 2,
        'maximum': 2,
        'options': ['运动', '察觉'],
      },
    ],
  },
);

Future<void> _goToBuilderStep(WidgetTester tester, int index) async {
  final unselected = find.byKey(Key('builder-step-$index'));
  final selected = find.byKey(Key('builder-step-$index-selected'));
  await tester.tap(unselected.evaluate().isNotEmpty ? unselected : selected);
  await tester.pumpAndSettle();
}

void main() {
  group('ClassRuleSummary（唯一口径）', () {
    test('未声明职业 / 条目为 null 时三项都是 null，不显示 0', () {
      expect(ClassRuleSummary.of(null), (
        hitDie: null,
        savingThrows: null,
        skillChoice: null,
      ));

      final bare = _classEntry('test:class/bare');
      expect(ClassRuleSummary.of(bare), (
        hitDie: null,
        savingThrows: null,
        skillChoice: null,
      ));
    });

    test('hitDie：声明 10 → d10；非法骰面 0 视为未声明而不是 d0', () {
      expect(ClassRuleSummary.of(_declaredOnly).hitDie, 'd10');
      expect(
        ClassRuleSummary.of(
          _classEntry(
            'test:class/zero-die',
            structured: const {
              'classRules': {'hitDie': 0},
            },
          ),
        ).hitDie,
        isNull,
      );
    });

    test('savingThrows：1 / 2 / 3 个属性分别用「、」「与」「、」连接', () {
      String? labelsFor(List<String> abilities) => ClassRuleSummary.of(
        _classEntry(
          'test:class/saves',
          structured: {
            'classRules': {
              'hitDie': 8,
              'savingThrowAbilities': abilities,
            },
          },
        ),
      ).savingThrows;

      expect(labelsFor(const ['wis']), '感知');
      expect(labelsFor(const ['str', 'con']), '力量与体质');
      expect(labelsFor(const ['str', 'dex', 'con']), '力量、敏捷、体质');
    });

    test('skillChoice：0 项未声明 → null；无候选 → 任选；有候选 → 选择', () {
      String? skillChoiceFor(Map<String, Object?>? rules) =>
          ClassRuleSummary.of(
            _classEntry('test:class/skills', rules: rules),
          ).skillChoice;

      expect(skillChoiceFor(null), isNull);
      expect(
        skillChoiceFor(const {
          'choices': [
            {'id': 'x', 'optionType': 'feat', 'minimum': 1, 'maximum': 1},
          ],
        }),
        isNull,
      );
      expect(
        skillChoiceFor(const {
          'choices': [
            {'id': 'x', 'optionType': 'skill', 'minimum': 1, 'maximum': 1},
          ],
        }),
        '任选1项（任意技能）',
      );
      expect(
        skillChoiceFor(const {
          'choices': [
            {
              'id': 'x',
              'optionType': 'skill',
              'minimum': 20,
              'maximum': 20,
              'options': ['运动', '察觉'],
            },
          ],
        }),
        '选择20项：运动、察觉',
      );
    });
  });

  group('创建向导职业摘要', () {
    testWidgets('只有 classRules 时步骤 0 / 4 仍显示生命骰与豁免熟练', (tester) async {
      tester.view.physicalSize = const Size(1200, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterEditorPage(
            defaultCreationMethod: 'standard',
            contentEntries: [_declaredOnly],
            onSubmit: (_) async => true,
          ),
        ),
      );

      expect(find.text('职业规则摘要'), findsOneWidget);
      expect(find.text('生命骰'), findsOneWidget);
      expect(find.text('d10'), findsOneWidget);

      await _goToBuilderStep(tester, 4);
      expect(find.text('职业熟练摘要'), findsOneWidget);
      expect(find.text('豁免熟练'), findsOneWidget);
      expect(find.text('力量与体质'), findsOneWidget);
      expect(find.text('技能选择'), findsOneWidget);
      expect(find.text('选择2项：运动、察觉'), findsOneWidget);
      expect(find.text('武器熟练'), findsOneWidget);
      expect(find.text('简易武器'), findsOneWidget);
    });

    testWidgets('完全未声明 classRules 时规则行不出现', (tester) async {
      tester.view.physicalSize = const Size(1200, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final bare = _classEntry(
        'test:class/bare',
        structured: const {'primaryAbility': '智力'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterEditorPage(
            defaultCreationMethod: 'standard',
            contentEntries: [bare],
            onSubmit: (_) async => true,
          ),
        ),
      );

      // 展示元数据仍在，但规则值未声明——不显示该行，也不显示 d0。
      expect(find.text('职业规则摘要'), findsOneWidget);
      expect(find.text('主属性'), findsOneWidget);
      expect(find.text('智力'), findsWidgets);
      expect(find.text('生命骰'), findsNothing);
      expect(find.text('d0'), findsNothing);

      await _goToBuilderStep(tester, 4);
      expect(find.text('豁免熟练'), findsNothing);
      expect(find.text('技能选择'), findsNothing);
    });
  });

  group('资料库职业卡片', () {
    testWidgets('渲染 生命骰 / 主属性 / 豁免熟练 / 技能选择（读 classRules）', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ContentMetadataView(entry: _declaredOnly)),
        ),
      );

      expect(find.text('生命骰'), findsOneWidget);
      expect(find.text('d10'), findsOneWidget);
      expect(find.text('主属性'), findsOneWidget);
      expect(find.text('力量或敏捷'), findsOneWidget);
      expect(find.text('豁免熟练'), findsOneWidget);
      expect(find.text('力量与体质'), findsOneWidget);
      expect(find.text('技能选择'), findsOneWidget);
      expect(find.text('选择2项：运动、察觉'), findsOneWidget);
    });

    testWidgets('未声明 classRules 时不渲染规则行', (tester) async {
      final bare = _classEntry('test:class/bare');

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ContentMetadataView(entry: bare))),
      );

      expect(find.text('生命骰'), findsNothing);
      expect(find.text('主属性'), findsNothing);
      expect(find.text('豁免熟练'), findsNothing);
      expect(find.text('技能选择'), findsNothing);
    });
  });

  group('生命骰 facet（计数与筛选共用同一派生点）', () {
    test('facet 计数从 classRules.hitDie 派生出 d10', () async {
      final controller = ContentLibraryController(
        repository: MemoryContentRepository(initialEntries: [_declaredOnly]),
      );

      final options = await controller.facetOptionsWithCounts(
        type: 'class',
        fields: const ['hitDie'],
      );

      expect(options['hitDie'], isNotNull);
      expect(options['hitDie']!.map((option) => option.value).toList(), ['d10']);
      expect(options['hitDie']!.single.count, 1);
    });

    test('facet 筛选按派生出的 d10 命中 / 按 d8 不命中', () {
      expect(contentEntryMatchesFacets(_declaredOnly, const {
        'hitDie': {'d10'},
      }), isTrue);
      expect(contentEntryMatchesFacets(_declaredOnly, const {
        'hitDie': {'d8'},
      }), isFalse);
    });

    test('未声明生命骰的职业不产生 facet 值', () {
      final bare = _classEntry('test:class/bare');
      expect(
        normalizedContentFacetValues(bare, 'hitDie', bare.structured['hitDie']),
        isEmpty,
      );
    });
  });
}
