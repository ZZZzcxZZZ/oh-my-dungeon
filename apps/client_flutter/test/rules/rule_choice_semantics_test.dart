import 'dart:io';

import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/rules/domain/character_rule_definition.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_choice_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final featA = _entry(
    id: 'p:feat/a',
    type: 'feat',
    name: 'A 专长',
    tags: const ['fighting-style'],
  );
  final featB = _entry(
    id: 'p:feat/b',
    type: 'feat',
    name: 'B 专长',
    tags: const ['fighting-style'],
  );
  final entries = {featA.id: featA, featB.id: featB};

  group('candidatesFor', () {
    test('内联选项在前（声明顺序），条目候选在后（等级→名称排序）', () {
      const definition = RuleChoiceDefinition(
        id: 'pick',
        label: '选一个',
        optionType: 'feat',
        minimum: 1,
        maximum: 1,
        optionTags: ['fighting-style'],
        options: [
          RuleChoiceOption(id: 'inline-1', label: '内联一'),
          RuleChoiceOption(id: 'inline-2', label: '内联二'),
        ],
      );

      final candidates = RuleChoiceSemantics.candidatesFor(
        definition,
        entries: entries,
      );

      expect(candidates.map((c) => c.id), [
        'inline-1',
        'inline-2',
        featA.id,
        featB.id,
      ]);
      expect(candidates.first.isInline, isTrue);
      expect(candidates[2].entry, same(featA));
      expect(candidates[3].entry, same(featB));
      expect(candidates[2].isInline, isFalse);
      expect(candidates[2].label, 'A 专长');
    });

    test('空 options 且无条目候选 → 空候选集', () {
      const definition = RuleChoiceDefinition(
        id: 'pick',
        label: '选一个',
        optionType: 'feat',
        minimum: 1,
        maximum: 1,
      );

      expect(
        RuleChoiceSemantics.candidatesFor(definition, entries: const {}),
        isEmpty,
      );
    });

    test('过滤（标签 / 等级 / 白名单）与 RuleChoiceResolver 同源', () {
      final lowLevel = _entry(
        id: 'p:feat/low',
        type: 'feat',
        name: '低阶专长',
        tags: const ['fighting-style'],
        structured: const {'level': 1},
      );
      final highLevel = _entry(
        id: 'p:feat/high',
        type: 'feat',
        name: '高阶专长',
        tags: const ['fighting-style'],
        structured: const {'level': 8},
      );
      final wrongTag = _entry(
        id: 'p:feat/tag',
        type: 'feat',
        name: '别派专长',
        tags: const ['other'],
        structured: const {'level': 1},
      );
      // 未声明等级的条目在声明 maximumOptionLevel 时被排除（判据在
      // RuleChoiceResolver，语义层不另写一份）。
      final noLevel = _entry(
        id: 'p:feat/nolevel',
        type: 'feat',
        name: '无等级专长',
        tags: const ['fighting-style'],
      );
      const definition = RuleChoiceDefinition(
        id: 'pick',
        label: '选一个',
        optionType: 'feat',
        minimum: 1,
        maximum: 1,
        optionTags: ['fighting-style'],
        maximumOptionLevel: 4,
      );

      final candidates = RuleChoiceSemantics.candidatesFor(
        definition,
        entries: {
          lowLevel.id: lowLevel,
          highLevel.id: highLevel,
          wrongTag.id: wrongTag,
          noLevel.id: noLevel,
        },
      );

      expect(candidates.map((c) => c.id), [lowLevel.id]);
    });

    test('白名单 optionEntryIds 只放行列出的条目', () {
      const definition = RuleChoiceDefinition(
        id: 'pick',
        label: '选一个',
        optionType: 'feat',
        minimum: 1,
        maximum: 1,
        optionEntryIds: ['p:feat/b'],
      );

      final candidates = RuleChoiceSemantics.candidatesFor(
        definition,
        entries: entries,
      );

      expect(candidates.map((c) => c.id), [featB.id]);
    });

    test('重复声明的内联选项 id 按声明顺序保留，选择不去重', () {
      const definition = RuleChoiceDefinition(
        id: 'pick',
        label: '选一个',
        optionType: 'feat',
        minimum: 1,
        maximum: 2,
        options: [
          RuleChoiceOption(id: 'a', label: 'A'),
          RuleChoiceOption(id: 'a', label: 'A 副本'),
        ],
      );

      final candidates = RuleChoiceSemantics.candidatesFor(
        definition,
        entries: const {},
      );
      expect(candidates.map((c) => c.id), ['a', 'a']);

      final selection = RuleChoiceSemantics.normalizeSelection(
        definition,
        const ['a'],
        entries: const {},
      );
      expect(selection.selected, ['a']);
      expect(selection.invalidSelected, isEmpty);
    });

    test('内联 id 与 optionTags 派生的条目候选撞名：保留内联、丢弃条目', () {
      const definition = RuleChoiceDefinition(
        id: 'pick',
        label: '选一个',
        optionType: 'feat',
        minimum: 1,
        maximum: 1,
        optionTags: ['fighting-style'],
        options: [
          RuleChoiceOption(
            id: 'p:feat/a',
            label: '内联 A',
            grants: [
              RuleGrantDefinition(
                id: 'inline-a-grant',
                kind: RuleGrantKind.ability,
                label: '内联 A 加值',
                target: 'str',
                value: 1,
              ),
            ],
          ),
        ],
      );

      final candidates = RuleChoiceSemantics.candidatesFor(
        definition,
        entries: entries,
      );

      // 撞名的 featA 条目候选被丢弃；不撞名的 featB 仍在（顺序不变）。
      expect(candidates.map((c) => c.id), ['p:feat/a', featB.id]);
      expect(candidates.first.isInline, isTrue);
      expect(candidates.first.grants.single.id, 'inline-a-grant');
      expect(candidates.last.entry, same(featB));
    });
  });

  group('normalizeSelection', () {
    const definition = RuleChoiceDefinition(
      id: 'pick',
      label: '选两个',
      optionType: 'feat',
      minimum: 1,
      maximum: 2,
      options: [
        RuleChoiceOption(id: 'a', label: 'A'),
        RuleChoiceOption(id: 'b', label: 'B'),
        RuleChoiceOption(id: 'c', label: 'C'),
      ],
    );

    test('非 repeatable：重复项只保留第一次，其余进 invalidSelected', () {
      final result = RuleChoiceSemantics.normalizeSelection(
        definition,
        const ['a', 'a', 'b'],
        entries: const {},
      );

      expect(result.selected, ['a', 'b']);
      expect(result.invalidSelected, ['a']);
      expect(result.violations, contains(RuleChoiceViolation.notRepeatable));
    });

    test('repeatable：同一 id 保留 N 次，maximum 是次数上限', () {
      const repeatable = RuleChoiceDefinition(
        id: 'pick',
        label: '选两个',
        optionType: 'feat',
        minimum: 1,
        maximum: 2,
        repeatable: true,
        options: [RuleChoiceOption(id: 'a', label: 'A')],
      );

      final ok = RuleChoiceSemantics.normalizeSelection(
        repeatable,
        const ['a', 'a'],
        entries: const {},
      );
      expect(ok.selected, ['a', 'a']);
      expect(ok.invalidSelected, isEmpty);

      final over = RuleChoiceSemantics.normalizeSelection(
        repeatable,
        const ['a', 'a', 'a'],
        entries: const {},
      );
      expect(over.selected, ['a', 'a']);
      expect(over.invalidSelected, ['a']);
      expect(over.violations, contains(RuleChoiceViolation.aboveMaximum));
    });

    test('effectiveMaximum（池额度）优先于定义 maximum', () {
      const repeatable = RuleChoiceDefinition(
        id: 'pick',
        label: '选两个',
        optionType: 'feat',
        minimum: 1,
        maximum: 2,
        repeatable: true,
        options: [RuleChoiceOption(id: 'a', label: 'A')],
      );

      final result = RuleChoiceSemantics.normalizeSelection(
        repeatable,
        const ['a', 'a'],
        entries: const {},
        effectiveMaximum: 1,
      );

      expect(result.selected, ['a']);
      expect(result.invalidSelected, ['a']);
      expect(result.violations, contains(RuleChoiceViolation.aboveMaximum));
    });

    test('空候选集：所有请求值都进 invalidSelected', () {
      const empty = RuleChoiceDefinition(
        id: 'pick',
        label: '选一个',
        optionType: 'feat',
        minimum: 1,
        maximum: 1,
      );

      final result = RuleChoiceSemantics.normalizeSelection(
        empty,
        const ['a'],
        entries: const {},
      );

      expect(result.selected, isEmpty);
      expect(result.invalidSelected, ['a']);
      expect(result.violations, contains(RuleChoiceViolation.notACandidate));
    });

    test('不在候选集里的值进 invalidSelected（条目与内联一视同仁）', () {
      final result = RuleChoiceSemantics.normalizeSelection(
        definition,
        const ['a', 'p:feat/zzz'],
        entries: entries,
      );

      expect(result.selected, ['a']);
      expect(result.invalidSelected, ['p:feat/zzz']);
      expect(result.violations, contains(RuleChoiceViolation.notACandidate));
    });

    test('条目候选可被选中', () {
      final result = RuleChoiceSemantics.normalizeSelection(
        definition,
        [featA.id],
        entries: entries,
      );

      expect(result.selected, [featA.id]);
      expect(result.invalidSelected, isEmpty);
    });

    test('顺序即声明/用户选择顺序，不被排序改写', () {
      final result = RuleChoiceSemantics.normalizeSelection(
        definition,
        const ['c', 'a'],
        entries: const {},
      );

      expect(result.selected, ['c', 'a']);
    });
  });

  group('autoGrantsFor（字符串简写，契约 §3.10.2 表）', () {
    test('skill → proficiency: skill:<选项 id>', () {
      final grants = RuleChoiceSemantics.autoGrantsFor(
        optionType: 'skill',
        optionId: '察觉',
      )!;

      expect(grants, hasLength(1));
      expect(grants.single.kind, RuleGrantKind.proficiency);
      expect(grants.single.target, 'skill:察觉');
      expect(grants.single.id, 'skill:察觉');
    });

    test('ability → ability，加值取 data[value]，缺省或 null 为 1', () {
      final def = RuleChoiceSemantics.autoGrantsFor(
        optionType: 'ability',
        optionId: 'cha',
      )!;
      expect(def.single.kind, RuleGrantKind.ability);
      expect(def.single.target, 'cha');
      expect(def.single.value, 1);

      final plusTwo = RuleChoiceSemantics.autoGrantsFor(
        optionType: 'ability',
        optionId: 'cha',
        data: const {'value': 2},
      )!;
      expect(plusTwo.single.value, 2);

      // 值为 null 仍算"没写"，缺省为 1（<choice.value ?? 1>）。
      final nullValue = RuleChoiceSemantics.autoGrantsFor(
        optionType: 'ability',
        optionId: 'cha',
        data: const {'value': null},
      )!;
      expect(nullValue.single.value, 1);
    });

    test('ability 的 data[value] 显式非法 → 无法推断（null），不静默改写成 1', () {
      for (final bad in <Object?>[0, -1, '2', 2.5, double.nan]) {
        expect(
          RuleChoiceSemantics.autoGrantsFor(
            optionType: 'ability',
            optionId: 'cha',
            data: {'value': bad},
          ),
          isNull,
          reason: '$bad',
        );
      }
    });

    test('language / damageType / weaponMastery / value 只记录选择，不产出 grants', () {
      for (final type in ['language', 'damageType', 'weaponMastery', 'value']) {
        final grants = RuleChoiceSemantics.autoGrantsFor(
          optionType: type,
          optionId: 'x',
        );
        expect(grants, isNotNull, reason: type);
        expect(grants, isEmpty, reason: type);
      }
    });

    test('kAutoGrantOptionTypes 与 autoGrantsFor 的 switch 双向一致', () {
      expect(kAutoGrantOptionTypes, {
        'skill',
        'ability',
        'language',
        'damageType',
        'weaponMastery',
        'value',
      });
      // 正方向：集合里每个类型都能推出结果（非 null；空列表 = 只记录选择）。
      for (final type in kAutoGrantOptionTypes) {
        final grants = RuleChoiceSemantics.autoGrantsFor(
          optionType: type,
          optionId: 'x',
        );
        expect(grants, isNotNull, reason: type);
      }
      // 反方向：switch 里出现的每个 case 字面量都在集合里。集合与 switch 是两份
      // 字面量，只有读源码才能双向锁定；在 switch 里新增 case 却忘记加入集合时，
      // 本条断言会红。
      final switchBody = _autoGrantsSwitchBody();
      final caseLabels = RegExp(r"case '([^']+)':")
          .allMatches(switchBody)
          .map((match) => match.group(1)!)
          .toSet();
      expect(caseLabels, kAutoGrantOptionTypes);
    });

    test('条目类型无法推断 → null（导入期据此报 invalidAutoGrant）', () {
      for (final type in [
        'feat',
        'spell',
        'item',
        'classFeature',
        'equipmentBundle',
      ]) {
        expect(
          RuleChoiceSemantics.autoGrantsFor(optionType: type, optionId: 'x'),
          isNull,
          reason: type,
        );
      }
    });
  });

  group('grantsForSelection', () {
    test('显式 grants 优先于自动推断；重复项按次数展开', () {
      const definition = RuleChoiceDefinition(
        id: 'asi',
        label: '属性提升',
        optionType: 'ability',
        minimum: 1,
        maximum: 2,
        repeatable: true,
        options: [
          RuleChoiceOption(
            id: 'str',
            label: '力量 +1',
            grants: [
              RuleGrantDefinition(
                id: 'asi-str',
                kind: RuleGrantKind.ability,
                label: '力量提升',
                target: 'str',
                value: 1,
              ),
            ],
          ),
        ],
      );

      final grants = RuleChoiceSemantics.grantsForSelection(
        definition,
        const ['str', 'str'],
        entries: const {},
      );

      expect(grants, hasLength(2));
      expect(grants.every((g) => g.id == 'asi-str'), isTrue);
    });

    test('字符串简写 skill 自动授予；语言类只记录不产出 grants', () {
      const skillChoice = RuleChoiceDefinition(
        id: 'training',
        label: '技能训练',
        optionType: 'skill',
        minimum: 1,
        maximum: 1,
        options: [RuleChoiceOption(id: '察觉', label: '察觉')],
      );
      expect(
        RuleChoiceSemantics.grantsForSelection(
          skillChoice,
          const ['察觉'],
          entries: const {},
        ).single.target,
        'skill:察觉',
      );

      const languageChoice = RuleChoiceDefinition(
        id: 'languages',
        label: '语言',
        optionType: 'language',
        minimum: 1,
        maximum: 1,
        options: [RuleChoiceOption(id: '精灵语', label: '精灵语')],
      );
      expect(
        RuleChoiceSemantics.grantsForSelection(
          languageChoice,
          const ['精灵语'],
          entries: const {},
        ),
        isEmpty,
      );
    });

    test('条目候选的自身 grants 不在这里展开（由规则队列承担）', () {
      final feat = _entry(
        id: 'p:feat/grants',
        type: 'feat',
        name: '授予专长',
        tags: const ['fighting-style'],
        rules: const CharacterRuleDefinition(
          grants: [
            RuleGrantDefinition(
              id: 'feat-grant',
              kind: RuleGrantKind.speed,
              label: '速度',
            ),
          ],
        ),
      );
      const definition = RuleChoiceDefinition(
        id: 'pick',
        label: '选一个',
        optionType: 'feat',
        minimum: 1,
        maximum: 1,
      );

      expect(
        RuleChoiceSemantics.grantsForSelection(
          definition,
          [feat.id],
          entries: {feat.id: feat},
        ),
        isEmpty,
      );
    });

    test('未知/非候选选中值被忽略，不抛错', () {
      const definition = RuleChoiceDefinition(
        id: 'pick',
        label: '选一个',
        optionType: 'skill',
        minimum: 1,
        maximum: 1,
        options: [RuleChoiceOption(id: 'a', label: 'A')],
      );

      expect(
        RuleChoiceSemantics.grantsForSelection(
          definition,
          const ['zzz'],
          entries: const {},
        ),
        isEmpty,
      );
    });

    test('内联 id 与条目候选撞名时，内联 grants 仍然生效（不被静默丢弃）', () {
      final feat = _entry(
        id: 'p:feat/a',
        type: 'feat',
        name: 'A 专长',
        tags: const ['fighting-style'],
      );
      const definition = RuleChoiceDefinition(
        id: 'pick',
        label: '选一个',
        optionType: 'feat',
        minimum: 1,
        maximum: 1,
        optionTags: ['fighting-style'],
        options: [
          RuleChoiceOption(
            id: 'p:feat/a',
            label: '内联 A',
            grants: [
              RuleGrantDefinition(
                id: 'inline-a-grant',
                kind: RuleGrantKind.ability,
                label: '内联 A 加值',
                target: 'str',
                value: 1,
              ),
            ],
          ),
        ],
      );

      final grants = RuleChoiceSemantics.grantsForSelection(
        definition,
        const ['p:feat/a'],
        entries: {feat.id: feat},
      );

      expect(grants.map((grant) => grant.id), ['inline-a-grant']);
    });
  });

  group('requiresSatisfied', () {
    test('{choice, option} 命中同一 sourceEntryId 的已选值', () {
      const requires = [
        RuleRequiresDefinition(choice: 'spellbook', option: 'p:spell/a'),
      ];
      expect(
        RuleChoiceSemantics.requiresSatisfied(
          requires,
          sourceEntryId: 'p:class/mage',
          selectedByKey: const {
            'p:class/mage#spellbook': ['p:spell/a'],
          },
          abilities: const {},
          entries: entries,
        ),
        isTrue,
      );
    });

    test('内联选项 id 与条目 id 都算命中（决策 D5）', () {
      const requires = [
        RuleRequiresDefinition(choice: 'spellbook', option: 'inline-a'),
      ];
      expect(
        RuleChoiceSemantics.requiresSatisfied(
          requires,
          sourceEntryId: 'p:class/mage',
          selectedByKey: const {
            'p:class/mage#spellbook': ['inline-a', 'p:spell/a'],
          },
          abilities: const {},
          entries: entries,
        ),
        isTrue,
      );
    });

    test('只写 {choice} 时该选择有任意选中值即满足', () {
      const requires = [RuleRequiresDefinition(choice: 'pact')];
      expect(
        RuleChoiceSemantics.requiresSatisfied(
          requires,
          sourceEntryId: 'p:class/mage',
          selectedByKey: const {
            'p:class/mage#pact': ['p:feat/a'],
          },
          abilities: const {},
          entries: entries,
        ),
        isTrue,
      );
      expect(
        RuleChoiceSemantics.requiresSatisfied(
          requires,
          sourceEntryId: 'p:class/mage',
          selectedByKey: const {'p:class/mage#pact': []},
          abilities: const {},
          entries: entries,
        ),
        isFalse,
      );
    });

    test('option 不匹配 / 选择未选 / 不在作用域内 → 不满足', () {
      const requires = [
        RuleRequiresDefinition(choice: 'spellbook', option: 'p:spell/a'),
      ];
      // option 不匹配
      expect(
        RuleChoiceSemantics.requiresSatisfied(
          requires,
          sourceEntryId: 'p:class/mage',
          selectedByKey: const {
            'p:class/mage#spellbook': ['p:spell/b'],
          },
          abilities: const {},
          entries: entries,
        ),
        isFalse,
      );
      // 选择未选
      expect(
        RuleChoiceSemantics.requiresSatisfied(
          requires,
          sourceEntryId: 'p:class/mage',
          selectedByKey: const {},
          abilities: const {},
          entries: entries,
        ),
        isFalse,
      );
      // 选择键属于作用域外的条目
      expect(
        RuleChoiceSemantics.requiresSatisfied(
          requires,
          sourceEntryId: 'p:class/mage',
          selectedByKey: const {
            'p:class/other#spellbook': ['p:spell/a'],
          },
          abilities: const {},
          entries: entries,
        ),
        isFalse,
      );
      // choiceId 不同
      expect(
        RuleChoiceSemantics.requiresSatisfied(
          requires,
          sourceEntryId: 'p:class/mage',
          selectedByKey: const {
            'p:class/mage#grimoire': ['p:spell/a'],
          },
          abilities: const {},
          entries: entries,
        ),
        isFalse,
      );
    });

    test('多等级键（带 #等级）同样命中；祖先条目的选择也算', () {
      final subclass = _entry(
        id: 'p:subclass/x',
        type: 'subclass',
        name: 'X',
        relations: const [
          ContentRelation(type: 'subclassOf', targetId: 'p:class/mage'),
        ],
      );
      const requires = [
        RuleRequiresDefinition(choice: 'spellbook', option: 'p:spell/a'),
      ];
      expect(
        RuleChoiceSemantics.requiresSatisfied(
          requires,
          sourceEntryId: 'p:subclass/x',
          selectedByKey: const {
            'p:class/mage#spellbook#3': ['p:spell/a'],
          },
          abilities: const {},
          entries: {...entries, subclass.id: subclass},
        ),
        isTrue,
      );
    });

    test('featureOf 链上的祖先同样在作用域内，且可跨多跳', () {
      final feature = _entry(
        id: 'p:feature/f',
        type: 'classFeature',
        name: 'F',
        relations: const [
          ContentRelation(type: 'featureOf', targetId: 'p:subclass/x'),
        ],
      );
      final subclass = _entry(
        id: 'p:subclass/x',
        type: 'subclass',
        name: 'X',
        relations: const [
          ContentRelation(type: 'subclassOf', targetId: 'p:class/mage'),
        ],
      );
      const requires = [RuleRequiresDefinition(choice: 'spellbook')];
      expect(
        RuleChoiceSemantics.requiresSatisfied(
          requires,
          sourceEntryId: 'p:feature/f',
          selectedByKey: const {
            'p:class/mage#spellbook': ['p:spell/a'],
          },
          abilities: const {},
          entries: {...entries, feature.id: feature, subclass.id: subclass},
        ),
        isTrue,
      );
      // 不在链上的条目不算
      expect(
        RuleChoiceSemantics.requiresSatisfied(
          requires,
          sourceEntryId: 'p:feature/f',
          selectedByKey: const {
            'p:class/STRANGER#spellbook': ['p:spell/a'],
          },
          abilities: const {},
          entries: {...entries, feature.id: feature, subclass.id: subclass},
        ),
        isFalse,
      );
    });

    test('{ability, minimum} 用入参基础属性判定', () {
      const requires = [RuleRequiresDefinition(ability: 'cha', minimum: 13)];
      expect(
        RuleChoiceSemantics.requiresSatisfied(
          requires,
          sourceEntryId: 'p:class/warlock',
          selectedByKey: const {},
          abilities: const {'cha': 13},
          entries: const {},
        ),
        isTrue,
      );
      expect(
        RuleChoiceSemantics.requiresSatisfied(
          requires,
          sourceEntryId: 'p:class/warlock',
          selectedByKey: const {},
          abilities: const {'cha': 12},
          entries: const {},
        ),
        isFalse,
      );
      // 属性键缺失 = 未记录 → 不满足（不猜成 10 或 0）。
      expect(
        RuleChoiceSemantics.requiresSatisfied(
          requires,
          sourceEntryId: 'p:class/warlock',
          selectedByKey: const {},
          abilities: const {},
          entries: const {},
        ),
        isFalse,
      );
    });

    test('多个 requires 是 AND：任一不满足即不满足', () {
      const requires = [
        RuleRequiresDefinition(ability: 'cha', minimum: 13),
        RuleRequiresDefinition(choice: 'pact'),
      ];
      expect(
        RuleChoiceSemantics.requiresSatisfied(
          requires,
          sourceEntryId: 'p:class/warlock',
          selectedByKey: const {
            'p:class/warlock#pact': ['p:feat/a'],
          },
          abilities: const {'cha': 13},
          entries: entries,
        ),
        isTrue,
      );
      expect(
        RuleChoiceSemantics.requiresSatisfied(
          requires,
          sourceEntryId: 'p:class/warlock',
          selectedByKey: const {
            'p:class/warlock#pact': ['p:feat/a'],
          },
          abilities: const {'cha': 12},
          entries: entries,
        ),
        isFalse,
      );
    });

    test('空 requires 恒满足', () {
      expect(
        RuleChoiceSemantics.requiresSatisfied(
          const [],
          sourceEntryId: 'p:class/x',
          selectedByKey: const {},
          abilities: const {},
          entries: const {},
        ),
        isTrue,
      );
    });
  });

  group('scopeEntryIdsFor', () {
    test('包含自身与沿 featureOf / subclassOf 的祖先，不含无关条目', () {
      final feature = _entry(
        id: 'p:feature/f',
        type: 'classFeature',
        name: 'F',
        relations: const [
          ContentRelation(type: 'featureOf', targetId: 'p:subclass/x'),
        ],
      );
      final subclass = _entry(
        id: 'p:subclass/x',
        type: 'subclass',
        name: 'X',
        relations: const [
          ContentRelation(type: 'subclassOf', targetId: 'p:class/mage'),
        ],
      );

      expect(
        RuleChoiceSemantics.scopeEntryIdsFor('p:feature/f', {
          feature.id: feature,
          subclass.id: subclass,
        }),
        {'p:feature/f', 'p:subclass/x', 'p:class/mage'},
      );
      // 只有 featureOf / subclassOf 参与作用域；其它关系类型不跟随。
      final related = _entry(
        id: 'p:feat/rel',
        type: 'feat',
        name: 'R',
        relations: const [
          ContentRelation(type: 'related', targetId: 'p:class/mage'),
        ],
      );
      expect(
        RuleChoiceSemantics.scopeEntryIdsFor('p:feat/rel', {
          related.id: related,
        }),
        {'p:feat/rel'},
      );
    });
  });

  group('candidateRequiresSatisfied（options[].requires，决策 D6）', () {
    test('内联选项自带的 requires 走同一判定实现', () {
      const definition = RuleChoiceDefinition(
        id: 'invocations',
        label: '祈唤',
        optionType: 'classFeature',
        minimum: 1,
        maximum: 1,
        requires: [RuleRequiresDefinition(ability: 'cha', minimum: 13)],
        options: [
          RuleChoiceOption(
            id: 'a',
            label: 'A',
            requires: [RuleRequiresDefinition(choice: 'spellbook')],
          ),
        ],
      );

      final candidate = RuleChoiceSemantics.candidatesFor(
        definition,
        entries: const {},
      ).single;

      expect(
        RuleChoiceSemantics.candidateRequiresSatisfied(
          candidate,
          sourceEntryId: 'p:class/mage',
          selectedByKey: const {
            'p:class/mage#spellbook': ['p:spell/a'],
          },
          abilities: const {'cha': 13},
          entries: entries,
        ),
        isTrue,
      );
      // 选项自身的 requires 不满足（choice 未选）。
      expect(
        RuleChoiceSemantics.candidateRequiresSatisfied(
          candidate,
          sourceEntryId: 'p:class/mage',
          selectedByKey: const {},
          abilities: const {'cha': 13},
          entries: entries,
        ),
        isFalse,
      );
    });

    test('没有 requires 的候选恒满足', () {
      const definition = RuleChoiceDefinition(
        id: 'pick',
        label: '选一个',
        optionType: 'feat',
        minimum: 1,
        maximum: 1,
        options: [RuleChoiceOption(id: 'a', label: 'A')],
      );

      final candidate = RuleChoiceSemantics.candidatesFor(
        definition,
        entries: const {},
      ).single;

      expect(
        RuleChoiceSemantics.candidateRequiresSatisfied(
          candidate,
          sourceEntryId: 'p:class/mage',
          selectedByKey: const {},
          abilities: const {},
          entries: entries,
        ),
        isTrue,
      );
    });
  });

  group('definitionForKey', () {
    test('解析 <entryId>#<choiceId>[#<level>]，条目缺失返回 null', () {
      final classEntry = _entry(
        id: 'p:class/mage',
        type: 'class',
        name: '法师',
        rules: const CharacterRuleDefinition(
          choices: [
            RuleChoiceDefinition(
              id: 'spellbook',
              label: '法术书',
              optionType: 'spell',
              minimum: 1,
              maximum: 1,
            ),
          ],
        ),
      );

      final found = RuleChoiceSemantics.definitionForKey(
        'p:class/mage#spellbook#3',
        entries: {classEntry.id: classEntry},
      );

      expect(found, isNotNull);
      expect(found!.definition.id, 'spellbook');
      expect(found.sourceEntryId, 'p:class/mage');
      expect(found.level, 3);
      expect(
        RuleChoiceSemantics.definitionForKey(
          'p:class/mage#spellbook',
          entries: {classEntry.id: classEntry},
        )!.level,
        isNull,
      );
      expect(
        RuleChoiceSemantics.definitionForKey(
          'p:class/missing#spellbook',
          entries: {classEntry.id: classEntry},
        ),
        isNull,
      );
      expect(
        RuleChoiceSemantics.definitionForKey(
          'p:class/mage#unknown',
          entries: {classEntry.id: classEntry},
        ),
        isNull,
      );
      expect(
        RuleChoiceSemantics.definitionForKey(
          'p:class/mage',
          entries: {classEntry.id: classEntry},
        ),
        isNull,
      );
    });

    test('progression[].choices 里的定义同样可解析（等级段键）', () {
      final classEntry = _entry(
        id: 'p:class/mage',
        type: 'class',
        name: '法师',
        rules: const CharacterRuleDefinition(
          progression: [
            RuleProgressionDefinition(
              levels: [3],
              choices: [
                RuleChoiceDefinition(
                  id: 'signature',
                  label: '招牌法术',
                  optionType: 'spell',
                  minimum: 1,
                  maximum: 1,
                ),
              ],
            ),
          ],
        ),
      );

      final found = RuleChoiceSemantics.definitionForKey(
        'p:class/mage#signature#3',
        entries: {classEntry.id: classEntry},
      );

      expect(found, isNotNull);
      expect(found!.definition.id, 'signature');
      expect(found.level, 3);
    });
  });
}

