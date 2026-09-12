// 任务 8 的新契约端到端用例：自制职业**只靠 `structured.classRules`** 就能算出
// 生命骰 / 豁免 / 法术位 / 准备上限 / 职业资源；未声明的职业一律不猜。
//
// 数值按 `samples/homebrew-astral-knight/entries.json` 的实际数据核对
// （任务 4.5 收尾第 10 条要求）。
import 'dart:convert';
import 'dart:io';

import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_edit_draft.dart';
import 'package:dnd_table_client/src/features/characters/domain/dnd5e_rules.dart';
import 'package:dnd_table_client/src/features/characters/domain/rules_driven_character_builder.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_editor_page.dart';
import 'package:dnd_table_client/src/features/characters/presentation/widgets/rule_choice_section.dart';
import 'package:dnd_table_client/src/features/content/data/import/content_package_importer.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/rules/domain/character_build.dart';
import 'package:dnd_table_client/src/features/rules/domain/character_rule_definition.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_choice_semantics.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/content_test_support.dart';

/// 星界骑士的 `structured`（schema 内片段）：d10、感知/魅力豁免、
/// 半施法者 + 自带 slots 与 prepared 表、一个 formula 资源。
final _astralKnightStructured = <String, Object?>{
  'classRules': <String, Object?>{
    'hitDie': 10,
    'savingThrowAbilities': <String>['wis', 'cha'],
    'spellcasting': <String, Object?>{
      'mode': 'prepared',
      'ability': 'cha',
      'archetype': 'half-caster',
      'slots': <String, Object?>{
        '5': <String, Object?>{'1': 4, '2': 2},
      },
      'prepared': <int>[
        3,
        4,
        5,
        6,
        7,
        7,
        8,
        8,
        10,
        10,
        11,
        11,
        12,
        12,
        13,
        13,
        15,
        15,
        16,
        16,
      ],
    },
    'resources': <Map<String, Object?>>[
      <String, Object?>{
        'id': 'surge',
        'name': '星界涌动',
        'recovery': 'shortRestOne',
        'maximum': <String, Object?>{'formula': 'level'},
      },
    ],
  },
};

ResolvedClassRules _resolveAstralKnight() => Dnd5eRules.resolveClassRules(
  entryId: 'my-pack:class/astral-knight',
  classSummary: '星界骑士',
  structured: _astralKnightStructured,
);

