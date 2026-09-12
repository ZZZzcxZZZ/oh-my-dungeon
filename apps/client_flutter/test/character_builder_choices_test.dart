import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_edit_draft.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_editor_page.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_upgrade_page.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Spec §创建与升级选择: 自动授予单独显示；必选项未完成时不能创建；
// 子职业通过 progression choice + subclassOf 关系加载；属性生成支持
// 标准数组/购点/随机并在审核页显示来源；升级页点击关联条目使用当前 reader。
void main() {
  testWidgets('auto-grants are shown separately from required choices', (
    tester,
  ) async {
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
              rules: const {
                'progression': [
                  {
                    'levels': [1],
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
  });

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

  // 阻塞项 1：§3.10.3-2 明确允许「条目引用 + 内联 `options`」并存。混合选择必须继续
  // 走通用条目卡片：`usesDedicatedOptionUi` 只在**内联选项是唯一候选载体**时成立。
  // 判据过宽会让整条选择从渲染、`ruleChoicesAreValid`、`pendingChoices` 里消失，
  // 于是候选不可见、不选也能创建（§3.10.3-7 的静默失效）。
  testWidgets(
    'mixed entry+inline choice keeps its entry candidate and stays required',
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
                id: 'guide:class/astral',
                type: 'class',
                name: '星界骑士',
                rules: const {
                  'progression': [
                    {
                      'levels': [1],
                      'choices': [
                        {
                          'id': 'fighting-style',
                          'label': '选择战斗风格',
                          'optionType': 'feat',
                          'minimum': 1,
                          'maximum': 1,
                          'optionTags': ['fighting-style'],
                          'options': <Object?>[
                            {'id': 'astral-poise', 'label': '星界之势（内联）'},
                          ],
                          'builderStep': 'class',
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
                rules: const {},
              ),
              _entry(
                id: 'guide:species/human',
                type: 'species',
                name: '人类',
                rules: const {},
              ),
              _entry(
                id: 'guide:feat/fighting-style-astral-poise',
                type: 'feat',
                name: '星界之势',
                tags: const ['fighting-style'],
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

      // 通用卡片渲染了这条混合选择，并列出它的条目候选（内联选项对通用卡片不可见）。
      expect(find.text('选择战斗风格'), findsOneWidget);
      expect(find.text('星界之势'), findsOneWidget);

      // 计入 `ruleChoicesAreValid`：未选时不能创建。
      await _goToDesktopStep(tester, 8);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '创建角色'))
            .onPressed,
        isNull,
      );

      await _goToDesktopStep(tester, 0);
      await tester.ensureVisible(find.text('星界之势'));
      await tester.tap(find.text('星界之势'));
      await tester.pumpAndSettle();

      // 选中条目候选后创建按钮启用。
      await _goToDesktopStep(tester, 8);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '创建角色'))
            .onPressed,
        isNotNull,
      );
    },
  );

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
                rules: const {
                  'progression': [
                    {
                      'levels': [3],
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
      await tester.tap(
        find.byKey(const Key('standard-level-increment-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('standard-level-increment-button')),
      );
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
  testWidgets('upgrade page choice options open the reader on tap', (
    tester,
  ) async {
    final entries = <ContentEntry>[
      _entry(
        id: 'class:fighter',
        type: 'class',
        name: '战士',
        structured: const {'hitDie': 10},
        rules: const {
          'progression': [
            {
              'levels': [2],
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
    final character =
        CharacterSheet.local(
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
  });

  // GAP: 审核页未显示属性生成来源。
  testWidgets('review step shows the ability generation source', (
    tester,
  ) async {
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
  });

  testWidgets(
    'spell step filters by class and level while keeping custom spells separate',
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
                id: 'guide:class/wizard',
                type: 'class',
                name: '法师 / Wizard',
                structured: const {
                  // 任务 8.5：法术选择规则走新契约 `classRules.spellcasting`
                  // （逐级表 + 原型），不再有顶层 progression 行数组。
                  // 任务 10：生命骰同样在 `classRules`（旧字符串键已删除）。
                  'classRules': {
                    'hitDie': 6,
                    'spellcasting': {
                      'mode': 'prepared',
                      'ability': 'int',
                      'listTags': ['spell-list:wizard'],
                      'maximumSpellLevel': [1],
                      'cantrips': [3],
                      'prepared': [4],
                    },
                  },
                },
              ),
              _entry(
                id: 'guide:background/sage',
                type: 'background',
                name: '贤者',
              ),
              _entry(id: 'guide:species/human', type: 'species', name: '人类'),
              _entry(
                id: 'guide:spell/alarm',
                type: 'spell',
                name: '警报术',
                structured: const {'level': 1, 'school': '防护'},
                tags: const ['spell-list:wizard'],
              ),
              _entry(
                id: 'guide:spell/wish',
                type: 'spell',
                name: '祈愿术',
                structured: const {'level': 9, 'school': '咒法'},
                tags: const ['spell-list:wizard'],
              ),
              _entry(
                id: 'guide:spell/cure-wounds',
                type: 'spell',
                name: '疗伤术',
                structured: const {'level': 1, 'school': '防护'},
                tags: const ['spell-list:cleric'],
              ),
            ],
            onSubmit: (draft) async => true,
          ),
        ),
      );

      await _goToDesktopStep(tester, 6);

      expect(find.textContaining('最高 1 环'), findsOneWidget);
      expect(find.text('警报术'), findsOneWidget);
      expect(find.text('祈愿术'), findsNothing);
      expect(find.text('疗伤术'), findsNothing);
      expect(find.byKey(const Key('spell-choice-search')), findsOneWidget);

      await tester.tap(find.byKey(const Key('add-custom-spell')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('custom-spell-name')),
        '自创星火',
      );
      await tester.tap(find.byKey(const Key('custom-spell-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('自创星火'), findsOneWidget);
      expect(find.text('自定义法术不计入规则选择上限。'), findsOneWidget);
    },
  );

  testWidgets('equipment budget warns but never blocks overspending', (
    tester,
  ) async {
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
              id: 'guide:class/wizard',
              type: 'class',
              name: '法师',
              structured: const {
                // 任务 10：生命骰在 `classRules`（旧字符串键已删除）。
                'classRules': {'hitDie': 6},
                'startingEquipment': '选择A或B：(A) 法术书；或(B) 55GP',
              },
            ),
            _entry(id: 'guide:background/sage', type: 'background', name: '贤者'),
            _entry(id: 'guide:species/human', type: 'species', name: '人类'),
            _entry(
              id: 'guide:equipment/plate',
              type: 'equipment',
              name: '昂贵板甲',
              structured: const {'price': '60 GP'},
            ),
          ],
          onSubmit: (draft) async => true,
        ),
      ),
    );

    await _goToDesktopStep(tester, 5);
    expect(find.text('建议金币上限 55 GP'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, '昂贵板甲'));
    await tester.pumpAndSettle();

    expect(find.text('已选总价 60 GP'), findsOneWidget);
    expect(find.text('已超出建议上限，仍可继续创建和购买。'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, '昂贵板甲'), findsOneWidget);
  });

  // 任务 6a：选择状态由 `Set` 改为有序 `List`——顺序即用户点击顺序，
  // 落进 `build.choices` 后可直接表达"同一选项重复 N 次"。
  testWidgets('选择顺序按用户点击顺序落进 build.choices（Set → List）', (
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
              rules: const {
                'progression': [
                  {
                    'levels': [1],
                    'choices': [
                      {
                        'id': 'style',
                        'label': '选择两种战斗风格',
                        'optionType': 'feat',
                        'minimum': 2,
                        'maximum': 2,
                        'optionEntryIds': [
                          'guide:feat/duel',
                          'guide:feat/defense',
                        ],
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
              rules: const {},
            ),
            _entry(
              id: 'guide:species/human',
              type: 'species',
              name: '人类',
              rules: const {},
            ),
            _entry(id: 'guide:feat/duel', type: 'feat', name: '决斗'),
            _entry(id: 'guide:feat/defense', type: 'feat', name: '防御'),
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

    // 依次点第二个、第一个。
    await tester.ensureVisible(find.text('防御'));
    await tester.tap(find.text('防御'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('决斗'));
    await tester.tap(find.text('决斗'));
    await tester.pumpAndSettle();

    await _goToDesktopStep(tester, 8);
    await tester.tap(find.widgetWithText(FilledButton, '创建角色'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    final build = submitted!.data['build']! as Map;
    expect(
      (build['choices']! as Map)['guide:class/fighter#style#1'],
      ['guide:feat/defense', 'guide:feat/duel'],
      reason: '顺序即点击顺序，不被排序改写',
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
  int revision = 1,
  Map<String, Object?> structured = const {},
  Map<String, Object?>? rules,
  List<Map<String, Object?>> relations = const [],
  List<String> tags = const [],
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
    'tags': tags,
  });
}
