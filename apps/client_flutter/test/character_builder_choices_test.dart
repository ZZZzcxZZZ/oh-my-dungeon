import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_editor_page.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_upgrade_page.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Spec §创建与升级选择: 自动授予单独显示；必选项未完成时不能创建；
// 子职业通过 progression choice + subclassOf 关系加载；属性生成支持
// 标准数组/购点/随机并在审核页显示来源；升级页点击关联条目使用当前 reader。
void main() {
  testWidgets(
    'auto-grants are shown separately from required choices',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterEditorPage(
            defaultCreationMethod: 'standard',
            contentEntries: [
              _entry(
                id: 'guide:class/fighter',
                type: 'class',
                name: '战士',
                revision: 1,
                structured: const {'hitDie': 'd10'},
                rules: const {
                  'progression': [
                    {
                      'level': 1,
                      'grants': [
                        {
                          'id': 'second-wind',
                          'kind': 'feature',
                          'entryId': 'guide:class-feature/second-wind',
                          'label': '回气',
                        },
                      ],
                      'choices': [
                        {
                          'id': 'fighting-style',
                          'label': '选择战斗风格',
                          'optionType': 'classFeature',
                          'minimum': 1,
                          'maximum': 1,
                          'optionEntryIds': ['guide:class-feature/defense'],
                        },
                      ],
                    },
                  ],
                },
              ),
              _entry(
                id: 'guide:background/soldier',
                type: 'background',
                name: '士兵',
                revision: 1,
                rules: const {},
              ),
              _entry(
                id: 'guide:species/human',
                type: 'species',
                name: '人类',
                revision: 1,
                rules: const {},
              ),
              _entry(
                id: 'guide:class-feature/second-wind',
                type: 'classFeature',
                name: '回气',
                revision: 1,
                rules: const {},
              ),
              _entry(
                id: 'guide:class-feature/defense',
                type: 'classFeature',
                name: '防御战斗风格',
                revision: 1,
                rules: const {},
              ),
            ],
            onSubmit: (draft) async => true,
          ),
        ),
      );

      // 自动授予单独显示在"自动获得"卡片中。
      expect(find.text('自动获得'), findsOneWidget);
      expect(find.text('回气'), findsOneWidget);
      // 必选项显示为独立的规则选择卡片。
      expect(find.text('选择战斗风格'), findsOneWidget);
      expect(find.text('防御战斗风格'), findsOneWidget);
    },
  );

  testWidgets('required choices block creation until resolved', (tester) async {
    tester.view.physicalSize = const Size(1200, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          defaultCreationMethod: 'standard',
          contentEntries: [
            _entry(
              id: 'guide:class/fighter',
              type: 'class',
              name: '战士',
              revision: 1,
              structured: const {'hitDie': 'd10'},
              rules: const {
                'progression': [
                  {
                    'level': 1,
                    'choices': [
                      {
                        'id': 'fighting-style',
                        'label': '选择战斗风格',
                        'optionType': 'classFeature',
                        'minimum': 1,
                        'maximum': 1,
                        'optionEntryIds': ['guide:class-feature/defense'],
                      },
                    ],
                  },
                ],
              },
            ),
            _entry(
              id: 'guide:background/soldier',
              type: 'background',
              name: '士兵',
              revision: 1,
              rules: const {},
            ),
            _entry(
              id: 'guide:species/human',
              type: 'species',
              name: '人类',
              revision: 1,
              rules: const {},
            ),
            _entry(
              id: 'guide:class-feature/defense',
              type: 'classFeature',
              name: '防御战斗风格',
              revision: 1,
              rules: const {},
            ),
          ],
          onSubmit: (draft) async => true,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('standard-character-name-field')),
      '布伦',
    );
    await tester.pumpAndSettle();

    // 未完成必选项时，审核页的创建按钮应被禁用。
    await _goToDesktopStep(tester, 8);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '创建角色'))
          .onPressed,
      isNull,
    );

    // 回到职业步骤选择战斗风格。
    await _goToDesktopStep(tester, 0);
    await tester.ensureVisible(find.text('防御战斗风格'));
    await tester.tap(find.text('防御战斗风格'));
    await tester.pumpAndSettle();

    // 选择完成后，创建按钮应启用。
    await _goToDesktopStep(tester, 8);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '创建角色'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'subclasses load via progression choice and subclassOf relation',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterEditorPage(
            defaultCreationMethod: 'standard',
            contentEntries: [
              _entry(
                id: 'guide:class/fighter',
                type: 'class',
                name: '战士',
                revision: 1,
                structured: const {'hitDie': 'd10'},
                rules: const {
                  'progression': [
                    {
                      'level': 3,
                      'choices': [
                        {
                          'id': 'martial-archetype',
                          'label': '选择武术原型',
                          'optionType': 'subclass',
                          'minimum': 1,
                          'maximum': 1,
                        },
                      ],
                    },
                  ],
                },
              ),
              _entry(
                id: 'guide:background/soldier',
                type: 'background',
                name: '士兵',
                revision: 1,
                rules: const {},
              ),
              _entry(
                id: 'guide:species/human',
                type: 'species',
                name: '人类',
                revision: 1,
                rules: const {},
              ),
              _entry(
                id: 'guide:subclass/champion',
                type: 'subclass',
                name: '冠军',
                revision: 1,
                rules: const {},
                relations: const [
                  {'type': 'subclassOf', 'targetId': 'guide:class/fighter'},
                ],
              ),
              _entry(
                id: 'guide:subclass/thief',
                type: 'subclass',
                name: '盗贼',
                revision: 1,
                rules: const {},
                relations: const [
                  {'type': 'subclassOf', 'targetId': 'guide:class/rogue'},
                ],
              ),
            ],
            onSubmit: (draft) async => true,
          ),
        ),
      );

      // 选择职业并将等级提升到 3 以解锁子职业选择。
      await tester.tap(find.text('战士'), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('standard-level-increment-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('standard-level-increment-button')));
      await tester.pumpAndSettle();

      // 只有 subclassOf 当前职业的子职业才出现；不硬编码职业名称。
      expect(find.text('选择武术原型'), findsOneWidget);
      expect(find.text('冠军'), findsOneWidget);
      expect(find.text('盗贼'), findsNothing);
    },
  );

  testWidgets(
    'ability generation exposes standard, point-buy, and rolled methods',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterEditorPage(
            defaultCreationMethod: 'standard',
            contentEntries: [
              _entry(
                id: 'guide:class/fighter',
                type: 'class',
                name: '战士',
                revision: 1,
                structured: const {'hitDie': 'd10'},
                rules: const {},
              ),
              _entry(
                id: 'guide:background/soldier',
                type: 'background',
                name: '士兵',
                revision: 1,
                rules: const {},
              ),
              _entry(
                id: 'guide:species/human',
                type: 'species',
                name: '人类',
                revision: 1,
                rules: const {},
              ),
            ],
            onSubmit: (draft) async => true,
          ),
        ),
      );

      // 属性步骤暴露三种生成方式。
      await _goToDesktopStep(tester, 3);
      expect(find.byKey(const Key('ability-method-standard')), findsOneWidget);
      expect(find.byKey(const Key('ability-method-point-buy')), findsOneWidget);
      expect(find.byKey(const Key('ability-method-rolled')), findsOneWidget);

      // 切换到购点模式应显示剩余点数。
      await tester.tap(find.byKey(const Key('ability-method-point-buy')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('point-buy-remaining')), findsOneWidget);
    },
  );

  // GAP: 升级页 _ChoiceOptions 缺少打开 reader 的 IconButton。
  testWidgets(
    'upgrade page choice options open the reader on tap',
    (tester) async {
      final entries = <ContentEntry>[
        _entry(
          id: 'class:fighter',
          type: 'class',
          name: '战士',
          structured: const {'hitDie': 10},
          rules: const {
            'progression': [
              {
                'level': 2,
                'choices': [
                  {
                    'id': 'style',
                    'label': '战斗风格',
                    'optionType': 'feat',
                    'minimum': 1,
                    'maximum': 1,
                  },
                ],
              },
            ],
          },
        ),
        _entry(id: 'feat:defense', type: 'feat', name: '防御'),
      ];
      final character = CharacterSheet.local(
        id: 'hero',
        name: '阿雅',
        level: 1,
        classSummary: '战士',
      ).copyWith(
        maxHp: 12,
        currentHp: 12,
        abilities: const {
          'str': 16,
          'dex': 12,
          'con': 14,
          'int': 10,
          'wis': 10,
          'cha': 8,
        },
        data: const {
          'build': {
            'level': 1,
            'selections': {'class': 'class:fighter'},
            'choices': {},
          },
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterUpgradePage(
            character: character,
            contentEntries: entries,
            onApply: (value) async => true,
          ),
        ),
      );

      // 升级页的选项应提供打开 reader 的按钮（与创建向导一致的 key 规范）。
      expect(
        find.byKey(const Key('builder-open-entry-feat:defense')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('builder-open-entry-feat:defense')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('content-detail-close')), findsOneWidget);
      await tester.tap(find.byKey(const Key('content-detail-close')));
      await tester.pumpAndSettle();
    },
  );

  // GAP: 审核页未显示属性生成来源。
  testWidgets(
    'review step shows the ability generation source',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterEditorPage(
            defaultCreationMethod: 'standard',
            contentEntries: [
              _entry(
                id: 'guide:class/fighter',
                type: 'class',
                name: '战士',
                revision: 1,
                structured: const {'hitDie': 'd10'},
                rules: const {},
              ),
              _entry(
                id: 'guide:background/soldier',
                type: 'background',
                name: '士兵',
                revision: 1,
                rules: const {},
              ),
              _entry(
                id: 'guide:species/human',
                type: 'species',
                name: '人类',
                revision: 1,
                rules: const {},
              ),
            ],
            onSubmit: (draft) async => true,
          ),
        ),
      );

      // 选择购点生成方式。
      await _goToDesktopStep(tester, 3);
      await tester.tap(find.byKey(const Key('ability-method-point-buy')));
      await tester.pumpAndSettle();

      // 审核页应显示属性生成来源。
      await _goToDesktopStep(tester, 8);
      expect(find.text('27 点购点'), findsOneWidget);
    },
  );
}

Future<void> _goToDesktopStep(WidgetTester tester, int index) async {
  final unselected = find.byKey(Key('builder-step-$index'));
  final selected = find.byKey(Key('builder-step-$index-selected'));
  await tester.tap(unselected.evaluate().isNotEmpty ? unselected : selected);
  await tester.pumpAndSettle();
}

ContentEntry _entry({
  required String id,
  required String type,
  required String name,
  int revision = 1,
  Map<String, Object?> structured = const {},
  Map<String, Object?>? rules,
  List<Map<String, Object?>> relations = const [],
}) {
  return ContentEntry.fromJson({
    'id': id,
    'type': type,
    'slug': id.split('/').last,
    'name': name,
    'body': <Map<String, Object?>>[],
    'revision': revision,
    'structured': structured,
    'rules': ?rules,
    'relations': relations,
  });
}
