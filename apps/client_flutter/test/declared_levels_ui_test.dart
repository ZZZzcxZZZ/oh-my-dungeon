import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/domain/declared_levels.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_detail_page.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_editor_page.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_upgrade_page.dart';
import 'package:dnd_table_client/src/features/characters/presentation/widgets/declared_level_banner.dart';
import 'package:dnd_table_client/src/features/characters/presentation/widgets/declared_level_track_shape.dart';
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

    test('undeclares 只在"有声明但超范围"时为真，完全没有声明时为假', () {
      const declared = DeclaredLevels(min: 5, max: 10);
      expect(declared.undeclares(3), isTrue, reason: '低于最早声明等级');
      expect(declared.undeclares(11), isTrue, reason: '高于最后声明等级');
      expect(declared.undeclares(5), isFalse);
      expect(declared.undeclares(10), isFalse);

      // 完全没有等级声明：这不是"该等级未声明"，而是"该职业没有等级表"。
      expect(const DeclaredLevels().undeclares(3), isFalse);
    });

    test('isDeclared 从 classIdentity.declared 读取，缺省为 true', () {
      expect(
        DeclaredLevels.isDeclared(
          _character(level: 3, classIdentity: _identity(min: 1, max: 5)),
        ),
        isTrue,
      );
      expect(
        DeclaredLevels.isDeclared(
          _character(
            level: 3,
            classIdentity: _identity(min: null, max: null, declared: false),
          ),
        ),
        isFalse,
        reason: '职业名解析不到档案 = 未声明',
      );
      // 没有 classIdentity（老存档 / 快速创建）：没有可比的"未声明"标记，
      // 按"已声明但没有等级表"处理，不能说成未知职业。
      expect(DeclaredLevels.isDeclared(_character(level: 3)), isTrue);
    });

    test('rangeLevelLabel 只在职业身份未声明时给范围级文案', () {
      expect(
        const DeclaredLevels(min: 1, max: 5).rangeLevelLabel(isDeclared: true),
        isNull,
        reason: '已声明但没有数值时由调用方说"暂无"，不是范围级文案',
      );
      expect(
        const DeclaredLevels().rangeLevelLabel(isDeclared: false),
        '该职业未声明任何等级内容',
        reason: '范围级文案与 rangeLabel 同一份实现',
      );
      // 身份未声明但记录里碰巧有范围（迁移期数据）：仍以 rangeLabel 为准，
      // 不把"不知道"渲染成"该职业没有"。
      expect(
        const DeclaredLevels(min: 1, max: 5).rangeLevelLabel(isDeclared: false),
        '职业声明：1–5 级',
      );
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
    testWidgets('轨道按已声明 / 未声明双色（primary / outlineVariant），越界给信息条', (
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
      var sliderTheme = SliderTheme.of(tester.element(find.byType(Slider)));
      // §3.12：未声明区间用 `outlineVariant`（不是 tertiary——那是"生命环·受伤"的
      // 角色），已声明区间用主题色；两者同时存在，轨道才是双色。
      expect(sliderTheme.activeTrackColor, theme.colorScheme.primary);
      expect(sliderTheme.inactiveTrackColor, theme.colorScheme.outlineVariant);
      expect(
        sliderTheme.inactiveTrackColor,
        isNot(theme.colorScheme.tertiary),
      );
      expect(sliderTheme.thumbColor, theme.colorScheme.primary);
      final shape = sliderTheme.trackShape;
      expect(shape, isA<DeclaredLevelTrackShape>());
      expect((shape! as DeclaredLevelTrackShape).levels.max, 5);
      expect((shape as DeclaredLevelTrackShape).levels.min, 1);

      // 升到 8 级：越过最后声明等级，信息条出现；轨道两色不变（区间没变）。
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
      sliderTheme = SliderTheme.of(tester.element(find.byType(Slider)));
      expect(sliderTheme.activeTrackColor, theme.colorScheme.primary);
      expect(sliderTheme.inactiveTrackColor, theme.colorScheme.outlineVariant);
    });
  });

  group('声明区间文案与轨道比例（唯一口径）', () {
    test('declaredRangeCaption 覆盖未声明 / 单侧未声明 / 全覆盖三种边界', () {
      expect(
        const DeclaredLevels(min: 1, max: 5).declaredRangeCaption,
        '已声明 1–5 级 · 6–20 级未声明',
      );
      expect(
        const DeclaredLevels(min: 5, max: 10).declaredRangeCaption,
        '已声明 5–10 级 · 1–4 级未声明 · 11–20 级未声明',
      );
      expect(
        const DeclaredLevels(min: 1, max: 20).declaredRangeCaption,
        '已声明 1–20 级',
      );
      expect(
        const DeclaredLevels().declaredRangeCaption,
        '该职业未声明任何等级 · 1–20 级均按未声明处理',
      );
    });

    test('min == max（稀疏表只声明一个等级）时区间不写成倒序或空档', () {
      // 稀疏 `{"5": …}`（或 progression 只有 [5]）让 min == max == 5：
      // 文案必须说"已声明 5–5 级"，两侧的未声明区间各说一次，不能出现
      // "已声明 5–5 级 · 5–4 级未声明" 这类倒序，也不能漏掉任何一侧。
      const single = DeclaredLevels(min: 5, max: 5);
      expect(single.declaredRangeCaption, '已声明 5–5 级 · 1–4 级未声明 · 6–20 级未声明');
      expect(single.rangeLabel, '职业声明：5–5 级');
      expect(single.covers(5), isTrue);
      expect(single.covers(4), isFalse);
      expect(single.covers(6), isFalse);

      // 边界：min == max == 1 只有右侧未声明；min == max == 20 只有左侧未声明。
      expect(
        const DeclaredLevels(min: 1, max: 1).declaredRangeCaption,
        '已声明 1–1 级 · 2–20 级未声明',
      );
      expect(
        const DeclaredLevels(min: 20, max: 20).declaredRangeCaption,
        '已声明 20–20 级 · 1–19 级未声明',
      );
    });

    test('declaredRangeFraction 对单级声明给零宽区间，仍画出可见的已声明段', () {
      // min == max 的区间比例宽度为 0，但它**不是**"没有已声明区间"：文案会写
      // "已声明 5–5 级"，轨道若整条都是未声明色就与文案自相矛盾。
      final single = DeclaredLevelTrackShape.declaredRangeFraction(
        levels: const DeclaredLevels(min: 5, max: 5),
        min: 1,
        max: 20,
      );
      expect(single, (4 / 19, 4 / 19), reason: '单级声明是零宽区间，不是 null');

      // 零宽区间落成像素时撑到最小可见宽度（1 逻辑像素），区间宽 > 0。
      final track = Rect.fromLTWH(0, 0, 380, 8);
      final rect = DeclaredLevelTrackShape.declaredTrackRect(
        track: track,
        fraction: single!,
      );
      expect(rect.width, kDeclaredTrackMinWidth);
      expect(rect.width, greaterThan(0));
      expect(rect.left, greaterThanOrEqualTo(track.left));
      expect(rect.right, lessThanOrEqualTo(track.right));

      // 轨道右端的单级声明（20 级）改为向左展开，同样不越界。
      final atEnd = DeclaredLevelTrackShape.declaredTrackRect(
        track: track,
        fraction: DeclaredLevelTrackShape.declaredRangeFraction(
          levels: const DeclaredLevels(min: 20, max: 20),
          min: 1,
          max: 20,
        )!,
      );
      expect(atEnd.width, kDeclaredTrackMinWidth);
      expect(atEnd.left, greaterThanOrEqualTo(track.left));
      expect(atEnd.right, lessThanOrEqualTo(track.right));

      // 倒序（min > max）仍是坏数据：不得画出负宽度轨道。
      expect(
        DeclaredLevelTrackShape.declaredRangeFraction(
          levels: const DeclaredLevels(min: 5, max: 4),
          min: 1,
          max: 20,
        ),
        isNull,
        reason: 'min > max 的坏数据不得画出负宽度轨道',
      );
    });

    test('declaredRangeFraction 用真实比例切分轨道', () {
      expect(
        DeclaredLevelTrackShape.declaredRangeFraction(
          levels: const DeclaredLevels(min: 1, max: 5),
          min: 1,
          max: 20,
        ),
        (0.0, 4 / 19),
      );
      expect(
        DeclaredLevelTrackShape.declaredRangeFraction(
          levels: const DeclaredLevels(min: 5, max: 10),
          min: 1,
          max: 20,
        ),
        (4 / 19, 9 / 19),
      );
      expect(
        DeclaredLevelTrackShape.declaredRangeFraction(
          levels: const DeclaredLevels(min: 1, max: 20),
          min: 1,
          max: 20,
        ),
        (0.0, 1.0),
      );
      expect(
        DeclaredLevelTrackShape.declaredRangeFraction(
          levels: const DeclaredLevels(),
          min: 1,
          max: 20,
        ),
        isNull,
        reason: '完全没有声明时整条轨道都是未声明色',
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

    testWidgets('完全没有等级声明时不说"未声明"（没有等级表的职业本来就没有法术位）', (
      tester,
    ) async {
      // max == null（无 classIdentity）：内置 rogue / monk 这类职业没有法术位表，
      // 快速创建也会落库 {min: null, max: null}——喊"该职业未声明该等级的内容"
      // 是错误陈述，应照实说"暂无法术位 / 暂无可追踪资源"。
      final character = _character(level: 5);

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

      expect(find.text('暂无法术位'), findsOneWidget);
      expect(find.textContaining('该职业未声明该等级的内容'), findsNothing);

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

      expect(find.text('暂无可追踪资源'), findsOneWidget);
      expect(find.textContaining('该职业未声明该等级的内容'), findsNothing);
    });

    testWidgets('职业身份未声明（declared: false）时说"未声明"，不说"没有"', (tester) async {
      // 职业名解析不到档案（未重导入的自制职业 / 老存档匹配失败）→
      // `classIdentity.declared == false`、`declaredLevels.max == null`。
      // 这和"已知职业但没有随等级变化的表"（rogue / monk）不是一回事：
      // 断言成"暂无法术位 / 暂无可追踪资源"就是把"未知"说成"没有"（§3.12）。
      final character = _character(
        level: 5,
        classIdentity: _identity(min: null, max: null, declared: false),
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

      expect(find.text('该职业未声明任何等级内容'), findsOneWidget);
      expect(
        find.text('暂无法术位'),
        findsNothing,
        reason: '"未声明"不能被断言成"该职业没有法术位"',
      );

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

      expect(find.text('该职业未声明任何等级内容'), findsOneWidget);
      expect(
        find.text('暂无可追踪资源'),
        findsNothing,
        reason: '"未声明"不能被断言成"该职业没有资源"',
      );
    });

    testWidgets('超出声明范围但已有数值时不显示"未声明"（沿用语义不被覆盖）', (
      tester,
    ) async {
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

    testWidgets('非职业条目即使带 classRules 也不显示"职业声明"（判据只看条目类型）', (
      tester,
    ) async {
      // 物种条目带了 `structured.classRules` 时能解析出 1–5 级，但"职业声明"是
      // 职业概念：资料库不能因为条目碰巧有规则块就凭空显示一条职业声明。
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ContentCharacterRulesView(
                entry: _entry(
                  id: 'test:species/human',
                  type: 'species',
                  name: '人类',
                  structured: const <String, Object?>{
                    'classRules': <String, Object?>{
                      'hitDie': 8,
                      'resources': <Object?>[
                        <String, Object?>{
                          'id': 'focus',
                          'name': '专注',
                          'recovery': 'longRest',
                          'maximum': <String, Object?>{
                            'table': <String, int>{'1': 2, '5': 4},
                          },
                        },
                      ],
                    },
                  },
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
