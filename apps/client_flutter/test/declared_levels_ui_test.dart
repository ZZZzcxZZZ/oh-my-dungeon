import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/domain/declared_levels.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_detail_page.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_editor_page.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_upgrade_page.dart';
import 'package:dnd_table_client/src/features/characters/presentation/widgets/declared_level_banner.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/content/domain/content_import_report.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_import_preview_dialog.dart';
import 'package:dnd_table_client/src/features/content/presentation/widgets/content_character_rules_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 只声明 1–5 级的职业条目（`resources` 表最短只到 5 级，§3.12 部分声明）。
ContentEntry _partialClassEntry({
  String id = 'test:class/tester',
  String name = '测试职业',
}) {
  return _entry(
    id: id,
    type: 'class',
    name: name,
    structured: const <String, Object?>{
      'classRules': <String, Object?>{
        'hitDie': 10,
        'resources': <Object?>[
          <String, Object?>{
            'id': 'focus',
            'name': '专注',
            'recovery': 'longRest',
            'maximum': <String, Object?>{
              'table': <String, int>{'1': 2, '3': 3, '5': 4},
            },
          },
        ],
      },
    },
    rules: const <String, Object?>{
      'grants': <Object?>[
        <String, Object?>{
          'id': 'focus-grant',
          'kind': 'feature',
          'label': '专注特性',
        },
      ],
    },
  );
}

ContentEntry _entry({
  required String id,
  required String type,
  required String name,
  Map<String, Object?> structured = const <String, Object?>{},
  Map<String, Object?>? rules,
}) {
  return ContentEntry.fromJson(<String, Object?>{
    'id': id,
    'type': type,
    'slug': id.split('/').last,
    'name': name,
    'body': <Object?>[],
    'revision': 1,
    'structured': structured,
    'tags': <Object?>[],
    'rules': ?rules,
  });
}

CharacterSheet _character({
  required int level,
  Map<String, Object?>? classIdentity,
  Map<String, Object?>? extraData,
}) {
  return CharacterSheet.local(
    id: 'hero',
    name: '阿雅',
    level: level,
    classSummary: '测试职业',
  ).copyWith(
    maxHp: 40,
    currentHp: 40,
    abilities: const <String, int>{
      'str': 16,
      'dex': 12,
      'con': 14,
      'int': 10,
      'wis': 10,
      'cha': 8,
    },
    data: <String, Object?>{
      'classIdentity': ?classIdentity,
      ...?extraData,
    },
  );
}

Map<String, Object?> _identity({int? min, int? max, bool declared = true}) {
  return <String, Object?>{
    'entryId': 'test:class/tester',
    'slug': 'tester',
    'name': '测试职业',
    'declared': declared,
    'declaredLevels': <String, Object?>{'min': min, 'max': max},
  };
}

