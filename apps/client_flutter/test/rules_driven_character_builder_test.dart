import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_edit_draft.dart';
import 'package:dnd_table_client/src/features/characters/domain/declared_levels.dart';
import 'package:dnd_table_client/src/features/characters/domain/dnd5e_rules.dart';
import 'package:dnd_table_client/src/features/characters/domain/rules_driven_character_builder.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/rules/domain/character_build.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a traceable character sheet from D&D 2024 content rules', () {
    final fighter = _entry(
      id: 'test:class/fighter',
      type: 'class',
      name: '战士',
      structured: {'hitDie': 'd10'},
      rules: {
        'grants': [
          {
            'id': 'strength-save',
            'kind': 'proficiency',
            'target': 'save:str',
            'label': '力量豁免',
          },
          {
            'id': 'fighter-ac',
            'kind': 'armorClass',
            'value': 1,
            'label': '防御加值',
          },
        ],
        'progression': [
          {
            'levels': [1],
            'grants': [
              {
                'id': 'second-wind',
                'kind': 'feature',
                'entryId': 'test:class-feature/second-wind',
                'label': '回气',
              },
            ],
          },
        ],
      },
    );
    final background = _entry(
      id: 'test:background/soldier',
      type: 'background',
      name: '士兵',
      rules: {
        'grants': [
          {
            'id': 'athletics',
            'kind': 'proficiency',
            'target': 'skill:运动',
            'label': '运动熟练',
          },
        ],
      },
    );
    final species = _entry(
      id: 'test:species/human',
      type: 'species',
      name: '人类',
      rules: {
        'grants': [
          {
            'id': 'walking-speed',
            'kind': 'speed',
            'value': 30,
            'label': '步行速度',
          },
        ],
      },
    );
    final feature = _entry(
      id: 'test:class-feature/second-wind',
      type: 'classFeature',
      name: '回气',
      summary: '以附赠动作恢复生命值。',
      body: const [
        {'type': 'paragraph', 'text': '你可以恢复 1d10 + 战士等级的生命值。'},
      ],
      structured: const {'activation': 'bonusAction'},
      rules: const {},
    );
    final entries = {
      for (final entry in [fighter, background, species, feature])
        entry.id: entry,
    };
    final builder = RulesDrivenCharacterBuilder(entries: entries);

    final draft = builder.build(
      name: '阿兰尼斯',
      build: const CharacterBuild(
        level: 1,
        selections: {
          'class': 'test:class/fighter',
          'background': 'test:background/soldier',
          'species': 'test:species/human',
        },
      ),
      abilities: const {
        'str': 16,
        'dex': 14,
        'con': 14,
        'int': 10,
        'wis': 12,
        'cha': 8,
      },
    );

    expect(draft.classSummary, '战士');
    expect(draft.raceSummary, '人类');
    expect(draft.maxHp, 12);
    expect(draft.armorClass, 13);
    expect(draft.speed, 30);
    expect(draft.saves['str'], isTrue);
    expect(draft.skills['运动'], isTrue);
    expect(
      (draft.data['build'] as Map<String, Object?>)['selections'],
      containsPair('class', 'test:class/fighter'),
    );
    expect(
      (draft.data['contentRefs'] as Map<String, Object?>)['features'],
      contains('test:class-feature/second-wind'),
    );
    expect(
      draft.data['resolvedGrants'],
      contains(containsPair('sourceEntryName', '战士')),
    );

    final character = draft.toLocalCharacter();
    expect(
      character.contentReferences.map((reference) => reference.entryKey),
      containsAll([
        'test:class/fighter',
        'test:background/soldier',
        'test:species/human',
      ]),
    );
    final featureSnapshot =
        (draft.data['ruleSnapshots'] as Map<String, Object?>)[feature.id]
            as Map<String, Object?>;
    expect(featureSnapshot['name'], '回气');
    expect(featureSnapshot['summary'], contains('恢复生命值'));
    expect(
      featureSnapshot['structured'],
      containsPair('activation', 'bonusAction'),
    );
    expect(featureSnapshot['body'], isNotEmpty);
  });

  test('classRules 声明豁免与生命骰，散文键被忽略（非内置 slug）', () {    // 用**非内置** slug（`bulwark` 不在档案里）确保豁免/生命骰不可能来自档案：
    // 命中内置 slug 时 id 末段会继承档案数值，用例就测不到"条目声明"。
    // `structured.hitDie` / `structured.savingThrows` 是旧散文键，契约要求忽略，
    // 这里放一份与 classRules 冲突的值（体质 + 感知 vs 力量 + 体质），
    // 断言命中的是 classRules。
    expect(Dnd5eRules.profile.classRules('bulwark'), isNull);
    final bulwark = _entry(
      id: 'test:class/bulwark',
      type: 'class',
      name: '壁垒守卫',
      structured: const {
        'hitDie': 'd12',
        'savingThrows': '感知与魅力',
        'classRules': {
          'hitDie': 10,
          'savingThrowAbilities': ['str', 'con'],
        },
      },
      rules: const {
        'progression': [
          {
            'levels': [1],
            'grants': [
              {'id': 'second-wind', 'kind': 'feature', 'label': '回气'},
            ],
          },
        ],
      },
    );
    final builder = RulesDrivenCharacterBuilder(entries: {bulwark.id: bulwark});

    final draft = builder.build(
      name: '莱娅',
      build: const CharacterBuild(
        level: 1,
        selections: {'class': 'test:class/bulwark'},
      ),
      abilities: const {
        'str': 15,
        'dex': 13,
        'con': 14,
        'int': 10,
        'wis': 12,
        'cha': 8,
      },
      skillProficiencies: const ['运动', '察觉'],
    );

    expect(draft.saves['str'], isTrue, reason: 'classRules.savingThrowAbilities');
    expect(draft.saves['con'], isTrue);
    expect(draft.saves['wis'], isFalse, reason: '散文 savingThrows 必须被忽略');
    expect(draft.saves['cha'], isFalse);
    expect(draft.skills['运动'], isTrue);
    expect(draft.skills['察觉'], isTrue);
  });

  test('kind: ability 的合法 target 生效，非法 target 跳过（判据是档案 abilities）', () {
    // 导入期按档案 `abilities` 放行 target；运行期必须用同一份集合。
    // 合法 target（`str`）不加值会让"导入放行、运行期静默丢弃"变成真 bug；
    // 非法 target（`luck` ≠ 任何档案属性）必须被跳过而不是塞进属性表。
    expect(Dnd5eRules.profile.abilities, containsAll(<String>['str', 'int']));
    expect(Dnd5eRules.profile.abilities, isNot(contains('luck')));
    final classEntry = _entry(
      id: 'test:class/ascendant',
      type: 'class',
      name: 'Ascendant',
      structured: const {
        'classRules': {'hitDie': 10},
      },
      rules: const {
        'progression': [
          {
            'levels': [1],
            'grants': [
              {
                'id': 'asi-str',
                'kind': 'ability',
                'target': 'str',
                'value': 2,
                'label': '属性提升：力量 +2',
              },
              {
                'id': 'asi-luck',
                'kind': 'ability',
                'target': 'luck',
                'value': 5,
                'label': '非法属性',
              },
            ],
          },
        ],
      },
    );

    final draft = RulesDrivenCharacterBuilder(
      entries: {'test:class/ascendant': classEntry},
    ).build(
      name: 'Aria',
      build: const CharacterBuild(
        level: 1,
        selections: {'class': 'test:class/ascendant'},
      ),
      abilities: const {'str': 10, 'dex': 10, 'con': 10, 'int': 10},
    );

    expect(draft.abilities['str'], 12, reason: '合法 target 的 +2 必须生效');
    expect(
      draft.abilities.containsKey('luck'),
      isFalse,
      reason: '非档案属性不得被塞进属性表',
    );
  });
  test('persists only rule-approved choices and keeps explicit extras', () {
    final mage = _entry(
      id: 'test:class/mage',
      type: 'class',
      name: 'Mage',
      rules: const {
        'choices': [
          {
            'id': 'cantrip',
            'label': 'Cantrip',
            'optionType': 'spell',
            'minimum': 1,
            'maximum': 1,
            'optionTags': ['spell-list:mage'],
          },
        ],
      },
    );
    final invalid = _entry(
      id: 'test:spell/invalid',
      type: 'spell',
      name: 'Invalid',
      tags: const ['spell-list:priest'],
      rules: const {},
    );
    final extraItem = _entry(
      id: 'test:equipment/rope',
      type: 'equipment',
      name: 'Rope',
      rules: const {},
    );
    final builder = RulesDrivenCharacterBuilder(
      entries: {mage.id: mage, invalid.id: invalid, extraItem.id: extraItem},
    );

    final draft = builder.build(
      name: 'Aria',
      build: const CharacterBuild(
        level: 1,
        selections: {'class': 'test:class/mage'},
        choices: {
          'test:class/mage#cantrip': ['test:spell/invalid'],
        },
      ),
      abilities: const {
        'str': 8,
        'dex': 14,
        'con': 14,
        'int': 16,
        'wis': 12,
        'cha': 10,
      },
      extraItemRefs: const ['test:equipment/rope'],
    );

    final refs = draft.data['contentRefs'] as Map<String, Object?>;
    expect(refs['spells'], isEmpty);
    expect(refs['items'], ['test:equipment/rope']);
    final persistedBuild = draft.data['build'] as Map<String, Object?>;
    expect(persistedBuild['choices'], {'test:class/mage#cantrip': <String>[]});
    expect(
      draft.contentReferences.map((reference) => reference.entryKey),
      isNot(contains('test:spell/invalid')),
    );
  });

  test('法术位与职业资源只来自条目声明的 classRules（不再读 grant）', () {
    final classEntry = _entry(
      id: 'test:class/arcanist',
      type: 'class',
      name: 'Arcanist',
      structured: const {
        'classRules': {
          'hitDie': 6,
          'savingThrowAbilities': ['int', 'wis'],
          'spellcasting': {
            'mode': 'prepared',
            'ability': 'int',
            // 半施法者原型：1 级由原型补齐，5 级由条目整级替换。
            'archetype': 'half-caster',
            'slots': {
              '5': {'1': 4, '2': 3},
            },
            'prepared': [4, 5, 6, 7, 9],
          },
          'resources': [
            {
              'id': 'arcane-recovery',
              'name': 'Arcane Recovery',
              'recovery': 'shortRest',
              'maximum': 1,
            },
          ],
        },
      },
      rules: const {
        'progression': [
          {
            'levels': [1],
            'grants': [
              // 旧契约的 `resource` / `spellSlot:` 授予已随任务 9 移除；这里放一条
              // 合法但不提供法术位的授予，证明数值只来自 classRules。
              {
                'id': 'legacy-slots',
                'kind': 'action',
                'label': 'Legacy spell slots',
                'target': 'spellSlot:1',
                'value': 9,
              },
            ],
          },
        ],
      },
    );

    final draft =
        RulesDrivenCharacterBuilder(entries: {classEntry.id: classEntry}).build(
          name: 'Aria',
          build: const CharacterBuild(
            level: 1,
            selections: {'class': 'test:class/arcanist'},
          ),
          abilities: const {
            'str': 8,
            'dex': 14,
            'con': 14,
            'int': 16,
            'wis': 12,
            'cha': 10,
          },
        );

    // 1 级：自身 slots 表未声明 → 回退 half-caster 原型 {'1': 2}；
    // 旧 grant 的 value: 9 不再参与。
    expect(draft.data['spellSlots'], {'1': 2});
    expect(draft.data['spellcastingAbility'], 'int');
    expect(draft.data['preparedSpellLimit'], 4);
    expect(draft.data['hitDie'], 6);
    expect(draft.data['savingThrowAbilities'], ['int', 'wis']);
    expect(draft.data['classIdentity'], {
      'entryId': 'test:class/arcanist',
      'slug': 'arcanist',
      'name': 'Arcanist',
      'declared': true,
      'declaredLevels': {'min': 1, 'max': 5},
    });
    expect(draft.data['classResources'], [
      {
        'id': 'arcane-recovery',
        'name': 'Arcane Recovery',
        'maximum': 1,
        'recovery': 'shortRest',
      },
    ]);
  });

  test('emits preparedSpellLimit for prepared casters', () {
    final classEntry = _entry(
      id: 'test:class/cleric',
      type: 'class',
      name: 'Cleric',
      structured: const {
        'classRules': {
          'hitDie': 8,
          'spellcasting': {
            'mode': 'prepared',
            'ability': 'wis',
            'archetype': 'full-caster',
            // 条目自带的 prepared 表：只看职业自身，不回退原型。
            'prepared': [4, 5, 6],
          },
        },
      },
      rules: const {
        'progression': [
          {'levels': [1], 'grants': []},
        ],
      },
    );

    final draft =
        RulesDrivenCharacterBuilder(entries: {classEntry.id: classEntry}).build(
          name: 'Mira',
          build: const CharacterBuild(
            level: 1,
            selections: {'class': 'test:class/cleric'},
          ),
          abilities: const {
            'str': 8,
            'dex': 14,
            'con': 14,
            'int': 12,
            'wis': 16,
            'cha': 10,
          },
        );

    // 2024 官方表：牧师 1 级准备 4 个法术（与感知无关）
    expect(draft.data['preparedSpellLimit'], 4);
  });

  test('omits preparedSpellLimit without a prepared table', () {
    final classEntry = _entry(
      id: 'test:class/barbarian',
      type: 'class',
      name: 'Barbarian',
      // 新契约：准备上限只来自职业自身 `spellcasting.prepared` 表；这里既不声明
      // prepared 表、也不是档案职业（slug 未命中），因此没有准备上限、没有法术位。
      structured: const {},
      rules: const {
        'progression': [
          {
            'levels': [1],
            'grants': [
              {
                'id': 'legacy-slots',
                'kind': 'action',
                'label': 'Legacy slots',
                'target': 'spellSlot:1',
                'value': 2,
              },
            ],
          },
        ],
      },
    );

    final draft =
        RulesDrivenCharacterBuilder(entries: {classEntry.id: classEntry}).build(
          name: 'Aria',
          build: const CharacterBuild(
            level: 1,
            selections: {'class': 'test:class/barbarian'},
          ),
          abilities: const {
            'str': 16,
            'dex': 14,
            'con': 14,
            'int': 12,
            'wis': 10,
            'cha': 16,
          },
        );

    expect(draft.data.containsKey('preparedSpellLimit'), isFalse);
    expect(draft.data.containsKey('spellSlots'), isFalse);
    expect(draft.data.containsKey('spellcastingAbility'), isFalse);
    // 条目没有规则块 → 档案按条目 id 最后一段（barbarian）补齐。
    expect(draft.data['hitDie'], 12);
    expect(draft.data['classIdentity'], {
      'entryId': 'test:class/barbarian',
      'slug': 'barbarian',
      'name': 'Barbarian',
      'declared': true,
      // §3.12 口径 = 合并后实际生效的范围：条目只声明 1 级（progression[].levels），
      // 档案 barbarian 的狂暴表声明到 17 级，合并后是 1–17。
      'declaredLevels': {'min': 1, 'max': 17},
    });
    expect(draft.maxHp, 14, reason: '档案 d12 + CON 14（+2）');
  });

  test('emits startingEquipmentMaximum when declared', () {
    final classEntry = _entry(
      id: 'test:class/fighter',
      type: 'class',
      name: 'Fighter',
      structured: const {
        'startingEquipmentChoice': {'maximum': 5},
      },
      rules: const {
        'progression': [
          {'levels': [1], 'grants': []},
        ],
      },
    );

    final draft =
        RulesDrivenCharacterBuilder(entries: {classEntry.id: classEntry}).build(
          name: 'Bob',
          build: const CharacterBuild(
            level: 1,
            selections: {'class': 'test:class/fighter'},
          ),
          abilities: const {
            'str': 16,
            'dex': 14,
            'con': 14,
            'int': 10,
            'wis': 12,
            'cha': 10,
          },
        );

    expect(draft.data['startingEquipmentMaximum'], 5);
  });

  // §3.12：声明范围只有一种口径 = 合并后实际生效的范围。写入（Builder）与
  // 创建向导必须同源，否则同一角色在不同界面显示不同数字。
  group('声明范围口径：Builder 写入 = 向导读取', () {
    CharacterEditDraft buildFor(ContentEntry classEntry) =>
        RulesDrivenCharacterBuilder(entries: {classEntry.id: classEntry}).build(
          name: 'Aria',
          build: CharacterBuild(
            level: 1,
            selections: {'class': classEntry.id},
          ),
          abilities: const {
            'str': 16,
            'dex': 14,
            'con': 14,
            'int': 10,
            'wis': 12,
            'cha': 10,
          },
        );

    test('条目只声明 levels 1/3/5，但 slug 命中内置职业时并上档案范围', () {
      final classEntry = _entry(
        id: 'test:class/fighter',
        type: 'class',
        name: '战士',
        structured: const {
          'classRules': {
            'hitDie': 10,
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
        },
      );

      final draft = buildFor(classEntry);
      // 向导等级滑杆 / 信息条读的就是同一个函数。
      final wizardLevels = DeclaredLevels.fromEntry(classEntry);

      expect(
        draft.data['classIdentity'],
        containsPair('declaredLevels', wizardLevels.toData()),
        reason: '写入口径必须与向导算出来的完全一致',
      );

      final archive = Dnd5eRules.profile.classRules('fighter')!;
      expect(
        archive.declaredMaxLevel,
        greaterThan(5),
        reason: '构造用例的前提：档案范围超出条目自身的 1–5',
      );
      expect(wizardLevels.min, archive.declaredMinLevel, reason: '并上档案侧 min');
      expect(wizardLevels.max, archive.declaredMaxLevel, reason: '并上档案侧 max');
      expect(wizardLevels.max, 17);
    });

    test('完全自制的职业只有条目范围，min/max 与条目一致', () {
      final classEntry = _entry(
        id: 'test:class/astral-knight',
        type: 'class',
        name: '星界骑士',
        structured: const {
          'classRules': {
            'hitDie': 10,
            'resources': [
              {
                'id': 'focus',
                'name': '专注',
                'recovery': 'longRest',
                'maximum': {
                  'table': {'3': 3},
                },
              },
            ],
          },
        },
        rules: const {
          'progression': [
            {'levels': [1, 3, 5], 'grants': []},
          ],
        },
      );

      expect(Dnd5eRules.profile.classRules('astral-knight'), isNull);
      final draft = buildFor(classEntry);
      final wizardLevels = DeclaredLevels.fromEntry(classEntry);

      expect(wizardLevels.min, 1, reason: 'progression[].levels 的最早等级');
      expect(wizardLevels.max, 5, reason: 'progression[].levels 的最后等级');
      expect(
        draft.data['classIdentity'],
        containsPair('declaredLevels', wizardLevels.toData()),
      );
      expect(draft.data['classIdentity'], containsPair('slug', 'astral-knight'));
    });

    test('条目与档案都没有声明时 max 为 null，不写成 0 / 20', () {
      final classEntry = _entry(
        id: 'test:class/astral-knight',
        type: 'class',
        name: '星界骑士',
        structured: const {},
        rules: const {'grants': []},
      );

      final draft = buildFor(classEntry);
      final wizardLevels = DeclaredLevels.fromEntry(classEntry);
      expect(wizardLevels.max, isNull);
      expect(wizardLevels.isEmpty, isTrue);
      final persisted =
          draft.data['classIdentity']! as Map<String, Object?>;
      final declaredLevels = persisted['declaredLevels'] as Map<String, Object?>;
      expect(declaredLevels['max'], isNull);
      expect(declaredLevels, wizardLevels.toData());
    });

    test('条目展示 slug 为空串时身份仍用 id 末段：职业资源可解析', () {
      // `ContentEntry.slug` 是**展示字段**，允许空串（只判 null）；运行期的职业身份
      // 口径是 entry id 末段（`Dnd5eRules.resolveClassSlug`）。写入口径若用展示字段，
      // `CharacterSheet.classResources` 会误判"没有职业身份"并提前返回空列表。
      final classEntry = ContentEntry.fromJson({
        'id': 'test:class/fighter',
        'type': 'class',
        'slug': '',
        'name': '战士',
        'body': <Map<String, Object?>>[],
        'revision': 1,
        'structured': <String, Object?>{},
        'rules': <String, Object?>{
          'progression': [
            {'levels': [1], 'grants': <Object?>[]},
          ],
        },
      });

      final draft = buildFor(classEntry);
      final identity = draft.data['classIdentity']! as Map<String, Object?>;
      expect(identity['slug'], 'fighter', reason: '身份口径 = entry id 末段');
      // 1 级战士：档案 `second_wind` 表 {'1': 2}（真实数值，不放松断言）。
      expect(draft.data['classResources'], [
        {
          'id': 'second_wind',
          'name': '第二气息',
          'maximum': 2,
          'recovery': 'shortRestOne',
        },
      ]);

      // 读侧：没有显式 `data.classResources` 的角色（老存档 / 投影路径）靠
      // `classIdentity` 重新解析规则档案。
      final sheet = CharacterSheet.local(
        id: 'sheet-1',
        name: 'Aria',
        level: 1,
        classSummary: '战士',
      ).copyWith(
        abilities: const <String, Object?>{
          'str': 16,
          'dex': 14,
          'con': 14,
          'int': 10,
          'wis': 12,
          'cha': 10,
        },
        data: <String, Object?>{'classIdentity': identity},
      );
      expect(sheet.classResources.map((resource) => resource.id), [
        'second_wind',
      ]);
    });
  });

  // §3.5：`levels: [1,2,3]` 是"同一份效果在每个已达等级各生效一次"，
  // hitPoints 到 3 级要 +3、ability 到 3 级要 +3；派生本身必须幂等。
  group('多等级 grant：每个已达等级各生效一次且派生幂等', () {
    ContentEntry classEntry({required bool withGrants}) => _entry(
      id: 'test:class/ascendant',
      type: 'class',
      name: 'Ascendant',
      structured: const {
        'classRules': {'hitDie': 10},
      },
      rules: {
        'progression': [
          {
            'levels': [1, 2, 3],
            'grants': withGrants
                ? const [
                    {
                      'id': 'hp-up',
                      'kind': 'hitPoints',
                      'value': 1,
                      'label': '生命提升',
                    },
                    {
                      'id': 'asi-int',
                      'kind': 'ability',
                      'target': 'int',
                      'value': 1,
                      'label': '属性提升：智力 +1',
                    },
                  ]
                : const <Map<String, Object?>>[],
          },
        ],
      },
    );

    const baseAbilities = {
      'str': 16,
      'dex': 14,
      'con': 14,
      'int': 10,
      'wis': 12,
      'cha': 8,
    };
    const build = CharacterBuild(
      level: 3,
      selections: {'class': 'test:class/ascendant'},
    );

    CharacterEditDraft derive({required bool withGrants}) =>
        RulesDrivenCharacterBuilder(
          entries: {'test:class/ascendant': classEntry(withGrants: withGrants)},
        ).build(name: 'Aria', build: build, abilities: baseAbilities);

    test('hitPoints +1 到 3 级累计 +3，ability int +1 累计 +3', () {
      final plain = derive(withGrants: false);
      final boosted = derive(withGrants: true);

      expect(
        boosted.maxHp - plain.maxHp,
        3,
        reason: '1/2/3 级各 +1，被压成一次就只有 +1',
      );
      expect(boosted.abilities['int'], 13, reason: '10 + 1×3');
      expect(
        boosted.armorClass,
        plain.armorClass,
        reason: '智力加值不影响 AC；AC 只由 dex 派生',
      );
      expect(boosted.initiativeBonus, plain.initiativeBonus);
    });

    test('同一份输入连续派生两次，数值完全相同（幂等）', () {
      final first = derive(withGrants: true);
      final second = derive(withGrants: true);

      expect(second.maxHp, first.maxHp);
      expect(second.armorClass, first.armorClass);
      expect(second.initiativeBonus, first.initiativeBonus);
      expect(second.abilities, first.abilities);
      expect(second.level, first.level);
    });

    test('真往返：final → baseAbilitiesFrom → build 得到同一份最终值', () {
      // 不是"同一纯函数调两次"的重言式：真的把派生结果喂回再派生的入口
      // （`CharacterRuleProjector` / 升级规划器 / 编辑器都这么用）。
      final entries = {'test:class/ascendant': classEntry(withGrants: true)};
      final builder = RulesDrivenCharacterBuilder(entries: entries);
      final derived = derive(withGrants: true);
      expect(derived.abilities['int'], 13, reason: '10 + 1×3');

      final base = builder.baseAbilitiesFrom(derived.abilities, build);
      expect(base['int'], 10, reason: '逆运算必须精确回到基础值');
      final rebuilt = builder.build(
        name: 'Aria',
        build: build,
        abilities: base,
      );
      expect(rebuilt.abilities, derived.abilities);
      expect(rebuilt.maxHp, derived.maxHp);
      expect(rebuilt.armorClass, derived.armorClass);
    });

    test('_subtract 下限：最终值低于授予加值 → 基础值 clamp 到 0，不是负数', () {
      final builder = RulesDrivenCharacterBuilder(
        entries: {'test:class/ascendant': classEntry(withGrants: true)},
      );
      // 脏数据：最终 int 只有 1，而 1/2/3 级共授予 +3。
      final base = builder.baseAbilitiesFrom(
        const {'int': 1, 'str': 16},
        build,
      );
      expect(base['int'], 0, reason: '负基础值会把调整值带到 -1 以下');
      expect(base['str'], 16, reason: '未受授予影响的属性原样保留');
    });
  });

  // §3.5 与 `character_rules_engine.dart`：多等级展开是"每个等级一个生效单元"，
  // 但 `kind: action` 的动作身份与等级无关——运行期只应有一行动作。
  group('多等级 kind: action 不产出重复动作行', () {
    final classEntry = _entry(
      id: 'test:class/ascendant',
      type: 'class',
      name: 'Ascendant',
      structured: const {
        'classRules': {'hitDie': 10},
      },
      rules: {
        'progression': [
          {
            'levels': [1, 2, 3],
            'grants': const [
              {
                'id': 'action-surge',
                'kind': 'action',
                'label': '动作如潮',
                'entryId': 'test:class-feature/action-surge',
              },
            ],
          },
        ],
      },
    );

    test('3 级派生出的 actions 只有一条（不是逐级 3 条）', () {
      final draft = RulesDrivenCharacterBuilder(
        entries: {'test:class/ascendant': classEntry},
      ).build(
        name: 'Aria',
        build: const CharacterBuild(
          level: 3,
          selections: {'class': 'test:class/ascendant'},
        ),
        abilities: const {'str': 16},
      );

      final actions = (draft.data['actions']! as List)
          .cast<Map<Object?, Object?>>();
      expect(
        actions,
        hasLength(1),
        reason: '动作行未去重会让角色卡重复显示同一动作',
      );
      expect(actions.single['id'], 'action-surge');
      expect(actions.single['name'], '动作如潮');
    });
  });
}

ContentEntry _entry({
  required String id,
  required String type,
  required String name,
  Map<String, Object?> structured = const {},
  List<Map<String, Object?>> body = const [],
  String summary = '',
  List<String> tags = const [],
  required Map<String, Object?> rules,
}) {
  return ContentEntry.fromJson({
    'id': id,
    'type': type,
    'slug': id.split('/').last,
    'name': name,
    'body': body,
    'revision': 1,
    'structured': structured,
    'summary': summary,
    'tags': tags,
    'rules': rules,
  });
}
