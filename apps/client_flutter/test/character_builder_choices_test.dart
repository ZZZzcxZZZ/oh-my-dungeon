import 'dart:io';

import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_edit_draft.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_editor_page.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_upgrade_page.dart';
import 'package:dnd_table_client/src/features/characters/presentation/widgets/rule_choice_section.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/rules/domain/character_rule_definition.dart';
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

  // 任务 6b（决策 D7）：`allowedBuilderSteps` 是导入期放行的契约白名单。
  // 只要有一项没有渲染位置，就会出现"看不见却阻塞创建"的静默失效——示例包里
  // `builderStep: "details"` 的 `asi-or-feat` 正是这个缺陷。
  group('结构守卫：每个 allowedBuilderSteps 都有渲染位置（决策 D7）', () {
    for (final declaredStep in RuleChoiceDefinition.allowedBuilderSteps) {
      testWidgets('builderStep=$declaredStep 的选择可见，且未选时阻塞创建', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1200, 1500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final label = '守卫选择-$declaredStep';
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterEditorPage(
              defaultCreationMethod: 'standard',
              contentEntries: [
                _entry(
                  id: 'guide:class/guardian',
                  type: 'class',
                  name: '守卫者',
                  rules: {
                    'progression': [
                      {
                        'levels': [1],
                        'choices': [
                          {
                            'id': 'guard',
                            'label': label,
                            'optionType': 'feat',
                            'minimum': 1,
                            'maximum': 1,
                            'optionEntryIds': ['guide:feat/defense'],
                            'builderStep': declaredStep,
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
                _entry(id: 'guide:feat/defense', type: 'feat', name: '防御'),
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

        final step = ruleChoiceBuilderStep(
          declaredStep,
          inheritedStep: 0,
        );
        await _goToDesktopStep(tester, step);
        expect(
          find.text(label),
          findsOneWidget,
          reason: 'builderStep=$declaredStep 必须在步骤 $step 真的渲染选择区',
        );

        // 不选它时不能创建：可见 + 阻塞，而不是"看不见却阻塞"。
        await _goToDesktopStep(tester, 8);
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, '创建角色'))
              .onPressed,
          isNull,
          reason: 'builderStep=$declaredStep 的选择未完成时必须阻塞创建',
        );
      });
    }
  });

  testWidgets('选择级 requires 不满足：显示原因、隐藏候选、阻塞创建；属性到位后解除', (
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
              id: 'guide:class/warlock',
              type: 'class',
              name: '邪术师',
              rules: const {
                'progression': [
                  {
                    'levels': [1],
                    'choices': [
                      {
                        'id': 'invocations',
                        'label': '祈唤',
                        'optionType': 'feat',
                        'minimum': 1,
                        'maximum': 1,
                        'optionEntryIds': ['guide:feat/defense'],
                        'requires': [
                          {'ability': 'cha', 'minimum': 13},
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
            _entry(id: 'guide:feat/defense', type: 'feat', name: '防御'),
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

    // 默认魅力 8 < 13：原因可见、候选隐藏、创建被阻塞（不是静默跳过）。
    expect(find.text('需要魅力 13'), findsOneWidget);
    expect(find.text('防御'), findsNothing);
    await _goToDesktopStep(tester, 8);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '创建角色'))
          .onPressed,
      isNull,
    );

    // 把魅力改到 13 → 前置满足：候选出现，原因消失。
    await _goToDesktopStep(tester, 3);
    await tester.enterText(
      find.byKey(const Key('standard-ability-cha-field')),
      '13',
    );
    await tester.pumpAndSettle();
    await _goToDesktopStep(tester, 0);
    expect(find.text('需要魅力 13'), findsNothing);
    expect(find.text('防御'), findsOneWidget);

    // 仍然必须真的选它才能创建。
    await _goToDesktopStep(tester, 8);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '创建角色'))
          .onPressed,
      isNull,
    );
    await _goToDesktopStep(tester, 0);
    await tester.tap(find.widgetWithText(FilterChip, '防御'));
    await tester.pumpAndSettle();
    await _goToDesktopStep(tester, 8);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '创建角色'))
          .onPressed,
      isNotNull,
    );

    // 再把魅力调回 8 → 已选值变成"已选但未生效"：原因可见、选中值不丢、创建重新被阻塞。
    await _goToDesktopStep(tester, 3);
    await tester.enterText(
      find.byKey(const Key('standard-ability-cha-field')),
      '8',
    );
    await tester.pumpAndSettle();
    await _goToDesktopStep(tester, 0);
    expect(find.text('需要魅力 13'), findsOneWidget);
    expect(
      find.text('已选但未生效：防御'),
      findsOneWidget,
      reason: '前置不满足不得静默丢弃已选值（§3.10.3-5）',
    );
    await _goToDesktopStep(tester, 8);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '创建角色'))
          .onPressed,
      isNull,
      reason: '本已选值不生效时同样不得创建',
    );
  });

  testWidgets('repeatable：同一选项点两次，草稿里真的有两份', (tester) async {
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
              id: 'guide:class/warlock',
              type: 'class',
              name: '邪术师',
              rules: const {
                'progression': [
                  {
                    'levels': [1],
                    'choices': [
                      {
                        'id': 'invocations',
                        'label': '祈唤',
                        'optionType': 'classFeature',
                        'minimum': 1,
                        'maximum': 2,
                        'repeatable': true,
                        'options': <Object?>[
                          {'id': 'agonizing-blast', 'label': '苦痛魔爆'},
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

    await tester.tap(find.widgetWithText(FilterChip, '苦痛魔爆'));
    await tester.pumpAndSettle();
    expect(find.text('苦痛魔爆'), findsOneWidget, reason: '×1 不显示重复计数');
    await tester.tap(find.widgetWithText(FilterChip, '苦痛魔爆'));
    await tester.pumpAndSettle();

    expect(find.text('苦痛魔爆 ×2'), findsOneWidget, reason: '两次选取显示 ×2');
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, '苦痛魔爆 ×2'))
          .selected,
      isTrue,
    );

    await _goToDesktopStep(tester, 8);
    await tester.tap(find.widgetWithText(FilledButton, '创建角色'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    final build = submitted!.data['build']! as Map;
    expect(
      (build['choices']! as Map)['guide:class/warlock#invocations#1'],
      ['agonizing-blast', 'agonizing-blast'],
      reason: 'repeatable 的两次选取必须落库两份（有序 List 的语义）',
    );
  });

  // 任务 7：技能选择的选中值走与通用选择同一份状态（`_ruleChoices` →
  // `build.choices`），顺序 = 点击顺序；背景预设仍走 `skillProficiencies`。
  testWidgets('熟练步骤的选择写进 build.choices 并按点击顺序保存', (tester) async {
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
              id: 'guide:class/ranger',
              type: 'class',
              name: '游侠',
              structured: const {
                'classRules': {'hitDie': 10},
              },
              rules: const {
                'progression': [
                  {
                    'levels': [1],
                    'choices': [
                      {
                        'id': 'class-skills',
                        'label': '选择两项技能熟练',
                        'optionType': 'skill',
                        'minimum': 2,
                        'maximum': 2,
                        'builderStep': 'proficiencies',
                        'options': ['察觉', '求生', '隐匿'],
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

    await _goToDesktopStep(tester, 4);
    // 依次点『求生』『察觉』：落库顺序必须是点击顺序，不是候选声明顺序。
    await tester.tap(find.byKey(const Key('standard-skill-求生-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('standard-skill-察觉-chip')));
    await tester.pumpAndSettle();

    await _goToDesktopStep(tester, 8);
    await tester.tap(find.widgetWithText(FilledButton, '创建角色'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    final build = submitted!.data['build']! as Map;
    expect(
      (build['choices']! as Map)['guide:class/ranger#class-skills#1'],
      ['求生', '察觉'],
      reason: '技能选择与通用选择同一份状态：顺序 = 点击顺序',
    );
    expect(submitted!.data['choices'], {
      'guide:class/ranger#class-skills#1': ['求生', '察觉'],
    });
    expect(submitted!.skills['求生'], isTrue, reason: '自动授予进 skills');
    expect(submitted!.skills['察觉'], isTrue, reason: '自动授予进 skills');
    expect(submitted!.skills['隐匿'], isFalse);
    // 背景预设仍走 `skillProficiencies`（士兵 = 运动、威吓），不与技能选择混同。
    expect(submitted!.skills['运动'], isTrue, reason: '背景预设仍在');
    expect(submitted!.skills['威吓'], isTrue, reason: '背景预设仍在');
  });

  // 任务 7：技能选择不再有"专门 UI 免检"——未完成时必须阻塞创建，
  // 否则就是"声明了却不用完成"的静默失效。
  testWidgets('未完成的技能选择阻塞创建（不再免检）', (tester) async {
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
              id: 'guide:class/ranger',
              type: 'class',
              name: '游侠',
              structured: const {
                'classRules': {'hitDie': 10},
              },
              rules: const {
                'progression': [
                  {
                    'levels': [1],
                    'choices': [
                      {
                        'id': 'class-skills',
                        'label': '选择两项技能熟练',
                        'optionType': 'skill',
                        'minimum': 2,
                        'maximum': 2,
                        'builderStep': 'proficiencies',
                        'options': ['察觉', '求生', '隐匿'],
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
          ],
          onSubmit: (_) async => true,
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('standard-character-name-field')),
      '布伦',
    );
    await tester.pumpAndSettle();

    await _goToDesktopStep(tester, 8);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '创建角色'))
          .onPressed,
      isNull,
      reason: '技能选择未完成时不得创建（免检已删除）',
    );

    await _goToDesktopStep(tester, 4);
    await tester.tap(find.byKey(const Key('standard-skill-求生-chip')));
    await tester.pumpAndSettle();
    expect(
      find.text('还需选择 1 项技能'),
      findsOneWidget,
      reason: '未达 minimum 时界面必须说明还差几项',
    );
    await tester.tap(find.byKey(const Key('standard-skill-察觉-chip')));
    await tester.pumpAndSettle();

    await _goToDesktopStep(tester, 8);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '创建角色'))
          .onPressed,
      isNotNull,
      reason: '技能选择完成后即可创建',
    );
  });

  // 任务 9：显式 `optionType: "spell"` 的选择由**法术池**渲染（专用渲染器），
  // 候选按 `maximumOptionLevel`（环阶）与 `optionTags`（法术列表）过滤——与引擎
  // 同一份 `candidatesFor`；选中的法术落库进 `manualOverrides`。
  testWidgets('显式法术选择由法术池渲染并按环阶/列表过滤', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
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
              name: '法师',
              structured: const {
                'classRules': {'hitDie': 6},
              },
              rules: const {
                'choices': [
                  {
                    'id': 'spells-1',
                    'label': '一环法术',
                    'optionType': 'spell',
                    'minimum': 0,
                    'maximum': 2,
                    'builderStep': 'spells',
                    'optionTags': ['spell-list:x'],
                    'maximumOptionLevel': 0,
                    'countsToward': 'prepared',
                  },
                ],
              },
            ),
            _entry(
              id: 'guide:background/sage',
              type: 'background',
              name: '贤者',
              rules: const {},
            ),
            _entry(
              id: 'guide:species/human',
              type: 'species',
              name: '人类',
              rules: const {},
            ),
            _entry(
              id: 'guide:spell/spark',
              type: 'spell',
              name: '电火花',
              structured: const {'level': 0, 'school': '塑能'},
              tags: const ['spell-list:x'],
              rules: const {},
            ),
            _entry(
              id: 'guide:spell/ward',
              type: 'spell',
              name: '护盾术',
              structured: const {'level': 1, 'school': '防护'},
              tags: const ['spell-list:x'],
              rules: const {},
            ),
            _entry(
              id: 'guide:spell/hex',
              type: 'spell',
              name: '邪术之箭',
              structured: const {'level': 0, 'school': '塑能'},
              tags: const ['spell-list:y'],
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
      '米尔',
    );
    await tester.pumpAndSettle();

    await _goToDesktopStep(tester, 6);
    // 池标题 = 选择 label；上限来自 `maximum`（池无声明上限时等于 maximum）。
    expect(find.text('一环法术'), findsOneWidget);
    expect(find.text('已选 0/2'), findsOneWidget);
    expect(find.byKey(const Key('spell-choice-guide:spell/spark')), findsOneWidget);
    // 环阶过滤：1 环超出 `maximumOptionLevel: 0`。
    expect(find.byKey(const Key('spell-choice-guide:spell/ward')), findsNothing);
    // 列表过滤：另一条法术列表的戏法不在候选里。
    expect(find.byKey(const Key('spell-choice-guide:spell/hex')), findsNothing);

    await tester.tap(find.byKey(const Key('spell-choice-guide:spell/spark')));
    await tester.pumpAndSettle();
    expect(find.text('已选 1/2'), findsOneWidget);

    // 自定义法术与显式法术选择**合并**（不互相覆盖）。
    await tester.tap(find.byKey(const Key('add-custom-spell')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('custom-spell-name')),
      '自创星火',
    );
    await tester.tap(find.byKey(const Key('custom-spell-confirm')));
    await tester.pumpAndSettle();

    await _goToDesktopStep(tester, 8);
    await tester.tap(find.widgetWithText(FilledButton, '创建角色'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    final build = submitted!.data['build']! as Map;
    expect(
      (build['choices']! as Map)['guide:class/mage#spells-1'],
      ['guide:spell/spark'],
    );
    final overrideSpells =
        (submitted!.data['manualOverrides']! as Map)['spells']! as Map;
    expect(overrideSpells['preparedEntryIds'], ['guide:spell/spark']);
    expect(
      overrideSpells['custom'],
      hasLength(1),
      reason: '自定义法术不能被选择镜像覆盖掉',
    );
  });

  // 结构守卫（任务 7）：`usesDedicatedOptionUi` 只允许作为**渲染判据**存在
  // （决定由哪个专门渲染器画），校验 / 免检路径不得再出现它；升级规划器与独立
  // 升级页完全不得出现（本级新增的选择由共享组件真的渲染，无需免检）。
  test('结构守卫：usesDedicatedOptionUi 不是免检判据', () {
    // 只比对**代码行**（注释里讨论这个判据是允许的，注释不是分支）。
    String codeOf(String relativePath) => File(relativePath)
        .readAsStringSync()
        .split('\n')
        .where((line) {
          final trimmed = line.trimLeft();
          return !trimmed.startsWith('//');
        })
        .join('\n');

    final builderPage = codeOf(
      'lib/src/features/characters/presentation/character_editor_builder_page.dart',
    );
    // 校验 / pending / 推荐 三条免检路径曾用这两种写法；删除后不得复活。
    expect(
      builderPage,
      isNot(contains('!active.definition.usesDedicatedOptionUi')),
    );
    expect(
      builderPage,
      isNot(contains('active.definition.usesDedicatedOptionUi) continue')),
    );
    // 唯一允许的负向判断是**渲染**过滤（决定谁不归通用卡片画）。
    expect(
      builderPage,
      contains('!choice.definition.usesDedicatedOptionUi'),
      reason: '渲染判据必须保留，否则专门渲染器的选择会被通用卡片重复渲染',
    );
    for (final path in const [
      'lib/src/features/characters/domain/character_upgrade_planner.dart',
      'lib/src/features/characters/presentation/character_upgrade_page.dart',
    ]) {
      expect(
        codeOf(path),
        isNot(contains('usesDedicatedOptionUi')),
        reason: '$path 不得再出现免检分支',
      );
    }
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