void main() {
  group('DeclaredLevels 读取器', () {
    test('从 character.dataMap 读出声明范围，超出即不覆盖', () {
      final levels = DeclaredLevels.fromCharacter(
        _character(level: 8, classIdentity: _identity(min: 1, max: 5)),
      );

      expect(levels.min, 1);
      expect(levels.max, 5);
      expect(levels.isEmpty, isFalse);
      expect(levels.covers(1), isTrue);
      expect(levels.covers(5), isTrue);
      expect(levels.covers(6), isFalse);
      expect(levels.covers(8), isFalse);
      expect(levels.rangeLabel, '职业声明：1–5 级');
      expect(
        levels.beyondLabel,
        '该职业未声明 6 级以上内容，你仍可继续（数值按未声明处理）',
      );
    });

    test('缺省 / 全 null 声明 = 完全没有等级声明（max 为 null，不是 20）', () {
      final missing = DeclaredLevels.fromCharacter(_character(level: 3));
      expect(missing.min, 1);
      expect(missing.max, isNull);
      expect(missing.isEmpty, isTrue);
      expect(missing.covers(1), isFalse);
      expect(missing.rangeLabel, '该职业未声明任何等级内容');
      expect(missing.detailLabel(3), isNull, reason: '完全没有声明时文案只出现一次');

      final allNull = DeclaredLevels.fromCharacter(
        _character(level: 3, classIdentity: _identity(min: null, max: null)),
      );
      expect(allNull.max, isNull);
      expect(allNull.isEmpty, isTrue);
    });

    test('低于最早声明等级也算未声明（min 之外的等级没有数值）', () {
      final levels = DeclaredLevels.fromCharacter(
        _character(level: 3, classIdentity: _identity(min: 5, max: 10)),
      );

      expect(levels.covers(3), isFalse);
      expect(levels.isBelow(3), isTrue);
      expect(levels.isBeyond(3), isFalse);
      expect(levels.detailLabel(3), '该职业未声明 5 级以下内容，你仍可继续（数值按未声明处理）');
    });
  });

  group('DeclaredLevelBanner 共用的信息条', () {
    testWidgets('已声明区间只给范围，不出现"仍可继续"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeclaredLevelBanner(
              levels: DeclaredLevels(min: 1, max: 5),
              currentLevel: 3,
            ),
          ),
        ),
      );

      expect(find.text('职业声明：1–5 级'), findsOneWidget);
      expect(find.textContaining('仍可继续'), findsNothing);
      final theme = Theme.of(tester.element(find.byType(DeclaredLevelBanner)));
      expect(
        tester.widget<Icon>(find.byIcon(Icons.rule_outlined)).color,
        theme.colorScheme.primary,
      );
    });

    testWidgets('超出声明范围时追加提示，用 tertiary 而非 error 色', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeclaredLevelBanner(
              levels: DeclaredLevels(min: 1, max: 5),
              currentLevel: 8,
            ),
          ),
        ),
      );

      expect(find.text('职业声明：1–5 级'), findsOneWidget);
      expect(find.textContaining('该职业未声明 6 级以上内容'), findsOneWidget);
      expect(find.textContaining('仍可继续'), findsOneWidget);
      final theme = Theme.of(tester.element(find.byType(DeclaredLevelBanner)));
      expect(
        tester.widget<Icon>(find.byIcon(Icons.info_outline)).color,
        theme.colorScheme.tertiary,
      );
      expect(theme.colorScheme.tertiary, isNot(theme.colorScheme.error));
    });

    testWidgets('完全没有声明时不崩、不显示 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeclaredLevelBanner(
              levels: DeclaredLevels(min: 1),
              currentLevel: 8,
            ),
          ),
        ),
      );

      expect(find.text('该职业未声明任何等级内容'), findsOneWidget);
      expect(find.textContaining('0'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('创建向导：等级滑杆区分已声明 / 未声明区间', () {
    testWidgets('默认声明范围内滑杆用 primary，超出后转 tertiary 并给信息条', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterEditorPage(
            defaultCreationMethod: 'standard',
            contentEntries: [_partialClassEntry()],
            onSubmit: (_) async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('职业声明：1–5 级'), findsOneWidget);
      expect(find.text('已声明 1–5 级 · 6–20 级未声明'), findsOneWidget);
      expect(find.textContaining('仍可继续'), findsNothing);

      final theme = Theme.of(tester.element(find.byType(Slider)));
      expect(
        SliderTheme.of(tester.element(find.byType(Slider))).thumbColor,
        theme.colorScheme.primary,
      );

      // 升到 8 级：越过最后声明等级，滑杆与信息条同时变化。
      final increment = find.byKey(
        const Key('standard-level-increment-button'),
      );
      for (var i = 0; i < 7; i++) {
        await tester.ensureVisible(increment);
        await tester.tap(increment);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.textContaining('该职业未声明 6 级以上内容'), findsOneWidget);
      expect(find.textContaining('仍可继续'), findsOneWidget);
      expect(
        SliderTheme.of(tester.element(find.byType(Slider))).thumbColor,
        theme.colorScheme.tertiary,
      );
    });
  });

  group('角色卡：未声明等级不渲染成 0', () {
    testWidgets('低于最早声明等级时法术位与资源区都显示"未声明"', (tester) async {
      final character = _character(
        level: 3,
        classIdentity: _identity(min: 5, max: 10),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterDetailPage(
            character: character,
            initialTab: 'spells',
            onSaveCharacter: (_) async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('该职业未声明该等级的内容'), findsOneWidget);
      expect(find.text('暂无法术位'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterDetailPage(
            character: character,
            initialTab: 'resources',
            onSaveCharacter: (_) async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('该职业未声明该等级的内容'), findsOneWidget);
      expect(find.text('暂无可追踪资源'), findsNothing);
    });

    testWidgets('已声明等级有数值时不能说未声明（沿用语义不被覆盖）', (tester) async {
      final character = _character(
        level: 8,
        classIdentity: _identity(min: 1, max: 5),
        extraData: const <String, Object?>{
          'spellSlots': <String, int>{'1': 4, '2': 2},
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterDetailPage(
            character: character,
            initialTab: 'spells',
            onSaveCharacter: (_) async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('该职业未声明该等级的内容'), findsNothing);
    });
  });

  group('升级页：超出声明范围时在确认按钮上方提示', () {
    testWidgets('目标等级越过最后声明等级时出现信息条', (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterUpgradePage(
            character: _upgradeCharacter(level: 5),
            contentEntries: [_partialClassEntry()],
            onApply: (_) async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('该职业未声明 6 级以上内容'), findsOneWidget);
      expect(find.byType(DeclaredLevelBanner), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(DeclaredLevelBanner)).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('apply-upgrade'))).dy,
        ),
      );
    });

    testWidgets('目标等级仍在声明范围内时不出现信息条', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterUpgradePage(
            character: _upgradeCharacter(level: 3),
            contentEntries: [_partialClassEntry()],
            onApply: (_) async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DeclaredLevelBanner), findsNothing);
      expect(find.textContaining('仍可继续'), findsNothing);
    });
  });

  group('资料库规则视图：顶部显示声明范围', () {
    testWidgets('职业条目显示自身声明的范围，且不出现"超出"文案', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ContentCharacterRulesView(entry: _partialClassEntry()),
            ),
          ),
        ),
      );

      expect(find.byType(DeclaredLevelBanner), findsOneWidget);
      expect(find.text('职业声明：1–5 级'), findsOneWidget);
      expect(find.textContaining('仍可继续'), findsNothing);
    });

    testWidgets('未声明任何等级的职业条目显式说明"未声明"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ContentCharacterRulesView(
                entry: _entry(
                  id: 'test:class/bare',
                  type: 'class',
                  name: '无表职业',
                  rules: const <String, Object?>{'grants': <Object?>[]},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('该职业未声明任何等级内容'), findsOneWidget);
    });

    testWidgets('非职业条目（无声明范围）不显示职业声明信息条', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ContentCharacterRulesView(
                entry: _entry(
                  id: 'test:species/human',
                  type: 'species',
                  name: '人类',
                  rules: const <String, Object?>{
                    'grants': <Object?>[
                      <String, Object?>{
                        'id': 'speed',
                        'kind': 'speed',
                        'value': 30,
                        'label': '步行速度',
                      },
                    ],
                  },
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(DeclaredLevelBanner), findsNothing);
      expect(find.textContaining('职业声明'), findsNothing);
    });
  });

  group('导入预览：副标题显示声明范围', () {
    testWidgets('职业条目在预览里列出声明范围', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ContentImportPreviewDialog(
            report: _report(entries: [_partialClassEntry()]),
            onConfirm: () async {},
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('职业声明：1–5 级'), findsOneWidget);
      expect(find.textContaining('该职业未声明'), findsNothing);
    });

    testWidgets('完全没声明的职业条目给显式"未声明"副标题', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ContentImportPreviewDialog(
            report: _report(
              entries: [
                _entry(
                  id: 'test:class/bare',
                  type: 'class',
                  name: '无表职业',
                  rules: const <String, Object?>{'grants': <Object?>[]},
                ),
              ],
            ),
            onConfirm: () async {},
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('该职业未声明任何等级内容'), findsOneWidget);
    });
  });
}

ContentImportReport _report({List<ContentEntry> entries = const []}) {
  return ContentImportReport(
    valid: true,
    formatVersion: 3,
    packageId: 'test-pkg',
    packageName: '测试资料包',
    version: '1.0.0',
    locale: 'zh-CN',
    system: 'dnd5e-2024',
    entryCount: entries.length,
    entries: entries,
    errors: const [],
    assets: const {},
    contentHash: 'fake-hash',
  );
}

CharacterSheet _upgradeCharacter({required int level}) {
  return _character(
    level: level,
    classIdentity: _identity(min: 1, max: 5),
    extraData: <String, Object?>{
      'build': <String, Object?>{
        'level': level,
        'selections': <String, String>{'class': 'test:class/tester'},
        'choices': <String, List<String>>{},
      },
    },
  );
}