ContentEntry _entry({
  required String id,
  required String type,
  required String name,
  List<String> tags = const [],
  Map<String, Object?> structured = const {},
  List<ContentRelation> relations = const [],
  CharacterRuleDefinition? rules,
}) => ContentEntry.fromJson({
  'id': id,
  'type': type,
  'slug': id.split('/').last,
  'name': name,
  'body': <Object?>[],
  'revision': 1,
  'tags': tags,
  'structured': structured,
  'relations': [
    for (final relation in relations)
      {'type': relation.type, 'targetId': relation.targetId},
  ],
  if (rules != null) 'rules': rules.toJson(),
});

/// `rule_choice_semantics.dart` 里 `autoGrantsFor` 的 `switch (optionType)` 正文
/// （到 `default:` 为止）。用于把 switch 的 case 字面量与 [kAutoGrantOptionTypes]
/// 双向锁定：两份字面量不能只在运行时"碰巧"一致。
String _autoGrantsSwitchBody() {
  final file = File(
    'lib/src/features/rules/domain/rule_choice_semantics.dart',
  );
  if (!file.existsSync()) {
    throw StateError(
      '找不到 rule_choice_semantics.dart（cwd=${Directory.current.path}）',
    );
  }
  final source = file.readAsStringSync();
  final start = source.indexOf('switch (optionType)');
  final end = start < 0 ? -1 : source.indexOf('default:', start);
  if (start < 0 || end < 0) {
    throw StateError('autoGrantsFor 的 switch 结构已变，守护测试需要同步');
  }
  return source.substring(start, end);
}