void main() {
  group('自制职业：只靠 classRules 算出全部职业数值', () {
    test('生命骰 / 豁免 / 法术位 / 施法属性来自条目声明', () {
      final resolved = _resolveAstralKnight();
      expect(resolved.hitDie, 10);
      expect(resolved.savingThrowAbilities, {'wis', 'cha'});
      // 1 级：自身 slots 表未声明该等级 → 回退半施法者原型。
      expect(resolved.spellSlots(1), {'1': 2});
      // 5 级：自身 slots 表**已声明**该等级 → 整级替换。
      expect(resolved.spellSlots(5), {'1': 4, '2': 2});
      expect(resolved.spellcastingAbility, 'cha');
      expect(resolved.spellcastingMode, 'prepared');
    });

    test('准备上限只看职业自身的 prepared 表', () {
      expect(_resolveAstralKnight().preparedLimit(5), 7);
      // 片段里没有 cantrips 表 → 未声明（不猜、不回退原型）。
      expect(_resolveAstralKnight().cantripLimit(5), isNull);
    });

    test('资源上限按等级与属性结算', () {
      final resources = _resolveAstralKnight().resourcesAt(7, const {
        'cha': 16,
      });
      expect(resources.single.id, 'surge');
      expect(resources.single.name, '星界涌动');
      expect(resources.single.maximum, 7);
      expect(resources.single.recovery, 'shortRestOne');
    });
  });

  test('未知职业不猜：数值为空而非回退到相近职业', () {
    final rules = Dnd5eRules.resolveClassRules(
      entryId: 'my-pack:class/unknown',
      classSummary: '星界游侠',
    );
    expect(rules.hitDie, isNull);
    expect(rules.spellSlots(5), isEmpty);
    expect(rules.preparedLimit(5), isNull);
    expect(rules.savingThrowAbilities, isEmpty);
    expect(rules.spellcastingAbility, isNull, reason: 'mode none 没有施法属性');
    expect(rules.resourcesAt(5, const {'cha': 16}), isEmpty);
  });

  test('展示名 → slug 解析走唯一入口（精确 / 别名+分隔符，禁止裸子串）', () {
    expect(Dnd5eRules.resolveClassSlug(classSummary: '战士'), 'fighter');
    expect(Dnd5eRules.resolveClassSlug(classSummary: 'Fighter'), 'fighter');
    expect(Dnd5eRules.resolveClassSlug(classSummary: '法师 / Wizard'), 'wizard');
    expect(Dnd5eRules.resolveClassSlug(classSummary: '星界游侠'), isEmpty);
    expect(Dnd5eRules.resolveClassSlug(classSummary: '自定义职业'), isEmpty);
    // 条目身份优先于展示名。
    expect(
      Dnd5eRules.resolveClassSlug(
        entryId: 'my-pack:class/astral-knight',
        classSummary: '战士',
      ),
      'astral-knight',
    );
  });

  group('角色卡 classResources：CHA 16 的吟游诗人', () {
    CharacterSheet bard() =>
        CharacterSheet.local(
          id: 'char-bard',
          name: '竖琴手',
          level: 1,
          classSummary: '吟游诗人',
        ).copyWith(
          abilities: const <String, Object?>{
            'str': 8,
            'dex': 14,
            'con': 14,
            'int': 10,
            'wis': 10,
            'cha': 16,
          },
          data: <String, Object?>{
            'classIdentity': <String, Object?>{
              'entryId': 'guide:class/bard',
              'slug': 'bard',
              'name': '吟游诗人',
            },
          },
        );

    test('诗人激励上限 == CHA 调整值（3），不是固定 1', () {
      final resources = bard().classResources;
      expect(resources.single.id, 'bardic_inspiration');
      expect(resources.single.name, '诗人激励');
      expect(resources.single.maximum, 3);
      expect(resources.single.recovery, 'longRest');
    });

    test('能力值会把「诗人激励」上限带到其它职业资源调用点', () {
      // 同一份档案规则，直接走新 API 也必须是 3。
      final rules = Dnd5eRules.resolveClassRules(
        entryId: 'guide:class/bard',
        classSummary: '吟游诗人',
      );
      expect(
        Dnd5eRules.classResourcesFromRules(
          rules: rules,
          level: 1,
          abilities: const {'cha': 16},
        ).single.maximum,
        3,
      );
      // 缺省（未传 abilities）按属性 10 计算，不崩。
      expect(
        Dnd5eRules.classResourcesFromRules(
          rules: rules,
          level: 1,
        ).single.maximum,
        1,
      );
    });
  });

  // 任务 11：选择系统运行时语义端到端（规格 §6.3）。全部走**真实导入器**：
  // 示例包 `samples/homebrew-astral-knight` 与合成包都必须先被导入器接受，
  // 再喂给 `RulesDrivenCharacterBuilder`（引擎 + 共享语义层）。
  group('选择系统运行时语义端到端（§6.3）', () {
    test('示例包：真实导入 → 完成必选即可建出角色（P0 回归）', () async {
      final entries = await _importSample();
      // P0：示例包不得再出现"看不见却阻塞创建"的选择——每一个 minimum > 0 的
      // 选择都必须至少有一个候选。旧缺陷：`spells-1` / `oath-spells` 声明了
      // `spell-list:astral-knight`，但包内没有一条法术条目。
      for (final key in const [
        'astral-knight:class/astral-knight#class-skills',
        'astral-knight:class/astral-knight#fighting-style',
        'astral-knight:class/astral-knight#starting-equipment',
        'astral-knight:class/astral-knight#invocations#2',
        'astral-knight:subclass/oath-of-the-astral#oath-spells#3',
      ]) {
        final found = RuleChoiceSemantics.definitionForKey(key, entries: entries);
        expect(found, isNotNull, reason: '$key 必须能解析');
        final candidates = RuleChoiceSemantics.candidatesFor(
          found!.definition,
          entries: entries,
          sourceEntryId: found.sourceEntryId,
        );
        expect(candidates, isNotEmpty, reason: '$key 的候选集不得为空');
        if (found.definition.minimum > 0) {
          expect(
            candidates.length,
            greaterThanOrEqualTo(found.definition.minimum),
            reason: '$key 的 minimum 必须可选满，否则创建被永久阻塞',
          );
        }
      }

      final draft = RulesDrivenCharacterBuilder(entries: entries).build(
        name: '星界试炼者',
        build: const CharacterBuild(
          level: 3,
          selections: {
            'class': 'astral-knight:class/astral-knight',
            'subclass': 'astral-knight:subclass/oath-of-the-astral',
          },
          choices: {
            'astral-knight:class/astral-knight#class-skills': ['奥秘', '察觉'],
            'astral-knight:class/astral-knight#fighting-style': ['astral-poise'],
            'astral-knight:class/astral-knight#starting-equipment': [
              'astral-knight:equipmentBundle/starting-a',
            ],
            'astral-knight:class/astral-knight#spells-1': [
              'astral-knight:spell/astral-spark',
            ],
            'astral-knight:class/astral-knight#invocations': [
              'astral-knight:classFeature/invocation-keen-edge',
            ],
            'astral-knight:class/astral-knight#subclass': [
              'astral-knight:subclass/oath-of-the-astral',
            ],
            'astral-knight:subclass/oath-of-the-astral#oath-spells': [
              'astral-knight:spell/astral-shield',
            ],
          },
        ),
        abilities: _sampleAbilities,
      );
      expect(draft.classSummary, '星界骑士');
      expect(draft.maxHp, greaterThan(0));
      expect(draft.skills['奥秘'], isTrue);
      expect(draft.skills['察觉'], isTrue);
      expect(draft.inventory.map((row) => row['name']), contains('长剑'));
      expect(draft.currency['gp'], 15);
      expect(
        draft.data['pendingChoices'],
        isEmpty,
        reason: '所有必选都已选满，不得再有 pending（P0：不可见即阻塞）',
      );
    });

    test('字符串简写技能选项自动授予熟练', () async {
      final entries = await _importSample();
      final draft = RulesDrivenCharacterBuilder(entries: entries).build(
        name: '技能试炼者',
        build: const CharacterBuild(
          level: 1,
          selections: {'class': 'astral-knight:class/astral-knight'},
          choices: {
            'astral-knight:class/astral-knight#class-skills': ['奥秘', '察觉'],
          },
        ),
        abilities: _sampleAbilities,
      );
      expect(draft.skills['奥秘'], isTrue);
      expect(draft.skills['察觉'], isTrue);
      expect(draft.skills['运动'], isFalse);
    });

    test('内联 ability 选项真的改变派生（AC / 先攻，不是只落库）', () async {
      final entries = await _importSynthetic([
        _syntheticClassJson(
          rules: const {
            'choices': [
              {
                'id': 'aptitude',
                'label': '星界天赋',
                'optionType': 'ability',
                'minimum': 1,
                'maximum': 1,
                'builderStep': 'abilities',
                'options': [
                  {
                    'id': 'dex',
                    'label': '敏捷 +2',
                    'data': {'value': 2},
                  },
                ],
              },
            ],
          },
        ),
      ]);
      final builder = RulesDrivenCharacterBuilder(entries: entries);
      CharacterEditDraft derive(List<String> picks) => builder.build(
        name: '天赋试炼者',
        build: CharacterBuild(
          level: 1,
          selections: const {'class': 'e2e-pack:class/mystic'},
          choices: {'e2e-pack:class/mystic#aptitude': picks},
        ),
        abilities: _sampleAbilities,
      );

      final without = derive(const []);
      final withPick = derive(const ['dex']);
      expect(withPick.abilities['dex'], 16);
      expect(
        withPick.armorClass,
        without.armorClass + 1,
        reason: '内联 ability 加值必须进入 effectiveAbilities 并改变 AC',
      );
      expect(withPick.initiativeBonus, without.initiativeBonus + 1);
    });

    test('内联 grants：repeatable 同一选项选两次 → grants 结算两次', () async {
      final entries = await _importSynthetic([
        _syntheticClassJson(
          rules: const {
            'choices': [
              {
                'id': 'blessing',
                'label': '星界祝福（可重复）',
                'optionType': 'feat',
                'minimum': 1,
                'maximum': 2,
                'repeatable': true,
                'options': [
                  {
                    'id': 'inner-light',
                    'label': '内在之光',
                    'grants': [
                      {
                        'id': 'inner-light-ac',
                        'kind': 'armorClass',
                        'value': 1,
                        'label': '内在之光',
                      },
                    ],
                  },
                ],
              },
            ],
          },
        ),
      ]);
      final builder = RulesDrivenCharacterBuilder(entries: entries);
      CharacterEditDraft derive(List<String> picks) => builder.build(
        name: '祝福试炼者',
        build: CharacterBuild(
          level: 1,
          selections: const {'class': 'e2e-pack:class/mystic'},
          choices: {'e2e-pack:class/mystic#blessing': picks},
        ),
        abilities: _sampleAbilities,
      );

      final draft = derive(const ['inner-light', 'inner-light']);
      final buildChoices = draft.data['build']! as Map;
      expect(
        (buildChoices['choices']! as Map)['e2e-pack:class/mystic#blessing'],
        ['inner-light', 'inner-light'],
        reason: 'resolvedChoices 必须保留两份',
      );
      final grants = (draft.data['resolvedGrants']! as List).where(
        (grant) => (grant as Map)['id'] == 'inner-light-ac',
      );
      expect(
        grants,
        hasLength(2),
        reason: 'repeatable 的每次选取都是独立生效单元，grants 结算两次',
      );
      expect(draft.armorClass, derive(const []).armorClass + 2);
    });

    test('repeatable: false 的重复选中被拒：导入期不报错，运行期进 pending', () async {
      final entries = await _importSynthetic([
        _syntheticClassJson(
          rules: const {
            'choices': [
              {
                'id': 'blessing',
                'label': '星界祝福（不可重复）',
                'optionType': 'feat',
                'minimum': 1,
                'maximum': 2,
                'options': [
                  {
                    'id': 'inner-light',
                    'label': '内在之光',
                    'grants': [
                      {
                        'id': 'inner-light-ac',
                        'kind': 'armorClass',
                        'value': 1,
                        'label': '内在之光',
                      },
                    ],
                  },
                ],
              },
            ],
          },
        ),
      ]);
      final draft = RulesDrivenCharacterBuilder(entries: entries).build(
        name: '祝福试炼者',
        build: const CharacterBuild(
          level: 1,
          selections: {'class': 'e2e-pack:class/mystic'},
          choices: {
            'e2e-pack:class/mystic#blessing': ['inner-light', 'inner-light'],
          },
        ),
        abilities: _sampleAbilities,
      );
      final buildChoices = draft.data['build']! as Map;
      expect(
        (buildChoices['choices']! as Map)['e2e-pack:class/mystic#blessing'],
        ['inner-light'],
      );
      final pending = (draft.data['pendingChoices']! as List).single as Map;
      expect(pending['reason'], 'notRepeatable');
    });

    test('requires 不满足时选择不生效并进 pending（引用 + 能力门槛）', () async {
      final entries = await _importSynthetic([
        _syntheticClassJson(
          rules: const {
            'choices': [
              {
                'id': 'talent',
                'label': '前置天赋',
                'optionType': 'classFeature',
                'minimum': 1,
                'maximum': 1,
                'optionEntryIds': ['e2e-pack:classFeature/spark'],
              },
              {
                'id': 'mastery',
                'label': '进阶天赋',
                'optionType': 'classFeature',
                'minimum': 1,
                'maximum': 1,
                'optionEntryIds': ['e2e-pack:classFeature/aura'],
                'requires': [
                  {'choice': 'talent', 'option': 'e2e-pack:classFeature/spark'},
                ],
              },
              {
                'id': 'gated',
                'label': '属性门槛天赋',
                'optionType': 'classFeature',
                'minimum': 1,
                'maximum': 1,
                'optionEntryIds': ['e2e-pack:classFeature/aura'],
                'requires': [
                  {'ability': 'int', 'minimum': 13},
                ],
              },
            ],
          },
        ),
        _syntheticFeatureJson('spark', '火花', 'spark-ac', 1),
        _syntheticFeatureJson('aura', '灵光', 'aura-ac', 2),
      ]);
      final builder = RulesDrivenCharacterBuilder(entries: entries);
      CharacterEditDraft derive({
        required List<String> talent,
        required List<String> mastery,
        required List<String> gated,
        Map<String, int> abilities = _sampleAbilities,
      }) => builder.build(
        name: '前置试炼者',
        build: CharacterBuild(
          level: 1,
          selections: const {'class': 'e2e-pack:class/mystic'},
          // `requires: {ability, minimum}` 的**唯一数据源**是 `CharacterBuild.abilities`
          // （决策 D4/D2：入参基础属性）——只传 `build(abilities:)` 不够。
          abilities: abilities,
          choices: {
            'e2e-pack:class/mystic#talent': talent,
            'e2e-pack:class/mystic#mastery': mastery,
            'e2e-pack:class/mystic#gated': gated,
          },
        ),
        abilities: abilities,
      );

      bool hasGrant(CharacterEditDraft draft, String id) =>
          (draft.data['resolvedGrants']! as List).any(
            (grant) => (grant as Map)['id'] == id,
          );
      List<Object?> reasons(CharacterEditDraft draft) =>
          (draft.data['pendingChoices']! as List)
              .map((row) => (row as Map)['reason'])
              .toList();

      const spark = 'e2e-pack:classFeature/spark';
      const aura = 'e2e-pack:classFeature/aura';

      // 引用不满足：没选 talent 就选 mastery → 不生效、进 pending。
      final unmet = derive(
        talent: const [],
        mastery: const [aura],
        gated: const [],
      );
      expect(hasGrant(unmet, 'aura-ac'), isFalse, reason: '前置不满足不得生效');
      expect(reasons(unmet), contains('requiresUnsatisfied'));

      // 选上 talent 后 mastery 生效（aura 的 AC +2 落账）。
      final satisfied = derive(
        talent: const [spark],
        mastery: const [aura],
        gated: const [],
      );
      expect(hasGrant(satisfied, 'aura-ac'), isTrue);
      expect(reasons(satisfied), isNot(contains('requiresUnsatisfied')));

      // 能力门槛读**入参基础属性**：int 10 不满足、int 16 满足。
      final lowInt = derive(
        talent: const [],
        mastery: const [],
        gated: const [aura],
        abilities: const {
          'str': 10,
          'dex': 14,
          'con': 14,
          'int': 10,
          'wis': 12,
          'cha': 10,
        },
      );
      expect(hasGrant(lowInt, 'aura-ac'), isFalse);
      expect(reasons(lowInt), contains('requiresUnsatisfied'));

      final highInt = derive(
        talent: const [],
        mastery: const [],
        gated: const [aura],
      );
      expect(hasGrant(highInt, 'aura-ac'), isTrue);
    });

    test('装备方案 A / B 写入 inventory 与 currency', () async {
      final entries = await _importSample();
      final builder = RulesDrivenCharacterBuilder(entries: entries);
      CharacterEditDraft derive(String bundle) => builder.build(
        name: '装备试炼者',
        build: CharacterBuild(
          level: 1,
          selections: const {'class': 'astral-knight:class/astral-knight'},
          choices: {
            'astral-knight:class/astral-knight#starting-equipment': [bundle],
          },
        ),
        abilities: _sampleAbilities,
      );

      final a = derive('astral-knight:equipmentBundle/starting-a');
      expect(
        a.inventory.map((row) => row['name']),
        containsAll(<String>['长剑', '皮甲']),
      );
      expect(a.currency['gp'], 15);

      final b = derive('astral-knight:equipmentBundle/starting-b');
      expect(b.inventory, isEmpty);
      expect(b.currency['gp'], 100);
    });

    test('optionType: "spell" + countsToward 受 prepared 上限约束（池超额进 pending）', () async {
      final entries = await _importSynthetic([
        _syntheticClassJson(
          classRules: const {
            'hitDie': 6,
            'spellcasting': {
              'mode': 'prepared',
              'ability': 'int',
              'prepared': [2, 2, 2],
            },
          },
          rules: const {
            'progression': [
              {
                'levels': [1],
                'choices': [
                  {
                    'id': 'spells',
                    'label': '一环法术',
                    'optionType': 'spell',
                    'minimum': 1,
                    'maximum': 3,
                    'countsToward': 'prepared',
                    'optionTags': ['spell-list:e2e'],
                  },
                ],
              },
            ],
          },
        ),
        _syntheticSpellJson('bolt'),
        _syntheticSpellJson('veil'),
        _syntheticSpellJson('rune'),
      ]);
      final draft = RulesDrivenCharacterBuilder(entries: entries).build(
        name: '法术试炼者',
        build: const CharacterBuild(
          level: 1,
          selections: {'class': 'e2e-pack:class/mystic'},
          choices: {
            'e2e-pack:class/mystic#spells': [
              'e2e-pack:spell/bolt',
              'e2e-pack:spell/veil',
              'e2e-pack:spell/rune',
            ],
          },
        ),
        abilities: _sampleAbilities,
      );
      final buildChoices = draft.data['build']! as Map;
      expect(
        (buildChoices['choices']! as Map)['e2e-pack:class/mystic#spells#1'],
        ['e2e-pack:spell/bolt', 'e2e-pack:spell/veil'],
        reason: 'prepared 池上限 2：第 3 个必须被拒',
      );
      final pending = (draft.data['pendingChoices']! as List).single as Map;
      expect(pending['reason'], 'poolExceeded');
    });

    test('countsToward: null 的法术选择记 alwaysPreparedEntryIds', () async {
      final entries = await _importSample();
      final draft = RulesDrivenCharacterBuilder(entries: entries).build(
        name: '誓约试炼者',
        build: const CharacterBuild(
          level: 3,
          selections: {
            'class': 'astral-knight:class/astral-knight',
            'subclass': 'astral-knight:subclass/oath-of-the-astral',
          },
          choices: {
            'astral-knight:class/astral-knight#class-skills': ['奥秘', '察觉'],
            'astral-knight:class/astral-knight#fighting-style': ['astral-poise'],
            'astral-knight:class/astral-knight#starting-equipment': [
              'astral-knight:equipmentBundle/starting-a',
            ],
            'astral-knight:class/astral-knight#invocations': [
              'astral-knight:classFeature/invocation-keen-edge',
            ],
            'astral-knight:class/astral-knight#subclass': [
              'astral-knight:subclass/oath-of-the-astral',
            ],
            'astral-knight:subclass/oath-of-the-astral#oath-spells': [
              'astral-knight:spell/astral-shield',
            ],
          },
        ),
        abilities: _sampleAbilities,
      );
      final spells = (draft.data['manualOverrides']! as Map)['spells']! as Map;
      expect(
        spells['alwaysPreparedEntryIds'],
        contains('astral-knight:spell/astral-shield'),
      );
      expect(
        spells['preparedEntryIds'],
        isNot(contains('astral-knight:spell/astral-shield')),
        reason: 'preparedEntryIds 是用户手动准备的专属存储，派生不写',
      );
    });

    testWidgets('示例包的 group / help 落到选择面板', (tester) async {
      final entries = await _importSample();
      final skills = RuleChoiceSemantics.definitionForKey(
        'astral-knight:class/astral-knight#class-skills',
        entries: entries,
      )!;
      final invocations = RuleChoiceSemantics.definitionForKey(
        'astral-knight:class/astral-knight#invocations',
        entries: entries,
      )!;
      final defs = <({RuleChoiceDefinition definition, String sourceEntryId})>[
        (definition: skills.definition, sourceEntryId: skills.sourceEntryId),
        (
          definition: invocations.definition,
          sourceEntryId: invocations.sourceEntryId,
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RuleChoiceGroupedSections(
                groups: groupRuleChoiceSections(
                  defs,
                  groupOf: (def) => def.definition.group,
                  buildChoice: (def) => RuleChoiceSection(
                    definition: def.definition,
                    candidates: RuleChoiceSemantics.candidatesFor(
                      def.definition,
                      entries: entries,
                      sourceEntryId: def.sourceEntryId,
                    ),
                    selected: const <String>[],
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('技能'), findsOneWidget);
      expect(find.text('2 级祈唤'), findsOneWidget);
      expect(find.text('同一祈唤可以重复选取，最多 2 次。'), findsOneWidget);
    });

    testWidgets('示例包：创建向导路径能在 3 级建出角色（P0：第 6 步不再永久阻塞）', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final entries = await _importSample();
      CharacterEditDraft? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterEditorPage(
            defaultCreationMethod: 'standard',
            contentEntries: [
              ...entries.values,
              // 示例包只演示职业：起源两项用合成条目补齐，否则审核页永远缺起源。
              _syntheticOrigin('species', 'human', '人类'),
              _syntheticOrigin('background', 'soldier', '士兵'),
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
        '向导试炼者',
      );
      await tester.pumpAndSettle();

      // 升到 3 级：子职业与 `oath-spells` 才会激活（P0 只在有子职业时暴露）。
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const Key('standard-level-increment-button')));
        await tester.pumpAndSettle();
      }

      await _goToDesktopStep(tester, 0);
      await _tapChoiceText(tester, '星界誓约');
      await _tapChoiceText(tester, '星界之势');
      await _tapChoiceText(tester, '锐锋祈唤');

      await _goToDesktopStep(tester, 4);
      await _tapKey(tester, const Key('standard-skill-奥秘-chip'));
      await _tapKey(tester, const Key('standard-skill-察觉-chip'));

      await _goToDesktopStep(tester, 5);
      await _tapChoiceText(tester, '星界骑士起始装备 A');

      await _goToDesktopStep(tester, 6);
      // P0 回归：示例包的法术选择现在真的有候选（此前为 0，第 6 步永久阻塞）。
      expect(
        find.byKey(const Key('spell-choice-astral-knight:spell/astral-shield')),
        findsOneWidget,
        reason: 'oath-spells 必须渲染出包内法术候选',
      );
      await _tapKey(
        tester,
        const Key('spell-choice-astral-knight:spell/astral-shield'),
      );

      await _goToDesktopStep(tester, 8);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '创建角色'))
            .onPressed,
        isNotNull,
        reason: 'P0：示例包不得再"看不见却阻塞创建"',
      );
      await tester.tap(find.widgetWithText(FilledButton, '创建角色'));
      await tester.pumpAndSettle();

      expect(submitted, isNotNull);
      expect(submitted!.classSummary, '星界骑士');
      expect(submitted!.skills['奥秘'], isTrue);
      expect(submitted!.skills['察觉'], isTrue);
    });
  });
}

