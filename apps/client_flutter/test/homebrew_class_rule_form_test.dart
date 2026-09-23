import 'dart:convert';

import 'package:dnd_table_client/src/features/content/presentation/homebrew_class_rule_form.dart';
import 'package:dnd_table_client/src/features/rules/domain/character_rule_definition.dart';
import 'package:dnd_table_client/src/features/rules/domain/class_rule_set.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_diagnostic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 表单的宿主：两段 JSON 文本就是唯一事实来源（与作者对话框同一形状）。
class _Host extends StatefulWidget {
  const _Host({required this.structured, required this.rules});

  final String structured;
  final String rules;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late final TextEditingController structured = TextEditingController(
    text: widget.structured,
  );
  late final TextEditingController rules = TextEditingController(
    text: widget.rules,
  );

  @override
  void dispose() {
    structured.dispose();
    rules.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: HomebrewClassRuleForm(
          structuredJson: () => structured.text,
          rulesJson: () => rules.text,
          onChanged: (structured, rules) => setState(() {
            this.structured.text = structured;
            this.rules.text = rules;
          }),
        ),
      ),
    ),
  );
}

Map<String, Object?> _decode(String text) =>
    Map<String, Object?>.from(jsonDecode(text) as Map);

void main() {
  Future<_HostState> pumpForm(
    WidgetTester tester, {
    required Map<String, Object?> structured,
    required Map<String, Object?> rules,
  }) async {
    tester.view.physicalSize = const Size(1400, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _Host(
        structured: jsonEncode(structured),
        rules: jsonEncode(rules),
      ),
    );
    await tester.pumpAndSettle();
    return tester.state<_HostState>(find.byType(_Host));
  }

  Future<void> tapKey(WidgetTester tester, Key key) async {
    final finder = find.byKey(key);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('未知数量池显示原值而不是假装未设置', (tester) async {
    await pumpForm(
      tester,
      structured: {'classRules': <String, Object?>{}},
      rules: {
        'choices': [
          {
            'id': 'legacy-choice',
            'label': '旧选择',
            'optionType': 'value',
            'countsToward': 'legacyPool',
          },
        ],
      },
    );

    final dropdown = tester.widget<DropdownButton<String>>(
      find.byKey(const Key('homebrew-choice-root-0-counts-toward')),
    );
    expect(dropdown.value, 'legacyPool');
  });

  testWidgets('现有 classRules / progression 渲染成控件（不是"空白表单"）', (tester) async {
    await pumpForm(
      tester,
      structured: {
        'classRules': {
          'hitDie': 8,
          'savingThrowAbilities': ['con', 'wis'],
          'spellcasting': {'ability': 'int'},
          'resources': [
            {'id': 'focus', 'name': '专注点', 'maximum': 3, 'recovery': 'shortRest'},
          ],
        },
      },
      rules: {
        'progression': [
          {
            'levels': [1, 3],
            'grants': [
              {'id': 'g1', 'kind': 'ability', 'target': 'str', 'value': 2},
            ],
          },
        ],
      },
    );

    // 生命骰显示 d8、施法属性显示智力（受控下拉读的就是 JSON 的值）。
    expect(find.text('d8'), findsOneWidget);
    expect(find.text('智力'), findsWidgets, reason: 'DropDownButton 会为选中项渲染两次');
    expect(find.text('专注点'), findsOneWidget);
    expect(find.text('等级 1、3'), findsOneWidget);
    expect(find.byKey(const Key('homebrew-form-save-con')), findsOneWidget);
    expect(
      tester.widget<FilterChip>(find.byKey(const Key('homebrew-form-save-con'))).selected,
      isTrue,
    );
    expect(
      tester.widget<FilterChip>(find.byKey(const Key('homebrew-form-step-0-level-3'))).selected,
      isTrue,
    );
    expect(find.byKey(const Key('homebrew-form-save-warning')), findsNothing);
  });

  testWidgets('改生命骰 / 豁免 / 施法属性 → 只动 classRules 的对应列', (tester) async {
    final host = await pumpForm(
      tester,
      structured: {
        'classRules': {
          'hitDie': 8,
          'savingThrowAbilities': ['con', 'wis'],
          // 表单不认识的列必须原样保留（Table / MaxSpec 形态仍归 JSON）。
          'spellcasting': {
            'ability': 'int',
            'prepared': {
              'table': {'1': 4, '2': 5},
            },
          },
        },
      },
      rules: const {},
    );

    await tapKey(tester, const Key('homebrew-form-hit-die'));
    await tester.tap(find.text('d10').last);
    await tester.pumpAndSettle();
    await tapKey(tester, const Key('homebrew-form-save-dex'));
    // 三项豁免 → 就地问责"恰好两项"（不静默保存一个导入期必被拦下的声明）。
    expect(find.byKey(const Key('homebrew-form-save-warning')), findsOneWidget);
    await tapKey(tester, const Key('homebrew-form-spell-ability'));
    await tester.tap(find.text('感知').last);
    await tester.pumpAndSettle();

    final classRules = _decode(host.structured.text)['classRules']!
        as Map<String, Object?>;
    expect(classRules['hitDie'], 10);
    expect(classRules['savingThrowAbilities'], ['con', 'wis', 'dex']);
    final spellcasting = classRules['spellcasting']! as Map<String, Object?>;
    expect(spellcasting['ability'], 'wis');
    expect(
      spellcasting['prepared'],
      {
        'table': {'1': 4, '2': 5},
      },
      reason: '表单没建模的列必须原样带回去',
    );

    // 取消一个豁免 → 回到两项，警告消失。
    await tapKey(tester, const Key('homebrew-form-save-con'));
    expect(find.byKey(const Key('homebrew-form-save-warning')), findsNothing);
  });

  testWidgets('添加资源：id / 名称 / 整数上限 / 恢复写进 resources[]', (tester) async {
    final host = await pumpForm(
      tester,
      structured: const {},
      rules: const {},
    );

    await tapKey(tester, const Key('homebrew-form-add-resource'));
    await tester.enterText(
      find.byKey(const Key('homebrew-form-resource-0-id')),
      'focus',
    );
    await tester.enterText(
      find.byKey(const Key('homebrew-form-resource-0-name')),
      '专注点',
    );
    await tester.enterText(
      find.byKey(const Key('homebrew-form-resource-0-maximum')),
      '3',
    );
    await tester.pumpAndSettle();
    await tapKey(tester, const Key('homebrew-form-resource-0-recovery'));
    await tester.tap(find.text('短休').last);
    await tester.pumpAndSettle();

    final classRules = _decode(host.structured.text)['classRules']!
        as Map<String, Object?>;
    final resources = classRules['resources']! as List<Object?>;
    final resource = resources.single as Map<String, Object?>;
    expect(resource['id'], 'focus');
    expect(resource['name'], '专注点');
    expect(resource['maximum'], 3);
    expect(resource['recovery'], 'shortRest');

    // 删掉唯一资源 → classRules 整块不再声明（不写 `resources: []`，空数组
    // 在契约里是"本块没有声明"，语义不同）。
    await tapKey(tester, const Key('homebrew-form-resource-0-remove'));
    expect(_decode(host.structured.text).containsKey('classRules'), isFalse);
  });

  testWidgets('等级步骤与授予：等级多选 + kind/target/value 写进 progression', (tester) async {
    final host = await pumpForm(
      tester,
      structured: const {},
      rules: const {},
    );

    await tapKey(tester, const Key('homebrew-form-add-step'));
    await tapKey(tester, const Key('homebrew-form-step-0-level-5'));
    await tapKey(tester, const Key('homebrew-form-step-0-add-grant'));
    await tapKey(tester, const Key('homebrew-form-grant-0-kind'));
    await tester.tap(find.text('熟练').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('homebrew-form-grant-0-target')),
      'skill:察觉',
    );
    await tester.enterText(
      find.byKey(const Key('homebrew-form-grant-0-value')),
      '0',
    );
    await tester.pumpAndSettle();

    final rules = _decode(host.rules.text);
    final step = (rules['progression']! as List<Object?>).single
        as Map<String, Object?>;
    expect(step['levels'], [1, 5]);
    final grant = (step['grants']! as List<Object?>).single
        as Map<String, Object?>;
    expect(grant['kind'], 'proficiency');
    expect(grant['target'], 'skill:察觉');
    expect(grant['value'], 0);
    expect(grant['id'], isNotEmpty);

    // 删除步骤 → progression 整个键消失（不写空数组）。
    await tapKey(tester, const Key('homebrew-form-step-0-remove'));
    expect(_decode(host.rules.text).containsKey('progression'), isFalse);
  });

  testWidgets('表形态的 recovery 不伪装成长休，也不会被一次点选写坏', (tester) async {
    final host = await pumpForm(
      tester,
      structured: {
        'classRules': {
          'resources': [
            {
              'id': 'focus',
              'name': '专注点',
              'recovery': {
                'table': {'1': 'longRest', '5': 'shortRest'},
              },
            },
          ],
        },
      },
      rules: const {},
    );

    expect(
      find.byKey(const Key('homebrew-form-resource-0-recovery-table')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('homebrew-form-resource-0-recovery')),
      findsNothing,
      reason: '表形态不提供可点选的下拉框，避免一键把整张表替换成常量',
    );
    expect(find.text('长休'), findsNothing);
    expect(find.textContaining('shortRest'), findsOneWidget);

    final resource =
        ((_decode(host.structured.text)['classRules']! as Map)['resources']!
                as List)
            .single
        as Map<String, Object?>;
    expect(resource['recovery'], {
      'table': {'1': 'longRest', '5': 'shortRest'},
    });
  });

  testWidgets('名称字段不做 trim 写回，词中/词尾空格保留', (tester) async {
    final host = await pumpForm(tester, structured: const {}, rules: const {});
    await tapKey(tester, const Key('homebrew-form-add-resource'));
    final finder = find.byKey(const Key('homebrew-form-resource-0-name'));
    await tester.enterText(finder, '专 注 ');
    await tester.pumpAndSettle();

    final resource =
        ((_decode(host.structured.text)['classRules']! as Map)['resources']!
                as List)
            .single
        as Map<String, Object?>;
    expect(resource['name'], '专 注 ', reason: '自由文本原样写回，不裁剪');
    // 若写回时 trim，父级重建会把 controller 文本改回裁剪值（光标重置），
    // 于是词中间的空格永远打不出来。
    expect(
      tester.widget<TextFormField>(finder).controller!.text,
      '专 注 ',
      reason: 'controller 不被裁剪后的值重置',
    );
  });

  testWidgets('添加资源产出的默认形状本身合法（不写空 name）', (tester) async {
    final host = await pumpForm(tester, structured: const {}, rules: const {});
    await tapKey(tester, const Key('homebrew-form-add-resource'));

    final classRules = _decode(host.structured.text)['classRules']!
        as Map<String, Object?>;
    final resource =
        (classRules['resources']! as List).single as Map<String, Object?>;
    expect(resource.containsKey('name'), isFalse, reason: '缺省 = patch 未声明');
    // 契约层直接解析一次：默认产物不能是导入期才炸的 error（`name: ""` 就是）。
    final diagnostics = <RuleDiagnostic>[];
    ClassRuleSet.parse(
      classRules,
      path: r'$',
      diagnostics: diagnostics,
      abilities: kDefaultAbilities,
    );
    expect(
      diagnostics.where((item) => item.severity == RuleSeverity.error),
      isEmpty,
      reason: '${diagnostics.map((item) => item.message)}',
    );
  });

  testWidgets('顶层选择与等级选择可视化编辑，包含内联选项和属性前置', (tester) async {
    final host = await pumpForm(tester, structured: const {}, rules: const {});
    await tapKey(tester, const Key('homebrew-choice-root-add'));
    await tester.enterText(
      find.byKey(const Key('homebrew-choice-root-0-id')),
      'class-skills',
    );
    await tester.enterText(
      find.byKey(const Key('homebrew-choice-root-0-label')),
      '选择技能',
    );
    await tester.enterText(
      find.byKey(const Key('homebrew-choice-root-0-type')),
      'skill',
    );
    await tester.enterText(
      find.byKey(const Key('homebrew-choice-root-0-group')),
      '职业选择',
    );
    await tapKey(tester, const Key('homebrew-choice-root-0-add-option'));
    await tester.enterText(
      find.byKey(const Key('homebrew-choice-root-0-option-0-id')),
      '察觉',
    );
    await tapKey(tester, const Key('homebrew-choice-root-0-add-requires'));

    final choice = (_decode(host.rules.text)['choices']! as List).single
        as Map<String, Object?>;
    expect(choice['id'], 'class-skills');
    expect(choice['optionType'], 'skill');
    expect(choice['options'], ['察觉']);
    expect(choice['requires'], [
      {'ability': 'str', 'minimum': 13},
    ]);
    expect(RuleChoiceDefinition.fromJson(choice).group, '职业选择');

    await tapKey(tester, const Key('homebrew-form-add-step'));
    await tapKey(tester, const Key('homebrew-choice-step-0-add'));
    final step = (_decode(host.rules.text)['progression']! as List).single
        as Map<String, Object?>;
    expect((step['choices'] as List), hasLength(1));
    expect(step['levels'], [1]);
  });

  testWidgets('编辑对象选项不丢失已有 data/grants/requires，删除选择只删目标', (tester) async {
    final host = await pumpForm(
      tester,
      structured: const {},
      rules: {
        'choices': [
          {
            'id': 'talent',
            'label': '天赋',
            'optionType': 'value',
            'options': [
              {
                'id': 'swift',
                'label': '迅捷',
                'data': {'custom': true},
                'grants': [
                  {'id': 'speed', 'kind': 'speed', 'value': 5},
                ],
                'requires': [
                  {'choice': 'origin', 'option': 'human'},
                ],
              },
            ],
          },
          {'id': 'other', 'label': '其他', 'optionType': 'value'},
        ],
      },
    );
    await tester.enterText(
      find.byKey(const Key('homebrew-choice-root-0-option-0-label')),
      '迅捷步伐',
    );
    final first = (_decode(host.rules.text)['choices']! as List).first
        as Map<String, Object?>;
    final option = (first['options'] as List).single as Map<String, Object?>;
    expect(option['label'], '迅捷步伐');
    expect(option['data'], {'custom': true});
    expect((option['grants'] as List).single, {
      'id': 'speed', 'kind': 'speed', 'value': 5,
    });
    expect(option['requires'], [
      {'choice': 'origin', 'option': 'human'},
    ]);

    await tapKey(tester, const Key('homebrew-choice-root-0-remove'));
    final remaining = (_decode(host.rules.text)['choices']! as List).single
        as Map<String, Object?>;
    expect(remaining['id'], 'other');
  });

  testWidgets('条目白名单和标签可逐项添加、编辑、删除', (tester) async {
    final host = await pumpForm(tester, structured: const {}, rules: const {});
    await tapKey(tester, const Key('homebrew-choice-root-add'));
    await tapKey(tester, const Key('homebrew-choice-root-0-entry-ids-add'));
    await tester.enterText(
      find.byKey(const Key('homebrew-choice-root-0-entry-ids-0')),
      'homebrew:subclass/alpha',
    );
    await tapKey(tester, const Key('homebrew-choice-root-0-entry-ids-add'));
    await tester.enterText(
      find.byKey(const Key('homebrew-choice-root-0-entry-ids-1')),
      'homebrew:subclass/beta',
    );
    await tapKey(tester, const Key('homebrew-choice-root-0-tags-add'));
    await tester.enterText(
      find.byKey(const Key('homebrew-choice-root-0-tags-0')),
      'origin',
    );
    final choice = (_decode(host.rules.text)['choices'] as List).single as Map;
    expect(choice['optionEntryIds'], [
      'homebrew:subclass/alpha',
      'homebrew:subclass/beta',
    ]);
    expect(choice['optionTags'], ['origin']);
    await tapKey(tester, const Key('homebrew-choice-root-0-entry-ids-0-remove'));
    expect(((_decode(host.rules.text)['choices'] as List).single as Map)
        ['optionEntryIds'], ['homebrew:subclass/beta']);
  });

  testWidgets('内联对象选项可编辑授予和依赖其他选择的前置条件', (tester) async {
    final host = await pumpForm(tester, structured: const {}, rules: const {});
    await tapKey(tester, const Key('homebrew-choice-root-add'));
    await tapKey(tester, const Key('homebrew-choice-root-0-add-option'));
    await tapKey(tester, const Key('homebrew-choice-root-0-option-0-details'));
    await tester.enterText(
      find.byKey(const Key('homebrew-choice-root-0-option-0-label')),
      '迅捷步伐',
    );
    await tapKey(tester, const Key('homebrew-choice-root-0-option-0-add-requires'));
    await tapKey(tester, const Key('homebrew-choice-root-0-option-0-requires-0-kind'));
    await tester.tap(find.text('choice').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('homebrew-choice-root-0-option-0-requires-0-choice')),
      'origin',
    );
    await tapKey(tester, const Key('homebrew-choice-root-0-option-0-add-grant'));
    await tester.enterText(
      find.byKey(const Key('homebrew-choice-root-0-option-0-grant-0-target')),
      'skill:察觉',
    );

    final choice = (_decode(host.rules.text)['choices'] as List).single
        as Map<String, Object?>;
    final option = (choice['options'] as List).single as Map<String, Object?>;
    expect(option['label'], '迅捷步伐');
    expect(option['requires'], [
      {'choice': 'origin'},
    ]);
    expect((option['grants'] as List).single, {
      'id': 'grant-1', 'kind': 'feature', 'target': 'skill:察觉',
    });
    expect(RuleChoiceDefinition.fromJson(choice).options.single.label,
        '迅捷步伐');
  });

  testWidgets('选择表单在手机宽度下不发生布局溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_Host(
      structured: '{}',
      rules: jsonEncode({
        'choices': [
          {
            'id': 'many-options',
            'label': '非常长的职业选择名称用于验证手机宽度下的布局',
            'optionType': 'subclass',
            'optionEntryIds': ['package:subclass/a', 'package:subclass/b'],
            'requires': [
              {'ability': 'str', 'minimum': 13},
            ],
          },
        ],
      }),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('homebrew-choice-root-0-entry-ids-add')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('删除中间资源后，剩下的行不会显示上一行的值', (tester) async {
    final host = await pumpForm(
      tester,
      structured: {
        'classRules': {
          'resources': [
            {'id': 'a', 'name': 'alpha'},
            {'id': 'b', 'name': 'beta'},
          ],
        },
      },
      rules: const {},
    );

    await tapKey(tester, const Key('homebrew-form-resource-0-remove'));

    final nameField = find.byKey(const Key('homebrew-form-resource-0-name'));
    expect(
      tester.widget<TextFormField>(nameField).controller!.text,
      'beta',
      reason: '行位移后 controller 必须同步成新行（否则显示上一行的值）',
    );
    final resources =
        ((_decode(host.structured.text)['classRules']! as Map)['resources']!
                as List)
            .map((item) => Map<String, Object?>.from(item as Map))
            .toList();
    expect(resources.single['id'], 'b');
    expect(resources.single['name'], 'beta');
  });

  testWidgets('JSON 不是合法对象：表单拒绝渲染并提示切回 JSON', (tester) async {    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const _Host(structured: '{not json', rules: '{}'),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('homebrew-form-invalid-json')), findsOneWidget);
    expect(find.byKey(const Key('homebrew-form-hit-die')), findsNothing);
  });

  test('grantKindLabels 覆盖全部 RuleGrantKind（单一来源守卫）', () {
    expect(
      HomebrewClassRuleForm.grantKindLabels.keys.toSet(),
      RuleGrantKind.values.toSet(),
    );
    expect(
      HomebrewClassRuleForm.abilityLabels.keys.toSet(),
      {'str', 'dex', 'con', 'int', 'wis', 'cha'},
    );
  });
}
