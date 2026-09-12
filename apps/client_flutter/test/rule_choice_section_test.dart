// 共享选择组件 `RuleChoiceSection` 的行为契约（计划任务 6a / 6b）：
// 有序 List（点击顺序）、repeatable 的 ×N 与"取消只移除一份"、group/help 文案、
// 选择级 requires 的"已选但未生效"、选项级 requires 的候选隐藏。
import 'package:dnd_table_client/src/features/characters/presentation/widgets/rule_choice_section.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/rules/domain/character_rule_definition.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_choice_semantics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _chip(String label) => find.widgetWithText(FilterChip, label);

void main() {
  const definition = RuleChoiceDefinition(
    id: 'pick',
    label: '选择战斗风格',
    optionType: 'feat',
    minimum: 1,
    maximum: 2,
    options: [
      RuleChoiceOption(id: 'a', label: '决斗'),
      RuleChoiceOption(id: 'b', label: '防御'),
    ],
  );

  testWidgets('选中顺序即点击顺序（有序 List，不是 Set）', (tester) async {
    var selected = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => RuleChoiceSection(
              definition: definition,
              candidates: RuleChoiceSemantics.candidatesFor(
                definition,
                entries: const <String, ContentEntry>{},
              ),
              selected: selected,
              onChanged: (next) => setState(() => selected = next),
            ),
          ),
        ),
      ),
    );

    await tester.tap(_chip('防御'));
    await tester.pump();
    await tester.tap(_chip('决斗'));
    await tester.pump();

    expect(selected, ['b', 'a'], reason: '顺序即点击顺序，不被排序改写');
  });

  testWidgets('取消选择按 id 移除，不影响其它项', (tester) async {
    List<String>? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RuleChoiceSection(
            definition: definition,
            candidates: RuleChoiceSemantics.candidatesFor(
              definition,
              entries: const <String, ContentEntry>{},
            ),
            selected: const ['a', 'b'],
            onChanged: (next) => changed = next,
          ),
        ),
      ),
    );

    await tester.tap(_chip('决斗'));
    await tester.pump();

    expect(changed, ['b']);
  });

  testWidgets('repeatable：点两次 chip 显示 ×2 且回调带两份；取消一次只移除一份', (
    tester,
  ) async {
    const repeatable = RuleChoiceDefinition(
      id: 'invocations',
      label: '祈唤',
      optionType: 'classFeature',
      minimum: 1,
      maximum: 2,
      repeatable: true,
      options: [RuleChoiceOption(id: 'a', label: '魔能爆')],
    );
    var selected = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => RuleChoiceSection(
              definition: repeatable,
              candidates: RuleChoiceSemantics.candidatesFor(
                repeatable,
                entries: const <String, ContentEntry>{},
              ),
              selected: selected,
              onChanged: (next) => setState(() => selected = next),
            ),
          ),
        ),
      ),
    );

    await tester.tap(_chip('魔能爆'));
    await tester.pump();
    expect(selected, ['a'], reason: '第一次选取只有一份');
    expect(find.text('魔能爆'), findsOneWidget, reason: '×1 不显示重复计数');

    await tester.tap(_chip('魔能爆'));
    await tester.pump();
    expect(selected, ['a', 'a'], reason: 'repeatable 的草稿里必须真有两份');
    expect(
      tester.widget<FilterChip>(find.widgetWithText(FilterChip, '魔能爆 ×2')),
      isNotNull,
    );
    expect(
      tester.widget<FilterChip>(find.byType(FilterChip)).selected,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('rule-choice-remove-a')));
    await tester.pump();
    expect(selected, ['a'], reason: '取消一次只移除第一次出现的那份');
    expect(find.text('魔能爆'), findsOneWidget);
    expect(find.text('魔能爆 ×2'), findsNothing);
  });
  testWidgets('达到 maximum 后 repeatable 不再追加（不静默超额）', (tester) async {
    const capped = RuleChoiceDefinition(
      id: 'invocations',
      label: '祈唤',
      optionType: 'classFeature',
      minimum: 1,
      maximum: 2,
      repeatable: true,
      options: [
        RuleChoiceOption(id: 'a', label: '魔能爆'),
        RuleChoiceOption(id: 'b', label: '苦痛魔爆'),
      ],
    );
    List<String>? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RuleChoiceSection(
            definition: capped,
            candidates: RuleChoiceSemantics.candidatesFor(
              capped,
              entries: const <String, ContentEntry>{},
            ),
            selected: const ['a', 'a'],
            onChanged: (next) => changed = next,
          ),
        ),
      ),
    );

    await tester.tap(_chip('苦痛魔爆'));
    await tester.pump();

    expect(changed, isNull, reason: '已达次数上限时不得悄悄追加或丢值');
    expect(find.text('魔能爆 ×2'), findsOneWidget);
  });

  testWidgets('选项级 requires 不满足的候选不出现（决策 D6）', (tester) async {
    const gated = RuleChoiceDefinition(
      id: 'invocations',
      label: '祈唤',
      optionType: 'classFeature',
      minimum: 1,
      maximum: 2,
      options: [
        RuleChoiceOption(id: 'a', label: '魔能爆'),
        RuleChoiceOption(
          id: 'b',
          label: '高阶祈唤',
          requires: [RuleRequiresDefinition(ability: 'cha', minimum: 13)],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RuleChoiceSection(
            definition: gated,
            candidates: RuleChoiceSemantics.candidatesFor(
              gated,
              entries: const <String, ContentEntry>{},
            ),
            selected: const <String>[],
            requiresContext: const RuleChoiceRequiresContext(
              sourceEntryId: 'test:class/warlock',
              selectedByKey: <String, List<String>>{},
              abilities: {'cha': 12},
              entries: <String, ContentEntry>{},
            ),
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('魔能爆'), findsOneWidget);
    expect(find.text('高阶祈唤'), findsNothing, reason: '前置不满足的候选必须隐藏');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RuleChoiceSection(
            definition: gated,
            candidates: RuleChoiceSemantics.candidatesFor(
              gated,
              entries: const <String, ContentEntry>{},
            ),
            selected: const <String>[],
            requiresContext: const RuleChoiceRequiresContext(
              sourceEntryId: 'test:class/warlock',
              selectedByKey: <String, List<String>>{},
              abilities: {'cha': 13},
              entries: <String, ContentEntry>{},
            ),
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('高阶祈唤'), findsOneWidget, reason: '前置满足后候选可见');
  });

  testWidgets('选择级 requires 不满足：不渲染候选、给原因、已选值标"已选但未生效"', (
    tester,
  ) async {
    const gated = RuleChoiceDefinition(
      id: 'invocations',
      label: '祈唤',
      optionType: 'classFeature',
      minimum: 1,
      maximum: 2,
      requires: [RuleRequiresDefinition(ability: 'cha', minimum: 13)],
      options: [RuleChoiceOption(id: 'a', label: '魔能爆')],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RuleChoiceSection(
            definition: gated,
            candidates: RuleChoiceSemantics.candidatesFor(
              gated,
              entries: const <String, ContentEntry>{},
            ),
            selected: const ['a'],
            blockedReason: '需要魅力 13',
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('需要魅力 13'), findsOneWidget);
    expect(find.text('已选但未生效：魔能爆'), findsOneWidget);
    expect(find.text('魔能爆'), findsNothing, reason: '前置不满足时不渲染候选 chip');
  });

  testWidgets('help 以小字展示，group 标题由分组容器按首次声明顺序渲染', (
    tester,
  ) async {
    const helped = RuleChoiceDefinition(
      id: 'invocations',
      label: '祈唤',
      optionType: 'classFeature',
      minimum: 1,
      maximum: 1,
      group: '魔能契约',
      help: '每次长休后可以更换一项。',
      options: [RuleChoiceOption(id: 'a', label: '魔能爆')],
    );
    const ungrouped = RuleChoiceDefinition(
      id: 'pact',
      label: '契约恩赐',
      optionType: 'classFeature',
      minimum: 1,
      maximum: 1,
      options: [RuleChoiceOption(id: 'b', label: '链主恩赐')],
    );
    final groups = groupRuleChoiceSections<RuleChoiceDefinition>(
      const [helped, ungrouped],
      groupOf: (definition) => definition.group,
      buildChoice: (definition) => RuleChoiceSection(
        definition: definition,
        candidates: RuleChoiceSemantics.candidatesFor(
          definition,
          entries: const <String, ContentEntry>{},
        ),
        selected: const <String>[],
        onChanged: (_) {},
      ),
    );

    expect(groups, hasLength(2));
    expect(groups.first.title, '魔能契约');
    expect(groups.last.title, isNull, reason: '未声明 group 的组排最后');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RuleChoiceGroupedSections(groups: groups),
          ),
        ),
      ),
    );

    expect(find.text('魔能契约'), findsOneWidget);
    expect(find.text('每次长休后可以更换一项。'), findsOneWidget);
    expect(find.text('祈唤'), findsOneWidget);
    expect(find.text('契约恩赐'), findsOneWidget);
  });
}
