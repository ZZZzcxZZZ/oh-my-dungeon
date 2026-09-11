import 'package:dnd_table_client/src/features/characters/domain/character_edit_draft.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_editor_page.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('guided builder uses a focused desktop step workflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          defaultCreationMethod: 'standard',
          onSubmit: (_) async => true,
        ),
      ),
    );

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('选择职业'), findsOneWidget);
    expect(
      find.byKey(const Key('standard-character-name-field')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('standard-ability-str-field')), findsNothing);

    await tester.tap(find.byKey(const Key('builder-step-3')));
    await tester.pumpAndSettle();

    expect(find.text('设置属性'), findsOneWidget);
    expect(find.byKey(const Key('standard-ability-str-field')), findsOneWidget);
    expect(find.text('选择职业'), findsNothing);

    await tester.tap(find.byKey(const Key('builder-step-8')));
    await tester.pumpAndSettle();

    expect(find.text('审核角色'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '创建角色'), findsOneWidget);
  });

  testWidgets('guided builder persists stable D&D 2024 content selections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    CharacterEditDraft? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          defaultCreationMethod: 'standard',
          contentEntries: [
            _entry(
              id: 'guide:class/fighter',
              type: 'class',
              name: '战士',
              revision: 3,
              structured: const {'hitDie': 'd10'},
              rules: const {
                'grants': [
                  {
                    'id': 'strength-save',
                    'kind': 'proficiency',
                    'target': 'save:str',
                    'label': '力量豁免',
                  },
                ],
              },
            ),
            _entry(
              id: 'guide:background/soldier',
              type: 'background',
              name: '士兵',
              revision: 2,
              rules: const {
                'grants': [
                  {
                    'id': 'athletics',
                    'kind': 'proficiency',
                    'target': 'skill:运动',
                    'label': '运动熟练',
                  },
                ],
              },
            ),
            _entry(
              id: 'guide:species/human',
              type: 'species',
              name: '人类',
              revision: 4,
              rules: const {
                'grants': [
                  {
                    'id': 'walking-speed',
                    'kind': 'speed',
                    'value': 30,
                    'label': '步行速度',
                  },
                ],
              },
            ),
          ],
          onSubmit: (draft) async {
            submitted = draft;
            return true;
          },
        ),
      ),
    );

    expect(find.text('自动获得'), findsOneWidget);
    expect(find.text('力量豁免'), findsOneWidget);
    await tester.tap(find.byTooltip('查看 战士'));
    await tester.pumpAndSettle();
    expect(find.text('角色规则'), findsOneWidget);
    await tester.tap(find.byKey(const Key('content-detail-close')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('standard-character-name-field')),
      '莱娅',
    );
    await tester.pumpAndSettle();
    await _goToDesktopStep(tester, 8);
    await tester.ensureVisible(find.widgetWithText(FilledButton, '创建角色'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '创建角色'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.widgetWithText(FilledButton, '创建角色'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    final build = submitted!.data['build'] as Map<String, Object?>;
    expect(build['selections'], {
      'class': 'guide:class/fighter',
      'species': 'guide:species/human',
      'background': 'guide:background/soldier',
    });
    expect(submitted!.saves['str'], isTrue);
    expect(submitted!.skills['运动'], isTrue);
    expect(
      submitted!.contentReferences.map(
        (reference) => '${reference.entryKey}@${reference.sourceRevision}',
      ),
      containsAll([
        'guide:class/fighter@3',
        'guide:background/soldier@2',
        'guide:species/human@4',
      ]),
    );
  });

  testWidgets('guided builder requires and resolves level rule choices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    CharacterEditDraft? submitted;
    final fightingStyle = _entry(
      id: 'guide:class-feature/defense',
      type: 'classFeature',
      name: '防御战斗风格',
      revision: 1,
      rules: const {
        'grants': [
          {
            'id': 'defense-ac',
            'kind': 'armorClass',
            'value': 1,
            'label': '防御加值',
          },
        ],
        'choices': [
          {
            'id': 'maneuver',
            'label': '选择战技',
            'optionType': 'feature',
            'minimum': 1,
            'maximum': 1,
            'optionEntryIds': ['guide:feature/riposte'],
          },
        ],
      },
    );
    final riposte = _entry(
      id: 'guide:feature/riposte',
      type: 'feature',
      name: '还击',
      revision: 1,
      rules: const {
        'grants': [
          {'id': 'riposte-action', 'kind': 'action', 'label': '还击动作'},
        ],
      },
    );
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
                    'levels': [1],
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
            fightingStyle,
            riposte,
          ],
          onSubmit: (draft) async {
            submitted = draft;
            return true;
          },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('standard-character-name-field')),
      '布伦',
    );
    await tester.pumpAndSettle();
    expect(find.text('选择战斗风格'), findsOneWidget);
    expect(find.text('防御战斗风格'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '创建角色'), findsNothing);

    await _goToDesktopStep(tester, 8);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '创建角色'))
          .onPressed,
      isNull,
    );

    await _goToDesktopStep(tester, 0);
    await tester.ensureVisible(find.text('防御战斗风格'));
    await tester.tap(find.text('防御战斗风格'));
    await tester.pumpAndSettle();
    expect(find.text('选择战技'), findsOneWidget);
    expect(find.text('还击'), findsOneWidget);
    await tester.tap(find.text('还击'));
    await tester.pumpAndSettle();
    await _goToDesktopStep(tester, 8);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '创建角色'))
          .onPressed,
      isNotNull,
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, '创建角色'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '创建角色'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    final contentRefs = submitted!.data['contentRefs'] as Map<String, Object?>;
    expect(
      contentRefs['features'],
      containsAll(['guide:class-feature/defense', 'guide:feature/riposte']),
    );
    expect(submitted!.armorClass, 13);
  });

  testWidgets('routes automated spell and equipment choices to their steps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    CharacterEditDraft? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          defaultCreationMethod: 'standard',
          contentEntries: [
            _entry(
              id: 'guide:class/mage',
              type: 'class',
              name: 'Mage',
              revision: 1,
              structured: const {'hitDie': 'd6'},
              rules: const {
                'progression': [
                  {
                    'levels': [1],
                    'choices': [
                      {
                        'id': 'starting-spells',
                        'label': 'Choose starting spells',
                        'optionType': 'spell',
                        'minimum': 2,
                        'maximum': 2,
                        'optionTags': ['spell-list:mage'],
                        'maximumOptionLevel': 1,
                        'recommendedEntryIds': [
                          'guide:spell/spark',
                          'guide:spell/ward',
                        ],
                        'builderStep': 'spells',
                      },
                      {
                        'id': 'starting-equipment',
                        'label': 'Choose equipment pack',
                        'optionType': 'equipmentBundle',
                        'minimum': 1,
                        'maximum': 1,
                        'recommendedEntryIds': [
                          'guide:equipment-bundle/scholar',
                        ],
                        'builderStep': 'equipment',
                      },
                    ],
                  },
                ],
              },
            ),
            _entry(
              id: 'guide:species/human',
              type: 'species',
              name: 'Human',
              revision: 1,
              rules: const {},
            ),
            _entry(
              id: 'guide:background/sage',
              type: 'background',
              name: 'Sage',
              revision: 1,
              rules: const {},
            ),
            _entry(
              id: 'guide:spell/spark',
              type: 'spell',
              name: 'Spark',
              revision: 1,
              structured: const {'level': 0},
              tags: const ['spell-list:mage'],
              rules: const {},
            ),
            _entry(
              id: 'guide:spell/ward',
              type: 'spell',
              name: 'Ward',
              revision: 1,
              structured: const {'level': 1},
              tags: const ['spell-list:mage'],
              rules: const {},
            ),
            _entry(
              id: 'guide:spell/storm',
              type: 'spell',
              name: 'Storm',
              revision: 1,
              structured: const {'level': 2},
              tags: const ['spell-list:mage'],
              rules: const {},
            ),
            _entry(
              id: 'guide:equipment-bundle/scholar',
              type: 'equipmentBundle',
              name: 'Scholar pack',
              revision: 1,
              rules: const {
                'grants': [
                  {
                    'id': 'book',
                    'kind': 'equipment',
                    'label': 'Book',
                    'entryId': 'guide:equipment/book',
                  },
                ],
              },
            ),
            _entry(
              id: 'guide:equipment/book',
              type: 'equipment',
              name: 'Book',
              revision: 1,
              rules: const {},
            ),
          ],
          onSubmit: (draft) async {
            submitted = draft;
            return true;
          },
        ),
      ),
    );

    expect(find.text('Choose starting spells'), findsNothing);
    expect(find.text('Choose equipment pack'), findsNothing);

    await _goToDesktopStep(tester, 5);
    expect(find.text('Choose equipment pack'), findsOneWidget);
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Scholar pack'))
          .selected,
      isTrue,
    );

    await _goToDesktopStep(tester, 6);
    expect(find.text('Choose starting spells'), findsOneWidget);
    expect(find.text('Spark'), findsWidgets);
    expect(find.text('Ward'), findsWidgets);
    expect(find.text('Storm'), findsNothing);
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Spark'))
          .selected,
      isTrue,
    );

    await tester.enterText(
      find.byKey(const Key('standard-character-name-field')),
      'Aria',
    );
    await _goToDesktopStep(tester, 8);
    await tester.ensureVisible(find.widgetWithText(FilledButton, '创建角色'));
    await tester.tap(find.widgetWithText(FilledButton, '创建角色'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    final refs = submitted!.data['contentRefs'] as Map<String, Object?>;
    expect(
      refs['spells'],
      containsAll(['guide:spell/spark', 'guide:spell/ward']),
    );
    expect(refs['items'], contains('guide:equipment/book'));
  });

  testWidgets('standard builder 按条目身份算职业数值（法术位 / 职业资源 / 声明范围）', (tester) async {
    tester.view.physicalSize = const Size(1200, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    CharacterEditDraft? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          defaultCreationMethod: 'standard',
          contentEntries: [
            _entry(
              id: 'guide:class/mage',
              type: 'class',
              name: '星界法师',
              revision: 1,
              structured: const {
                'classRules': {
                  'hitDie': 6,
                  'savingThrowAbilities': ['int', 'wis'],
                  'spellcasting': {
                    'mode': 'prepared',
                    'ability': 'int',
                    // 内部 slots 表（半施法者原型）与 prepared 表都随条目声明。
                    'archetype': 'half-caster',
                    'slots': {
                      '3': {'1': 4, '2': 2},
                    },
                    'prepared': [4, 5, 6],
                  },
                  'resources': [
                    {
                      'id': 'astral-focus',
                      'name': '星界专注',
                      'recovery': 'shortRest',
                      'maximum': {'formula': 'level'},
                    },
                  ],
                },
              },
              rules: const {'choices': <Map<String, Object?>>[]},
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
          onSubmit: (draft) async {
            submitted = draft;
            return true;
          },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('standard-character-name-field')),
      '星辉',
    );
    await tester.pumpAndSettle();

    // 第 0 步（职业）的等级摘要：法术位与职业资源必须按条目身份算出来。
    await _goToDesktopStep(tester, 0);
    await tester.tap(find.byKey(const Key('standard-level-increment-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('standard-level-increment-button')));
    await tester.pumpAndSettle();
    expect(find.text('当前等级 3'), findsOneWidget);
    expect(find.text('法术位 一环 4 / 二环 2'), findsOneWidget);
    expect(find.text('职业资源 星界专注 3'), findsOneWidget);

    await _goToDesktopStep(tester, 8);
    await tester.ensureVisible(find.widgetWithText(FilledButton, '创建角色'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '创建角色'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.data['classIdentity'], {
      'entryId': 'guide:class/mage',
      'slug': 'mage',
      'name': '星界法师',
      'declared': true,
      // 条目自身声明到 3 级（slots 表只写 3、prepared 表 1..3）。
      'declaredLevels': {'min': 1, 'max': 3},
    });
    expect(submitted!.data['spellSlots'], {'1': 4, '2': 2});
    expect(submitted!.data['preparedSpellLimit'], 6);
    expect(submitted!.data['classResources'], [
      {
        'id': 'astral-focus',
        'name': '星界专注',
        'maximum': 3,
        'recovery': 'shortRest',
      },
    ]);
  });

  testWidgets('声明范围只有一种口径：向导显示与 Builder 写入同源（§3.12）', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    CharacterEditDraft? submitted;
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
              structured: const {
                'classRules': {
                  'hitDie': 10,
                  // 条目自身只声明到 5 级。
                  'resources': [
                    {
                      'id': 'focus',
                      'name': '专注',
                      'recovery': 'longRest',
                      'maximum': {
                        'table': {'1': 2, '3': 3, '5': 4},
                      },
                    },
                  ],
                },
              },
              rules: const {
                'progression': [
                  {'levels': [1, 3, 5], 'grants': []},
                ],
                'choices': <Map<String, Object?>>[],
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
          ],
          onSubmit: (draft) async {
            submitted = draft;
            return true;
          },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('standard-character-name-field')),
      '莉安',
    );
    await tester.pumpAndSettle();
    await _goToDesktopStep(tester, 0);

    // 合并后实际生效的范围：条目只到 5 级，内置档案 fighter 声明到 17 级，必须并上。
    expect(find.text('职业声明：1–17 级'), findsOneWidget);
    expect(find.text('已声明 1–17 级 · 18–20 级未声明'), findsOneWidget);

    await _goToDesktopStep(tester, 8);
    await tester.ensureVisible(find.widgetWithText(FilledButton, '创建角色'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '创建角色'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    // 写进角色的硬性值与向导显示的完全一致（同一个函数），不得一处条目自身、
    // 一处合并后。
    expect(
      submitted!.data['classIdentity'],
      containsPair('declaredLevels', <String, Object?>{'min': 1, 'max': 17}),
    );
  });
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
  required int revision,
  Map<String, Object?> structured = const {},
  List<String> tags = const [],
  required Map<String, Object?> rules,
}) {
  return ContentEntry.fromJson({
    'id': id,
    'type': type,
    'slug': id.split('/').last,
    'name': name,
    'body': <Map<String, Object?>>[],
    'revision': revision,
    'structured': structured,
    'tags': tags,
    'rules': rules,
  });
}