Future<void> _goToDesktopStep(WidgetTester tester, int index) async {
  final unselected = find.byKey(Key('builder-step-$index'));
  final selected = find.byKey(Key('builder-step-$index-selected'));
  await tester.tap(unselected.evaluate().isNotEmpty ? unselected : selected);
  await tester.pumpAndSettle();
}

Future<void> _tapChoiceText(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(FilterChip, label);
  expect(chip, findsWidgets, reason: '找不到候选 chip：$label');
  await tester.ensureVisible(chip.first);
  await tester.tap(chip.first);
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, Key key) async {
  final target = find.byKey(key);
  expect(target, findsWidgets, reason: '找不到控件：$key');
  await tester.ensureVisible(target.first);
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

// ── 任务 11 的端到端夹具：真实导入器 + 合成包 ──

const _sampleAbilities = <String, int>{
  'str': 10,
  'dex': 14,
  'con': 14,
  'int': 16,
  'wis': 12,
  'cha': 10,
};

/// 用真实 [ContentPackageImporter] 导入 `samples/homebrew-astral-knight`。
Future<Map<String, ContentEntry>> _importSample() async {
  final manifest =
      jsonDecode(
            File(
              '../../samples/homebrew-astral-knight/manifest.json',
            ).readAsStringSync(),
          )
          as Map<String, Object?>;
  final entries =
      jsonDecode(
            File(
              '../../samples/homebrew-astral-knight/entries.json',
            ).readAsStringSync(),
          )
          as List<Object?>;
  final combined = Map<String, Object?>.from(manifest)..['entries'] = entries;
  final report = await ContentPackageImporter(
    MemoryContentRepository(),
  ).previewJson(jsonEncode(combined));
  expect(report.valid, isTrue, reason: report.errors.toString());
  return {for (final entry in report.entries) entry.id: entry};
}

/// 合成包：条目也必须过**真实导入器**（`formatVersion: 3`、id 前缀匹配）。
Future<Map<String, ContentEntry>> _importSynthetic(
  List<Map<String, Object?>> entries,
) async {
  final report = await ContentPackageImporter(MemoryContentRepository())
      .previewJson(
        jsonEncode({
          'formatVersion': 3,
          'id': 'e2e-pack',
          'name': 'E2E pack',
          'version': '1.0.0',
          'locale': 'zh-CN',
          'system': 'dnd5e-2024',
          'entryCount': entries.length,
          'entries': entries,
        }),
      );
  expect(report.valid, isTrue, reason: report.errors.toString());
  return {for (final entry in report.entries) entry.id: entry};
}

Map<String, Object?> _syntheticClassJson({
  String slug = 'mystic',
  Map<String, Object?> classRules = const {'hitDie': 10},
  required Map<String, Object?> rules,
}) => {
  'id': 'e2e-pack:class/$slug',
  'type': 'class',
  'slug': slug,
  'name': '秘术师',
  'body': <Object?>[],
  'revision': 1,
  'structured': {'classRules': classRules},
  'rules': rules,
};

Map<String, Object?> _syntheticFeatureJson(
  String slug,
  String name,
  String grantId,
  int acValue,
) => {
  'id': 'e2e-pack:classFeature/$slug',
  'type': 'classFeature',
  'slug': slug,
  'name': name,
  'body': <Object?>[],
  'revision': 1,
  'structured': {'level': 1, 'classSlug': 'mystic'},
  'rules': {
    'grants': [
      {'id': grantId, 'kind': 'armorClass', 'value': acValue, 'label': name},
    ],
  },
};

Map<String, Object?> _syntheticSpellJson(String slug) => {
  'id': 'e2e-pack:spell/$slug',
  'type': 'spell',
  'slug': slug,
  'name': '法术 $slug',
  'body': <Object?>[],
  'revision': 1,
  'structured': {'level': 1, 'school': '塑能'},
  'tags': ['spell-list:e2e'],
};

ContentEntry _syntheticOrigin(String type, String slug, String name) =>
    ContentEntry.fromJson({
      'id': 'e2e-origin:$type/$slug',
      'type': type,
      'slug': slug,
      'name': name,
      'body': <Object?>[],
      'revision': 1,
    });
